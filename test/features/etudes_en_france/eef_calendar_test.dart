// EefCalendar : la fenêtre de campagne, et ce qu'elle REFUSE de deviner.
//
// L'horloge et la source de dates sont injectables, et c'est le point : sans
// couture, aucun test ne peut atteindre la date de clôture — c'est l'erreur que
// le dépôt a déjà commise une fois, et que `IntakeCalendar` documente.

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';

void main() {
  // Les données de locale d'`intl`. En production ce sont les délégués de
  // `flutter_localizations` qui les initialisent en chargeant la locale de
  // l'app ; un test unitaire n'a pas de MaterialApp, donc il les pose lui-même.
  // Sans cet appel, `DateFormat('…', 'fr')` lève `LocaleDataException` — et
  // c'est ce qui a fait ajouter le repli numérique de `dayLabel`, éprouvé plus
  // bas.
  setUpAll(initializeDateFormatting);

  setUp(() {
    Get.locale = const Locale('fr');
  });

  tearDown(() {
    EefCalendar.resetForTest();
    Get.reset();
  });

  void serve({DateTime? opensAt, DateTime? closesAt}) {
    EefCalendar.windowSource =
        () => EefCampaignWindow(opensAt: opensAt, closesAt: closesAt);
  }

  void freezeAt(DateTime now) {
    EefCalendar.clock = () => now;
  }

  group('phase', () {
    // LE cas par défaut en production le jour où ce code est livré : personne
    // n'a encore posé les variables. Il ne doit produire AUCUNE annonce.
    test('sans aucune date servie, la phase est inconnue et rien ne s\'affiche',
        () {
      serve();
      freezeAt(DateTime(2026, 8, 21));

      expect(EefCalendar.phase(), EefCampaignPhase.unknown);
      expect(EefCalendar.rangeLabel(), isNull);
      expect(EefCalendar.daysUntilOpening(), isNull);
    });

    test('avant l\'ouverture annoncée', () {
      serve(opensAt: DateTime(2026, 8, 26), closesAt: DateTime(2026, 12, 15));
      freezeAt(DateTime(2026, 8, 21, 9));

      expect(EefCalendar.phase(), EefCampaignPhase.beforeOpening);
    });

    test('pendant la campagne', () {
      serve(opensAt: DateTime(2026, 8, 26), closesAt: DateTime(2026, 12, 15));
      freezeAt(DateTime(2026, 9, 30));

      expect(EefCalendar.phase(), EefCampaignPhase.open);
    });

    test('après la clôture', () {
      serve(opensAt: DateTime(2026, 8, 26), closesAt: DateTime(2026, 12, 15));
      freezeAt(DateTime(2026, 12, 16));

      expect(EefCalendar.phase(), EefCampaignPhase.closed);
    });

    test('une ouverture seule suffit à ouvrir, sans jamais clore', () {
      serve(opensAt: DateTime(2026, 8, 26));
      freezeAt(DateTime(2027, 5, 1));

      expect(EefCalendar.phase(), EefCampaignPhase.open);
    });

    // Une faute de configuration ne doit pas produire une phase qui se lit
    // comme une information : « close avant d'être ouverte » n'est pas un état
    // qu'on affiche, c'est un état qu'on tait.
    test('une fenêtre incohérente est traitée comme inconnue', () {
      serve(opensAt: DateTime(2026, 12, 15), closesAt: DateTime(2026, 8, 26));
      freezeAt(DateTime(2026, 10, 1));

      expect(EefCalendar.phase(), EefCampaignPhase.unknown);
    });
  });

  group('daysUntilOpening', () {
    // Le défaut que le comptage en jours CALENDAIRES évite : une division
    // entière de `Duration` rend 0 pour une ouverture demain à 8 h — « dans
    // 0 jour » pour quelque chose qui n'a pas eu lieu.
    test('compte les jours calendaires, pas les durées entières', () {
      serve(opensAt: DateTime(2026, 8, 22, 8));
      freezeAt(DateTime(2026, 8, 21, 23, 30));

      expect(EefCalendar.daysUntilOpening(), 1);
    });

    test('rend 5 pour une ouverture dans cinq jours', () {
      serve(opensAt: DateTime(2026, 8, 26));
      freezeAt(DateTime(2026, 8, 21, 14));

      expect(EefCalendar.daysUntilOpening(), 5);
    });

    test('rend null dès que la campagne est ouverte', () {
      serve(opensAt: DateTime(2026, 8, 26));
      freezeAt(DateTime(2026, 8, 26, 0, 1));

      expect(EefCalendar.daysUntilOpening(), isNull);
    });
  });

  group('rangeLabel', () {
    test('deux bornes, en français', () {
      serve(opensAt: DateTime(2026, 8, 26), closesAt: DateTime(2026, 12, 15));

      expect(EefCalendar.rangeLabel(), 'du 26 août 2026 au 15 décembre 2026');
    });

    test('deux bornes, en anglais', () {
      Get.locale = const Locale('en');
      serve(opensAt: DateTime(2026, 8, 26), closesAt: DateTime(2026, 12, 15));

      expect(EefCalendar.rangeLabel(), '26 August 2026 → 15 December 2026');
    });

    test('ouverture seule, pas encore ouverte', () {
      serve(opensAt: DateTime(2026, 8, 26));
      freezeAt(DateTime(2026, 8, 1));
      expect(EefCalendar.rangeLabel(), 'À partir du 26 août 2026');
    });

    // Audit build 57, T5-08 : ouverte depuis un mois, la ligne ne place plus en
    // tête une date passée et ne laisse pas croire qu'une clôture suit.
    test('ouverture seule, déjà ouverte : la date limite dépend du pays', () {
      serve(opensAt: DateTime(2026, 8, 26));
      freezeAt(DateTime(2026, 10, 31));
      expect(EefCalendar.rangeLabel(),
          'Ouverte depuis le 26 août 2026 · la date limite dépend de ton pays');
      Get.locale = const Locale('en');
      expect(EefCalendar.rangeLabel(),
          'Open since 26 August 2026 · the deadline depends on your country');
    });

    test('clôture seule', () {
      serve(closesAt: DateTime(2026, 12, 15));
      expect(EefCalendar.rangeLabel(), "Jusqu'au 15 décembre 2026");
    });
  });

  // Le repli quand les données de locale ne sont PAS chargées. On ne peut pas
  // les décharger, donc on éprouve le repli à sa source : une locale qui
  // n'existe pas fait lever `DateFormat` exactement comme une locale non
  // initialisée, et `dayLabel` doit rendre une date numérique plutôt que de
  // faire tomber l'écran.
  group('dayLabel — repli', () {
    test('rend une date numérique au lieu de lever', () {
      Get.locale = const Locale('zz');

      expect(EefCalendar.dayLabel(DateTime(2026, 8, 26)), isNotNull);
      expect(
        EefCalendar.dayLabel(DateTime(2026, 8, 26)),
        anyOf(contains('26'), contains('août')),
      );
    });

    test('rend null pour une date absente', () {
      expect(EefCalendar.dayLabel(null), isNull);
    });
  });

  // « 1er octobre », jamais « 1 octobre ». DateFormat français ne pose pas
  // l'ordinal, et la date d'ouverture de la campagne EST un premier du mois :
  // c'est donc la chaîne que tous les utilisateurs verront.
  group('dayLabel — l\'ordinal du premier du mois', () {
    test('rend « 1er » en français', () {
      expect(EefCalendar.dayLabel(DateTime(2026, 10, 1)), '1er octobre 2026');
    });

    test('les autres jours restent cardinaux', () {
      expect(EefCalendar.dayLabel(DateTime(2026, 10, 2)), '2 octobre 2026');
      expect(EefCalendar.dayLabel(DateTime(2026, 11, 15)), '15 novembre 2026');
    });

    test('l\'anglais ne prend pas l\'ordinal français', () {
      Get.locale = const Locale('en');
      expect(EefCalendar.dayLabel(DateTime(2026, 10, 1)), '1 October 2026');
    });

    test('la fenêtre servie s\'écrit correctement de bout en bout', () {
      EefCalendar.windowSource =
          () => EefCampaignWindow(opensAt: DateTime(2026, 10, 1));
      freezeAt(DateTime(2026, 9, 1));
      expect(EefCalendar.rangeLabel(), 'À partir du 1er octobre 2026');
    });
  });
}
