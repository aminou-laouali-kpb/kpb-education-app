// Parrainage côté app (build 57 / 2.3.1) : le code du parrain, de l'invitation
// jusqu'au rattachement confirmé.
//
// Trois responsabilités, et une règle commune — RIEN NE PART SANS L'ÉLÈVE :
//
//   1. Play Install Referrer (Android) : lu UNE fois par installation, derrière
//      `features.referralInstallReferrer`. On en extrait `ref` (format STRICT
//      des codes réels) et on le garde EN LOCAL pour préremplir un champ. Aucun
//      appel réseau ici : le code ne part que quand l'élève appuie sur
//      « Valider le code ».
//   2. Identifiant d'installation : un UUID v4 ALÉATOIRE (jamais l'IMEI, jamais
//      l'identifiant publicitaire), créé au premier rattachement demandé et
//      envoyé dans l'en-tête `X-KPB-Device-Id` de `POST /referrals/redeem` —
//      et d'aucune autre requête. Une réinstallation en crée un nouveau
//      (`android:allowBackup="false"` : rien n'est restauré).
//   3. Le rattachement lui-même (`POST /referrals/redeem`), avec une issue
//      FERMÉE par cas d'erreur, que l'onboarding et l'écran Parrainage
//      traduisent chacun en un message clair.

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../repositories/app_api_client.dart';
import '../utils/app_logger.dart';

/// Les formats RÉELS des codes de parrainage (voir
/// `backend/src/modules/referrals/referral-code.ts` et `referrals.service.ts`).
///
/// * code PERSONNEL : 8 caractères de l'alphabet sans ambiguïté du serveur
///   (`ABCDEFGHJKLMNPQRSTUVWXYZ23456789` — ni I, ni O, ni 0, ni 1) ;
/// * code AMBASSADEUR : `KTOU-XX-######` (deux initiales, une seule pour les
///   codes distribués avant l'unification, puis six caractères base 36).
///
/// La stricte égalité de forme ne sert qu'au PRÉREMPLISSAGE depuis un lien :
/// une saisie manuelle part telle quelle, le serveur reste juge (404).
abstract final class ReferralCodeFormat {
  static final _personal = RegExp(r'^[A-HJ-NP-Z2-9]{8}$');
  static final _ambassador = RegExp(r'^KTOU-[A-Z]{1,2}-[0-9A-Z]{6}$');

  /// Le code en majuscules s'il a l'une des deux formes réelles, sinon `null`.
  static String? normalize(String? raw) {
    final code = (raw ?? '').trim().toUpperCase();
    if (code.isEmpty || code.length > 16) return null;
    if (_personal.hasMatch(code) || _ambassador.hasMatch(code)) return code;
    return null;
  }

  /// Extrait `ref` de la chaîne servie par le Play Install Referrer.
  ///
  /// Le lien d'`invite.html` porte
  /// `referrer=utm_source=invite&utm_medium=referral&ref=<CODE>` (la valeur
  /// encodée une fois). Google Play rend normalement la valeur DÉCODÉE ; une
  /// valeur restée encodée (`utm_source%3Dinvite%26…%26ref%3DKTOU…`) est
  /// décodée une fois de plus. Toute autre forme — clé absente, valeur vide,
  /// format inconnu, encodage cassé, chaîne démesurée — rend `null` : rien
  /// n'est prérempli, l'élève saisit son code à la main.
  static String? fromInstallReferrer(String? raw) {
    var text = (raw ?? '').trim();
    if (text.isEmpty || text.length > 1024) return null;
    if (!text.contains('=') && text.toLowerCase().contains('%3d')) {
      try {
        text = Uri.decodeComponent(text);
      } catch (_) {
        return null;
      }
    }
    if (text.startsWith('?')) text = text.substring(1);
    final Map<String, String> params;
    try {
      params = Uri.splitQueryString(text);
    } catch (_) {
      return null;
    }
    return normalize(params['ref']);
  }
}

/// D'où vient le code gardé en local.
enum PendingReferralOrigin {
  /// Le lien d'invitation, via le Play Install Referrer.
  installReferrer,

  /// Saisi par l'élève, mais pas encore validé (hors ligne, limite horaire).
  typed;

