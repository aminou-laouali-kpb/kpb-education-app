// Les papiers de la build 56 disent des chiffres : on les recompte.
//
// Le pack de la 55 annonçait « 3 950 caractères, il en reste une cinquantaine » ;
// le champ « Notes for Review » d'Apple s'arrête à 4 000. Un décompte écrit à la
// main dans un document vieillit à la première retouche du texte. Ce test relit
// le bloc à coller, remplace les deux marqueurs par la place qu'on leur réserve,
// recompte, et compare au chiffre que le document affiche.
//
// Il garde aussi ce que le texte ne peut PAS perdre en étant raccourci : la
// déclaration d'activation à distance (guideline 2.3.1) pour chacun des trois
// interrupteurs, et la non-affiliation. Chaque garde est LIÉE à sa phrase (une
// expression régulière qui relie l'interrupteur à son état « OFF at review
// time »), pas une sous-chaîne cherchée n'importe où : « OFF at review time »
// apparaît deux fois, et l'une ne doit pas masquer la disparition de l'autre.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Place réservée, dans le décompte, à l'adresse du compte de démonstration et à
/// la méthode de lecture de son code (remplaçant `<ADDRESS>` et `<METHOD>`).
const _reserveAddress = 40;
const _reserveMethod = 120;

/// Limite du champ « Notes for Review » d'App Store Connect.
const _appleLimit = 4000;

/// Marge qu'on exige sous la limite : un mot de plus ne doit pas tout faire
/// déborder.
const _minMargin = 50;

String _read(String path) => File(path).readAsStringSync();

/// Le texte sur une seule ligne : un retour à la ligne de Markdown ne change pas
/// ce que dit la phrase.
String _flat(String text) => text.replaceAll(RegExp(r'\s+'), ' ');

/// Le bloc à coller : la première clôture dont le contenu commence par `SIGN-IN`.
String _notesBlock(String pack) {
  final match =
      RegExp(r'```\n(SIGN-IN\n.*?)\n```', dotAll: true).firstMatch(pack);
  // Appelée dans le corps d'un `group`, hors de tout `test` : `expect` y lève
  // OutsideTestException même quand tout va bien.
  if (match == null) {
    throw TestFailure(
        'le pack 56 ne contient plus le bloc « Notes for Review » '
        '(une clôture qui commence par SIGN-IN)');
  }
  return match.group(1)!;
}

String _filled(String block) => block
    .replaceAll('<ADDRESS>', 'x' * _reserveAddress)
    .replaceAll('<METHOD>', 'x' * _reserveMethod);

