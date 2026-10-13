// Correctifs 7 & 8 — les TEXTES ne doivent promettre que ce que la build 49
// livre, et décrire la dictée telle que le code la fait vraiment.
//
// ## Pourquoi une garde sur des chaînes
//
// Un texte faux ne casse aucun test de rendu : l'écran s'affiche, la couleur
// est bonne, la clé existe des deux côtés. `translations_parity_test.dart`
// vérifie que FR et EN portent le MÊME jeu de clés — pas que leurs valeurs
// disent la vérité. Les deux défauts corrigés ici vivaient donc sous une suite
// verte :
//
//   (7) `auth_intelligence_benefit_ai` vantait « lettre, entretien » sur le
//       PREMIER écran, alors que le générateur de lettres et le simulateur
//       d'entretien sont masqués par `AppConfig.aiToolsEnabled` (faux) ;
//   (8) la politique de confidentialité résumait la dictée en « le micro
//       convertit votre voix en texte », sans dire qu'Android peut faire
//       traiter cette voix hors de l'appareil.
//
// ## Le principe de ce fichier : coupler la PROMESSE au CODE qui la tient
//
// Aucune assertion ne compare un texte à un texte attendu — un tel test se
// met à jour en même temps que le mensonge et ne détecte rien. Chaque
// assertion part du code :
//
//   · les outils promis sont confrontés à `KpbToolsDrawer.toolsForTest`, qui
//     reflète les drapeaux à l'exécution ;
//   · la description de la dictée est confrontée à la présence, dans
//     `speech_input_service.dart`, du chemin réseau `allowPlatformService` ;
//   · la puce Cloud Messaging est confrontée à ce que `PushService` envoie
//     réellement (jeton + plateforme, vers notre backend seulement) ;
//   · le libellé de l'interrupteur d'analyse est confronté au fait que
//     `AnalyticsService.setCollectionEnabled` coupe bien Crashlytics.
//
// Corollaire voulu : le jour où le masque IA se lève, le groupe (A) rougit et
// force à relire la copie d'accueil au lieu de la laisser périmée à l'envers.
//
// ## Deux pièges de harnais, évités exprès
//
//  1. On lit `AppTranslations().keys` — la MAP compilée — et jamais le source
//     du fichier. Le source porte maintenant des commentaires qui citent les
//     mots interdits (« promettait lettre, entretien ») : un `contains` sur le
//     texte brut serait satisfait par la prose et resterait vert après un
//     retour du défaut. Pour les fichiers de code, dont on lit bien le source,
//     les lignes de commentaire sont retirées par [_codeWithoutComments].
//  2. Chaque groupe porte un tiroir : sans lui, une extraction cassée rend
//     « rien à vérifier », donc vert et muet.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/shell/kpb_tools_drawer.dart';

Map<String, String> _fr() => AppTranslations().keys['fr']!;
Map<String, String> _en() => AppTranslations().keys['en']!;

/// Source d'un fichier de code, PRIVÉ de ses lignes de commentaire.
///
/// Les commentaires de ce dépôt expliquent les défauts en les citant : ils
/// contiennent donc les mots que les assertions cherchent. Les garder rendrait
/// n'importe quel comptage satisfaisable par la prose seule.
String _codeWithoutComments(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'ô': 'o',
  'ö': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ÿ': 'y',
  'ç': 'c',
  'œ': 'oe',
  '’': "'",
};

String _fold(String input) {
  var out = input.toLowerCase();
  _accents.forEach((from, to) => out = out.replaceAll(from, to));
  return out;
}

/// Mots porteurs de sens d'un libellé d'outil.
///
/// Seuil à 4 lettres : il évacue les articles et les sigles (« CV », « IA »,
/// « de », « vol ») dont la présence dans une phrase ne prouverait rien.
Set<String> _significantWords(String label) => _fold(label)
    .split(RegExp(r"[^a-z]+"))
    .where((word) => word.length >= 4)
    .toSet();

bool _mentionsWord(String haystack, String word) =>
    RegExp('(?<![a-z])$word(?![a-z])').hasMatch(_fold(haystack));