  String get wireName => switch (this) {
        PendingReferralOrigin.installReferrer => 'install_referrer',
        PendingReferralOrigin.typed => 'typed',
      };

  static PendingReferralOrigin? fromWire(Object? raw) => switch (raw) {
        'install_referrer' => PendingReferralOrigin.installReferrer,
        'typed' => PendingReferralOrigin.typed,
        _ => null,
      };
}

/// Un code en attente de confirmation par l'élève.
@immutable
class PendingReferralCode {
  const PendingReferralCode({required this.code, required this.origin});

  final String code;
  final PendingReferralOrigin origin;

  Map<String, String> toJson() => {'code': code, 'origin': origin.wireName};

  static PendingReferralCode? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final code = raw['code'];
    final origin = PendingReferralOrigin.fromWire(raw['origin']);
    if (code is! String || code.trim().isEmpty || origin == null) return null;
    return PendingReferralCode(code: code.trim(), origin: origin);
  }
}

/// Le stockage LOCAL du parrainage. Interface pour les tests (une panne de
/// stockage ne se simule pas avec un vrai `SharedPreferences`) ; chaque méthode
/// peut lever, l'appelant traite l'échec.
abstract interface class ReferralLocalStore {
  Future<bool> installReferrerChecked();
  Future<void> markInstallReferrerChecked();
  Future<PendingReferralCode?> readPendingCode();
  Future<void> writePendingCode(PendingReferralCode code);
  Future<void> clearPendingCode();
  Future<String?> readInstallId();
  Future<void> writeInstallId(String id);
}

/// `SharedPreferences`, sous des clés versionnées de l'espace de noms de l'app.
/// Rien de tout cela n'est sauvegardé ailleurs que sur l'appareil.
class SharedPreferencesReferralStore implements ReferralLocalStore {
  const SharedPreferencesReferralStore();

