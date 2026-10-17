// Fiches États-Unis — l'avis « visas étudiants suspendus » (décision du
// propriétaire du 17/10/2026).
//
// Ce que ce fichier garantit, pour l'élève :
//  * une fiche formation, établissement ou pays des États-Unis porte l'avis, et
//    seulement celles-là ;
//  * si le pays de résidence du profil est dans la liste, l'avis le dit EN
//    PREMIER ; sinon il reste général ;
//  * la liste vient de `/config/app` (une liste vide retire l'avis) ;
//  * deux vrais boutons : la page officielle et WhatsApp, lus par TalkBack ;
//  * rien ne déborde à l'échelle 1,5 sur 360 pt, en français comme en anglais ;
//  * le renvoi mesuré ne porte ni pays ni « concerné ».

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/models/us_visa_suspension.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/explore/country_detail_screen.dart';
import 'package:karatou/app/features/explore/program_detail_screen.dart';

import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

LocalizedText _t(String value) => LocalizedText(fr: value, en: value);

InstitutionModel _institution(String id, String countryId) => InstitutionModel(
      id: id,
      name: _t('Université $id'),
      countryId: countryId,
      location: _t('Ville'),
      overview: _t('Établissement de test.'),
      studyLevels: const ['Bachelor'],
      tuitionLabel: _t('USD 30 000/an'),
      languageRequirements: _t('TOEFL 80'),
      intakePeriods: const ['Fall 2027'],
      programIds: const [],
      isPartner: false,
    );

ProgramModel _program(String id, String institutionId, String countryId) =>
    ProgramModel(
      id: id,
      institutionId: institutionId,
      countryId: countryId,
      fieldId: 'd01',
      name: _t('BSc Computer Science $id'),
      level: _t('Bachelor'),
      duration: _t('4 ans'),
      tuition: _t('USD 30 000/an'),
      language: _t('Anglais'),
      requirements: <LocalizedText>[_t('TOEFL 80')],
    );

