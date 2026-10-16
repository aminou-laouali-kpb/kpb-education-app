// Chantier L2 — la voix KPB tutoie l'élève (docs/voice-guide.md).
//
// ## Ce que ce fichier interdit
//
// Aucune valeur FR ne contient « vous », « votre » ou « vos » (mots entiers,
// casse ignorée), hors exceptions NOMMÉES ci-dessous. Avant ce garde-fou,
// l'app mélangeait les deux registres d'un écran à l'autre — parfois dans le
// même écran : « Ton plan » sur l'accueil, « Vérifiez votre connexion » dans
// l'erreur juste en dessous.
//
// Comme `honest_labels_guard_test.dart`, on lit `AppTranslations().keys` (la
// map compilée), jamais le source : les commentaires du fichier de
// traductions citent des formules vouvoyées pour expliquer des défauts.
//
// « rendez-vous » est un nom commun, pas un vouvoiement : il est retiré avant
// la recherche.
//
// ## Les exceptions sont nommées, une par une
//
// Préfixes entiers : l'espace parent (on s'adresse à un adulte), la politique
// de confidentialité et les conditions d'utilisation (textes juridiques, au
// registre de leur version validée). Clés isolées : chacune porte sa raison,
// et une exception devenue inutile fait rougir le tiroir, pour qu'elle ne
// survive pas à son texte.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/translations/app_translations.dart';

/// Préfixes de clés où le vouvoiement est la règle.
const _exemptPrefixes = <String, String>{
  'parent_': 'espace parent : on vouvoie le parent',
  'privacy_': 'politique de confidentialité : texte juridique',
  'terms_': 'conditions d\'utilisation : texte juridique',
};

/// Clés isolées où le vouvoiement est légitime.
const _exemptKeys = <String, String>{
  // Messages WhatsApp pré-remplis : c'est l'ÉLÈVE qui écrit, à l'équipe KPB.
  // Vouvoyer une organisation, c'est la politesse attendue de lui.
  'external_link_failed_prefill': 'message de l\'élève à KPB',
  'kpb_prefill_case': 'message de l\'élève à KPB',
  'scholarship_guide_whatsapp_prefill': 'message de l\'élève à KPB',
  'case_document_whatsapp_prefill': 'message de l\'élève à KPB',
  'case_documents_handoff_prefill': 'message de l\'élève à KPB',
  'mentor_intro_prefill': 'message de l\'élève à KPB',
  'force_update_prefill': 'message de l\'élève à KPB',
  'scholarship_match_whatsapp_prefill': 'message de l\'élève à KPB',
  // Comptes partenaires (écoles, structures) : un public professionnel.
  'home_hero_title_partner': 'accueil du compte partenaire',
  'onboarding_partner_title': 'onboarding du compte partenaire',
  'onboarding_partner_subtitle': 'onboarding du compte partenaire',
  'partner_support': 'demande d\'échange d\'une structure partenaire',
  // Compte parent, hors du préfixe `parent_`.
  'home_hero_title_parent': 'accueil du compte parent',
  // Textes de consentement VERSIONNÉS (`premium-waitlist-v1`) : leur empreinte
  // est verrouillée par `premium_waitlist_consent_version_test.dart`, et le
  // backend n'accepte que les versions qu'il sait restituer. Les tutoyer
  // demande une `premium-waitlist-v2` : backend déployé d'abord, app ensuite.
  // À VALIDER (propriétaire) : planifier cette v2.
  'premium_waitlist_body': 'consentement versionné premium-waitlist-v1',
  'premium_waitlist_notice': 'consentement versionné premium-waitlist-v1',
  // Surface commerciale : un conseiller KPB écrit à un prospect, élève OU
  // parent. À VALIDER (propriétaire) : registre de ce modèle de réponse.
  'commercial_wa_reply': 'message d\'un conseiller à un prospect',
};

final _formalWord = RegExp(r'\b(?:vous|votre|vos)\b', caseSensitive: false);
final _rendezVous = RegExp(r'rendez-vous', caseSensitive: false);

bool _isFormal(String value) =>
    _formalWord.hasMatch(value.replaceAll(_rendezVous, ''));

bool _isExempt(String key) =>
    _exemptKeys.containsKey(key) ||
    _exemptPrefixes.keys.any((prefix) => key.startsWith(prefix));

String _codeWithoutComments(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  final fr = AppTranslations().keys['fr']!;

  group('voix KPB : l\'app tutoie l\'élève', () {
    test('tiroir : les traductions FR sont bien lues', () {
      expect(fr.length, greaterThan(1000));
    });

    test('fr : aucun « vous / votre / vos » hors exceptions nommées', () {
      final offenders = <String>[];
      fr.forEach((key, value) {
        if (_isExempt(key)) return;
        if (_isFormal(value)) offenders.add('$key: $value');
      });
      expect(offenders, isEmpty,
          reason: 'L\'app tutoie l\'élève (docs/voice-guide.md). Reformule '
              'au « tu », ou déclare l\'exception dans _exemptKeys avec sa '
              'raison.');
    });

    test('chaque exception existe encore et vouvoie encore', () {
      for (final key in _exemptKeys.keys) {
        final value = fr[key];
        expect(value, isNotNull,
            reason: '$key a disparu : retire l\'exception');
        expect(_isFormal(value!), isTrue,
            reason: '$key ne vouvoie plus : retire l\'exception');
      }
      for (final prefix in _exemptPrefixes.keys) {
        expect(fr.keys.any((key) => key.startsWith(prefix)), isTrue,
            reason: 'plus aucune clé « $prefix* » : retire le préfixe');
      }
    });

    test('la règle sait rougir (auto-test du motif)', () {
      expect(_isFormal('Vérifiez votre connexion.'), isTrue);
      expect(_isFormal('Vos initiales seront affichées.'), isTrue);
      expect(_isFormal('Pouvez-vous m\'aider ?'), isTrue);
      expect(_isFormal('VOUS êtes sur la liste'), isTrue);
      expect(_isFormal('Prendre rendez-vous'), isFalse);
      expect(_isFormal('Rendez-vous confirmé'), isFalse);
      expect(_isFormal('Vérifie ta connexion.'), isFalse);
    });
  });

  test('dossier créé sur l\'appareil : ses textes passent par les traductions',
      () {
    // `submitCase` écrivait ses libellés en dur (« Votre dossier est en
    // revue », « visible dans My Cases ») : hors du test de parité, hors de
    // cette garde, et vouvoyés. Ils viennent maintenant des clés
    // `case_local_*`, lues dans les deux langues.
    final code = _codeWithoutComments(
        'lib/app/core/controllers/app_controller/cases.dart');
    expect(RegExp(r'''fr:\s*['"]''').hasMatch(code), isFalse,
        reason: 'un texte FR en dur est revenu dans cases.dart');
    expect(code, isNot(contains('My Cases')));
    expect(code, isNot(contains('KPB Operations')));
    for (final key in const [
      'case_local_next_step_title',
      'case_local_next_step_body',
      'case_local_submitted_title',
      'case_local_submitted_body',
      'case_local_welcome_sender',
      'case_local_welcome_body',
      'case_local_doc_profile_title',
      'case_local_student_reply_title',
      'case_local_student_reply_body',
    ]) {
      expect(code, contains("'$key'"), reason: '$key n\'est plus utilisée');
    }
  });
}