  static const checkedKey =
      '${AppConfig.storageNamespace}.referral_install_referrer_checked_v1';
  static const pendingKey =
      '${AppConfig.storageNamespace}.referral_pending_code_v1';
  static const installIdKey = '${AppConfig.storageNamespace}.install_id_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static void _ensure(bool ok, String what) {
    if (!ok) throw StateError('Écriture refusée : $what');
  }

  @override
  Future<bool> installReferrerChecked() async =>
      (await _prefs).getBool(checkedKey) ?? false;

  @override
  Future<void> markInstallReferrerChecked() async =>
      _ensure(await (await _prefs).setBool(checkedKey, true), checkedKey);

  @override
  Future<PendingReferralCode?> readPendingCode() async {
    final raw = (await _prefs).getString(pendingKey);
    if (raw == null) return null;
    try {
      return PendingReferralCode.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writePendingCode(PendingReferralCode code) async => _ensure(
        await (await _prefs).setString(pendingKey, jsonEncode(code.toJson())),
        pendingKey,
      );

  @override
  Future<void> clearPendingCode() async => (await _prefs).remove(pendingKey);

  @override
  Future<String?> readInstallId() async =>
      (await _prefs).getString(installIdKey);

  @override
  Future<void> writeInstallId(String id) async =>
      _ensure(await (await _prefs).setString(installIdKey, id), installIdKey);
}

/// Lit la chaîne brute du Play Install Referrer.
typedef InstallReferrerReader = Future<String?> Function();

Future<String?> _readPlayInstallReferrer() async =>
    (await PlayInstallReferrer.installReferrer).installReferrer;

/// L'issue d'un `POST /referrals/redeem`, en valeurs FERMÉES (elles servent
/// aussi de valeur `result` à la mesure d'audience — jamais un texte serveur).
enum ReferralRedeemOutcome {
  /// Rattachement créé.
  attributed,

  /// Déjà parrainé (idempotent) : un SUCCÈS silencieux pour l'élève.
  alreadyReferred,

  /// 404 (ou 400 de forme) : code inconnu.
  unknownCode,

  /// 403 : c'est le code de l'élève lui-même.
  selfReferral,

  /// 403 : parrainage croisé, ou dossier déjà déposé.
  notAllowed,

  /// 429 `referral_code_rate_limited` : réessayer plus tard.
  rateLimited,

  /// Pas de réseau (connexion, délai) : réessayer plus tard.
  offline,

  /// Toute autre panne.
  error;

  String get wireName => switch (this) {
        ReferralRedeemOutcome.attributed => 'attributed',
        ReferralRedeemOutcome.alreadyReferred => 'already_referred',
        ReferralRedeemOutcome.unknownCode => 'unknown_code',
        ReferralRedeemOutcome.selfReferral => 'self_referral',
        ReferralRedeemOutcome.notAllowed => 'not_allowed',
        ReferralRedeemOutcome.rateLimited => 'rate_limited',
        ReferralRedeemOutcome.offline => 'offline',
        ReferralRedeemOutcome.error => 'error',
      };

  /// Le rattachement est acquis (créé ou déjà fait).
  bool get isSuccess =>
      this == ReferralRedeemOutcome.attributed ||
      this == ReferralRedeemOutcome.alreadyReferred;

  /// Un nouvel essai plus tard peut réussir avec le MÊME code.
  bool get isRetryable =>
      this == ReferralRedeemOutcome.rateLimited ||
      this == ReferralRedeemOutcome.offline ||
      this == ReferralRedeemOutcome.error;

  /// Lit une réponse ou une erreur de `POST /referrals/redeem`.
  static ReferralRedeemOutcome fromResponse(Map<String, dynamic> body) {
    if (body['alreadyReferred'] == true) {
      return ReferralRedeemOutcome.alreadyReferred;
    }
    if (body['attributed'] == true) return ReferralRedeemOutcome.attributed;
    return ReferralRedeemOutcome.error;
  }

  static ReferralRedeemOutcome fromError(Object error) {
    if (error is! DioException) return ReferralRedeemOutcome.error;
    final status = error.response?.statusCode;
    if (status == null) {
      return switch (error.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          ReferralRedeemOutcome.offline,
        _ => ReferralRedeemOutcome.error,
      };
    }
    switch (status) {
      case 404:
      case 400:
        return ReferralRedeemOutcome.unknownCode;
      case 403:
        // Le serveur ne sert pas de code machine pour ses 403 : seul le message
        // de l'auto-parrainage est reconnu, tout autre refus reste générique.
        final data = error.response?.data;
        final message = data is Map ? '${data['message']}' : '$data';
        return message.toLowerCase().contains('own referral code')
            ? ReferralRedeemOutcome.selfReferral
            : ReferralRedeemOutcome.notAllowed;
      case 429:
        return ReferralRedeemOutcome.rateLimited;
      default:
        return ReferralRedeemOutcome.error;
    }
  }
}

/// Le parrainage côté app : referrer, identifiant d'installation, rattachement.
class ReferralAttribution {
  ReferralAttribution({
    ReferralLocalStore? store,
    InstallReferrerReader? readInstallReferrer,
    bool Function()? isAndroid,
    String Function()? newInstallId,
  })  : _store = store ?? const SharedPreferencesReferralStore(),
        _readInstallReferrer = readInstallReferrer ?? _readPlayInstallReferrer,
        _isAndroid = isAndroid ?? _defaultIsAndroid,
        _newInstallId = newInstallId ?? (() => const Uuid().v4());

  static ReferralAttribution _instance = ReferralAttribution();

  static ReferralAttribution get instance => _instance;

  /// Remplace l'instance partagée (tests).
  @visibleForTesting
  static set instanceForTest(ReferralAttribution? value) =>
      _instance = value ?? ReferralAttribution();

  final ReferralLocalStore _store;
  final InstallReferrerReader _readInstallReferrer;
  final bool Function() _isAndroid;
  final String Function() _newInstallId;

  Future<void>? _capture;

  /// `dart:io` dit le système HÔTE : dans `flutter test`, c'est Linux ou macOS,
  /// jamais Android — aucune lecture du referrer dans les tests, même quand
  /// `defaultTargetPlatform` est simulé. Sur le web, `Platform` n'existe pas.
  static bool _defaultIsAndroid() => !kIsWeb && Platform.isAndroid;

  /// Lit le Play Install Referrer, UNE fois par installation.
  ///
  /// Rien ne se passe si [enabled] est faux (drapeau
  /// `features.referralInstallReferrer` fermé), hors Android ou sur le web —
  /// sans rien marquer : la lecture aura lieu au premier démarrage où le
  /// drapeau est ouvert. L'installation est marquée « lue » AVANT l'appel, pour
  /// qu'un échec, une absence ou une app tuée en plein appel ne donnent jamais
  /// lieu à une seconde lecture. Ne lève jamais.
  Future<void> captureInstallReferrerOnce({required bool enabled}) {
    if (!enabled || !_isAndroid()) return Future<void>.value();
    return _capture ??= _doCapture();
  }

  Future<void> _doCapture() async {
    try {
      if (await _store.installReferrerChecked()) return;
      await _store.markInstallReferrerChecked();
    } catch (error) {
      // Stockage en panne : on ne lit pas — une lecture qu'on ne saurait pas
      // marquer se répéterait à chaque démarrage.
      AppLogger.warning('Referral store unavailable: $error',
          tag: 'ReferralAttribution');
      return;
    }
    try {
      final code = ReferralCodeFormat.fromInstallReferrer(
        await _readInstallReferrer(),
      );
      if (code == null) return;
      // Un code déjà saisi par l'élève n'est jamais écrasé par le lien.
      if (await _store.readPendingCode() != null) return;
      await _store.writePendingCode(PendingReferralCode(
        code: code,
        origin: PendingReferralOrigin.installReferrer,
      ));
    } catch (error) {
      // Pas de Google Play, service indisponible, iOS : rien, saisie manuelle.
      AppLogger.warning('Install referrer unavailable: $error',
          tag: 'ReferralAttribution');
    }
  }

  /// Le code en attente de confirmation, ou `null`. Ne lève jamais.
  Future<PendingReferralCode?> pendingCode() async {
    try {
      return await _store.readPendingCode();
    } catch (_) {
      return null;
    }
  }

  /// Garde un code SAISI que le serveur n'a pas pu traiter (hors ligne, limite
  /// horaire) : l'écran Parrainage le proposera. Ne lève jamais.
  Future<void> rememberTypedCode(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.length < 4 || code.length > 16) return;
    try {
      await _store.writePendingCode(PendingReferralCode(
        code: code,
        origin: PendingReferralOrigin.typed,
      ));
    } catch (_) {}
  }

  /// Oublie le code en attente. Ne lève jamais.
  Future<void> clearPendingCode() async {
    try {
      await _store.clearPendingCode();
    } catch (_) {}
  }

  /// L'identifiant d'installation (UUID v4 aléatoire), créé au premier besoin.
  /// `null` si le stockage est en panne : l'en-tête est alors omis plutôt que
  /// d'envoyer un identifiant éphémère qui ne désignerait rien. Ne lève jamais.
  Future<String?> installId() async {
    try {
      final existing = await _store.readInstallId();
      if (existing != null && existing.isNotEmpty) return existing;
      final created = _newInstallId();
      await _store.writeInstallId(created);
      return created;
    } catch (_) {
      return null;
    }
  }

  /// `POST /referrals/redeem` pour [rawCode], confirmé par l'élève.
  ///
  /// Succès (créé ou déjà parrainé) : le code en attente est oublié. Refus
  /// définitif (code inconnu, auto-parrainage, refus) : oublié s'il s'agit du
  /// code en attente. Panne passagère
  /// (hors ligne, limite horaire, erreur) : le code est GARDÉ, pour que l'écran
  /// Parrainage le repropose. Ne lève jamais.
  Future<ReferralRedeemOutcome> redeem(
    AppApiClient api,
    String rawCode,
  ) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return ReferralRedeemOutcome.unknownCode;
    ReferralRedeemOutcome outcome;
    try {
      final deviceId = await installId();
      outcome = ReferralRedeemOutcome.fromResponse(
        await api.redeemReferral(code, deviceId: deviceId),
      );
    } catch (error) {
      outcome = ReferralRedeemOutcome.fromError(error);
    }
    final pending = await pendingCode();
    if (outcome.isRetryable) {
      if (pending?.code != code) await rememberTypedCode(code);
    } else if (outcome.isSuccess || pending?.code == code) {
      // Un refus définitif n'efface que CE code : une faute de frappe ne fait
      // pas perdre le code du lien d'invitation encore en attente.
      await clearPendingCode();
    }
    return outcome;
  }
}
