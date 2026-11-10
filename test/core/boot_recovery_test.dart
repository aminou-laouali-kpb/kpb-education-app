// Sortir d'un démarrage qui échoue (audit avant la 59).
//
// ## Le défaut
//
// Un stockage local illisible faisait échouer le démarrage à CHAQUE lancement.
// L'écran d'erreur n'avait qu'un texte brut et aucun bouton : la seule issue
// était d'effacer les données de l'app depuis les réglages du téléphone.
//
// ## Ce que ce fichier verrouille
//
// 1. Une session illisible dans le magasin sécurisé ne lève plus : elle vaut
//    « pas de session », et l'élève se reconnecte. Elle n'est pas effacée.
// 2. L'écran de dernier recours propose d'effacer les données locales, demande
//    confirmation, puis dit quoi faire.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/kpb_supabase_local_storage.dart';
import 'package:karatou/main.dart';

const _secureStorage =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('session illisible dans le magasin sécurisé', () {
    final calls = <String>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorage, (call) async {
        calls.add(call.method);
        if (call.method == 'read') {
          // Ce que rend Android quand la clé du Keystore est perdue.
          throw PlatformException(
            code: 'Exception encountered',
            message: 'javax.crypto.BadPaddingException',
          );
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorage, null);
    });

    test('la lecture ne lève pas : pas de session', () async {
      const storage = KpbSecureLocalStorage();

      expect(await storage.accessToken(), isNull);
      expect(await storage.hasAccessToken(), isFalse);
    });

    // La panne peut n'être que passagère (trousseau iOS verrouillé après un
    // redémarrage, app lancée en arrière-plan) : effacer la session là
    // déconnecterait pour de bon un élève qui n'avait rien perdu.
    test(
        'la session n\'est PAS effacée : une panne passagère ne déconnecte pas',
        () async {
      const storage = KpbSecureLocalStorage();
      await storage.accessToken();
      await storage.hasAccessToken();

      expect(calls, isNot(contains('delete')));
      expect(calls, everyElement('read'));
    });
  });

  group('écran de dernier recours', () {
    Future<void> pump(
      WidgetTester tester, {
      Future<void> Function()? onReset,
      Locale locale = const Locale('fr'),
    }) async {
      // Aucune traduction n'est chargée à ce stade : l'écran choisit sa langue
      // sur celle du téléphone.
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(BootstrapErrorApp(
        error: StateError('HiveError: box corrupted ' * 20),
        onReset: onReset,
      ));
    }

    testWidgets('dit quoi faire et propose une issue, sans déborder',
        (tester) async {
      await pump(tester);

      expect(find.text('L\'application n\'a pas pu démarrer.'), findsOneWidget);
      expect(find.text('Effacer les données de ce téléphone'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sur un téléphone en anglais, il parle anglais',
        (tester) async {
      await pump(tester, locale: const Locale('en'));

      expect(find.text('The app could not start.'), findsOneWidget);
      expect(find.text('Clear the data on this phone'), findsOneWidget);
    });

    testWidgets('rien n\'est effacé sans confirmation', (tester) async {
      var resets = 0;
      await pump(tester, onReset: () async => resets++);

      await tester.tap(find.text('Effacer les données de ce téléphone'));
      await tester.pump();

      expect(resets, 0);
      expect(find.text('Oui, effacer'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pump();

      expect(resets, 0);
      expect(find.text('Effacer les données de ce téléphone'), findsOneWidget);
    });

    testWidgets('confirmé, il efface puis dit de rouvrir l\'app',
        (tester) async {
      var resets = 0;
      await pump(tester, onReset: () async => resets++);

      await tester.tap(find.text('Effacer les données de ce téléphone'));
      await tester.pump();
      await tester.tap(find.text('Oui, effacer'));
      await tester.pumpAndSettle();

      expect(resets, 1);
      expect(find.text('C\'est fait.'), findsOneWidget);
      expect(find.textContaining('rouvre-la'), findsOneWidget);
      expect(find.text('Oui, effacer'), findsNothing);
    });

    testWidgets('un effacement qui échoue mène quand même à la suite',
        (tester) async {
      await pump(tester, onReset: () async => throw StateError('disque'));

      await tester.tap(find.text('Effacer les données de ce téléphone'));
      await tester.pump();
      await tester.tap(find.text('Oui, effacer'));
      await tester.pumpAndSettle();

      expect(find.text('C\'est fait.'), findsOneWidget);
    });
  });
}
