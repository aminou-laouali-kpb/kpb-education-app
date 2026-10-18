import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/observability/analytics_event_contract.dart';
import 'package:karatou/app/core/services/analytics_service.dart';

void main() {
  test('GA4 event names stay within typical length limits', () {
    const events = <String>[
      AnalyticsEventName.logout,
      AnalyticsEventName.orientationComplete,
      AnalyticsEventName.syncFullComplete,
      AnalyticsEventName.syncConflictResolved,
      AnalyticsEventName.syncCatalogHiveFallback,
      AnalyticsEventName.onboardingStepViewed,
      AnalyticsEventName.onboardingCompleted,
      AnalyticsEventName.onboardingSkipped,
      AnalyticsEventName.authFailed,
      AnalyticsEventName.dailyScholarshipViewed,
      AnalyticsEventName.dailyScholarshipOpened,
      AnalyticsEventName.eefHelpCardShown,
      AnalyticsEventName.eefHelpCtaTapped,
      AnalyticsEventName.eefBubbleOpened,
      AnalyticsEventName.eefPrivateInfoOpened,
      AnalyticsEventName.eefTourShown,
      AnalyticsEventName.eefTourCompleted,
      AnalyticsEventName.onboardingValidationFailed,
      AnalyticsEventName.aiCoachMessageSent,
      AnalyticsEventName.aiCoachLoadFailed,
    ];
    for (final e in events) {
      expect(e.length, lessThanOrEqualTo(40), reason: e);
    }
  });

  // La carte d'aide de l'espace « Études en France » : deux événements, trois
  // identifiants fermés. Ce groupe est le cliquet de la règle « jamais de donnée
  // personnelle dans la mesure » — il rougit si quelqu'un ajoute une propriété.
  group('carte d\'aide Études en France', () {
    final snakeCase = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

    test('les noms d\'événements sont ceux du contrat publié', () {
      expect(AnalyticsEventName.eefHelpCardShown, 'eef_help_card_shown');
      expect(AnalyticsEventName.eefHelpCtaTapped, 'eef_help_cta_tapped');
      for (final name in [
        AnalyticsEventName.eefHelpCardShown,
        AnalyticsEventName.eefHelpCtaTapped,
      ]) {
        expect(name, matches(snakeCase));
      }
    });

    test(
        'les clés de propriété sont en snake_case, et `step` n\'est pas '
        'réutilisée', () {
      expect(AnalyticsParamKey.helpStep, 'help_step');
      expect(AnalyticsParamKey.surface, 'surface');
      expect(AnalyticsParamKey.variant, 'variant');
      for (final key in [
        AnalyticsParamKey.helpStep,
        AnalyticsParamKey.surface,
        AnalyticsParamKey.variant,
      ]) {
        expect(key, matches(snakeCase));
      }
      // `step` est un entier (1-based) pour l'onboarding : deux types sous une
      // même clé de tableau de bord.
      expect(AnalyticsParamKey.helpStep, isNot(AnalyticsParamKey.step));
    });

    test('les propriétés envoyées sont EXACTEMENT ces trois clés', () {
      final params = AnalyticsService.eefHelpParams(
        step: 'hub',
        surface: 'hub',
        variant: 'card',
      );
      expect(
        params.keys.toSet(),
        {
          AnalyticsParamKey.helpStep,
          AnalyticsParamKey.surface,
          AnalyticsParamKey.variant,
        },
      );
      // `FirebaseAnalytics.logEvent` n'accepte que String ou num.
      for (final value in params.values) {
        expect(value, isA<String>());
      }
    });

    test('aucune clé de propriété ne désigne une donnée personnelle', () {
      final personal = RegExp(
        r'name|nom|mail|phone|tel|whatsapp|passport|passeport|country|pays|'
        r'user|uid|id$|profile|age|birth|address',
        caseSensitive: false,
      );
      final params = AnalyticsService.eefHelpParams(
        step: 'hub',
        surface: 'hub',
        variant: 'card',
      );
      for (final key in params.keys) {
        expect(personal.hasMatch(key), isFalse, reason: key);
      }
    });

    // Le contrat publié (docs/analytics-event-contract.md) doit citer les deux
    // événements et leurs propriétés : un événement sans ligne dans le contrat
    // est un événement que personne ne saura lire.
    test('docs/analytics-event-contract.md documente les deux événements', () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final needle in [
        '`eef_help_card_shown`',
        '`eef_help_cta_tapped`',
        '`help_step`',
        '`surface`',
        '`variant`',
      ]) {
        expect(doc, contains(needle), reason: '$needle absent du contrat');
      }
    });
  });

  // La bulle d'aide (build 56) : elle réutilise les deux événements ci-dessus,
  // avec EXACTEMENT les mêmes trois propriétés, et n'ajoute qu'un événement —
  // l'ouverture du menu, qui n'est pas un envoi vers WhatsApp et ne doit donc
  // pas gonfler `eef_help_cta_tapped`.
  group('bulle d\'aide Études en France', () {
    final snakeCase = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

    test('l\'événement neuf porte le nom du contrat publié', () {
      expect(AnalyticsEventName.eefBubbleOpened, 'eef_bubble_opened');
      expect(AnalyticsEventName.eefBubbleOpened, matches(snakeCase));
    });

    test('`eef_bubble_opened` ne porte QU\'une propriété : `surface`', () {
      final params = AnalyticsService.eefBubbleOpenedParams(surface: 'hub');
      expect(params.keys.toSet(), {AnalyticsParamKey.surface});
      for (final value in params.values) {
        expect(value, isA<String>());
      }
    });

    test(
        'les deux événements de la carte gardent EXACTEMENT leurs trois '
        'propriétés quand la bulle les utilise', () {
      final params = AnalyticsService.eefHelpParams(
        step: 'bubble_assistance',
        surface: 'catalog',
        variant: 'bubble',
      );
      expect(
        params.keys.toSet(),
        {
          AnalyticsParamKey.helpStep,
          AnalyticsParamKey.surface,
          AnalyticsParamKey.variant,
        },
      );
    });

    test('docs/analytics-event-contract.md documente la bulle', () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final needle in [
        '`eef_bubble_opened`',
        '`bubble`',
        '`bubble_assistance`',
        '`bubble_dossier`',
        '`bubble_choose`',
        '`bubble_question`',
        'eef_help_bubble_',
      ]) {
        expect(doc, contains(needle), reason: '$needle absent du contrat');
      }
    });
  });

  // Les écoles privées (build 56, PR 3) : un événement neuf, `eef_private_info_opened`,
  // pour ce qui n'est PAS un envoi (la feuille d'information a été ouverte). Une
  // seule propriété fermée, `entry`. Le départ vers WhatsApp, lui, réutilise
  // `eef_help_cta_tapped` (`help_step` = `private_sheet`).
  group('écoles privées Études en France', () {
    final snakeCase = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

    test('l\'événement neuf porte le nom du contrat publié', () {
      expect(
          AnalyticsEventName.eefPrivateInfoOpened, 'eef_private_info_opened');
      expect(AnalyticsEventName.eefPrivateInfoOpened, matches(snakeCase));
    });

    test('`eef_private_info_opened` ne porte QU\'une propriété : `entry`', () {
      for (final entry in ['bubble', 'catalog_empty']) {
        final params =
            AnalyticsService.eefPrivateInfoOpenedParams(entry: entry);
        expect(params.keys.toSet(), {AnalyticsParamKey.entry});
        expect(params[AnalyticsParamKey.entry], entry);
      }
      expect(AnalyticsParamKey.entry, 'entry');
    });

    test('docs/analytics-event-contract.md documente les écoles privées', () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final needle in [
        '`eef_private_info_opened`',
        '`entry`',
        '`bubble`',
        '`catalog_empty`',
        '`private_sheet`',
        '`private_note`',
        'eef_help_private_sheet',
      ]) {
        expect(doc, contains(needle), reason: '$needle absent du contrat');
      }
    });
  });
  // La visite guidée de l'espace (build 56, PR 4) : deux événements neufs, des
  // propriétés fermées, aucune donnée personnelle, aucun identifiant qui trahisse
  // la suspension d'un pays.
  group('visite guidée Études en France', () {
    final snakeCase = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

    test('les événements neufs portent le nom du contrat publié', () {
      expect(AnalyticsEventName.eefTourShown, 'eef_tour_shown');
      expect(AnalyticsEventName.eefTourCompleted, 'eef_tour_completed');
      for (final name in [
        AnalyticsEventName.eefTourShown,
        AnalyticsEventName.eefTourCompleted,
      ]) {
        expect(name, matches(snakeCase));
      }
    });

    test('les clés de propriété sont en snake_case', () {
      expect(AnalyticsParamKey.tourTrigger, 'tour_trigger');
      expect(AnalyticsParamKey.tourExit, 'tour_exit');
      expect(AnalyticsParamKey.tourCardsSeen, 'tour_cards_seen');
      for (final key in [
        AnalyticsParamKey.tourTrigger,
        AnalyticsParamKey.tourExit,
        AnalyticsParamKey.tourCardsSeen,
      ]) {
        expect(key, matches(snakeCase));
      }
    });

    test('`eef_tour_shown` ne porte QU\'une propriété : `tour_trigger`', () {
      for (final trigger in ['first_open', 'replay']) {
        final params = AnalyticsService.eefTourShownParams(trigger: trigger);
        expect(params.keys.toSet(), {AnalyticsParamKey.tourTrigger});
        expect(params[AnalyticsParamKey.tourTrigger], trigger);
      }
    });

    test(
        '`eef_tour_completed` ne porte QUE `tour_exit` et `tour_cards_seen` '
        '(un entier)', () {
      for (final exit in ['finished', 'skipped']) {
        final params = AnalyticsService.eefTourCompletedParams(
          exit: exit,
          cardsSeen: 3,
        );
        expect(
          params.keys.toSet(),
          {AnalyticsParamKey.tourExit, AnalyticsParamKey.tourCardsSeen},
        );
        expect(params[AnalyticsParamKey.tourExit], exit);
        expect(params[AnalyticsParamKey.tourCardsSeen], isA<int>());
        expect(params[AnalyticsParamKey.tourCardsSeen], 3);
      }
    });

    test('aucune clé de propriété ne désigne une donnée personnelle', () {
      final personal = RegExp(
        r'name|nom|mail|phone|tel|whatsapp|passport|passeport|country|pays|'
        r'user|uid|profile|age|birth|address|suspend',
        caseSensitive: false,
      );
      final keys = <String>{
        ...AnalyticsService.eefTourShownParams(trigger: 'replay').keys,
        ...AnalyticsService.eefTourCompletedParams(
          exit: 'finished',
          cardsSeen: 1,
        ).keys,
      };
      for (final key in keys) {
        expect(personal.hasMatch(key), isFalse, reason: key);
      }
    });

    test('docs/analytics-event-contract.md documente la visite', () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final needle in [
        '`eef_tour_shown`',
        '`eef_tour_completed`',
        '`tour_trigger`',
        '`first_open`',
        '`replay`',
        '`tour_exit`',
        '`finished`',
        '`skipped`',
        '`tour_cards_seen`',
      ]) {
        expect(doc, contains(needle), reason: '$needle absent du contrat');
      }
    });
  });

  // Les trous de mesure comblés en octobre 2026 : chaque nouvel événement
  // porte EXACTEMENT ses clés — jamais un texte saisi.
  group('trous de mesure (octobre 2026)', () {
    String doc() => File('docs/analytics-event-contract.md').readAsStringSync();

    test('`onboarding_validation_failed` : `step` et `reason`, rien d\'autre',
        () {
      expect(AnalyticsEventName.onboardingValidationFailed,
          'onboarding_validation_failed');
      expect(
        AnalyticsService.onboardingValidationParams(
                step: 1, reason: 'consent_missing')
            .keys
            .toSet(),
        {AnalyticsParamKey.step, AnalyticsParamKey.reason},
      );
    });

    test('`ai_coach_message_sent` ne porte jamais le texte de la question', () {
      final params = AnalyticsService.coachMessageParams(
        source: 'suggestion',
        result: 'ok',
      );
      expect(params.keys.toSet(), {
        AnalyticsParamKey.source,
        AnalyticsParamKey.result,
        AnalyticsParamKey.quotaRemaining,
      });
      // Quota inconnu : -1, pas une clé absente (un trou dans le tableau).
      expect(params[AnalyticsParamKey.quotaRemaining], -1);
    });

    test('`view_item` dit la famille du contenu', () {
      expect(
        AnalyticsService.viewItemParams('p1', 'program'),
        {
          AnalyticsParamKey.itemId: 'p1',
          AnalyticsParamKey.itemCategory: 'program'
        },
      );
    });

    test('docs/analytics-event-contract.md documente les nouveautés', () {
      final text = doc();
      for (final name in [
        'onboarding_validation_failed',
        'ai_coach_message_sent',
        'ai_coach_load_failed',
        'kpb_screen',
        'item_category',
      ]) {
        expect(text, contains(name), reason: name);
      }
    });
  });

  // Parrainage côté app (build 57) : des identifiants FERMÉS, jamais le code
  // (il désigne le parrain), ni rang, ni compteur, ni nom public.
  group('parrainage (build 57)', () {
    test('les noms d\'événements sont ceux du contrat publié', () {
      expect(AnalyticsEventName.referralCodePromptViewed,
          'referral_code_prompt_viewed');
      expect(
          AnalyticsEventName.referralCodeSubmitted, 'referral_code_submitted');
      expect(AnalyticsEventName.referralCodeSkipped, 'referral_code_skipped');
      expect(AnalyticsEventName.referralCompetitionViewed,
          'referral_competition_viewed');
      for (final name in [
        AnalyticsEventName.referralCodePromptViewed,
        AnalyticsEventName.referralCodeSubmitted,
        AnalyticsEventName.referralCodeSkipped,
        AnalyticsEventName.referralCompetitionViewed,
      ]) {
        expect(name.length, lessThanOrEqualTo(40), reason: name);
      }
    });

    test('les propriétés sont EXACTEMENT celles du contrat', () {
      expect(
        AnalyticsService.referralCodeParams(
                surface: 'onboarding', prefill: 'none')
            .keys
            .toSet(),
        {AnalyticsParamKey.surface, AnalyticsParamKey.prefill},
      );
      expect(
        AnalyticsService.referralCodeParams(
                surface: 'referral_screen',
                prefill: 'install_referrer',
                result: 'attributed')
            .keys
            .toSet(),
        {
          AnalyticsParamKey.surface,
          AnalyticsParamKey.prefill,
          AnalyticsParamKey.result,
        },
      );
      expect(
        AnalyticsService.referralCompetitionParams('running'),
        {AnalyticsParamKey.campaignPhase: 'running'},
      );
    });

    test('aucune clé ne désigne une donnée personnelle', () {
      final personal = RegExp(
        r'name|nom|mail|phone|code|rank|city|ville|user|uid|id$|profile',
        caseSensitive: false,
      );
      for (final key in [
        ...AnalyticsService.referralCodeParams(
                surface: 'onboarding', prefill: 'none', result: 'error')
            .keys,
        ...AnalyticsService.referralCompetitionParams('none').keys,
      ]) {
        expect(personal.hasMatch(key), isFalse, reason: key);
      }
    });

    test('docs/analytics-event-contract.md documente les quatre événements',
        () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final needle in [
        '`referral_code_prompt_viewed`',
        '`referral_code_submitted`',
        '`referral_code_skipped`',
        '`referral_competition_viewed`',
        '`prefill`',
        '`campaign_phase`',
      ]) {
        expect(doc, contains(needle), reason: needle);
      }
    });
  });
}
