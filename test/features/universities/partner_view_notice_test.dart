// Écran Universités — « Partenaires » par défaut, mais l'existence de « Tous »
// doit être évidente (décision du propriétaire du 17/10/2026).
//
// Ce que ce fichier garantit, pour l'élève :
//  * le sélecteur « Partenaires | Tous » est visible sans ouvrir « Filtres », avec
//    le nombre de formations de chaque vue, et TalkBack l'annonce ;
//  * à la première ouverture, l'avis complet reprend le texte du propriétaire MOT
//    POUR MOT, et la mention « Attention : cela dépend de ton dossier » ne s'en
//    sépare jamais ;
//  * fermé, l'avis laisse une ligne de rappel tant que « Tous » n'a jamais été
//    ouvert ; ouvert une fois, plus rien ;
//  * rien ne déborde à l'échelle de texte 1,5 sur un Android 360 pt.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/universities/universities_screen.dart';
import 'package:karatou/app/features/universities/widgets/partner_view_notice_store.dart';

import '../../support/screen_harness.dart';

LocalizedText _t(String value) => LocalizedText(fr: value, en: value);

/// Le texte voulu par le propriétaire, tel qu'il l'a écrit le 17/10/2026.
const _ownerTextFr =
    'Cette vue montre les universités partenaires de KPB Éducation. Avec '
    'elles, KPB peut accélérer ton dossier jusqu\'à 70 % plus vite et peut '
    'même t\'obtenir des garanties d\'admission. Attention : cela dépend de '
    'ton dossier. Pour voir toutes les universités et choisir n\'importe '
    'quelle destination, passe sur l\'onglet « Tous ».';

InstitutionModel _institution(String id, {required bool partner}) =>
    InstitutionModel(
      id: id,
      name: _t(partner ? 'École partenaire' : 'Université ouverte'),
      countryId: 'fra',
      location: _t('Paris'),
      overview: _t('Établissement de test.'),
      studyLevels: const ['Master'],
      tuitionLabel: _t('9 000 €/an'),
      languageRequirements: _t('Français B2'),
      intakePeriods: const ['Septembre'],
      programIds: const [],
      isPartner: partner,
    );

ProgramModel _program(String id, String institutionId) => ProgramModel(
      id: id,
      institutionId: institutionId,
      countryId: 'fra',
      fieldId: 'd01',
      name: _t('Master $id'),
      level: _t('Master'),
      duration: _t('2 ans'),
      tuition: _t('9 000 €/an'),
      language: _t('Français'),
      requirements: <LocalizedText>[_t('Licence')],
    );

void _seed(AppController controller) {
  controller.institutions
    ..clear()
    ..addAll([
      _institution('inst-partner', partner: true),
      _institution('inst-open', partner: false),
    ]);
  controller.programs
    ..clear()
    ..addAll([
      _program('partenaire-a', 'inst-partner'),
      _program('partenaire-b', 'inst-partner'),
      _program('ouverte-c', 'inst-open'),
    ]);
  controller.update();
}

Future<KpbScreenReport> _pump(
  WidgetTester tester,
  PartnerViewNoticeStore store, {
  KpbViewport viewport = iphone14,
  double textScale = 1.0,
  Locale locale = const Locale('fr'),
}) async {
  final controller = await seedKpbController();
  _seed(controller);
  return pumpKpbScreen(
    tester,
    screen: UniversitiesScreen(noticeStore: store),
    viewport: viewport,
    textScale: textScale,
    locale: locale,
    inDrawerShell: true,
  );
}