/// Les libellés d'outils DÉCLARÉS dans le tiroir, drapeaux ou pas.
///
/// Lu dans le source parce que `toolsForTest` ne rend, par construction, que
/// les outils survivants : la liste complète n'existe nulle part à
/// l'exécution. `tools_flight` en particulier est masqué par un drapeau sans
/// point d'entrée de test, donc inatteignable autrement.
Set<String> _declaredToolLabels() => RegExp(r"labelKey:\s*'([a-z0-9_]+)'")
    .allMatches(
        _codeWithoutComments('lib/app/features/shell/kpb_tools_drawer.dart'))
    .map((m) => m.group(1)!)
    .toSet();

Set<String> _runtimeToolLabels() =>
    KpbToolsDrawer.toolsForTest.map((tool) => tool.labelKey).toSet();

/// La puce d'un corps de politique, isolée par son intitulé.
///
/// On assert sur la LIGNE et non sur le corps entier : sinon la suppression de
/// la puce laisserait le test vert dès qu'un autre paragraphe contient par
/// hasard les mots cherchés.
String _bullet(String body, String marker) {
  final line = body.split('\n').firstWhere(
        (l) => l.contains(marker),
        orElse: () => '',
      );
  expect(line, isNotEmpty,
      reason: 'Puce « $marker » introuvable : elle a été supprimée ou '
          'renommée, et la divulgation a disparu avec elle.');
  return line;
}

