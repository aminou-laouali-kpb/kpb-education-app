// Comparateur de goldens qui tolère le BRUIT D'ANTI-CRÉNELAGE du texte, et
// rien d'autre.
//
// Pourquoi : `LocalFileComparator` exige l'égalité octet pour octet. Or le
// rasteriseur de glyphes de macOS bouge d'une machine / d'une version à l'autre :
// le golden `theme_gallery` (390×844, 329 160 px) diffère de 0,19 à 0,22 % entre
// deux Mac — écart médian 3/255, uniquement sur le CONTOUR des lettres, aucun
// pixel dans un aplat. Le golden de référence n'était donc reproductible que
// sur la machine qui l'avait généré, et rouge partout ailleurs sans qu'aucune
// régression n'existe (mesuré le 02/10/2026 : l'ANCIEN golden échouait aussi,
// avec l'ANCIEN code).
//
// Un comparateur tolérant ne vaut que s'il ÉCHOUE quand il le doit. Il juge donc
// la NATURE de l'écart, pas seulement sa taille. Les quatre conditions sont
// cumulatives :
//
//   1. mêmes dimensions ;
//   2. au plus [GoldenTolerance.maxDiffRatio] des pixels diffèrent ;
//   3. au plus [GoldenTolerance.maxStrongPixels] pixels s'écartent de plus de
//      [GoldenTolerance.strongDelta] sur 255 — un glyphe changé, déplacé ou
//      recoloré fait des dizaines de tels pixels, le bruit n'en fait pas ;
//   4. AUCUN pixel ne diffère au centre d'un bloc 3×3 uniforme dans les DEUX
//      images — c'est-à-dire qu'aucun aplat d'au moins 3×3 pixels ne change de
//      couleur. Un fond, un remplissage de bouton ou une couleur de token qui
//      bouge, même d'UNE unité, se voit ici et jamais dans le bruit de contour.
//
// Limites assumées, écrites plutôt que cachées (et épinglées par des tests qui
// portent leur nom dans `test/core/golden_tolerance_test.dart`) :
//
//   - un accent ou une ponctuation seuls (≲ 4 pixels forts) passent : le bruit
//     de rastérisation en produit autant. Mesuré sur la vraie galerie, retirer
//     l'accent de « Fermée » ajoute 7 pixels, dont un seul au-delà de 96 ;
//   - un trait d'un pixel de large qui change de peu (un séparateur, 0,1 % des
//     pixels) passe : aucun aplat, aucun pixel fort, sous le budget de pixels.
//     En revanche la bordure d'une carte (≈ 0,7 %) est refusée par ce budget.
//
// Le comparateur sert à décider « même rendu, autre Mac ? », pas à certifier un
// texte à l'accent près — les traductions ont leurs propres tests. Pour une
// exactitude au pixel, garder le comparateur par défaut.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Image RGBA 8 bits : 4 octets par pixel, ligne par ligne.
class RgbaImage {
  RgbaImage(this.width, this.height, this.rgba)
      : assert(rgba.length == width * height * 4, 'RGBA length mismatch');

  /// Image unie, pratique pour construire des cas de test.
  factory RgbaImage.filled(
    int width,
    int height, {
    int r = 255,
    int g = 255,
    int b = 255,
    int a = 255,
  }) {
    final bytes = Uint8List(width * height * 4);
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = r;
      bytes[i + 1] = g;
      bytes[i + 2] = b;
      bytes[i + 3] = a;
    }
    return RgbaImage(width, height, bytes);
  }

  final int width;
  final int height;
  final Uint8List rgba;

  RgbaImage copy() => RgbaImage(width, height, Uint8List.fromList(rgba));

  void setPixel(int x, int y, int r, int g, int b, [int a = 255]) {
    final i = (y * width + x) * 4;
    rgba[i] = r;
    rgba[i + 1] = g;
    rgba[i + 2] = b;
    rgba[i + 3] = a;
  }

  /// Décode un PNG. Doit tourner hors du temps simulé d'un `testWidgets` (le
  /// comparateur de `matchesGoldenFile` le fait déjà ; un test direct passe par
  /// `tester.runAsync` ou un simple `test()`).
  static Future<RgbaImage> decode(List<int> png) async {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(png));
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = data!.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        return RgbaImage(image.width, image.height, Uint8List.fromList(bytes));
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}