void main() {
  group('Pack de soumission de la build 56', () {
    final pack = _read('docs/release-56-store-pack.md');
    final block = _notesBlock(pack);
    final filled = _filled(block);

    test('le texte à coller tient sous 4 000 caractères, marge comprise', () {
      expect(block, contains('<ADDRESS>'));
      expect(block, contains('<METHOD>'));
      expect(filled.length, lessThanOrEqualTo(_appleLimit - _minMargin),
          reason: '${filled.length} caractères une fois l\'adresse '
              '($_reserveAddress) et la méthode ($_reserveMethod) réservées : '
              'il faut en garder au moins $_minMargin sous $_appleLimit');
      // Le champ compte des caractères ; on garde aussi les octets sous la
      // limite, au cas où la console compterait en UTF-8.
      expect(_utf8Length(filled), lessThanOrEqualTo(_appleLimit));
    });

    test('le décompte affiché par le document est le vrai', () {
      final stamp = RegExp(
        r'<!-- notes-for-review: chars=(\d+) bytes=(\d+) reserve=(\d+) -->',
      ).firstMatch(pack);
      expect(stamp, isNotNull,
          reason: 'le document doit afficher son décompte dans un commentaire '
              '<!-- notes-for-review: chars=… bytes=… reserve=… -->');
      final chars = int.parse(stamp!.group(1)!);
      final bytes = int.parse(stamp.group(2)!);
      final reserve = int.parse(stamp.group(3)!);
      expect(reserve, _reserveAddress + _reserveMethod);
      expect(filled.length, chars,
          reason: 'le document annonce $chars caractères, il y en a '
              '${filled.length}');
      expect(_utf8Length(filled), bytes,
          reason: 'le document annonce $bytes octets, il y en a '
              '${_utf8Length(filled)}');
      // Et la prose le répète en clair, formaté comme les autres chiffres du
      // dépôt (espace insécable avant les milliers).
      final spaced = _thousands(chars);
      expect(pack, contains('$spaced caractères'),
          reason: 'la prose du pack ne répète pas $spaced caractères');
    });

    test('rien de ce qui doit survivre au raccourcissement n\'a disparu', () {
      for (final needle in [
        'guideline 2.3.1',
        'api.kpbeducation.cloud/api/config/app',
        'update available',
        'NOT AFFILIATED WITH ANY GOVERNMENT',
        'not affiliated with Campus France',
        'excluded from our advisors\' call lists',
        'no in-app purchase',
        'AI consent',
        'Accounts require 16+',
      ]) {
        expect(block.toLowerCase(), contains(needle.toLowerCase()),
            reason: 'le texte à coller ne contient plus « $needle »');
      }
    });

    test(
        'la déclaration d\'activation à distance est liée à chaque interrupteur',
        () {
      // eefSpace : la phrase qui le nomme dit qu'il est FERMÉ à la revue.
      expect(
        block,
        matches(RegExp(
          r'flag eefSpace in api\.kpbeducation\.cloud/api/config/app\) '
          r'and is OFF at review time',
        )),
        reason: 'eefSpace n\'est plus déclaré « OFF at review time »',
      );
      // Les deux autres : « both OFF … effective only when eefSpace is ON »
      // précède les DEUX noms, dans cet ordre.
      expect(
        block,
        matches(RegExp(
          r'both OFF at review time and effective only when eefSpace is ON:'
          r'.*features\.eefHelpBubble.*features\.eefPrivateSchools',
          dotAll: true,
        )),
        reason: 'features.eefHelpBubble et features.eefPrivateSchools ne sont '
            'plus déclarés « both OFF at review time and effective only when '
            'eefSpace is ON »',
      );
      // Chacun de ces trois états doit exister : « OFF at review time » deux
      // fois au moins (eefSpace, puis les deux autres).
      expect('OFF at review time'.allMatches(block).length,
          greaterThanOrEqualTo(2));
      // Contrôle négatif : le texte ne dit jamais qu'un interrupteur est ouvert
      // à la revue (le relecteur verrait le hub : il faudrait un autre texte).
      expect(RegExp(r'\bON at review time').hasMatch(block), isFalse,
          reason: 'un interrupteur y est déclaré « ON at review time »');
    });

    test('les garanties de confidentialité et la visite restent dites', () {
      for (final needle in [
        // La bulle et la feuille n'ajoutent ni permission, ni SDK, ni hôte, ni
        // type de donnée. La phrase ne dit PAS « collects no data » : ils
        // émettent des événements d'analytique (déjà déclarés).
        'Neither adds a permission, SDK, host or data type',
        'analytics events, already declared',
        'never their name, email, phone or country name',
        'a short tour shown once on first opening',
      ]) {
        expect(block, contains(needle),
            reason: 'le texte à coller ne contient plus « $needle »');
      }
      // Cette phrase était fausse : la bulle émet `eef_bubble_opened`,
      // `eef_help_cta_tapped`, `whatsapp_handoff`…
      expect(block.toLowerCase().contains('collects data'), isFalse,
          reason: 'le texte affirme que la fonction ne collecte rien : faux, '
              'elle émet des événements d\'analytique');
    });

    test('le texte ne promet rien et ne chiffre rien de la bulle', () {
      final lower = block.toLowerCase();
      for (final banned in ['guarantee', '€', ' eur ']) {
        expect(lower.contains(banned), isFalse,
            reason: 'le texte à coller contient « $banned »');
      }
    });

    test('chaque décision du propriétaire a SA ligne, avec SA marque', () {
      // Les aiguilles « Niger », « XC-06 », « D5 » ou « ITMS-90062 » figurent
      // ailleurs dans le pack : chercher la marque n'importe où ne prouve rien.
      // On isole le tableau du §7 et on exige une ligne par lettre, a à g.
      final section = pack.substring(pack.indexOf('## 7. Décisions'));
      final rows = <String, String>{
        for (final m in RegExp(r'^\| \*\*([a-z])\*\* \|(.*)$', multiLine: true)
            .allMatches(section))
          m.group(1)!: m.group(2)!,
      };
      expect(rows.keys.toList(), ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
          reason: 'le tableau du §7 doit lister les décisions a à g, dans '
              'l\'ordre ; trouvé : ${rows.keys.toList()}');
      const byDecision = <String, List<String>>{
        // Tranchée le 06/10/2026 : la phrase de rémunération est retirée de l'app.
        'a': ['tranchée le 06/10/2026', 'la phrase est retirée'],
        'b': ['Niger'],
        'c': [
          'plus élevés que dans le public',
          'eef_help_private_point_fees_fallback',
        ],
        'd': ['+33768674292'], // qui répond
        'e': ['XC-06', 'D5'],
        // Décidées le 05/10/2026 : on n'envoie que la 56 (la 55, jamais soumise,
        // est abandonnée) et elle garde la version marketing 2.3.0.
        'f': ['la 56 seule', 'la 55 est abandonnée'],
        'g': ['ITMS-90062', '2.3.0'],
      };
      byDecision.forEach((letter, needles) {
        for (final needle in needles) {
          expect(rows[letter], contains(needle),
              reason: 'la décision ($letter) ne porte plus « $needle »');
        }
      });
    });

    test(
        'la décision (a) est TRANCHÉE : plus de clé ni de phrase de rémunération',
        () {
      final section = pack.substring(pack.indexOf('## 7. Décisions'));
      final row = RegExp(r'^\| \*\*a\*\* \|(.*)$', multiLine: true)
          .firstMatch(section)!
          .group(1)!;
      // La ligne dit qu'il n'y a plus rien à retirer, ni à décider.
      expect(row,
          contains('KPB ne se présente pas comme rémunéré par des écoles'));
      expect(row, contains('AVANT d\'allumer'));
      for (final stale in ['Si oui', 'Si non', 'retirer la clé']) {
        expect(row.contains(stale), isFalse,
            reason: 'la décision (a) est tranchée, mais la ligne dit encore '
                '« $stale »');
      }
      // Ni la clé retirée, ni la phrase, ne survivent dans le pack.
      expect(pack.contains('eef_help_private_disclosure'), isFalse);
      expect(pack.contains('KPB peut être rémunéré'), isFalse);
    });

    test('les liens relatifs du pack mènent à un fichier qui existe', () {
      final links =
          RegExp(r'`((?:docs|scripts|test|lib)/[A-Za-z0-9_./-]+\.[a-z]+)`')
              .allMatches(pack)
              .map((m) => m.group(1)!)
              .toSet();
      for (final link in links) {
        expect(File(link).existsSync(), isTrue,
            reason: 'le pack cite `$link`, qui n\'existe pas');
      }
    });
  });

  group('Exactitude : ce que les papiers affirment du code', () {
    final pack = _read('docs/release-56-store-pack.md');
    final qa = _read('docs/device-qa-build56.md');
    final console = _read('docs/CONSOLE_ANSWERS.md');
    final runbook = _read('docs/runbook-ouverture-espace-reel.md');
    final ledger = _read('docs/release-ledger.md');

    // Décision du propriétaire, 06/10/2026 : la phrase « KPB peut être rémunéré
    // par certaines écoles » n'existe plus dans l'app. Les papiers de la 56 ne la
    // décrivent donc plus comme affichée, et ne demandent plus à la retirer.
    test('les papiers de la 56 ne décrivent plus la phrase de rémunération',
        () {
      for (final entry in {
        'le pack': pack,
        'la recette appareil': qa,
        'le runbook': runbook,
        'le registre': ledger,
      }.entries) {
        for (final stale in [
          'eef_help_private_disclosure',
          'KPB peut être rémunéré',
          'KPB may be paid',
        ]) {
          expect(entry.value.contains(stale), isFalse,
              reason: '${entry.key} cite encore « $stale »');
        }
      }
      // La recette dit ce que l'étudiant lit : le point 4 sans phrase de plus.
      expect(qa, contains('Privé-4'));
      expect(qa, contains('aucune phrase de rémunération'));
    });

    // « Mesurée par script » : un chiffre écrit à la main vieillit à la première
    // clé retirée (72 avant le retrait de `eef_help_private_disclosure`, 70 après).
    // Le test refait la mesure du §1.1 : il compte les clés FR et EN, une par
    // langue, et compare au chiffre que le pack affiche.
    test(
        'le pack annonce le vrai nombre de clés `eef_help_bubble_*` et '
        '`eef_help_private_*`', () {
      final source =
          _read('lib/app/core/translations/app_translations_fr.dart') +
              _read('lib/app/core/translations/app_translations_en.dart');
      final counted = RegExp(
        r"^\s*'eef_help_(?:bubble|private)_[a-z0-9_]+':",
        multiLine: true,
      ).allMatches(source).length;
      expect(counted, greaterThan(0), reason: 'la mesure ne compte rien');
      final claimed =
          RegExp(r'les (\d+)\s+clés `eef_help_bubble_\*`').firstMatch(pack);
      expect(claimed, isNotNull,
          reason: 'le §1.1 ne dit plus « les N clés `eef_help_bubble_*` »');
      expect(int.parse(claimed!.group(1)!), counted,
          reason: 'le pack annonce ${claimed.group(1)} clés, il y en a '
              '$counted (FR + EN)');
    });

    // Le runbook et `ouverture-espace-eef.md` : avant, aucun test ne les lisait
    // vraiment (la liste de mots interdits ne contenait rien qu'ils aient jamais
    // dit). On exige ici ce qu'ils disent APRÈS la décision, et on refuse les
    // phrases d'avant.
    test(
        'le runbook dit la décision (a) tranchée, plus « deux textes compilés »',
        () {
      final flat = _flat(runbook);
      expect(flat, contains('la décision a, la rémunération, est tranchée'));
      expect(flat, contains('décision du 06/10/2026'));
      for (final stale in [
        'Deux textes de la feuille sont **compilés**',
        '(phrase sur la rémunération',
        'décisions a, b, c de',
        'phrase de rémunération, phrase sur les frais',
      ]) {
        expect(flat.contains(stale), isFalse,
            reason: 'le runbook dit encore « $stale »');
      }
    });

    test(
        'ouverture-espace-eef.md : le point 7 dit (a) tranchée, (c) seule '
        'compilée', () {
      final doc = _flat(_read('docs/ouverture-espace-eef.md'));
      final item7 = doc.substring(doc.indexOf('7. **Les décisions de la 56**'));
      expect(item7, contains('tranchée le 06/10/2026'));
      expect(item7, contains('la phrase est retirée'));
      expect(item7, contains('(c) porte sur un texte **compilé**'));
      for (final stale in [
        'KPB est-il rémunéré par des écoles privées ?',
        '(a) et (c) portent sur des textes **compilés**',
      ]) {
        expect(item7.contains(stale), isFalse,
            reason: 'le point 7 dit encore « $stale »');
      }
    });

    // #324 (hub, catalogue) et #326 (vitrine) retirent toute suspension affichée
    // et son lien ; il ne reste dans l'app que « Voir la plateforme officielle ».
    // Le texte du pack 55 §4 finissait par « les dates et suspensions affichées
    // dans l'app renvoient à leur source officielle » : collé dans la fiche, il
    // vante une fonction que la 56 n'a plus (guideline 2.3.1, métadonnées).
    test('les textes à coller de la 56 ne vantent aucune suspension affichée',
        () {
      final blocks = RegExp(r'```[a-z]*\n(.*?)```', dotAll: true)
          .allMatches(pack)
          .map((m) => m.group(1)!)
          .toList();
      expect(blocks, isNotEmpty);
      final advertises = RegExp(
        r'suspensions?\s+(affichées?|shown|displayed|visibles?)'
        r'|(affiche|shows?|displays?)[^.\n]{0,40}suspensions?'
        r'|suspensions?[^.\n]{0,40}(renvoient?|links?)\b',
        caseSensitive: false,
      );
      for (final block in blocks) {
        expect(advertises.hasMatch(block), isFalse,
            reason: 'un texte à coller de la 56 vante une suspension '
                'affichée :\n$block');
      }

      // §4 : le pack porte SON texte FR et EN, et ne renvoie plus à celui du
      // pack 55 (qui contient « suspensions »).
      final start = pack.indexOf('## 4. Google Play');
      final end = pack.indexOf('\n## 5.', start);
      expect(start, isNot(-1));
      expect(end, greaterThan(start));
      final section = pack.substring(start, end);
      final section4 = RegExp(r'```\n(.*?)\n```', dotAll: true)
          .allMatches(section)
          .map((m) => m.group(1)!)
          .toList();
      expect(section4, hasLength(2),
          reason: 'le §4 doit porter le texte FR et le texte EN à coller');
      expect(section4[0], contains('ni à Campus France'));
      expect(section4[1], contains('not affiliated with Campus France'));
      for (final text in section4) {
        expect(text, contains('https://www.campusfrance.org/fr'));
        expect(text.toLowerCase().contains('suspension'), isFalse,
            reason: 'le texte Play parle de suspension :\n$text');
      }
      expect(section.contains('valent tels quels'), isFalse,
          reason: 'le §4 renvoie encore au texte du pack 55');

      // La checklist et la réponse de console pointent vers CE texte-là.
      final checklist = _read('docs/mise-a-jour-56-checklist.md');
      expect(checklist, contains('**Pack 56 §4**'));
      expect(checklist.contains('repris par le pack 56 §4'), isFalse);
      final xc04 =
          console.split('\n').firstWhere((l) => l.contains('**XC-04**'));
      expect(xc04, contains('docs/release-56-store-pack.md'));
      expect(xc04.contains('suspension d\'un pays)'), isFalse,
          reason: 'XC-04 justifie encore « Government apps » par une '
              'suspension affichée');
    });

    test('aucun lien wa.me n\'est dit « à texte fixe » ni « rien d\'autre »',
        () {
      // Les aides de la 55 (`EefHelpMessages.forProgram`, `forFilters`,
      // `forTool`) citent l'intitulé de la formation, l'université, la ville et
      // les filtres posés ; les messages de la 56 portent le sujet choisi. Les
      // dire « fixes » fait vérifier la condition « Data Safety inchangé » à
      // l'envers.
      for (final entry in {
        'le pack': pack,
        'la fiche de recette': qa,
        'CONSOLE_ANSWERS': console,
      }.entries) {
        expect(entry.value.toLowerCase().contains('texte fixe'), isFalse,
            reason: '${entry.key} dit « texte fixe » : faux pour les aides de '
                'la 55');
      }
      final fact1 = RegExp(r'^\| 1 \| (.*)$', multiLine: true)
          .firstMatch(pack.substring(pack.indexOf('## 5. Réponses')))!
          .group(1)!;
      expect(fact1.contains('rien d\'autre'), isFalse,
          reason: 'le fait n°1 dit « rien d\'autre » : faux');
      expect(fact1, contains('intitulé'),
          reason: 'le fait n°1 doit dire que les aides de la 55 citent des '
              'données publiques du catalogue');
      expect(fact1, contains('sujet choisi'));
      expect(fact1, contains('aucune donnée personnelle'));
      final whatsAppLine = console
          .split('\n')
          .firstWhere((l) => l.startsWith('| **WhatsApp / Meta**'));
      expect(whatsAppLine, contains('intitulé'));
      expect(whatsAppLine, contains('sujet choisi'));
    });

    test('« 5 sujets » n\'est jamais promis à la seule bulle', () {
      // `EefBubbleMessages.optionsFor` : le 5e sujet (écoles privées) n'existe
      // que si `eefPrivateSchools` est vrai. La bulle seule en montre 4.
      for (final entry in {
        'le pack': pack,
        'le runbook': runbook,
        'le registre': ledger,
      }.entries) {
        expect(RegExp(r'\b5 (sujets|topics)\b').hasMatch(entry.value), isFalse,
            reason:
                '${entry.key} annonce « 5 sujets » : 4 avec la seule bulle, '
                '5 avec les écoles privées, 2 pour un compte suspendu');
      }
      expect(pack, contains('4 sujets (5 avec les écoles privées'));
      expect(pack, contains('4 topics (5 with private schools'));
    });
  });

  group('Fiche de recette de la build 56', () {
    final qa = _read('docs/device-qa-build56.md');

    test('les numéros sont uniques et continuent après Aide-43', () {
      final ids = RegExp(
              r'^\| ((?:Bulle|Visite|Privé|Serveur|Compte|Boutique)-\d+) \|',
              multiLine: true)
          .allMatches(qa)
          .map((m) => m.group(1)!)
          .toList();
      expect(ids, isNotEmpty);
      expect(ids.toSet().length, ids.length, reason: 'numéro en double : $ids');
      for (final prefix in [
        'Bulle',
        'Visite',
        'Privé',
        'Serveur',
        'Compte',
        'Boutique',
      ]) {
        final numbers = ids
            .where((id) => id.startsWith('$prefix-'))
            .map((id) => int.parse(id.split('-').last))
            .toList();
        expect(numbers, isNotEmpty, reason: 'aucun cas $prefix-');
        expect(numbers, List<int>.generate(numbers.length, (i) => i + 1),
            reason: '$prefix- doit être numéroté 1, 2, 3… sans trou');
      }
      // Aide-1 à Aide-43 appartiennent aux fiches 54 et 55 : aucun n'est repris.
      expect(RegExp(r'^\| Aide-\d+ \|', multiLine: true).hasMatch(qa), isFalse,
          reason: 'la fiche 56 ne redéfinit aucun Aide-n');
    });

    test('elle couvre tout ce que la 56 ajoute (mots d\'ensemble)', () {
      // Garde LARGE seulement : ces mots peuvent figurer dans l'en-tête. La
      // garde qui compte est la suivante, liée aux lignes.
      for (final needle in [
        'WhatsApp Business',
        'mode avion',
        'VoiceOver',
        'TalkBack',
        '360',
        'iPad',
        'eefHelpBubble',
        'eefPrivateSchools',
        'eefSpace',
        '/config/app',
        'longueur',
        'wa.me',
      ]) {
        expect(qa.toLowerCase(), contains(needle.toLowerCase()),
            reason: 'la fiche 56 ne couvre pas « $needle »');
      }
    });

    test('les effectifs de chaque section sont épinglés', () {
      // La suite 1..n sans trou n'attrape pas la disparition du DERNIER cas.
      const sizes = {
        'Bulle': 25,
        'Visite': 20,
        'Privé': 13,
        'Serveur': 10,
        'Compte': 8,
        'Boutique': 10,
      };
      sizes.forEach((prefix, expected) {
        final count = _rows(qa).keys.where((id) => id.startsWith('$prefix-'));
        expect(count.length, expected,
            reason: 'la section $prefix- compte ${count.length} cas, '
                '$expected attendus (un cas a disparu ou en a été ajouté : '
                'mettre l\'effectif à jour ICI en connaissance de cause)');
      });
    });

    test('chaque cas obligatoire existe, et porte son sujet DANS SA LIGNE', () {
      final rows = _rows(qa);
      // identifiant → ce que sa ligne doit contenir. Les mots « Niger »,
      // « Invité », « parent » figurent aussi dans l'en-tête : ils ne prouvent
      // rien hors de la ligne du cas.
      const required = <String, List<String>>{
        'Bulle-1': ['cercle vert'],
        'Bulle-2': ['catalogue'],
        'Bulle-3': ['Jamais', 'parent'],
        'Bulle-4': ['4', '5'],
        'Bulle-7': ['Niger', 'deux'],
        'Bulle-9': ['WhatsApp Business'],
        'Bulle-11': ['wa.me', 'MESURER'],
        'Bulle-13': ['WhatsApp absent', 'toast'],
        'Bulle-14': ['Mode avion'],
        'Bulle-15': ['Clavier'],
        'Bulle-16': ['Double tap', 'une seule'],
        'Bulle-19': ['VoiceOver', 'TalkBack'],
        'Bulle-21': ['iPad'],
        'Bulle-22': ['360'],
        'Bulle-23': ['Texte maximal'],
        'Bulle-24': ['eef_bubble_opened', 'whatsapp_handoff'],
        'Visite-3': ['bulle', 'eefHelpBubble'],
        'Visite-9': ['kill'],
        'Visite-10': ['Niger', 'neutre'],
        'Visite-11': ['Invité'],
        'Visite-12': ['parent'],
        'Visite-13': ['dialogue', 'PAS posé'],
        'Visite-20': ['eef_tour_shown', 'eef_tour_completed'],
        'Privé-3': ['bulle'],
        'Privé-7': ['Niger', 'organisme'],
        'Privé-8': ['eefPrivateSchools'],
        'Privé-9': ['Invité'],
        'Privé-13': ['eef_private_info_opened'],
        'Serveur-1': ['eefSpace', 'faux'],
        'Serveur-5': ['SANS', 'eefSpace'],
        'Serveur-6': ['eef-private-schools-off'],
        'Serveur-7': ['dry_run'],
        'Serveur-8': ['Ancien backend'],
        'Serveur-10': ['Soumettre', 'éteints'],
        'Compte-2': ['Niger'],
        'Compte-3': ['Invité'],
        'Compte-4': ['Parent'],
        'Compte-8': ['recalculé au tap'],
        'Boutique-1': ['non-affiliation'],
        'Boutique-5': ['six faits'],
        'Boutique-6': ['POSTHOG_API_KEY', 'AD_ID'],
        'Boutique-7': ['pubspec.lock', 'AndroidManifest.xml'],
        'Boutique-9': ['compte de démonstration'],
        'Boutique-10': ['versionCode'],
      };
      required.forEach((id, needles) {
        final row = rows[id];
        expect(row, isNotNull, reason: 'le cas $id n\'existe plus');
        for (final needle in needles) {
          expect(row!.toLowerCase(), contains(needle.toLowerCase()),
              reason: 'la ligne $id ne porte plus « $needle »');
        }
      });
    });

    test('les attendus décrivent le comportement RÉEL du code', () {
      final rows = _rows(qa);
      // Visite-13 : `EefTour.showIfFirstOpen` vérifie que la route du hub est au
      // sommet AVANT d'écrire le drapeau. Une visite empêchée par un dialogue
      // n'est donc PAS comptée comme vue ; elle reviendra au hub suivant.
      final tour13 = rows['Visite-13']!;
      expect(tour13.toLowerCase().contains('comptée comme vue'), isFalse,
          reason: 'Visite-13 promet « comptée comme vue » : le drapeau n\'est '
              'PAS posé quand un dialogue est déjà au-dessus');
      expect(tour13, contains('PAS posé'));
      expect(tour13, contains('prochaine ouverture'));
      // Privé-7 : la non-affiliation (« organisme privé d'accompagnement », pied
      // du hub) et la carte 1 neutre (« service privé d'accompagnement ») disent
      // « privé » à TOUS les comptes. Exiger l'absence du mot nu rougirait un
      // comportement correct.
      final private7 = rows['Privé-7']!;
      expect(
          RegExp(r'le mot « privé » n.apparaît', caseSensitive: false)
              .hasMatch(private7),
          isFalse,
          reason: 'Privé-7 interdit le mot « privé » nu : impossible, la '
              'non-affiliation et la carte 1 le portent');
      expect(private7, contains('école'));
      expect(private7, contains('organisme'));
      // Bulle-4 / Serveur-3 : 4 sujets avec la seule bulle, 5 avec les écoles.
      expect(rows['Serveur-3']!, contains('**4**'));
      expect(rows['Serveur-4']!, contains('**5**'));
    });

    test('l\'anglais n\'est pas promis là où la build ne le montre pas', () {
      // `kShippedLocale = 'fr'` : le sélecteur est masqué, toute préférence
      // revient à `fr`. Une fiche qui demande de « passer en anglais » sur la
      // build soumise demande l'impossible.
      final shipped = _read('lib/app/core/i18n/app_locale.dart');
      if (shipped.contains("const kShippedLocale = 'fr';")) {
        expect(qa, contains('kShippedLocale'),
            reason: 'la fiche doit dire que l\'anglais n\'est pas atteignable '
                'sur la build soumise');
      }
    });
  });
}

/// Les cas d'une fiche : « Bulle-7 » → toute la ligne du tableau.
Map<String, String> _rows(String qa) => {
      for (final m in RegExp(
              r'^\| ((?:Bulle|Visite|Privé|Serveur|Compte|Boutique)-\d+) \|(.*)$',
              multiLine: true)
          .allMatches(qa))
        m.group(1)!: m.group(2)!,
    };

int _utf8Length(String s) => s.runes.fold<int>(0, (n, r) {
      if (r <= 0x7f) return n + 1;
      if (r <= 0x7ff) return n + 2;
      if (r <= 0xffff) return n + 3;
      return n + 4;
    });

/// 3926 → « 3 926 » : le dépôt écrit les milliers avec une espace ordinaire.
String _thousands(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  return '${s.substring(0, s.length - 3)} ${s.substring(s.length - 3)}';
}
