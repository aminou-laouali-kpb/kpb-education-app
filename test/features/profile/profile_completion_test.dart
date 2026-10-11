// Gardes de la revue du build 49, points 4 et 5 :
//
//   (4) « quand le profil est incomplet, on doit montrer à l'utilisateur ce
//        qu'il manque pour que son profil soit à 100 % […] et un bouton pour
//        le remplir »
//   (5) « certaines options ne peuvent pas être complétées ou modifiées sur le
//        profil après (comme le budget) »
//
// Le défaut du (4) n'était PAS une carte absente : la carte existait, et elle
// se taisait. `_missingFields` énumérait cinq champs à la main quand le score
// en compte treize, et toute la liste — bouton compris — vivait sous
// `else if (missing.isNotEmpty)`. Un profil à qui il ne manquait que le budget
// affichait donc « 92 % », une barre, et rien d'autre. La fixture du dépôt
// (`createTestProfile`, sans budget) reproduit exactement ce cas, ce qui rend
// ces tests écrivables sans profil artificiel.
//
// La garde ne vérifie donc pas « la carte s'affiche » — elle s'affichait déjà.
// Elle vérifie que la liste et le score parlent de la MÊME chose.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('UserProfile — le score et la liste ont une seule source', () {
    test('missingCompletionItems est vide si et seulement si le score vaut 1',
        () {
      // Complet : la fixture plus les trois champs qu'elle laisse vides.
      final complete = createTestProfile().copyWith(
        annualTuitionBudgetEur: 7500,
      );
      expect(complete.completionScore, 1.0);
      expect(complete.missingCompletionItems, isEmpty);

      // Incomplet d'un seul item — LE cas qui produisait la carte muette.
      final noBudget = createTestProfile();
      expect(noBudget.completionScore, lessThan(1.0));
      expect(
        noBudget.missingCompletionItems,
        [ProfileCompletionItem.budget],
        reason: 'le budget est le seul manque de la fixture ; s\'il n\'est pas '
            'listé, la carte ne peut rien montrer à l\'utilisateur',
      );
    });

    test('chaque item non rempli est listé, et aucun autre', () {
      final bare = UserProfile(
        id: 'u1',
        accountType: AccountType.student,
        fullName: '',
        email: '',
        phone: '',
        countryOfResidence: '',
        preferredLanguage: '',
        whatsApp: '',
      );

      expect(bare.completionScore, 0.0);
      expect(
        bare.missingCompletionItems.toSet(),
        ProfileCompletionItem.values.toSet(),
        reason: 'un profil vide doit lister LES TREIZE items, sinon le score '
            'réclame quelque chose que la liste ne sait pas nommer',
      );
      expect(
        bare.completionBreakdown.length,
        ProfileCompletionItem.values.length,
      );
    });

    test('une chaîne d\'espaces compte comme vide des DEUX côtés', () {
      // L'ancienne liste testait `p.currentLevel == null` alors que le score
      // teste `.trim().isNotEmpty` : une chaîne blanche était donc manquante
      // pour le score et remplie pour la liste. Les deux dérivent maintenant du
      // même prédicat, donc ce désaccord ne peut plus exister.
      final blank = createTestProfile().copyWith(
        annualTuitionBudgetEur: 7500,
        currentLevel: '   ',
      );
      expect(blank.completionScore, lessThan(1.0));
      expect(
        blank.missingCompletionItems,
        contains(ProfileCompletionItem.currentLevel),
      );
    });
  });

  group('ProfileScreen — la carte de complétion parle', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    testWidgets(
        'un profil à qui il ne manque que le budget voit le manque ET le bouton',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        child: const ProfileScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      // `.tr` rend la clé brute dans ce harnais (convention du dépôt).
      expect(
        find.text('profile_missing_budget_field'),
        findsOneWidget,
        reason: 'c\'est le manque réel du profil ; sans cette ligne la carte '
            'affiche « 92 % » sans dire de quoi',
      );
      expect(
        find.text('profile_complete_cta'),
        findsOneWidget,
        reason: 'le bouton « Compléter mon profil » vivait sous la même '
            'condition que la liste : pas de liste, pas de bouton',
      );
    });

    testWidgets('un profil complet montre la confirmation, pas la liste',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        child: const ProfileScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile().copyWith(annualTuitionBudgetEur: 7500),
        ),
      );

      expect(find.text('profile_complete_optimized'), findsOneWidget);
      expect(find.text('profile_complete_cta'), findsNothing);
      expect(find.text('profile_missing_budget_field'), findsNothing);
    });
  });

  group('la série du bac peut être effacée', () {
    // Revue automatique de la PR #252 (P2). `copyWith(bacSeries: null)` ne
    // pouvait PAS effacer — `null` y signifie « ne change rien ». La feuille
    // met pourtant `_bacSeries` à null quand l'étudiant passe à un niveau sans
    // série de bac. Résultat : la série obsolète survivait, et continuait de
    // satisfaire l'item « moyenne » du score de complétion — donc un profil
    // affichait 100 % grâce à une donnée qui n'aurait plus dû exister.
    test('clearBacSeries efface, là où null ne pouvait pas', () {
      final withSeries = createTestProfile().copyWith(bacSeries: 'D');
      expect(withSeries.bacSeries, 'D');

      // L'ancien geste, celui qui ne marchait pas.
      expect(
        withSeries.copyWith(bacSeries: null).bacSeries,
        'D',
        reason: 'null veut dire « ne change rien » dans tout ce constructeur — '
            'c\'est bien pourquoi il fallait un drapeau explicite',
      );

      expect(withSeries.copyWith(clearBacSeries: true).bacSeries, isNull);
    });

    test(
        'effacer la série retire l\'item « moyenne » quand il n\'y a pas de moyenne',
        () {
      final onlySeries = createTestProfile().copyWith(
        gradeRange: '',
        bacSeries: 'D',
        annualTuitionBudgetEur: 7500,
      );
      expect(onlySeries.missingCompletionItems, isEmpty);

      final cleared = onlySeries.copyWith(clearBacSeries: true);
      expect(
        cleared.missingCompletionItems,
        contains(ProfileCompletionItem.grade),
        reason: 'sans série ni moyenne, l\'item doit redevenir manquant — '
            'sinon une donnée effacée continue de compter',
      );
    });
  });

  group('Point 5 — les champs orphelins sont redevenus modifiables', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    testWidgets('le budget se modifie depuis le profil et est persisté',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        child: const ProfileScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      final controller = Get.find<AppController>();
      expect(controller.profile!.annualTuitionBudgetEur, isNull);

      // Ouvre la feuille d'édition par le bouton de la carte de complétion —
      // le chemin que l'utilisateur emprunte réellement.
      await tester.tap(find.text('profile_complete_cta'));
      await tester.pumpAndSettle();

      final budgetDropdown = find.byType(DropdownButtonFormField<int>);
      expect(
        budgetDropdown,
        findsOneWidget,
        reason: 'sans ce menu, le budget n\'est réglable qu\'en rejouant '
            'l\'onboarding — le signalement du propriétaire',
      );

      await tester.tap(budgetDropdown);
      await tester.pumpAndSettle();
      // Le dernier élément du menu ; son libellé dépend de la devise, donc on
      // vise la position et non le texte.
      await tester.tap(find.byType(DropdownMenuItem<int>).last,
          warnIfMissed: false);
      await tester.pumpAndSettle();

      // La feuille s'est allongée (section « Filières ») : le bouton peut être
      // sous le pli.
      await tester.scrollUntilVisible(find.text('save_changes'), 300,
          scrollable: find
              .descendant(
                of: find.byType(DraggableScrollableSheet),
                matching: find.byType(Scrollable),
              )
              .first);
      await tester.tap(find.text('save_changes'));
      // `_save` termine par un `Get.snackbar`, dont le minuteur d'auto-fermeture
      // survit à `pumpAndSettle` et fait échouer le test sur « A Timer is still
      // pending ». On le laisse expirer explicitement.
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(
        controller.profile!.annualTuitionBudgetEur,
        isNotNull,
        reason: 'le budget choisi doit atteindre le profil, sinon le menu est '
            'décoratif',
      );
      expect(controller.profile!.completionScore, 1.0);
    });

    testWidgets('niveau visé, niveau de langue et moyenne ont un menu',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTestApp(
        tester,
        child: const ProfileScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      await tester.tap(find.text('profile_complete_cta'));
      await tester.pumpAndSettle();

      // On vise les LIBELLÉS, pas le nombre de menus : compter les
      // `DropdownButtonFormField` rendait le test dépendant de la série du bac,
      // qui n'apparaît que pour certains niveaux — il aurait rougi pour une
      // raison sans rapport avec ce qu'il prétend garder.
      // (`.tr` rend la clé brute dans ce harnais.)
      // La recherche est RESTREINTE au formulaire de la feuille. Trois de ces
      // libellés figurent aussi sur la carte « Informations académiques »
      // derrière la feuille : un `find.text` global aurait donc trouvé le
      // libellé même sans le menu, et ce test aurait été vert avant le
      // correctif comme après — c'est-à-dire inutile.
      final sheet = find.byType(Form);
      expect(sheet, findsOneWidget);

      for (final label in const [
        'target_level',
        'language_level',
        'grade_range',
        'tuition_budget_annual',
      ]) {
        expect(
          find.descendant(of: sheet, matching: find.text(label)),
          findsOneWidget,
          reason: '« $label » n\'était réglable qu\'à l\'inscription ; sans ce '
              'champ dans la feuille d\'édition, le profil ne peut pas '
              'atteindre 100 %',
        );
      }
    });
  });
}
