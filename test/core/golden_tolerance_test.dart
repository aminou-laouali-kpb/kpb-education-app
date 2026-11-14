// Contre-épreuve du comparateur de goldens tolérant.
//
// Un comparateur qui accepte un écart ne prouve rien tant qu'on ne l'a pas vu
// REFUSER un vrai changement. Ces tests font donc les deux, sur deux paires
// réelles (voir `golden_tolerance_fixtures/README.md`) :
//
//   - le bruit d'anti-crénelage mesuré entre deux Mac est ACCEPTÉ ;
//   - les mêmes images, MUTÉES (un aplat qui bouge d'une unité, un mot décalé,
//     tout l'écran décalé d'un pixel), sont REFUSÉES.
//
// Et la limite connue est épinglée par un test qui porte son nom, pour que la
// documentation du comparateur ne puisse pas dériver sans que ça se voie.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/golden_tolerance.dart';

const _fixtures = 'test/core/golden_tolerance_fixtures';
const _pairs = ['2026-10-02', '2026-08-08'];

Uint8List _bytes(String name) => File('$_fixtures/$name').readAsBytesSync();

Future<RgbaImage> _load(String name) => RgbaImage.decode(_bytes(name));

Future<Uint8List> _encodePng(RgbaImage image) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    image.rgba,
    image.width,
    image.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final decoded = await completer.future;
  final data = await decoded.toByteData(format: ui.ImageByteFormat.png);
  decoded.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

List<int> _px(RgbaImage image, int x, int y) {
  final i = (y * image.width + x) * 4;
  return image.rgba.sublist(i, i + 4);
}

/// Cadre du bouton « Action principale » dans la galerie (aplat bleu).
const _primaryButton = (x0: 24, y0: 175, x1: 366, y1: 215);

/// Rangée de texte « Carte standard ».
const _cardLabelRow = (x0: 30, y0: 412, x1: 150, y1: 434);

