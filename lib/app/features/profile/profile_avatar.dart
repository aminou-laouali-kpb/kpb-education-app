import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/app_tokens.dart';
import 'profile_avatar_error.dart';
import '../../core/ui/components/kpb_toast.dart';

/// What we currently know about the server-side photo.
enum AvatarPresence {
  /// Not probed yet — the widget may try to fetch.
  unknown,

  /// Fetched and decoded at least once this visit, or just uploaded.
  present,

  /// Confirmed absent: the fetch 404'd, or the user just removed it.
  absent,

  /// The fetch failed for some other reason. Renders the initials exactly like
  /// [absent], but is NOT re-attempted for the rest of this screen visit — a
  /// flaky link must not turn into a request per rebuild on a metered plan.
  unavailable,
}

/// Downscale budget, chosen for the audience: entry-level Android phones on
/// prepaid data in West Africa.
///
/// 512×512 at quality 80 lands around 40–80 KB for a portrait — two orders of
/// magnitude under the 3–5 MB a modern phone camera produces, and well under
/// the server's 2 MB cap. The resize and re-encode are done by the PLATFORM
/// encoder inside image_picker (not in Dart), which is what makes this cheap on
/// a low-end device. Re-encoding also normalises iOS HEIC to JPEG.
const double kAvatarMaxDimension = 512;
const int kAvatarJpegQuality = 80;

/// Server cap. Checked locally so an over-size file never costs the upload.
const int kAvatarMaxUploadBytes = 2 * 1024 * 1024;

