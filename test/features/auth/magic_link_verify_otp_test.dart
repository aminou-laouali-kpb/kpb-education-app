// Code OTP (chantier I3) : remplissage automatique, collage, validation au 6e
// chiffre — et UNE seule soumission, même quand le 6e chiffre, « OK » du
// clavier et le bouton arrivent ensemble.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:karatou/app/core/services/auth_service.dart';
import 'package:karatou/app/features/auth/magic_link_verify_screen.dart';

import '../../support/screen_harness.dart';

class _MockAuthService extends Mock implements AuthService {}

const _phone = KpbViewport(
  id: 'phone360',
  name: 'phone 360×640',
  size: Size(360, 640),
  padding: EdgeInsets.only(top: 24, bottom: 0),
);

void main() {
  group('OtpCodeInputFormatter — collage et remplissage', () {
    const formatter = OtpCodeInputFormatter();

    String apply(String pasted) => formatter
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: pasted,
            selection: TextSelection.collapsed(offset: pasted.length),
          ),
        )
        .text;

    test('frappe ordinaire : inchangée', () {
      expect(apply('12'), '12');
      expect(apply('123456'), '123456');
    });

    test('un code collé avec espaces ou tirets', () {
      expect(apply('123 456'), '123456');
      expect(apply('123-456'), '123456');
      expect(apply(' 123456\n'), '123456');
    });

    test('le code isolé dans une phrase, pas les autres chiffres', () {
      expect(apply('Ton code : 482913'), '482913');
      // « digitsOnly » aurait gardé « 60 » d'abord : « 604829 ».
      expect(apply('Valable 60 min : 482913'), '482913');
    });

    test('jamais plus de 6 chiffres', () {
      expect(apply('12345678'), '123456');
      expect(apply('abc'), '');
    });
  });

  group('MagicLinkVerifyScreen', () {
    late _MockAuthService auth;
    // Compté à la main : `verify(...)` de mocktail remet son compteur à zéro
    // et refuse de compter zéro appel.
    late List<String?> codes;

    setUp(() {
      auth = _MockAuthService();
      codes = <String?>[];
    });

    tearDown(Get.reset);

    Future<void> pumpVerify(WidgetTester tester) async {
      await pumpKpbScreen(
        tester,
        screen: MagicLinkVerifyScreen(
          authService: auth,
          email: 'eleve@example.com',
        ),
        viewport: _phone,
      );
    }

    void stubVerify(Future<AuthResponse> Function() answer) {
      when(() => auth.verifyMagicLink(
            email: any(named: 'email'),
            code: any(named: 'code'),
            token: any(named: 'token'),
          )).thenAnswer((invocation) {
        codes.add(invocation.namedArguments[#code] as String?);
        return answer();
      });
    }

    int verifyCalls() => codes.length;

    Finder codeField() => find.byType(TextField);

    testWidgets('le champ annonce un code à usage unique (autofill)',
        (tester) async {
      await pumpVerify(tester);
      final field = tester.widget<TextField>(codeField());
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(field.keyboardType, TextInputType.number);
      expect(field.maxLength, 6);
    });

    testWidgets(
        'validation automatique au 6e chiffre, une seule soumission malgré '
        '« OK » et le bouton', (tester) async {
      final pending = Completer<AuthResponse>();
      stubVerify(() => pending.future);
      await pumpVerify(tester);

      await tester.enterText(codeField(), '12345');
      await tester.pump();
      expect(verifyCalls(), 0);

      await tester.enterText(codeField(), '123456');
      await tester.pump();
      expect(verifyCalls(), 1);

      // « OK » du clavier et le bouton, pendant que la vérification tourne.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      final button = find.widgetWithText(FilledButton, 'Valider');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      expect(verifyCalls(), 1, reason: 'une seule soumission');

      pending.completeError(const AuthException('invalid', statusCode: '403'));
      await tester.pump();
      await tester.pump();
    });

    testWidgets(
        'un code collé d\'un e-mail part tout seul ; l\'erreur s\'écrit dans '
        'le champ', (tester) async {
      stubVerify(
          () => Future<AuthResponse>.error(const AuthException('invalid')));
      await pumpVerify(tester);

      await tester.enterText(codeField(), 'Ton code : 482913');
      await tester.pump();
      await tester.pump();

      expect(codes, ['482913']);

      final decorator = tester.widget<InputDecorator>(find.descendant(
        of: codeField(),
        matching: find.byType(InputDecorator),
      ));
      expect(decorator.decoration.errorText, isNotNull);

      // Le même code, inchangé, ne repart pas d'office.
      await tester.pump(const Duration(milliseconds: 50));
      expect(verifyCalls(), 1);

      // Corrigé : un nouveau code à 6 chiffres repart, une fois.
      await tester.enterText(codeField(), '48291');
      await tester.pump();
      await tester.enterText(codeField(), '482914');
      await tester.pump();
      await tester.pump();
      expect(codes, ['482913', '482914']);
    });
  });
}
