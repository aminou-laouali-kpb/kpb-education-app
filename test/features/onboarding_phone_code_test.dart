// L'indicatif téléphonique est un INDICATIF — jamais un emoji, jamais un
// bricolage d'affichage.
//
// L'entrée États-Unis portait `_DialCode('🇺🇸', '+1 🇺🇸', 'États-Unis')` : le
// deuxième champ est celui qui se CONCATÈNE dans `profile.phone` et
// `profile.whatsApp`, et l'emoji n'y était que pour distinguer le `+1`
// américain du `+1` canadien dans le menu déroulant. Résultat : chaque numéro
// américain était enregistré « +1 🇺🇸 5551234567 » — et le backend l'acceptait
// tel quel (`@IsString`, aucun format). Un numéro corrompu ne se compose pas,
// ne s'ouvre pas dans WhatsApp, et empoisonne la donnée pour tous les systèmes
// d'aval. Le champ d'affichage, `label`, porte désormais la désambiguïsation ;
// il n'est jamais persisté.
//
// ## Pourquoi ces gardes sont STATIQUES
//
// Prouver « +1 5551234567 » à travers le vrai formulaire exigerait de
// traverser la page identité entière — date de naissance au sélecteur,
// consentement, validation — pour une propriété qui ne dépend d'aucun de ces
// champs. À la place, deux assertions sur la source qui, ENSEMBLE, impliquent
// le résultat :
//   (a) chaque `code` de la table matche `^\+\d{1,4}$` — l'emoji ne peut pas
//       exister dans le champ ;
//   (b) la construction du profil concatène `.code`, jamais `.label` — le
//       champ propre est bien celui qui part en base.
// Remettre `'+1 🇺🇸'` fait échouer (a) sur la seule ligne fautive.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/features/onboarding/onboarding_screen.dart';

String get _source => File('lib/app/features/onboarding/onboarding_screen.dart')
    .readAsStringSync();

/// Les entrées `_DialCode('…', '…', '…')` telles qu'écrites dans la source.
List<({String flag, String code, String country})> readDialCodes() {
  final table =
      RegExp(r'const _dialCodes = <_DialCode>\[(.*?)\];', dotAll: true)
          .firstMatch(_source);
  expect(table, isNotNull,
      reason: 'La table _dialCodes a disparu de onboarding_screen.dart.');
  final entry =
      RegExp(r"_DialCode\('([^']*)', '([^']*)', '((?:[^'\\]|\\.)*)'\)");
  return entry
      .allMatches(table!.group(1)!)
      .map((m) => (flag: m.group(1)!, code: m.group(2)!, country: m.group(3)!))
      .toList();
}

void main() {
  test(
      '(a) chaque indicatif matche ^\\+\\d{1,4}\$ — l\'emoji ne peut pas '
      'revenir', () {
    final codes = readDialCodes();
    expect(codes.length, greaterThanOrEqualTo(20),
        reason: 'L\'extraction ne lit plus la table : garde morte.');

    final pattern = RegExp(r'^\+\d{1,4}$');
    final violations = [
      for (final c in codes)
        if (!pattern.hasMatch(c.code)) '${c.country} → « ${c.code} »',
    ];
    expect(
      violations,
      isEmpty,
      reason: 'Un indicatif porte autre chose que « + » et des chiffres. Ce '
          'champ est concaténé tel quel dans profile.phone et '
          'profile.whatsApp : tout bricolage d\'affichage ici corrompt le '
          'numéro enregistré. La désambiguïsation va dans `label`.\n'
          '${violations.join('\n')}',
    );
  });

  test('les libellés restent deux à deux distincts', () {
    // C'est la contrainte qui avait produit le bricolage : deux entrées
    // « +1 », indiscernables dans le menu sans le pays. La désambiguïsation
    // doit survivre — dans le libellé, pas dans l'indicatif.
    final codes = readDialCodes();
    final labels =
        codes.map((c) => '${c.flag} ${c.code} · ${c.country}').toList();
    expect(labels.toSet().length, labels.length,
        reason: 'Deux entrées du menu sont indiscernables : l\'utilisateur ne '
            'peut plus choisir entre elles.');
    // Et les deux « +1 » existent bien tous les deux.
    expect(codes.where((c) => c.code == '+1').length, 2,
        reason: 'Le Canada et les États-Unis partagent le +1 : si l\'un des '
            'deux a disparu, la désambiguïsation a été résolue en supprimant '
            'une option au lieu de nommer le pays.');
  });

  test('(b) le profil est construit depuis `.code`, jamais depuis `.label`',
      () {
    final source = _source;
    expect(
      source.contains(r"'${_phoneCode.code} ${_phoneCtrl.text.trim()}'"),
      isTrue,
      reason: 'La construction du téléphone ne concatène plus '
          '`_phoneCode.code` : vérifiez que le champ persisté reste '
          'l\'indicatif propre.',
    );
    expect(
      source.contains(r"'${_waCode.code} ${_whatsAppCtrl.text.trim()}'"),
      isTrue,
    );
    expect(
      RegExp(r'_(phoneCode|waCode)\.label.*(phone|whatsApp)',
              caseSensitive: false)
          .hasMatch(source),
      isFalse,
      reason: 'Le LIBELLÉ (drapeau + pays) part dans un champ persisté : '
          'c\'est exactement le défaut d\'origine, déplacé d\'un champ.',
    );
  });

  // Audit build 57, T1-10 : le public est aussi en Afrique centrale, de l'Est et
  // du Nord, et la liste s'arrêtait au Cameroun.
  test('(c) les indicatifs d\'Afrique centrale, de l\'Est et du Nord existent',
      () {
    final byCountry = {for (final c in readDialCodes()) c.country: c.code};
    const expected = {
      'RD Congo': '+243',
      'Congo': '+242',
      'Gabon': '+241',
      'Tchad': '+235',
      'Centrafrique': '+236',
      'Madagascar': '+261',
      'Rwanda': '+250',
      'Burundi': '+257',
      'Djibouti': '+253',
      'Comores': '+269',
      'Tunisie': '+216',
      'Algérie': '+213',
    };
    expected.forEach((country, code) {
      expect(byCountry[country], code, reason: country);
    });
    // L'indicatif par défaut ne bouge pas : le Niger reste en tête.
    expect(readDialCodes().first.country, 'Niger');
  });

  group('validateOnboardingPhone', () {
    test('refuse un « + » tapé dans le numéro', () {
      expect(
          validateOnboardingPhone('+22790123456', required: true), isNotNull);
    });

    test('7 à 12 chiffres, espaces et tirets tolérés', () {
      expect(validateOnboardingPhone('90 12 34 56', required: true), isNull);
      expect(validateOnboardingPhone('1234567', required: true), isNull);
      expect(validateOnboardingPhone('123456789012', required: true), isNull);
      expect(validateOnboardingPhone('12', required: true), isNotNull);
      expect(
          validateOnboardingPhone('1234567890123', required: true), isNotNull);
    });

    test('vide : refusé seulement quand le champ est obligatoire', () {
      expect(validateOnboardingPhone('  ', required: true), isNotNull);
      expect(validateOnboardingPhone('', required: false), isNull);
      expect(validateOnboardingPhone(null, required: false), isNull);
    });
  });
}