/// Circular profile photo with the initials as fallback, plus the whole
/// add / replace / remove flow behind a tap.
///
/// Why [CachedNetworkImage] directly instead of `KpbNetworkImage`: the avatar
/// endpoint is authenticated, so it needs `httpHeaders`, and replacing a photo
/// needs an explicit `cacheKey` to bust the old bytes. Neither is exposed by
/// the shared wrapper. The two policies that wrapper exists for are kept:
/// decode memory is bounded via `memCacheWidth`, and the failure path is a
/// deliberate fallback rather than a broken-image glyph. Data-saver mode does
/// NOT suppress it — this is the user's own identity, not decoration, and it is
/// under 100 KB and cached.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.profile,
    required this.initials,
    this.size = 54,
    this.editable = true,
    this.apiClient,
    this.picker,
  });

  final UserProfile profile;

  /// Fallback glyph, computed by the caller so the initials rule stays in one
  /// place.
  final String initials;

  final double size;

  /// False hides the camera badge and the tap target (read-only surfaces).
  final bool editable;

  /// Injectable for tests; defaults to the app controller's client.
  final AppApiClient? apiClient;
  final ImagePicker? picker;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  late final AppApiClient _api = widget.apiClient ?? _resolveApiClient();
  late final ImagePicker _picker = widget.picker ?? ImagePicker();

  Map<String, String>? _headers;
  bool _headersResolved = false;
  bool _busy = false;

  /// Seeded from the profile: `hasAvatar` is a POSITIVE hint only. True means
  /// the server says there is a photo, so the remove action is offered before
  /// the first byte arrives. False is NOT trusted as "no photo" — the flag is
  /// only as fresh as the last profile pull — so we still probe, and the 404
  /// path settles it.
  late AvatarPresence _presence = widget.profile.hasAvatar
      ? AvatarPresence.present
      : AvatarPresence.unknown;

  /// The file we just uploaded, rendered immediately instead of downloading
  /// back the very bytes we sent. Saves a round trip of airtime and makes the
  /// change visible even if the authenticated re-fetch then fails.
  /// Aperçu immédiat après envoi : les octets déjà en main, plutôt qu'un
  /// second aller-retour réseau pour retélécharger ce qu'on vient d'envoyer.
  Uint8List? _localPreview;

  /// Bumped on every successful upload/removal so the widget stops reading the
  /// previous bytes. Starts at 0 so a cold start reuses the disk cache — the
  /// photo can only change through this widget, so there is nothing else to
  /// invalidate.
  int _cacheNonce = 0;

  static AppApiClient _resolveApiClient() {
    try {
      return Get.find<AppController>().apiClient;
    } catch (_) {
      return AppApiClient();
    }
  }

  String get _cacheKey =>
      'kpb_profile_avatar_${widget.profile.id}_$_cacheNonce';

  @override
  void initState() {
    super.initState();
    _resolveHeaders();
  }

  /// Resolves the bearer header once. A null result (guest, signed out, or
  /// Supabase not initialised as in widget tests) means "render the initials
  /// and never touch the network".
  Future<void> _resolveHeaders() async {
    Map<String, String>? headers;
    try {
      headers = await _api.authImageHeaders();
    } catch (_) {
      headers = null;
    }
    if (!mounted) return;
    setState(() {
      _headers = headers;
      _headersResolved = true;
    });
  }

  bool get _canShowPhoto =>
      _headersResolved &&
      _headers != null &&
      _presence != AvatarPresence.absent &&
      _presence != AvatarPresence.unavailable;

  @override
  Widget build(BuildContext context) {
    final avatar = SizedBox(
      width: widget.size,
      height: widget.size,
      child: _busy ? _uploading() : _face(),
    );

    if (!widget.editable) return avatar;

    return Semantics(
      button: true,
      label: 'profile_avatar_a11y_label'.tr,
      // The header card is a decorated Container, not a Material, so without
      // this the ripple would paint on the Scaffold *behind* the white card and
      // stay invisible.
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: _busy ? null : _openSheet,
          customBorder: const CircleBorder(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    color: KpbColors.actionPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _face() {
    final preview = _localPreview;
    if (preview != null) {
      return ClipOval(
        child: Image.memory(
          preview,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsCircle(),
        ),
      );
    }

    if (!_canShowPhoto) return _initialsCircle();

    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final memWidth = (widget.size * dpr).clamp(64, 1024).round();

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: _api.avatarStreamUrl,
        cacheKey: _cacheKey,
        httpHeaders: _headers,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        memCacheWidth: memWidth,
        placeholder: (_, __) => _initialsCircle(),
        imageBuilder: (_, imageProvider) {
          _markPresence(AvatarPresence.present);
          return Image(
            image: imageProvider,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          );
        },
        errorWidget: (_, __, ___) {
          // A 404 (no photo) and a transient failure are indistinguishable here
          // without reaching into flutter_cache_manager's exception type, so
          // both stop further attempts for this visit. Reopening the screen or
          // taking a new photo retries.
          _markPresence(AvatarPresence.unavailable);
          return _initialsCircle();
        },
      ),
    );
  }

  /// Records what the image load told us, after the current frame — the
  /// builders above run *during* build, where setState is illegal.
  void _markPresence(AvatarPresence value) {
    if (_presence == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _presence == value) return;
      setState(() => _presence = value);
    });
  }

  Widget _initialsCircle() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        color: KpbColors.brandNavy,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        widget.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.size / 3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _uploading() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        color: KpbColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: widget.size / 2.6,
        height: widget.size / 2.6,
        child: const CircularProgressIndicator(
          strokeWidth: 2.2,
          color: KpbColors.actionPrimary,
        ),
      ),
    );
  }

  // ── Flow ────────────────────────────────────────────────────────────────

  Future<void> _openSheet() async {
    final canRemove = _presence == AvatarPresence.present;
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'profile_avatar_sheet_title'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: KpbColors.brandNavy,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: KpbColors.actionPrimary),
              title: Text('profile_avatar_take_photo'.tr),
              onTap: () => Navigator.pop(ctx, _AvatarAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: KpbColors.actionPrimary),
              title: Text('profile_avatar_choose_photo'.tr),
              onTap: () => Navigator.pop(ctx, _AvatarAction.gallery),
            ),
            if (canRemove)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: KpbColors.error),
                title: Text(
                  'profile_avatar_remove'.tr,
                  style: const TextStyle(color: KpbColors.error),
                ),
                onTap: () => Navigator.pop(ctx, _AvatarAction.remove),
              ),
            ListTile(
              leading:
                  const Icon(Icons.close_rounded, color: KpbColors.textMuted),
              title: Text('cancel'.tr),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case _AvatarAction.camera:
        await _pickAndUpload(ImageSource.camera);
      case _AvatarAction.gallery:
        await _pickAndUpload(ImageSource.gallery);
      case _AvatarAction.remove:
        await _confirmAndRemove();
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: kAvatarMaxDimension,
        maxHeight: kAvatarMaxDimension,
        imageQuality: kAvatarJpegQuality,
        // No EXIF/location harvesting: it avoids the extra iOS metadata
        // permission prompt and keeps GPS coordinates out of the upload.
        requestFullMetadata: false,
      );
    } catch (error) {
      _showFailure(error);
      return;
    }
    // Cancelling the picker is not a failure — say nothing, show nothing.
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      // `XFile.length()`/`readAsBytes()` plutôt que `File(picked.path)` : le
      // XFile connaît sa propre source, et le chemin peut ne pas exister.
      final bytes = await picked.readAsBytes();
      final size = bytes.lengthInBytes;
      if (size > kAvatarMaxUploadBytes) {
        throw AvatarTooLargeLocally(
          sizeBytes: size,
          maxBytes: kAvatarMaxUploadBytes,
        );
      }

      final updated = await _api.uploadAvatar(
        bytes: bytes,
        fileName: _uploadFileName(picked),
      );

      // Drop the bytes the previous key points at, then move to a new key so
      // the replacement is fetched instead of the stale image.
      final staleKey = _cacheKey;
      if (!mounted) return;
      setState(() {
        _cacheNonce++;
        _presence = presenceFromProfileJson(updated) ?? AvatarPresence.present;
        _localPreview = bytes;
      });
      // Purge du cache NON bloquante : `evictFromCache` passe par
      // flutter_cache_manager, donc par un canal de plateforme. L'attendre
      // faisait dépendre l'affichage d'une opération de ménage — un cache
      // verrouillé, un disque plein ou un canal muet figeait l'avatar sur son
      // indicateur de chargement, sans erreur et sans sortie.
      unawaited(_evict(staleKey));
      _showSuccess('profile_avatar_updated'.tr);
    } catch (error) {
      _showFailure(error);
    } finally {
      // The screen must never stay stuck on the spinner, whatever failed.
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile_avatar_remove_confirm_title'.tr),
        content: Text('profile_avatar_remove_confirm_body'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: KpbColors.error),
            child: Text('profile_avatar_remove'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      try {
        await _api.deleteAvatar();
      } on Object catch (error) {
        // Removal is idempotent: "there was nothing to remove" is the outcome
        // the user asked for, not a failure to report.
        if (!isAvatarAlreadyAbsent(error)) rethrow;
      }
      final staleKey = _cacheKey;
      if (!mounted) return;
      setState(() {
        _cacheNonce++;
        _presence = AvatarPresence.absent;
        _localPreview = null;
      });
      // Purge du cache NON bloquante : `evictFromCache` passe par
      // flutter_cache_manager, donc par un canal de plateforme. L'attendre
      // faisait dépendre l'affichage d'une opération de ménage — un cache
      // verrouillé, un disque plein ou un canal muet figeait l'avatar sur son
      // indicateur de chargement, sans erreur et sans sortie.
      unawaited(_evict(staleKey));
      _showSuccess('profile_avatar_removed'.tr);
    } catch (error) {
      _showFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _evict(String cacheKey) async {
    try {
      await CachedNetworkImage.evictFromCache(
        _api.avatarStreamUrl,
        cacheKey: cacheKey,
      );
    } catch (_) {
      // Cache housekeeping only — never surfaced to the user.
    }
  }

  String _uploadFileName(XFile file) {
    final name = file.name.trim();
    if (name.isNotEmpty && name.contains('.')) return name;
    return 'avatar.jpg';
  }

  void _showSuccess(String message) {
    KpbToast.success(
      message,
      title: 'profile_avatar_sheet_title'.tr,
    );
  }

  void _showFailure(Object error) {
    final failure = classifyAvatarFailure(error);
    KpbToast.error(
      avatarFailureMessageKey(failure).tr,
      title: 'profile_avatar_sheet_title'.tr,
    );
  }
}

enum _AvatarAction { camera, gallery, remove }

/// Reads the avatar state out of the profile payload the upload returns.
///
/// The contract allows either shape — a `hasAvatar` boolean or the URL of the
/// authenticated endpoint — and forbids a storage path. Null when the payload
/// says nothing, in which case the caller keeps its own conclusion (a 2xx
/// answer to POST means the photo is there).
AvatarPresence? presenceFromProfileJson(Map<String, dynamic> json) {
  final flag = json['hasAvatar'];
  if (flag is bool) {
    return flag ? AvatarPresence.present : AvatarPresence.absent;
  }
  final url = json['avatarUrl'];
  if (url is String) {
    return url.trim().isEmpty ? AvatarPresence.absent : AvatarPresence.present;
  }
  if (json.containsKey('avatarUrl') && json['avatarUrl'] == null) {
    return AvatarPresence.absent;
  }
  return null;
}