Future<AppController> _seed(
    {String countryOfResidence = 'Burkina Faso'}) async {
  final controller = await seedKpbController(
    snapshot: AppSnapshot(
      localeCode: 'fr',
      hasCompletedOnboarding: true,
      profile: createTestProfile(countryOfResidence: countryOfResidence),
    ),
  );
  controller.institutions
    ..clear()
    ..addAll([_institution('us-1', 'usa'), _institution('ca-1', 'can')]);
  controller.programs
    ..clear()
    ..addAll([
      _program('us-p', 'us-1', 'usa'),
      _program('ca-p', 'ca-1', 'can'),
    ]);
  controller.update();
  return controller;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  setUp(RemoteFeatureFlags.resetForTest);
  tearDown(() {
    RemoteFeatureFlags.resetForTest();
    Get.reset();
  });

  final notice = find.byKey(const ValueKey('us_visa_notice'));
  final concerned = find.byKey(const ValueKey('us_visa_notice_concerned'));

  testWidgets('formation aux États-Unis, pays concerné : il le dit en premier',
      (tester) async {
    await _seed(countryOfResidence: 'Burkina Faso');
    final report = await pumpKpbScreen(
      tester,
      screen: const ProgramDetailScreen(programId: 'us-p'),
      viewport: iphone14,
    );
    expect(report.errors, isEmpty);
    expect(notice, findsOneWidget);
    expect(concerned, findsOneWidget);
    expect(find.text('Ton pays est concerné.'), findsOneWidget);
    expect(
      find.text('Les demandes de visa étudiant sont actuellement suspendues '
          'pour les ressortissants de : Burkina Faso, Mali, Niger, Tchad, '
          'Congo, Bénin, Côte d\'Ivoire, Sénégal, Gabon, Mauritanie, Burundi, '
          'Togo.'),
      findsOneWidget,
    );
    expect(
        find.text('Vérifie ta situation sur travel.state.gov, ou écris-nous '
            'sur WhatsApp pour en parler.'),
        findsOneWidget);
    expect(find.text('Liste vérifiée le 17/10/2026.'), findsOneWidget);
    // « Ton pays est concerné » passe AVANT la liste.
    expect(
      tester.getTopLeft(concerned).dy,
      lessThan(
          tester.getTopLeft(find.textContaining('actuellement suspendues')).dy),
    );
  });

  testWidgets('pays non listé : avis général, sans « concerné »',
      (tester) async {
    await _seed(countryOfResidence: 'Cameroun');
    await pumpKpbScreen(
      tester,
      screen: const ProgramDetailScreen(programId: 'us-p'),
      viewport: iphone14,
    );
    expect(notice, findsOneWidget);
    expect(concerned, findsNothing);
  });

  testWidgets('hors États-Unis : aucun avis', (tester) async {
    await _seed();
    await pumpKpbScreen(
      tester,
      screen: const ProgramDetailScreen(programId: 'ca-p'),
      viewport: iphone14,
    );
    expect(notice, findsNothing);
  });

  testWidgets('la liste est pilotée par le serveur : vide = plus d\'avis',
      (tester) async {
    await _seed();
    RemoteFeatureFlags.instance.debugSetUsVisaSuspensionForTest(
      UsVisaSuspension.fromJson({'countries': <Object>[]}),
    );
    await pumpKpbScreen(
      tester,
      screen: const ProgramDetailScreen(programId: 'us-p'),
      viewport: iphone14,
    );
    expect(notice, findsNothing);

    RemoteFeatureFlags.instance.debugSetUsVisaSuspensionForTest(
      UsVisaSuspension.fromJson({
        'countries': [
          {'code': 'NG', 'nameFr': 'Nigeria', 'nameEn': 'Nigeria'},
        ],
      }),
    );
    await tester.pumpAndSettle();
    expect(notice, findsOneWidget);
    expect(find.textContaining('ressortissants de : Nigeria.'), findsOneWidget);
    expect(concerned, findsNothing, reason: 'le Burkina n\'y est plus');
    expect(find.textContaining('Liste vérifiée'), findsNothing,
        reason: 'aucune date servie : aucune date inventée');
  });

  testWidgets('fiche pays États-Unis : l\'avis y est aussi', (tester) async {
    await _seed();
    await pumpKpbScreen(
      tester,
      screen: const CountryDetailScreen(countryId: 'usa'),
      viewport: iphone14,
    );
    expect(notice, findsOneWidget);
  });

  testWidgets('deux vrais boutons, lus par TalkBack', (tester) async {
    final semantics = tester.ensureSemantics();
    await _seed();
    await pumpKpbScreen(
      tester,
      screen: const ProgramDetailScreen(programId: 'us-p'),
      viewport: iphone14,
    );
    for (final entry in {
      'us_visa_notice_official': 'Voir la page officielle',
      'us_visa_notice_whatsapp': 'En parler sur WhatsApp',
    }.entries) {
      final node = tester.getSemantics(find.byKey(ValueKey(entry.key)));
      expect(node.label, entry.value);
      expect(node, isSemantics(isButton: true, hasTapAction: true));
    }
    semantics.dispose();
  });

  for (final locale in const [Locale('fr'), Locale('en')]) {
    testWidgets('${locale.languageCode} ×1,5 sur 360 pt : aucun débordement',
        (tester) async {
      await _seed();
      final report = await pumpKpbScreen(
        tester,
        screen: const ProgramDetailScreen(programId: 'us-p'),
        viewport: compactAndroid,
        textScale: 1.5,
        locale: locale,
      );
      expect(report.overflows, isEmpty, reason: '$report');
      expect(notice, findsOneWidget);
    });
  }

  test('le renvoi WhatsApp est mesuré sans pays ni « concerné »', () {
    final source = File('lib/app/core/ui/components/us_visa_notice.dart')
        .readAsStringSync();
    final call = RegExp(r'openWhatsAppOrToast\(([^;]*)\);', dotAll: true)
        .firstMatch(source)!
        .group(1)!;
    expect(call, contains('source: UsVisaNotice.analyticsSource'));
    expect(call, contains('contextType: UsVisaNotice.analyticsContext'));
    expect(call, isNot(contains('concerned')));
    expect(call, isNot(contains('countryOfResidence')));
    expect(source, contains("analyticsSource = 'us_visa_notice'"));
    expect(source, contains("analyticsContext = 'us_visa'"));
    expect(source, isNot(contains('AnalyticsService')));
  });
}
