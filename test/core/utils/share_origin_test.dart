// Audit 57, F12 — partage impossible sur iPad.
//
// Sur iPad, share_plus 12 refuse d'ouvrir la feuille de partage quand
// `sharePositionOrigin` est absent ou vide (« sharePositionOrigin: argument
// must be set ») : « Partager mon lien », l'export « Mes données » et les
// invitations ne faisaient rien. Tout partage passe désormais par `kpbShare`,
// ancré sur le bouton touché, et un refus du système affiche une erreur.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/utils/share_origin.dart';

import '../../support/lib_scan.dart';

const _channel = MethodChannel('dev.fluttercommunity.plus/share');

/// Fichiers autorisés à parler à share_plus : l'utilitaire, et le service des
/// cartes (qui ajoute une image) — lui aussi ancré via [shareOriginFor].
const _shareFiles = {
  'lib/app/core/utils/share_origin.dart',
  'lib/app/core/services/share_card_service.dart',
};

/// Les blocs `ShareParams( … )` d'un source, parenthèses équilibrées.
Iterable<String> _shareParamsBlocks(String source) sync* {
  var from = 0;
  while (true) {
    final start = source.indexOf('ShareParams(', from);
    if (start < 0) return;
    var depth = 0;
    var i = start + 'ShareParams'.length;
    for (; i < source.length; i++) {
      final ch = source[i];
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    yield source.substring(start, i + 1);
    from = i + 1;
  }
}

Future<void> _drainToasts(WidgetTester tester) async {
  Get.closeAllSnackbars();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  Object? failWith;

  setUp(() {
    calls = [];
    failWith = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (failWith != null) throw failWith!;
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('shareOriginFor', () {
    testWidgets('le rectangle du bouton, en coordonnées globales',
        (tester) async {
      late BuildContext button;
      await tester.pumpWidget(MaterialApp(
        home: Stack(children: [
          Positioned(
            left: 100,
            top: 200,
            width: 80,
            height: 40,
            child: Builder(builder: (ctx) {
              button = ctx;
              return const SizedBox.expand();
            }),
          ),
        ]),
      ));
      expect(shareOriginFor(button), const Rect.fromLTWH(100, 200, 80, 40));
    });

    testWidgets('sans bouton mesurable : un petit carré, jamais vide',
        (tester) async {
      final none = shareOriginFor(null);
      expect(none.isEmpty, isFalse);

      late BuildContext gone;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          gone = ctx;
          return const SizedBox.shrink();
        }),
      ));
      // Bouton de taille nulle : repli au centre de l'écran.
      final zero = shareOriginFor(gone);
      expect(zero.isEmpty, isFalse);

      await tester.pumpWidget(const SizedBox());
      // Démonté : repli, pas d'exception.
      expect(shareOriginFor(gone).isEmpty, isFalse);
    });
  });

  group('kpbShare', () {
    testWidgets('transmet l\'origine du bouton au système', (tester) async {
      late BuildContext button;
      await tester.pumpWidget(GetMaterialApp(
        home: Stack(children: [
          Positioned(
            left: 10,
            top: 20,
            width: 120,
            height: 48,
            child: Builder(builder: (ctx) {
              button = ctx;
              return const SizedBox.expand();
            }),
          ),
        ]),
      ));

      final ok = await kpbShare(button, text: 'Mon lien', subject: 'Objet');

      expect(ok, isTrue);
      final args = Map<String, dynamic>.from(calls.single.arguments as Map);
      expect(args['text'], 'Mon lien');
      expect(args['subject'], 'Objet');
      expect(args['originX'], 10);
      expect(args['originY'], 20);
      expect(args['originWidth'], 120);
      expect(args['originHeight'], 48);
    });

    testWidgets('refus du système : faux, erreur affichée, aucune exception',
        (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
      failWith = PlatformException(
        code: 'error',
        message: 'sharePositionOrigin: argument must be set',
      );

      final ok = await kpbShare(null, text: 'x', errorMessage: 'Raté');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(ok, isFalse);
      expect(find.text('Raté'), findsOneWidget);
      await _drainToasts(tester);
    });
  });

  group('garde de source', () {
    test('share_plus n\'est appelé que par kpbShare et le service des cartes',
        () {
      final hits = countInLib(
        RegExp(r'SharePlus\.instance|\bShare\.share|shareXFiles|ShareParams\('),
        exempt: _shareFiles,
      );
      expect(
        hits,
        isEmpty,
        reason: 'Partage sans origine (iPad) : passe par kpbShare '
            '(lib/app/core/utils/share_origin.dart).\n'
            '${hits.entries.map((e) => '  ${e.key} : ${e.value}').join('\n')}',
      );
    });

    test('chaque ShareParams passe une origine', () {
      var blocks = 0;
      for (final path in _shareFiles) {
        final source = codeLines(path).join('\n');
        for (final block in _shareParamsBlocks(source)) {
          blocks++;
          expect(block, contains('sharePositionOrigin:'),
              reason: '$path : $block');
        }
      }
      expect(blocks, greaterThanOrEqualTo(2));
    });

    test('les écrans qui partagent passent par kpbShare', () {
      for (final path in const [
        'lib/app/features/referral/ambassador_competition_screen.dart',
        'lib/app/features/profile/profile_screen.dart',
        'lib/app/features/referral/referral_screen.dart',
        'lib/app/features/explore/program_detail_screen.dart',
        'lib/app/features/referral/ambassador_screen.dart',
        'lib/app/features/compare/institution_compare_screen.dart',
        'lib/app/features/tools/motivation_letters_screen.dart',
      ]) {
        expect(File(path).readAsStringSync(), contains('kpbShare('),
            reason: path);
      }
    });
  });
}
