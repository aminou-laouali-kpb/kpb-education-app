#!/usr/bin/env node
// Génère lib/app/core/data/world_countries_table.dart : tous les pays du
// monde avec leur indicatif téléphonique, pour l'inscription dans l'app.
//
// Deux sources, aucune saisie à la main :
//   - backend/src/common/iso-countries.ts : codes ISO 3166-1, noms français et
//     anglais. C'est la table que le serveur utilise pour reconnaître le pays
//     de résidence d'un profil : l'app enregistre donc des noms qu'il résout.
//   - libphonenumber-js (dépendance du backend) : indicatifs, et longueurs des
//     numéros de mobile, tenus à jour par Google.
//
// Usage, depuis la racine du dépôt, après `npm ci` dans backend/ :
//   node scripts/generate-world-countries.js && dart format lib/app/core/data/world_countries_table.dart
//
// Le test test/core/data/world_countries_test.dart relit la table du backend
// et échoue si les deux divergent.

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const ISO_SOURCE = path.join(ROOT, 'backend/src/common/iso-countries.ts');
const PHONE_ROOT = path.join(ROOT, 'backend/node_modules/libphonenumber-js');
const OUTPUT = path.join(ROOT, 'lib/app/core/data/world_countries_table.dart');

// Les noms que l'app enregistre DÉJÀ pour ces pays (liste d'inscription
// d'avant) : on les garde tels quels pour que les profils existants et les
// nouveaux portent la même valeur. Le serveur les résout tous les deux.
const NAME_FR_OVERRIDES = {
  CI: "Côte d'Ivoire",
  CD: 'RD Congo',
};
const NAME_EN_OVERRIDES = {
  CI: "Côte d'Ivoire",
  CD: 'DR Congo',
  CG: 'Congo',
};

// Territoires de la norme que l'app ne propose PAS : décision du propriétaire
// (17/11/2026). Le Kosovo, hors norme ISO, n'est pas proposé non plus, par la
// même décision : il n'y a rien à exclure ici pour lui, il ne faut simplement
// pas l'ajouter. Leurs habitants ont « Autre » et « Autre indicatif ».
// La même liste est tenue dans test/core/data/world_countries_test.dart.
const EXCLUDED_ALPHA2 = new Set([
  'EH', // Sahara occidental.
]);

// Territoires habités que libphonenumber ne décrit pas : indicatif du réseau
// qui les dessert.
const DIAL_CODE_OVERRIDES = {
  PN: '64', // Îles Pitcairn : réseau néo-zélandais.
};

// Bornes par défaut du nombre de chiffres d'un numéro (sans indicatif) : celles
// du formulaire. On ne les élargit que pour un pays dont les mobiles sortent
// de cet intervalle (Andorre : 6 chiffres), jamais on ne les resserre.
const DEFAULT_MIN_DIGITS = 7;
const DEFAULT_MAX_DIGITS = 12;

function readIsoRows() {
  const source = fs.readFileSync(ISO_SOURCE, 'utf8');
  const start = source.indexOf('const ROWS');
  const end = source.indexOf('\n];', start);
  if (start < 0 || end < 0) throw new Error('Table ROWS introuvable dans iso-countries.ts');
  const body = source.slice(source.indexOf('= [', start) + 3, end);

  const uninhabited = /const UNINHABITED = new Set\(\[([^\]]*)\]\)/.exec(source);
  if (!uninhabited) throw new Error('UNINHABITED introuvable dans iso-countries.ts');
  const skipped = new Set([...uninhabited[1].matchAll(/'([a-z]{3})'/g)].map((m) => m[1]));

  const rows = [];
  const literal = /'((?:[^'\\]|\\.)*)'/g;
  for (const row of body.matchAll(/\[([^\[\]]*)\]/g)) {
    const cells = [...row[1].matchAll(literal)].map((m) => m[1].replace(/\\(.)/g, '$1'));
    if (cells.length < 4) throw new Error(`Ligne ISO illisible : ${row[0]}`);
    const [alpha3, alpha2, nameFr, nameEn] = cells;
    if (skipped.has(alpha3) || EXCLUDED_ALPHA2.has(alpha2)) continue;
    rows.push({ alpha2, nameFr, nameEn });
  }
  return rows;
}