/// Seuils de [judgeGolden]. Les défauts sont calibrés sur la paire réelle
/// archivée dans `test/core/golden_tolerance_fixtures/` (bruit mesuré : 0,22 %
/// des pixels, écart max 71/255, 0 pixel au-delà de 96) et vérifiés contre des
/// mutations volontaires dans `test/core/golden_tolerance_test.dart`.
class GoldenTolerance {
  const GoldenTolerance({
    this.maxDiffRatio = 0.005,
    this.strongDelta = 96,
    this.maxStrongPixels = 4,
  });

  /// Part maximale de pixels qui diffèrent (0,005 = 0,5 %, soit ~2,3× le bruit
  /// mesuré).
  final double maxDiffRatio;

  /// Un pixel est « fort » si l'un de ses canaux (alpha compris) s'écarte de
  /// plus de ce nombre sur 255.
  final int strongDelta;

  /// Nombre de pixels « forts » toléré (quelques aberrants de rastérisation).
  final int maxStrongPixels;
}

/// Verdict chiffré de [judgeGolden].
class GoldenVerdict {
  GoldenVerdict({
    required this.accepted,
    required this.reasons,
    required this.width,
    required this.height,
    required this.differing,
    required this.flatDiffering,
    required this.histogram,
    required this.strongDelta,
  });

  final bool accepted;

  /// Une phrase par condition violée ; vide si [accepted].
  final List<String> reasons;
  final int width;
  final int height;

  /// Pixels dont au moins un canal diffère.
  final int differing;

  /// Pixels qui diffèrent au milieu d'un aplat des DEUX images.
  final int flatDiffering;

  /// `histogram[d]` = nombre de pixels dont l'écart maximal par canal vaut `d`.
  final List<int> histogram;
  final int strongDelta;

  int get total => width * height;
  double get ratio => total == 0 ? 0 : differing / total;
  int get maxDelta {
    for (var d = 255; d > 0; d--) {
      if (histogram[d] > 0) return d;
    }
    return 0;
  }

  /// Pixels dont l'écart maximal par canal dépasse strictement [delta].
  int countAbove(int delta) {
    var n = 0;
    for (var d = delta + 1; d < 256; d++) {
      n += histogram[d];
    }
    return n;
  }

  int get strong => countAbove(strongDelta);

  String describe() {
    final pct = (ratio * 100).toStringAsFixed(3);
    return '$differing px sur $total ($pct %), écart max $maxDelta/255, '
        '$strong pixel(s) au-delà de $strongDelta, '
        '$flatDiffering pixel(s) différent(s) dans un aplat';
  }
}

/// Juge si l'écart entre [reference] et [render] est du bruit de contour de
/// glyphes (voir l'en-tête du fichier). Fonction pure : aucune E/S.
GoldenVerdict judgeGolden(
  RgbaImage reference,
  RgbaImage render, [
  GoldenTolerance tolerance = const GoldenTolerance(),
]) {
  final histogram = List<int>.filled(256, 0);
  if (reference.width != render.width || reference.height != render.height) {
    return GoldenVerdict(
      accepted: false,
      reasons: [
        'dimensions différentes : référence '
            '${reference.width}×${reference.height}, '
            'rendu ${render.width}×${render.height}',
      ],
      width: reference.width,
      height: reference.height,
      differing: reference.width * reference.height,
      flatDiffering: 0,
      histogram: histogram,
      strongDelta: tolerance.strongDelta,
    );
  }

  final w = reference.width;
  final h = reference.height;
  final a = reference.rgba;
  final b = render.rgba;
  var differing = 0;
  var flatDiffering = 0;

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      var delta = 0;
      for (var c = 0; c < 4; c++) {
        final d = (a[i + c] - b[i + c]).abs();
        if (d > delta) delta = d;
      }
      if (delta == 0) continue;
      differing++;
      histogram[delta]++;
      if (_isFlat(a, w, h, x, y) && _isFlat(b, w, h, x, y)) flatDiffering++;
    }
  }

  final measured = GoldenVerdict(
    accepted: true,
    reasons: const [],
    width: w,
    height: h,
    differing: differing,
    flatDiffering: flatDiffering,
    histogram: histogram,
    strongDelta: tolerance.strongDelta,
  );

  final reasons = <String>[];
  if (measured.ratio > tolerance.maxDiffRatio) {
    reasons.add(
      'trop de pixels diffèrent : ${(measured.ratio * 100).toStringAsFixed(3)} % '
      '> ${(tolerance.maxDiffRatio * 100).toStringAsFixed(3)} % toléré',
    );
  }
  if (measured.strong > tolerance.maxStrongPixels) {
    reasons.add(
      "${measured.strong} pixel(s) s'écartent de plus de "
      '${tolerance.strongDelta}/255 (${tolerance.maxStrongPixels} toléré(s)) — '
      'pas du bruit de contour : glyphe, couleur ou position modifié',
    );
  }
  if (flatDiffering > 0) {
    reasons.add(
      "$flatDiffering pixel(s) diffèrent au milieu d'un aplat — fond, "
      'remplissage ou couleur de token modifié (le bruit de rastérisation '
      "n'atteint jamais un aplat)",
    );
  }

  return GoldenVerdict(
    accepted: reasons.isEmpty,
    reasons: reasons,
    width: w,
    height: h,
    differing: differing,
    flatDiffering: flatDiffering,
    histogram: histogram,
    strongDelta: tolerance.strongDelta,
  );
}