String _noticeText(WidgetTester tester) => tester
    .widget<RichText>(find.descendant(
      of: find.byKey(const ValueKey('partner_view_notice_body')),
      matching: find.byType(RichText),
    ))
    .text
    .toPlainText();

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  tearDown(Get.reset);

  group('le texte du propriétaire', () {
    test('FR : repris mot pour mot, mise en garde comprise', () {
      final fr = AppTranslations().keys['fr']!;
      expect(
        '${fr['uni_partner_notice_body']} ${fr['uni_partner_notice_caveat']} '
        '${fr['uni_partner_notice_switch_hint']}',
        _ownerTextFr,
      );
    });

    test('la mention « cela dépend de ton dossier » est OBLIGATOIRE', () {
      final keys = AppTranslations().keys;
      expect(keys['fr']!['uni_partner_notice_caveat'],
          'Attention : cela dépend de ton dossier.');
      expect(keys['en']!['uni_partner_notice_caveat'],
          contains('depends on your application'));
      // L'onglet nommé dans le texte est bien le libellé du sélecteur.
      expect(keys['fr']!['uni_partner_notice_switch_hint'],
          contains('« ${keys['fr']!['uni_view_all']} »'));
      expect(keys['en']!['uni_partner_notice_switch_hint'],
          contains('“${keys['en']!['uni_view_all']}”'));
    });
  });

  testWidgets('première ouverture : sélecteur avec compteurs, avis complet',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final store = MemoryPartnerViewNoticeStore();
    final report = await _pump(tester, store);
    expect(report.errors, isEmpty);

    expect(
        find.byKey(const ValueKey('university_view_switcher')), findsOneWidget);
    // Partenaires : 2 formations, Tous : 3 — lus par TalkBack avec le compte.
    expect(
        find.bySemanticsLabel('Partenaires : 2 formation(s)'), findsOneWidget);
    expect(find.bySemanticsLabel('Tous : 3 formation(s)'), findsOneWidget);

    expect(find.byKey(const ValueKey('partner_view_notice')), findsOneWidget);
    expect(_noticeText(tester), _ownerTextFr);
    // Le seul « % » de l'écran est celui de l'avis du propriétaire.
    expect(find.textContaining('%'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('partner_view_notice')),
            matching: find.textContaining('70 %')),
        findsOneWidget);
    expect(find.text('Voir toutes les universités'), findsOneWidget);
    expect(find.byTooltip('Fermer ce message'), findsOneWidget);
    // La liste reste sur les partenaires.
    expect(find.text('Master partenaire-a'), findsOneWidget);
    expect(find.text('Master ouverte-c'), findsNothing);
    semantics.dispose();
  });

  testWidgets('« Voir toutes les universités » ouvre « Tous », pour de bon',
      (tester) async {
    final store = MemoryPartnerViewNoticeStore();
    await _pump(tester, store);

    await tester
        .tap(find.byKey(const ValueKey('partner_view_notice_show_all')));
    await tester.pumpAndSettle();

    expect(find.text('Master ouverte-c'), findsOneWidget);
    expect(store.allViewOpened, isTrue);
    expect(find.byKey(const ValueKey('partner_view_notice')), findsNothing);

    // Retour sur « Partenaires » : l'élève sait que « Tous » existe, plus
    // d'avis ni de rappel.
    await tester.tap(find.byKey(const ValueKey('university_view_partners')));
    await tester.pumpAndSettle();
    expect(find.text('Master ouverte-c'), findsNothing);
    expect(find.byKey(const ValueKey('partner_view_notice')), findsNothing);
    expect(find.byKey(const ValueKey('partner_view_reminder')), findsNothing);
  });

  testWidgets('fermé : un rappel discret tant que « Tous » n\'est pas ouvert',
      (tester) async {
    final store = MemoryPartnerViewNoticeStore();
    await _pump(tester, store);

    await tester.tap(find.byKey(const ValueKey('partner_view_notice_close')));
    await tester.pumpAndSettle();
    expect(store.dismissed, isTrue);
    expect(find.byKey(const ValueKey('partner_view_notice')), findsNothing);
    expect(find.byKey(const ValueKey('partner_view_reminder')), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('partner_view_reminder_show_all')));
    await tester.pumpAndSettle();
    expect(find.text('Master ouverte-c'), findsOneWidget);
    expect(store.allViewOpened, isTrue);
  });

  testWidgets('mémorisé : rappel seul après fermeture, rien après « Tous »',
      (tester) async {
    await _pump(tester, MemoryPartnerViewNoticeStore(dismissed: true));
    expect(find.byKey(const ValueKey('partner_view_notice')), findsNothing);
    expect(find.byKey(const ValueKey('partner_view_reminder')), findsOneWidget);

    await _pump(tester,
        MemoryPartnerViewNoticeStore(dismissed: true, allViewOpened: true));
    expect(find.byKey(const ValueKey('partner_view_notice')), findsNothing);
    expect(find.byKey(const ValueKey('partner_view_reminder')), findsNothing);
    // Le sélecteur, lui, reste toujours là.
    expect(
        find.byKey(const ValueKey('university_view_switcher')), findsOneWidget);
  });

  testWidgets('stockage en panne : l\'avis complet, comme une 1re ouverture',
      (tester) async {
    await _pump(tester, MemoryPartnerViewNoticeStore(failReads: true));
    expect(find.byKey(const ValueKey('partner_view_notice')), findsOneWidget);
  });

  testWidgets('les boutons de l\'avis sont des boutons pour TalkBack',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, MemoryPartnerViewNoticeStore());
    expect(
      tester.getSemantics(
          find.byKey(const ValueKey('partner_view_notice_show_all'))),
      matchesSemantics(
        label: 'Voir toutes les universités',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isEnabled: true,
        isFocusable: true,
        hasEnabledState: true,
      ),
    );
    final partners = tester
        .getSemantics(find.byKey(const ValueKey('university_view_partners')));
    expect(partners, isSemantics(isButton: true, isSelected: true));
    semantics.dispose();
  });

  for (final locale in const [Locale('fr'), Locale('en')]) {
    testWidgets('${locale.languageCode} ×1,5 sur 360 pt : aucun débordement',
        (tester) async {
      final report = await _pump(
        tester,
        MemoryPartnerViewNoticeStore(),
        viewport: compactAndroid,
        textScale: 1.5,
        locale: locale,
      );
      expect(report.overflows, isEmpty, reason: '$report');
      expect(report.otherErrors, isEmpty, reason: '$report');
      expect(find.byKey(const ValueKey('partner_view_notice')), findsOneWidget);
    });
  }
}