void main() {
  tearDown(() => AppConfig.aiToolsEnabledOverride = null);

  group('(0) le tiroir — le harnais mesure vraiment quelque chose', () {
    test('les deux dictionnaires sont lus et distincts', () {
      expect(_fr().length, greaterThan(1000),
          reason: 'Le bloc FR n\'est plus lu : garde morte.');
      expect(_en().length, greaterThan(1000),
          reason: 'Le bloc EN n\'est plus lu : garde morte.');
      // Témoin : une clé dont la valeur est connue et volontairement identique
      // dans les deux langues (nom de marque), plus une qui doit différer.
      expect(_fr()['coach_ai_title'], 'KPB Intelligence');
      expect(_fr()['auth_continue_email'],
          isNot(equals(_en()['auth_continue_email'])));
    });

    test('le tiroir réagit vraiment au drapeau IA', () {
      // Sans cette contre-épreuve, `masked` pourrait être calculé sur une liste
      // figée (le tiroir a déjà eu un `static final` qui gelait les drapeaux)
      // et le groupe (A) ne vérifierait plus rien.
      AppConfig.aiToolsEnabledOverride = true;
      final withAi = _runtimeToolLabels().length;
      AppConfig.aiToolsEnabledOverride = false;
      final withoutAi = _runtimeToolLabels().length;
      expect(withAi, greaterThan(withoutAi),
          reason: 'Le drapeau IA ne change plus la liste du tiroir : la '
              'dérivation des outils masqués est creuse.');
    });

    test('les libellés déclarés dans le source sont bien extraits', () {
      final declared = _declaredToolLabels();
      expect(declared.length, greaterThanOrEqualTo(9),
          reason: 'L\'extraction `labelKey:` ne lit plus le tiroir.');
      expect(declared, containsAll(<String>['tools_cv', 'tools_doc_scanner']));
    });
  });

  group('(A) le premier écran ne promet aucun outil masqué', () {
    test('aucun mot d\'un outil masqué dans le bénéfice IA de l\'accueil', () {
      final masked = _declaredToolLabels().difference(_runtimeToolLabels());

      // ── Build 51 : les quatre outils IA ne sont PLUS masqués ────────────
      //
      // Ce pin affirmait l'inverse, et le message d'échec qu'il portait disait
      // déjà quoi faire le jour de la bascule. Il est retourné plutôt que
      // supprimé : il garde la trace du sens, et il rougira si quelqu'un
      // referme le masque sans reculer la promesse de l'écran d'accueil.
      expect(
        masked,
        isNot(anyElement(isIn(<String>[
          'tools_cv',
          'tools_motivation_letter',
          'tools_interview',
          'tools_doc_review',
        ]))),
        reason: 'Un outil IA est redevenu masqué. Si c\'est voulu '
            '(--dart-define=KPB_AI_TOOLS_ENABLED=false), il faut aussi vérifier '
            'que `auth_intelligence_benefit_ai` ne le promet plus.',
      );
      // Ce que la build livre vraiment, et qu'on a donc le droit de promettre.
      expect(
        _runtimeToolLabels(),
        containsAll(<String>['tools_doc_scanner', 'tools_cv']),
      );
      // CONTRE-GARDE. La boucle ci-dessous ne prouve rien si `masked` est vide :
      // zéro mot interdit, donc zéro infraction, donc vert. Il reste au moins
      // l'espace « Études en France », masqué tant que le serveur ne l'allume
      // pas — c'est lui qui donne des dents au contrôle.
      expect(
        masked,
        isNotEmpty,
        reason: 'Plus aucun outil masqué : la vérification qui suit ne mesure '
            'plus rien. Retirer ce test plutôt que de le laisser vert à vide.',
      );

      final offenders = <String>[];
      for (final lang in <String, Map<String, String>>{
        'fr': _fr(),
        'en': _en(),
      }.entries) {
        final benefit = lang.value['auth_intelligence_benefit_ai']!;
        for (final labelKey in masked) {
          final label = lang.value[labelKey];
          if (label == null) continue;
          for (final word in _significantWords(label)) {
            if (_mentionsWord(benefit, word)) {
              offenders.add('${lang.key}: « $word » (outil masqué $labelKey)');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Le premier écran nomme un outil que le testeur ne peut pas '
            'ouvrir. Soit la copie recule, soit l\'outil est démasqué :\n'
            '  ${offenders.join('\n  ')}',
      );
    });

    test('et il nomme bien la surface IA qui EST en ligne', () {
      // Sans cette assertion, vider la chaîne ou la réduire à « KPB » ferait
      // passer le test précédent : rien à interdire, donc vert.
      final coach = _fr()['coach_ai_title']!;
      for (final map in [_fr(), _en()]) {
        expect(map['auth_intelligence_benefit_ai'], contains(coach));
      }
    });
  });

  group('(B) la politique décrit la dictée telle que le code la fait', () {
    final speech =
        _codeWithoutComments('lib/app/core/services/speech_input_service.dart');

    test('le harnais lit bien le service de dictée', () {
      expect(speech.length, greaterThan(500),
          reason: 'Source de la dictée non lue : garde morte.');
      expect(speech, contains('startListening'));
      expect(speech, contains('onDevice'));
    });

    test('tant qu\'un chemin réseau existe, la politique le nomme', () {
      final hasPlatformPath = speech.contains('allowPlatformService') &&
          speech.contains('platformService');
      if (!hasPlatformPath) {
        // La reconnaissance serait alors strictement locale : la promesse sans
        // réserve redeviendrait vraie. Ce test ne doit pas l'interdire, mais il
        // doit forcer une relecture, donc il échoue avec la consigne.
        fail('Le chemin `allowPlatformService` a disparu du service. Si la '
            'dictée est désormais strictement locale, simplifiez la puce '
            '« Dictée vocale » de privacy_s2_body et ce test avec elle.');
      }

      final frBullet = _bullet(_fr()['privacy_s2_body']!, 'Dictée vocale');
      final enBullet = _bullet(_en()['privacy_s2_body']!, 'Voice dictation');

      // Android : `onDevice: true` n'est qu'`EXTRA_PREFER_OFFLINE`, et le
      // greffon retombe SILENCIEUSEMENT sur le reconnaisseur réseau quand le
      // modèle local manque. C'est le repli que la puce doit avouer.
      expect(frBullet, contains('Android'));
      expect(frBullet, contains('hors de l\'appareil'));
      expect(enBullet, contains('Android'));
      expect(enBullet, contains('off the device'));
    });
  });

  group('(C) les chaînes réclamées par les correctifs voisins', () {
    test('les clés du repli de dictée existent en FR et EN, et diffèrent', () {
      const requested = <String>[
        'case_message_dictation_on_device_unavailable_title',
        'case_message_dictation_on_device_unavailable_body',
        'case_message_dictation_use_platform_service',
        'listening_via_platform_service',
      ];
      for (final key in requested) {
        expect(_fr()[key], isNotNull, reason: '$key absente du bloc FR');
        expect(_en()[key], isNotNull, reason: '$key absente du bloc EN');
        expect(_fr()[key]!.trim(), isNotEmpty);
        expect(_en()[key], isNot(equals(_fr()[key])),
            reason: '$key : la valeur EN est la copie du FR.');
      }
      // Le corps doit AVERTIR, pas juste constater : il nomme le tiers qui
      // traiterait la voix. Sans ça l'étudiant accepte sans savoir quoi.
      expect(_fr()['case_message_dictation_on_device_unavailable_body'],
          contains('Google'));
      expect(_en()['case_message_dictation_on_device_unavailable_body'],
          contains('Google'));
    });

    test('la puce Cloud Messaging déclare ce que le code envoie', () {
      final controller = _codeWithoutComments(
          'lib/app/core/controllers/app_controller/session.dart');
      final sync =
          RegExp(r'syncPushIdentity\(\)\s*async\s*\{(.*?)\n  \}', dotAll: true)
              .firstMatch(controller)
              ?.group(1);
      expect(sync, isNotNull,
          reason: 'syncPushIdentity() introuvable : garde morte.');
      // Seul l'identifiant de compte part, et vers NOTRE backend : le ciblage
      // se calcule sur le serveur. Une étiquette qui reviendrait ici partirait
      // sans être déclarée.
      expect(sync, contains('PushService.instance.login(userId: current.id)'));
      expect(sync!.contains('tags'), isFalse,
          reason: 'des étiquettes de ciblage repartent : déclarez-les.');

      final push =
          _codeWithoutComments('lib/app/core/services/push_service.dart');
      expect(push, contains('registerDeviceToken(token, pushPlatformName())'),
          reason: 'le jeton n\'est plus enregistré comme la puce le décrit : '
              'repointez cette garde.');
      for (final leak in ['email', 'addTags', 'setTags', 'subscribeToTopic']) {
        expect(push.contains(leak), isFalse,
            reason: 'PushService transmet « $leak » : la puce dit « aucun '
                'identifiant de compte ni donnée de profil ».');
      }

      final frBullet = _bullet(_fr()['privacy_s5_body']!, 'Cloud Messaging');
      final enBullet = _bullet(_en()['privacy_s5_body']!, 'Cloud Messaging');
      expect(frBullet, contains('aucun identifiant de compte'));
      expect(enBullet, contains('no account identifier'));
    });

    // OneSignal ne vit plus dans ce code, mais les versions qui l'embarquent
    // sont encore installées : le serveur leur envoie leurs notifications, et
    // leurs abonnements portent les quatre étiquettes qu'elles envoyaient. La
    // source de vérité est donc l'artefact figé — ces quatre mots ne bougeront
    // plus. La puce disparaîtra avec le repli serveur (`PushSenderService`).
    test('la puce OneSignal reste tant que le serveur garde le repli', () {
      final router = _codeWithoutComments(
          'backend/src/modules/notifications/push-sender.service.ts');
      if (!router.contains('OneSignalSenderService')) {
        fail('Le repli OneSignal a été retiré du serveur : supprimez la puce '
            'OneSignal des deux politiques, et ce test.');
      }
      final frBullet = _bullet(_fr()['privacy_s5_body']!, 'OneSignal');
      final enBullet = _bullet(_en()['privacy_s5_body']!, 'OneSignal');
      expect(frBullet, contains('versions antérieures'));
      expect(enBullet, contains('earlier versions'));
      for (final word in [
        'type de compte',
        'niveau d\'études',
        'pays visé',
        'langue',
        'jamais votre adresse e-mail',
      ]) {
        expect(frBullet, contains(word), reason: word);
      }
      for (final word in [
        'account type',
        'study level',
        'target country',
        'language',
        'never your email address',
      ]) {
        expect(enBullet, contains(word), reason: word);
      }
    });

    test('l\'interrupteur d\'analyse nomme ce qu\'il coupe vraiment', () {
      final analytics =
          _codeWithoutComments('lib/app/core/services/analytics_service.dart');
      expect(analytics, contains('setCollectionEnabled'),
          reason: 'Source de l\'analytique non lue : garde morte.');

      if (!analytics.contains('crashlyticsConsent')) {
        fail('setCollectionEnabled ne passe plus par Crashlytics. Retirez '
            '« diagnostics de plantage » / « crash diagnostics » de '
            'profile_analytics_desc : le libellé promettrait une coupure que '
            'le code ne fait plus.');
      }
      expect(_fr()['profile_analytics_desc'], contains('plantage'));
      expect(_en()['profile_analytics_desc'], contains('crash'));
    });
  });
}