/// Vrai si les 9 pixels du voisinage 3×3 de (x, y) sont identiques. Hors image,
/// on retient le pixel le plus proche (bord prolongé).
bool _isFlat(Uint8List px, int w, int h, int x, int y) {
  final base = (y * w + x) * 4;
  for (var dy = -1; dy <= 1; dy++) {
    final yy = (y + dy).clamp(0, h - 1);
    for (var dx = -1; dx <= 1; dx++) {
      final xx = (x + dx).clamp(0, w - 1);
      final j = (yy * w + xx) * 4;
      if (px[j] != px[base] ||
          px[j + 1] != px[base + 1] ||
          px[j + 2] != px[base + 2] ||
          px[j + 3] != px[base + 3]) {
        return false;
      }
    }
  }
  return true;
}

/// Comparateur local qui n'accepte un écart que si [judgeGolden] l'a jugé
/// inoffensif. Une égalité exacte passe sans autre examen ; `--update-goldens`
/// reste celui de `LocalFileComparator`.
class TolerantGoldenComparator extends LocalFileComparator {
  TolerantGoldenComparator(
    super.testFile, {
    this.tolerance = const GoldenTolerance(),
  });

  final GoldenTolerance tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final goldenBytes = await getGoldenBytes(golden);
    final exact = await GoldenFileComparator.compareLists(
      imageBytes,
      goldenBytes,
    );
    if (exact.passed) {
      exact.dispose();
      return true;
    }

    final verdict = judgeGolden(
      await RgbaImage.decode(goldenBytes),
      await RgbaImage.decode(imageBytes),
      tolerance,
    );
    if (verdict.accepted) {
      exact.dispose();
      debugPrint('[golden] $golden : écart toléré (${verdict.describe()})');
      return true;
    }

    final output = await generateFailureOutput(exact, golden, basedir);
    exact.dispose();
    throw FlutterError(
      '$output\n\nLe comparateur tolérant refuse cet écart '
      '(${verdict.describe()}) :\n'
      '${verdict.reasons.map((r) => '  - $r').join('\n')}',
    );
  }
}

/// À appeler en tête de `main()` d'un fichier de golden : remplace le
/// comparateur exact par [TolerantGoldenComparator] pour ce fichier seulement
/// (chaque fichier de test tourne dans son propre isolat, et l'ancien
/// comparateur est rétabli en fin de fichier).
void useTolerantGoldenComparator({
  GoldenTolerance tolerance = const GoldenTolerance(),
}) {
  final previous = goldenFileComparator;
  if (previous is! LocalFileComparator) {
    throw StateError(
      'useTolerantGoldenComparator attend un LocalFileComparator, '
      'trouvé ${previous.runtimeType}.',
    );
  }
  goldenFileComparator = TolerantGoldenComparator(
    previous.basedir.resolve('golden_file.dart'),
    tolerance: tolerance,
  );
  tearDownAll(() => goldenFileComparator = previous);
}
