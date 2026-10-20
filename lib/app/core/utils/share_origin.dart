// ─────────────────────────────────────────────────────────────────────────────
// Partage système protégé, compatible iPad (audit 57, F12).
//
// Sur iPad, la feuille de partage s'ouvre en popover : elle a besoin d'un point
// d'ancrage. share_plus 12 renvoie une erreur (« sharePositionOrigin: argument
// must be set ») quand ce rectangle est absent ou vide, et rien ne s'ouvre :
// « Partager mon lien », l'export « Mes données » et les invitations ne
// faisaient rien sur iPad. Tout partage de l'app passe donc par [kpbShare], qui
// calcule l'origine depuis le bouton touché et affiche une erreur au lieu de
// laisser l'exception remonter.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../ui/components/kpb_toast.dart';

/// Rectangle d'ancrage, en coordonnées globales, de la feuille de partage.
///
/// Celui du widget de [context] (le bouton touché) quand il est mesurable ;
/// sinon un petit carré au centre de l'écran. Jamais vide : un rectangle vide
/// fait échouer le partage sur iPad.
Rect shareOriginFor(BuildContext? context) {
  if (context != null && context.mounted) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize && !box.size.isEmpty) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.maybeSizeOf(context);
    if (size != null && !size.isEmpty) return _centre(size);
  }
  final views = ui.PlatformDispatcher.instance.views;
  if (views.isNotEmpty) {
    final view = views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    if (!size.isEmpty) return _centre(size);
  }
  return const Rect.fromLTWH(0, 0, 1, 1);
}

Rect _centre(Size size) =>
    Rect.fromCenter(center: size.center(Offset.zero), width: 1, height: 1);

/// Ouvre la feuille de partage du système, ancrée sur [context].
///
/// Ne lève jamais : un refus du système affiche [errorMessage] (par défaut
/// `share_error`) et renvoie `false`. [showError] à `false` laisse l'appelant
/// gérer l'échec lui-même.
///
/// L'origine est calculée AVANT tout `await` : passée l'ouverture, le bouton
/// peut avoir quitté l'écran.
Future<bool> kpbShare(
  BuildContext? context, {
  String? text,
  String? subject,
  List<XFile>? files,
  String? errorMessage,
  bool showError = true,
}) async {
  final origin = shareOriginFor(context);
  try {
    await SharePlus.instance.share(ShareParams(
      text: text,
      subject: subject,
      files: files,
      sharePositionOrigin: origin,
    ));
    return true;
  } catch (_) {
    if (showError) KpbToast.error(errorMessage ?? 'share_error'.tr);
    return false;
  }
}
