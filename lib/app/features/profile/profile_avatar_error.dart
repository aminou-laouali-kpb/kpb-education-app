import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show PlatformException;

/// Why a profile-photo change failed, at the granularity the USER can act on.
///
/// Deliberately NOT a single bucket. « Vérifiez votre connexion » on every
/// failure is what hid a dead `/api` path in production for weeks on this
/// project (see the `_normalizePath` note in `AppApiClient`): the message
/// blamed the student's network for a server-side 404. So here every case the
/// backend distinguishes gets its own message, and [network] is reserved for a
/// genuine transport failure — nothing else may fall into it.
enum AvatarFailure {
  /// `AVATAR_TOO_LARGE` (413). Practically unreachable after the 512 px
  /// downscale, kept as a real, distinct answer.
  fileTooLarge,

  /// `AVATAR_TYPE_NOT_ALLOWED` (415) — byte-signature sniffing refused the
  /// content. The server accepts JPEG, PNG and WebP only.
  unsupportedType,

  /// `AVATAR_FILE_EMPTY` / `AVATAR_FILE_REQUIRED` (400) — nothing usable
  /// arrived. Actionable: pick another photo.
  fileUnreadable,

  /// `AVATAR_INFECTED` (422). The scan found something IN THIS FILE, so
  /// retrying the same photo cannot succeed — the user must pick another.
  infected,

  /// `AVATAR_SCANNER_UNAVAILABLE` (503). The scanner could not deliver a
  /// verdict and the backend fails CLOSED. Not the user's fault; retryable.
  scannerUnavailable,

  /// `AVATAR_STORAGE_UNAVAILABLE` (503), or a 503 with no code. Not the user's
  /// fault; retryable.
  serviceUnavailable,

  /// `AVATAR_UPLOAD_CONFLICT` (409) — a concurrent change won the row.
  /// Retryable, and nothing was lost server-side.
  conflict,

  /// `PROFILE_NOT_FOUND` (404) — the server has no profile row for this
  /// session. Not a photo problem.
  profileMissing,

  /// No valid session (401/403).
  unauthorized,

  /// Throttled (429).
  rateLimited,

  /// The OS denied camera or photo-library access. Retrying in-app cannot fix
  /// it — the user has to grant it in the system settings.
  permissionDenied,

  /// GENUINE transport failure: timeout, DNS, socket, no route to host.
  network,

  /// 5xx other than 503.
  server,

  /// Anything we could not classify. Gets its OWN message — never borrows the
  /// network one — so an unexpected server answer stays visible as such.
  unknown,
}

// Codes from `backend/src/modules/profiles/profile-avatar.errors.ts`
// (`ProfileAvatarErrorCode`). The body carries `code`; the HTTP status is used
// as the fallback so a proxy that strips the body still yields a truthful
// message. `AVATAR_NOT_FOUND` is deliberately absent: on GET it simply means
// "no photo" (the initials fallback), and DELETE is idempotent — neither is an
// error the user should read about.
const _codeToFailure = <String, AvatarFailure>{
  'AVATAR_TOO_LARGE': AvatarFailure.fileTooLarge,
  'AVATAR_TYPE_NOT_ALLOWED': AvatarFailure.unsupportedType,
  'AVATAR_FILE_EMPTY': AvatarFailure.fileUnreadable,
  'AVATAR_FILE_REQUIRED': AvatarFailure.fileUnreadable,
  'AVATAR_INFECTED': AvatarFailure.infected,
  'AVATAR_SCANNER_UNAVAILABLE': AvatarFailure.scannerUnavailable,
  'AVATAR_STORAGE_UNAVAILABLE': AvatarFailure.serviceUnavailable,
  'AVATAR_UPLOAD_CONFLICT': AvatarFailure.conflict,
  'PROFILE_NOT_FOUND': AvatarFailure.profileMissing,
};

/// image_picker / platform channel codes meaning "permission refused".
const _permissionDeniedPlatformCodes = <String>{
  'camera_access_denied',
  'photo_access_denied',
};

/// Reads the backend `code` out of a Dio error body, upper-cased. Null when the
/// body carries none (older backend, HTML error page, empty 503…).
String? avatarFailureCode(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final raw = data['code'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim().toUpperCase();
    }
  }
  return null;
}

