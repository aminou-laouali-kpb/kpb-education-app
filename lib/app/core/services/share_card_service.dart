// ─────────────────────────────────────────────────────────────────────────────
// Shared "result card" sharing (KPB-165).
//
// Turns any widget wrapped in a RepaintBoundary into a PNG and hands it to the
// OS share sheet together with an attribution link. Extracted from the one-off
// implementation that lived inside program_detail_screen so every shareable
// result (eligibility verdict, match, budget) behaves the same and is measured
// the same.
//
// Degrades honestly: if rendering or encoding fails we still share the TEXT
// (which carries the invite link), and the analytics event records that the
// image was missing rather than silently reporting a normal share.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/share_link.dart';
import 'analytics_service.dart';

class ShareCardService {
  ShareCardService._();
  static final instance = ShareCardService._();

  /// Renders [boundaryKey] to a PNG and shares it with [text].
  ///
  /// Returns true when the share sheet was handed a file, false when we fell
  /// back to a text-only share. Never throws — a failed share must not take a
  /// screen down.
  Future<bool> shareBoundary({
    required GlobalKey boundaryKey,
    required String text,
    required ShareSource source,
    double pixelRatio = 3,
  }) async {
    File? file;
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (bytes != null) {
          final out = File(
            '${Directory.systemTemp.path}/kpb_${source.wireName}_'
            '${DateTime.now().millisecondsSinceEpoch}.png',
          );
          await out.writeAsBytes(bytes.buffer.asUint8List());
          file = out;
        }
      }
    } catch (_) {
      // Fall through to the text-only share below.
      file = null;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files:
              file == null ? null : [XFile(file.path, mimeType: 'image/png')],
        ),
      );
    } catch (_) {
      // The OS sheet itself refused — report it, don't crash the caller.
      unawaited(AnalyticsService.instance.logShareCard(
        source: source.wireName,
        withImage: false,
        success: false,
      ));
      return false;
    }

    unawaited(AnalyticsService.instance.logShareCard(
      source: source.wireName,
      withImage: file != null,
      success: true,
    ));
    return file != null;
  }
}