function fold(text) {
  return text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function dartString(text) {
  return `'${text.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$')}'`;
}

function main() {
  const { Metadata } = require(path.join(PHONE_ROOT, 'core'));
  const raw = require(path.join(PHONE_ROOT, 'metadata.max.json'));
  const version = require(path.join(PHONE_ROOT, 'package.json')).version;
  const metadata = new Metadata(raw);

  const countries = readIsoRows().map((row) => {
    let dialCode = DIAL_CODE_OVERRIDES[row.alpha2];
    let lengths = [];
    if (raw.countries[row.alpha2]) {
      metadata.selectNumberingPlan(row.alpha2);
      const plan = metadata.numberingPlan;
      dialCode = plan.callingCode();
      const mobile = plan.type('MOBILE');
      lengths = (mobile && mobile.possibleLengths()) || plan.possibleLengths() || [];
    }
    if (!dialCode) throw new Error(`Pas d'indicatif pour ${row.alpha2} (${row.nameFr})`);
    if (!/^\d{1,4}$/.test(dialCode)) throw new Error(`Indicatif inattendu pour ${row.alpha2} : ${dialCode}`);
    const minDigits = Math.min(DEFAULT_MIN_DIGITS, ...lengths);
    const maxDigits = Math.max(DEFAULT_MAX_DIGITS, ...lengths);
    return {
      iso2: row.alpha2,
      nameFr: NAME_FR_OVERRIDES[row.alpha2] || row.nameFr,
      nameEn: NAME_EN_OVERRIDES[row.alpha2] || row.nameEn,
      dialCode: `+${dialCode}`,
      minDigits,
      maxDigits,
    };
  });

  countries.sort((a, b) => fold(a.nameFr).localeCompare(fold(b.nameFr), 'fr'));

  const lines = countries.map((c) => {
    const extras = [];
    if (c.minDigits !== DEFAULT_MIN_DIGITS) extras.push(`minDigits: ${c.minDigits}`);
    if (c.maxDigits !== DEFAULT_MAX_DIGITS) extras.push(`maxDigits: ${c.maxDigits}`);
    const args = [dartString(c.iso2), dartString(c.nameFr), dartString(c.nameEn), dartString(c.dialCode), ...extras];
    return `  WorldCountry(${args.join(', ')}),`;
  });

  const header = [
    '// GÉNÉRÉ — ne pas modifier à la main.',
    '//',
    '// Sources : backend/src/common/iso-countries.ts (codes ISO, noms) et',
    `// libphonenumber-js ${version} (indicatifs, longueurs des numéros de mobile).`,
    '// Régénérer : node scripts/generate-world-countries.js, puis dart format.',
    '',
    "part of 'world_countries.dart';",
    '',
    `/// Les ${countries.length} pays et territoires habités de la norme ISO 3166-1, triés par`,
    `/// nom français. Écartés par décision du propriétaire : ${[...EXCLUDED_ALPHA2].join(', ')}.`,
    'const List<WorldCountry> _worldCountriesTable = <WorldCountry>[',
  ];
  fs.writeFileSync(OUTPUT, [...header, ...lines, '];', ''].join('\n'));
  console.log(`${countries.length} pays écrits dans ${path.relative(ROOT, OUTPUT)}`);
  const widened = countries.filter(
    (c) => c.minDigits !== DEFAULT_MIN_DIGITS || c.maxDigits !== DEFAULT_MAX_DIGITS,
  );
  console.log(
    `bornes élargies (${widened.length}) : ` +
      widened.map((c) => `${c.iso2} ${c.minDigits}-${c.maxDigits}`).join(', '),
  );
}

main();
