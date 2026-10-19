// Chantier « corrections juridiques 57 » (validé par le propriétaire le
// 19/10/2026) : la politique — in-app FR et EN, page web — et la page de
// suppression disent la même chose, et ce qu'elles disent est vrai du code.
//
// 1. push promotionnel en OPT-IN (App Store 4.5.4) ;
// 2. et 3. base légale : exécution du service, consentements listés, intérêt
//    légitime (analytique avec droit d'opposition, anti-fraude du parrainage),
//    obligation légale (trace des prix versés) — plus jamais « l'acceptation de
//    cette politique », ni pour la base légale, ni pour les transferts ;
// 4. signalements orphelins gardés 12 mois après la suppression du compte ;
// 5. plus de données analytiques « conservées indéfiniment » ;
// 6. information des changements par notification, sans réacceptation ;
// 7. un ambassadeur mineur n'apparaît au classement public qu'avec
//    l'autorisation parentale vérifiée.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  final fr = _read('lib/app/core/translations/app_translations_fr.dart');
  final en = _read('lib/app/core/translations/app_translations_en.dart');
  final web = _read('web/public/confidentialite.html');
  final deletion = _read('web/public/suppression-compte.html');

  /// Le texte RENDU d'une entrée (le source Dart échappe l'apostrophe).
  String entry(String source, String key) {
    final start = source.indexOf("  '$key':");
    expect(start, isNot(-1), reason: 'clé $key absente');
    final end = source.indexOf(
      RegExp(r"^  '[a-z_0-9]+':", multiLine: true),
      start + key.length + 4,
    );
    return source.substring(start, end).replaceAll("\\'", "'");
  }

  void saysFr(String needle, List<String> keys) {
    final inApp = keys.map((k) => entry(fr, k)).join();
    expect(inApp, contains(needle), reason: 'politique in-app : « $needle »');
    expect(web, contains(needle), reason: 'confidentialite.html : « $needle »');
  }

  void saysEn(String needle, List<String> keys) {
    final inApp = keys.map((k) => entry(en, k)).join();
    expect(inApp, contains(needle), reason: 'EN policy: "$needle"');
  }

  test('1. push promotionnel : opt-in, deux choix distincts, FR/EN/web', () {
    saysFr('Nouvelles et offres de KPB par notification', ['privacy_s3_body']);
    saysFr('Nouvelles et offres de KPB par e-mail', ['privacy_s3_body']);
    saysFr('Les deux choix sont distincts et désactivés par défaut',
        ['privacy_s3_body']);
    saysEn('KPB news and offers by notification', ['privacy_s3_body']);
    saysEn(
        'The two choices are separate and off by default', ['privacy_s3_body']);
    for (final text in [entry(fr, 'privacy_s3_body'), web]) {
      expect(text, isNot(contains('tant que vous ne les avez pas coupées')));
    }
    // Les libellés cités sont ceux de l'app.
    expect(entry(fr, 'kpb_promotions_pref_title'),
        contains('Nouvelles et offres de KPB par notification'));
    expect(entry(fr, 'profile_promotions_email'),
        contains('Nouvelles et offres de KPB par e-mail'));
    expect(entry(en, 'kpb_promotions_pref_title'),
        contains('KPB news and offers by notification'));
    // Et le serveur l'exige.
    final rule = _read('backend/src/modules/notifications/campaign-purpose.ts');
    expect(
        rule,
        contains("if (recipient.promotionsPushOptIn !== true) "
            "return 'push_no_consent';"));
    expect(rule, contains("'push_minor_without_guardian'"));
  });

  test('2. et 3. base légale : exécution du service, consentements listés', () {
    for (final needle in [
      'Exécution du service',
      'Intérêt légitime : prévention de la fraude au parrainage et à la '
          'compétition (empreintes anti-fraude, identifiant d\'installation)',
      'Obligation légale : conservation comptable de la trace des prix versés',
      'Intérêt légitime, avec votre droit de vous y opposer',
      'Activer KPB Intelligence',
      'Mineurs de 16 et 17 ans',
    ]) {
      saysFr(needle, ['privacy_s4_body']);
    }
    for (final needle in [
      'Performance of the service',
      'Legitimate interest: preventing referral and competition fraud',
      'Legal obligation: keeping the accounting record of prizes paid',
      'Legitimate interest, with your right to object',
      'Enable KPB Intelligence',
      'Minors aged 16 and 17',
    ]) {
      saysEn(needle, ['privacy_s4_body']);
    }
    // Plus jamais « l'acceptation de la politique » comme fondement.
    for (final text in [
      entry(fr, 'privacy_s4_body'),
      entry(fr, 'privacy_transfers_body'),
      web,
    ]) {
      expect(text, isNot(contains('vous acceptez cette politique')));
      expect(text, isNot(contains('consentement à cette politique')));
    }
    for (final text in [
      entry(en, 'privacy_s4_body'),
      entry(en, 'privacy_transfers_body'),
    ]) {
      expect(text, isNot(contains('you accept this policy')));
      expect(text, isNot(contains('consent to this policy')));
    }
    saysFr('Ces transferts sont nécessaires pour vous fournir le service',
        ['privacy_transfers_body']);
    saysEn('These transfers are necessary to provide the service',
        ['privacy_transfers_body']);
    // Les noms cités existent dans l'app : la fenêtre de consentement IA.
    expect(entry(fr, 'ai_consent_title'), contains('Activer KPB Intelligence'));
    expect(entry(en, 'ai_consent_title'), contains('Enable KPB Intelligence'));
  });

  test('4. signalements orphelins : 12 mois, texte ET purge', () {
    saysFr('pendant 12 mois après sa suppression', ['privacy_community_body']);
    saysFr('12 mois après la suppression du compte, puis effacés',
        ['privacy_s6_body']);
    saysEn('for 12 months after its deletion', ['privacy_community_body']);
    saysEn('12 months after the account is deleted, then erased',
        ['privacy_s6_body']);
    expect(deletion, contains('(12 mois après la suppression, puis effacés)'));
    final constants =
        _read('backend/src/modules/community/community.constants.ts');
    expect(constants,
        contains('export const COMMUNITY_ORPHAN_REPORT_RETENTION_DAYS = 365;'));
    final purge =
        _read('backend/src/modules/community/community-purge-cron.service.ts');
    expect(purge, contains('reporterDeletedAt'));
    expect(purge, contains('COMMUNITY_ORPHAN_REPORT_RETENTION_DAYS'));
  });

  test('5. analytique : plus de « conservées indéfiniment », pas de chiffre',
      () {
    for (final text in [entry(fr, 'privacy_s6_body'), web]) {
      expect(text, isNot(contains('conservées indéfiniment')));
    }
    expect(entry(en, 'privacy_s6_body'), isNot(contains('kept indefinitely')));
    saysFr('pendant la durée de rétention de l\'outil, puis supprimés',
        ['privacy_s6_body']);
    saysEn('kept for the tool\'s retention period, then deleted',
        ['privacy_s6_body']);
    // La durée n'est documentée nulle part : l'inventaire le dit.
    expect(_read('docs/data-inventory.md'),
        contains('À VALIDER (propriétaire) : durée de rétention PostHog'));
  });

  test('6. modifications : notification avant, aucune « acceptation tacite »',
      () {
    saysFr('nous vous en informons dans l\'application, par une notification',
        ['privacy_s10_body']);
    saysEn('we inform you in the app, through a notification',
        ['privacy_s10_body']);
    for (final text in [entry(fr, 'privacy_s10_body'), web]) {
      expect(text, isNot(contains('En continuant à utiliser')));
    }
    expect(
        entry(en, 'privacy_s10_body'), isNot(contains('By continuing to use')));
    // Aucun mécanisme de réacceptation : le pack prévoit la notification.
    expect(_read('docs/release-57-store-pack.md'),
        contains('« Notre politique évolue »'));
  });

  test('7. classement public : mineur absent sans autorisation vérifiée', () {
    saysFr(
        'sans cette autorisation vérifiée, son nom public n\'apparaît pas au '
        'classement public',
        ['privacy_referral_body']);
    saysEn(
        'without that verified authorisation, their public name does not '
        'appear on the public leaderboard',
        ['privacy_referral_body']);
    final rules =
        _read('backend/src/modules/referrals/campaigns/campaign-rules.ts');
    expect(rules, contains("p.parentalAuthStatus !== 'verified'"));
    final service = _read(
        'backend/src/modules/referrals/campaigns/referral-campaign.service.ts');
    expect(service, contains('const rankable = rows.filter('));
  });

  test('chaque passage modifié porte sa note de relecture (non affichée)', () {
    expect(
        RegExp('Chantier juridique 57.{0,80}à relire par le propriétaire')
            .allMatches(web)
            .length,
        greaterThanOrEqualTo(4));
    expect(deletion, contains('à relire par le propriétaire'));
    for (final source in [fr, en]) {
      expect(
          RegExp('Chantier juridique 57', multiLine: true)
              .allMatches(source)
              .length,
          greaterThanOrEqualTo(6));
    }
  });
}
