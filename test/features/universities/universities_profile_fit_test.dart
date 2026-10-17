// Conformité marque — la liste Universités n'affiche AUCUN pourcentage ni
// « probabilité d'admission ».
//
// Constat du 25/09/2026 sur capture iPhone : sous-titre « Triées par
// probabilité d'admission — calculée pour toi » et un badge « 40 % » sur
// CHAQUE programme. Le 40 venait du repli de `AppSearchService._matchProgram`
// quand l'étudiant n'a pas de profil : une constante, triée ensuite par ordre
// alphabétique, présentée comme une probabilité calculée.
//
// Ces tests verrouillent : (1) jamais de « % » dans la liste, avec ou sans
// profil ; (2) sans profil, ni badge ni promesse de tri personnalisé.
//
// L'avis « vue Partenaires » (décision du propriétaire du 17/10/2026) porte un
// « 70 % » voulu, couvert par partner_view_notice_test.dart : il est masqué ici
// (élève qui a déjà ouvert « Tous ») pour que « aucun % » reste une assertion
// sur la LISTE, sans exception.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/ui/components/profile_fit_badge.dart';
import 'package:karatou/app/features/universities/universities_screen.dart';
import 'package:karatou/app/features/universities/widgets/partner_view_notice_store.dart';

import '../../support/screen_harness.dart';

LocalizedText _t(String value) => LocalizedText(fr: value, en: value);

const _partnerId = 'inst-fit-partner';

void _seedCatalog(AppController controller) {
  controller.institutions
    ..clear()
    ..add(InstitutionModel(
      id: _partnerId,
      name: _t('École partenaire de test'),
      countryId: 'fra',
      location: _t('Paris'),
      overview: _t('Établissement de test.'),
      studyLevels: const ['Master'],
      tuitionLabel: _t('9 000 €/an'),
      languageRequirements: _t('Français B2'),
      intakePeriods: const ['Septembre'],
      programIds: const ['p-a', 'p-b'],
      isPartner: true,
    ));
  controller.programs
    ..clear()
    ..addAll([
      for (final id in ['p-a', 'p-b'])
        ProgramModel(
          id: id,
          institutionId: _partnerId,
          countryId: 'fra',
          fieldId: 'd01',
          name: _t('Master $id'),
          level: _t('Master'),
          duration: _t('2 ans'),
          tuition: _t('9 000 €/an'),
          language: _t('Français'),
          requirements: <LocalizedText>[_t('Licence')],
        ),
    ]);
  controller.update();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  tearDown(Get.reset);

  testWidgets('avec profil : paliers qualitatifs, aucun pourcentage',
      (tester) async {
    final controller = await seedKpbController();
    _seedCatalog(controller);

    await pumpKpbScreen(
      tester,
      screen: UniversitiesScreen(
        noticeStore: MemoryPartnerViewNoticeStore(allViewOpened: true),
      ),
      viewport: iphone14,
      inDrawerShell: true,
    );

    expect(find.byType(ProfileFitBadge), findsNWidgets(2));
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('probabilit'), findsNothing);
    expect(find.text('uni_list_subtitle'.tr), findsOneWidget);
  });

  testWidgets('sans profil : ni badge ni tri « calculé pour toi »',
      (tester) async {
    final controller = await seedKpbController();
    controller.profile = null;
    _seedCatalog(controller);

    await pumpKpbScreen(
      tester,
      screen: UniversitiesScreen(
        noticeStore: MemoryPartnerViewNoticeStore(allViewOpened: true),
      ),
      viewport: iphone14,
      inDrawerShell: true,
    );

    expect(find.byType(ProfileFitBadge), findsNothing,
        reason: 'Sans profil, le score est une constante de repli (40) : '
            'l\'afficher, c\'est présenter du vide comme un calcul.');
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('uni_list_subtitle_no_profile'.tr), findsOneWidget);
    expect(find.text('uni_list_subtitle'.tr), findsNothing);
  });
}