/// True when a DELETE failed only because there was nothing left to delete.
/// Removal is idempotent by contract, so this is a SUCCESS for the user, not an
/// error to read.
bool isAvatarAlreadyAbsent(Object error) {
  if (error is! DioException) return false;
  if (error.response?.statusCode != 404) return false;
  final code = avatarFailureCode(error);
  return code == null || code == 'AVATAR_NOT_FOUND';
}

/// Classifies any error thrown by the pick → upload → delete path.
AvatarFailure classifyAvatarFailure(Object error) {
  if (error is AvatarTooLargeLocally) return AvatarFailure.fileTooLarge;

  if (error is PlatformException) {
    return _permissionDeniedPlatformCodes.contains(error.code)
        ? AvatarFailure.permissionDenied
        : AvatarFailure.unknown;
  }

  if (error is SocketException || error is TimeoutException) {
    return AvatarFailure.network;
  }

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return AvatarFailure.network;
      // badCertificate, cancel, badResponse, unknown — et toute valeur que
      // Dio ajouterait demain : c'est le corps codé puis le statut qui
      // tranchent. Pas de liste exhaustive ici, sinon un `pub upgrade` qui
      // ajoute un `DioExceptionType` casse la compilation.
      default:
        break;
    }

    // The coded body is authoritative — it is the only thing that tells the
    // two 503 causes apart (fail-closed scanner vs. storage down).
    final coded = _codeToFailure[avatarFailureCode(error)];
    if (coded != null) return coded;

    final status = error.response?.statusCode;
    switch (status) {
      case 400:
        // A 400 with no code is a rejected file, never a network problem.
        return AvatarFailure.fileUnreadable;
      case 401:
      case 403:
        return AvatarFailure.unauthorized;
      case 409:
        return AvatarFailure.conflict;
      case 413:
        return AvatarFailure.fileTooLarge;
      case 415:
        return AvatarFailure.unsupportedType;
      case 422:
        // The antivirus gate is the only 422 on this endpoint.
        return AvatarFailure.infected;
      case 429:
        return AvatarFailure.rateLimited;
      case 503:
        // Without the code the two causes are indistinguishable, so the message
        // must be true of both: "the service is down, not your photo".
        return AvatarFailure.serviceUnavailable;
    }
    if (status != null && status >= 500) return AvatarFailure.server;
    return AvatarFailure.unknown;
  }

  return AvatarFailure.unknown;
}

/// Translation key for the message shown to the user. One key per case.
String avatarFailureMessageKey(AvatarFailure failure) {
  switch (failure) {
    case AvatarFailure.fileTooLarge:
      return 'profile_avatar_error_too_large';
    case AvatarFailure.unsupportedType:
      return 'profile_avatar_error_unsupported_type';
    case AvatarFailure.fileUnreadable:
      return 'profile_avatar_error_unreadable';
    case AvatarFailure.conflict:
      return 'profile_avatar_error_conflict';
    case AvatarFailure.profileMissing:
      return 'profile_avatar_error_profile_missing';
    case AvatarFailure.infected:
      return 'profile_avatar_error_infected';
    case AvatarFailure.scannerUnavailable:
      return 'profile_avatar_error_scan_unavailable';
    case AvatarFailure.serviceUnavailable:
      return 'profile_avatar_error_service_unavailable';
    case AvatarFailure.unauthorized:
      return 'profile_avatar_error_unauthorized';
    case AvatarFailure.rateLimited:
      return 'profile_avatar_error_rate_limited';
    case AvatarFailure.permissionDenied:
      return 'profile_avatar_error_permission_denied';
    case AvatarFailure.network:
      return 'profile_avatar_error_network';
    case AvatarFailure.server:
      return 'profile_avatar_error_server';
    case AvatarFailure.unknown:
      return 'profile_avatar_error_unknown';
  }
}

/// Raised before any network call when the downscaled file is still over the
/// server cap — it saves the student the airtime of an upload that would 413.
class AvatarTooLargeLocally implements Exception {
  const AvatarTooLargeLocally(
      {required this.sizeBytes, required this.maxBytes});

  final int sizeBytes;
  final int maxBytes;

  @override
  String toString() =>
      'Avatar is $sizeBytes bytes, over the $maxBytes byte limit.';
}