void main() {
  late RgbaImage reference;
  late RgbaImage render;

  setUpAll(() async {
    reference = await _load('pair_2026-10-02_reference.png');
    render = await _load('pair_2026-10-02_render.png');
  });

  List<(int, int)> inkSpots(int n) {
    // Pixels déjà identiques dans les deux images, déjà « clairs », et dont
    // le voisinage n'est pas un aplat : la peinture tombe au bord d'un glyphe.
    final spots = <(int, int)>[];
    for (var y = 25; y < 50 && spots.length < n; y++) {
      for (var x = 20; x < 260 && spots.length < n; x += 7) {
        final a = _px(reference, x, y);
        final b = _px(render, x, y);
        final light = a[0] > 200 && a[1] > 200 && a[2] > 200;
        final same = a[0] == b[0] && a[1] == b[1] && a[2] == b[2];
        final nearInk = [
          _px(reference, x + 1, y),
          _px(reference, x - 1, y),
          _px(reference, x, y + 1),
          _px(reference, x, y - 1),
        ].any((p) => p[0] < 160);
        if (light && same && nearInk) spots.add((x, y));
      }
    }
    expect(spots.length, n, reason: 'pas assez de points d\'encre trouvés');
    return spots;
  }

  RgbaImage withInk(int n, {int delta = 240}) {
    final m = render.copy();
    for (final (x, y) in inkSpots(n)) {
      final p = _px(render, x, y);
      // Assombrit le pixel de `delta` unités sur chaque canal.
      int dark(int v) => (v - delta).clamp(0, 255);
      m.setPixel(x, y, dark(p[0]), dark(p[1]), dark(p[2]));
    }
    return m;
  }

  group('bruit réel entre deux Mac : ACCEPTÉ', () {
    for (final date in _pairs) {
      test('paire $date', () async {
        final ref = await _load('pair_${date}_reference.png');
        final img = await _load('pair_${date}_render.png');
        final verdict = judgeGolden(ref, img);

        // Garde-fou contre une fixture vide de sens : si la paire devenait
        // identique, « accepté » ne prouverait plus rien.
        expect(
          verdict.differing,
          greaterThan(300),
          reason: 'la paire $date doit contenir un vrai bruit',
        );
        expect(verdict.accepted, isTrue, reason: verdict.describe());
        expect(verdict.flatDiffering, 0, reason: verdict.describe());
        expect(verdict.strong, 0, reason: verdict.describe());
        // Marge : le bruit réel reste sous la moitié du budget de pixels.
        expect(
          verdict.ratio,
          lessThan(const GoldenTolerance().maxDiffRatio / 2),
          reason: verdict.describe(),
        );
      });
    }

    test('une image identique à elle-même : zéro écart', () {
      final verdict = judgeGolden(reference, reference);
      expect(verdict.accepted, isTrue);
      expect(verdict.differing, 0);
      expect(verdict.maxDelta, 0);
    });
  });

  group('mutations du rendu réel : REFUSÉES', () {
    test('un aplat qui bouge d\'UNE unité (couleur de token)', () {
      // La mutation la plus sournoise : invisible à l'œil, ~16 000 pixels.
      final m = render.copy();
      final c = _px(reference, 40, 195);
      expect(
        c.take(3).toList(),
        [0x25, 0x63, 0xEB],
        reason: 'le cadre du bouton doit tomber sur l\'aplat actionPrimary',
      );
      for (var y = _primaryButton.y0; y < _primaryButton.y1; y++) {
        for (var x = _primaryButton.x0; x < _primaryButton.x1; x++) {
          final p = _px(m, x, y);
          if (p[0] == 0x25 && p[1] == 0x63 && p[2] == 0xEB) {
            m.setPixel(x, y, p[0], p[1], p[2] + 1);
          }
        }
      }
      final verdict = judgeGolden(reference, m);
      expect(verdict.accepted, isFalse, reason: verdict.describe());
      expect(verdict.flatDiffering, greaterThan(1000));
      expect(verdict.maxDelta, lessThan(96), reason: 'écart de 1 : sans force');
    });

    test('un mot décalé de 3 px', () {
      final m = render.copy();
      for (var y = _cardLabelRow.y0; y < _cardLabelRow.y1; y++) {
        for (var x = _cardLabelRow.x1; x > _cardLabelRow.x0 + 3; x--) {
          final p = _px(render, x - 3, y);
          m.setPixel(x, y, p[0], p[1], p[2], p[3]);
        }
      }
      final verdict = judgeGolden(reference, m);
      expect(verdict.accepted, isFalse, reason: verdict.describe());
      expect(
        verdict.strong,
        greaterThan(const GoldenTolerance().maxStrongPixels),
        reason: verdict.describe(),
      );
    });

    test('tout l\'écran décalé d\'un pixel (padding +1)', () {
      final m = RgbaImage.filled(render.width, render.height);
      for (var y = 0; y < render.height; y++) {
        for (var x = 1; x < render.width; x++) {
          final p = _px(render, x - 1, y);
          m.setPixel(x, y, p[0], p[1], p[2], p[3]);
        }
      }
      final verdict = judgeGolden(reference, m);
      expect(verdict.accepted, isFalse, reason: verdict.describe());
    });

    test('dimensions différentes', () {
      final verdict = judgeGolden(
        reference,
        RgbaImage.filled(render.width, render.height + 1),
      );
      expect(verdict.accepted, isFalse);
      expect(verdict.reasons.single, contains('dimensions différentes'));
    });
  });

  group('chaque condition est vivante (seuils resserrés, même paire)', () {
    // Sans ces trois tests, on pourrait casser l'une des conditions sans
    // qu'aucun autre test ne le voie : les mutations ci-dessus tombent souvent
    // sous plusieurs conditions à la fois.
    test('budget de pixels', () {
      final v = judgeGolden(
        reference,
        render,
        const GoldenTolerance(maxDiffRatio: 0.001),
      );
      expect(v.accepted, isFalse);
      expect(v.reasons.single, contains('trop de pixels diffèrent'));
    });

    test('pixels forts', () {
      final v = judgeGolden(
        reference,
        render,
        const GoldenTolerance(strongDelta: 50, maxStrongPixels: 0),
      );
      expect(v.accepted, isFalse);
      expect(v.reasons.single, contains("s'écartent de plus de 50/255"));
    });

    test('aplat', () {
      // Un bloc 7×7 du fond de page, décalé de 2 unités : les 5×5 pixels du
      // centre ont un voisinage 3×3 uniforme dans les DEUX images.
      final m = render.copy();
      final bg = _px(reference, 4, 4);
      expect(bg.take(3).toList(), [0xF8, 0xFA, 0xFC], reason: 'fond de page');
      for (var y = 2; y < 9; y++) {
        for (var x = 2; x < 9; x++) {
          m.setPixel(x, y, bg[0] + 2, bg[1], bg[2]);
        }
      }
      final v = judgeGolden(reference, m);
      expect(v.accepted, isFalse);
      expect(v.flatDiffering, 25);
      expect(v.reasons.single, contains("au milieu d'un aplat"));
    });
  });

  test('« aplat » se juge dans les DEUX images, pas dans le seul rendu', () {
    // Une marque isolée et discrète (écart 25/255) présente dans la référence
    // seulement : le rendu est uniforme autour de ce pixel, la référence non.
    // Tester le rendu seul la compterait comme « aplat modifié » ; or c'est la
    // forme exacte d'un fil d'anti-crénelage qui apparaît ou disparaît.
    final ref = RgbaImage.filled(20, 20);
    ref.setPixel(10, 10, 230, 230, 230);
    final img = RgbaImage.filled(20, 20);

    final v = judgeGolden(ref, img);
    expect(v.differing, 1);
    expect(v.flatDiffering, 0, reason: v.describe());
    expect(v.accepted, isTrue, reason: v.describe());
  });

  group('LIMITES CONNUES — ce que le comparateur ne voit pas', () {
    // Écrit pour que la limite soit un fait vérifié et non une promesse. Un
    // accent ou une ponctuation, ce sont quelques pixels (mesuré sur la vraie
    // galerie : « Fermée » → « Fermee » ajoute 7 pixels, dont 1 seul au-delà
    // de 96/255). Le bruit de rastérisation en produit autant : les distinguer
    // ferait rejeter des Mac légitimes. Si ce test devient rouge parce que le
    // comparateur est devenu plus fin, bravo — mettre à jour l'en-tête de
    // `golden_tolerance.dart` en même temps.
    test('${const GoldenTolerance().maxStrongPixels} pixels forts : tolérés',
        () {
      final n = const GoldenTolerance().maxStrongPixels;
      final v = judgeGolden(reference, withInk(n));
      expect(v.strong, greaterThanOrEqualTo(n));
      expect(v.accepted, isTrue, reason: v.describe());
    });

    test('un de plus : refusé (la borne est exacte)', () {
      final n = const GoldenTolerance().maxStrongPixels + 1;
      final v = judgeGolden(reference, withInk(n));
      expect(v.accepted, isFalse, reason: v.describe());
    });

    test('un séparateur d\'un pixel, écart 8/255, 340 px : passe', () {
      // Aucun aplat (chaque pixel du trait a un voisinage non uniforme), aucun
      // pixel fort, 0,1 % des pixels : sous les trois budgets. Seule la
      // comparaison exacte verrait un trait de ce genre.
      final m = render.copy();
      final bg = _px(reference, 4, 4);
      for (var x = 20; x < 360; x++) {
        m.setPixel(x, 800, bg[0] - 8, bg[1] - 8, bg[2] - 8);
      }
      final v = judgeGolden(reference, m);
      expect(v.differing, greaterThanOrEqualTo(340));
      expect(v.accepted, isTrue, reason: v.describe());
    });
  });

  group('réglage PAR DÉFAUT : les bornes sont épinglées en valeurs absolues',
      () {
    // Les tests ci-dessus utilisent `maxStrongPixels + 1` ou des seuils passés
    // à la main : desserrer un défaut (budget ×10, pixels forts ×25) les
    // laissait tous verts — mesuré en cassant volontairement le comparateur.
    // Ici les nombres sont littéraux : changer un défaut doit être un geste
    // délibéré, qui oblige à relire ce fichier et l'en-tête du comparateur.

    RgbaImage withVerticalLines(int count) {
      // Lignes d'un pixel dans la marge (fond de page), écart 8/255 : ni aplat,
      // ni pixel fort — seul le budget de pixels peut les refuser.
      final m = render.copy();
      final bg = _px(reference, 4, 4);
      for (var i = 0; i < count; i++) {
        final x = 3 + 3 * i;
        for (var y = 0; y < m.height; y++) {
          m.setPixel(x, y, bg[0] - 8, bg[1] - 8, bg[2] - 8);
        }
      }
      return m;
    }

    test('budget de pixels : 1 ligne (0,26 % + bruit) passe, 2 lignes non', () {
      final one = judgeGolden(reference, withVerticalLines(1));
      expect(one.accepted, isTrue, reason: one.describe());
      expect(one.strong, 0);
      expect(one.flatDiffering, 0);

      final two = judgeGolden(reference, withVerticalLines(2));
      expect(two.accepted, isFalse, reason: two.describe());
      expect(two.reasons.single, contains('trop de pixels diffèrent'));
    });

    test('pixels forts, nombre : 4 passent, 9 non', () {
      expect(judgeGolden(reference, withInk(4)).accepted, isTrue);
      expect(judgeGolden(reference, withInk(9)).accepted, isFalse);
    });

    test('pixels forts, écart : 9 pixels à 90/255 passent, à 104/255 non', () {
      final soft = judgeGolden(reference, withInk(9, delta: 90));
      expect(soft.strong, 0, reason: soft.describe());
      expect(soft.accepted, isTrue, reason: soft.describe());

      final hard = judgeGolden(reference, withInk(9, delta: 104));
      expect(hard.strong, 9, reason: hard.describe());
      expect(hard.accepted, isFalse, reason: hard.describe());
    });
  });

  group('TolerantGoldenComparator (fichiers réels)', () {
    late Directory dir;
    late TolerantGoldenComparator comparator;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('kpb_golden_tolerance_');
      File('${dir.path}/golden.png').writeAsBytesSync(
        _bytes('pair_2026-10-02_reference.png'),
      );
      comparator =
          TolerantGoldenComparator(Uri.file('${dir.path}/t_test.dart'));
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('égalité exacte : passe', () async {
      expect(
        await comparator.compare(
          _bytes('pair_2026-10-02_reference.png'),
          Uri.parse('golden.png'),
        ),
        isTrue,
      );
    });

    test('bruit de contour réel : passe, et le dit', () async {
      final lines = <String>[];
      final old = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => lines.add(m ?? '');
      addTearDown(() => debugPrint = old);

      expect(
        await comparator.compare(
          _bytes('pair_2026-10-02_render.png'),
          Uri.parse('golden.png'),
        ),
        isTrue,
      );
      expect(lines.single, contains('écart toléré'));
      expect(lines.single, contains('728 px'));
    });

    test('rendu muté : FlutterError chiffrée, images de diff écrites',
        () async {
      final m = render.copy();
      for (var y = _primaryButton.y0; y < _primaryButton.y1; y++) {
        for (var x = _primaryButton.x0; x < _primaryButton.x1; x++) {
          final p = _px(m, x, y);
          if (p[2] == 0xEB) m.setPixel(x, y, p[0], p[1], 0xEA);
        }
      }
      final png = await _encodePng(m);

      await expectLater(
        comparator.compare(png, Uri.parse('golden.png')),
        throwsA(
          isA<FlutterError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Le comparateur tolérant refuse cet écart'),
              contains("au milieu d'un aplat"),
              contains('px sur 329160'),
            ),
          ),
        ),
      );
      expect(
        Directory('${dir.path}/failures').existsSync(),
        isTrue,
        reason: 'les images de diff doivent être écrites comme avant',
      );
    });
  });
}
