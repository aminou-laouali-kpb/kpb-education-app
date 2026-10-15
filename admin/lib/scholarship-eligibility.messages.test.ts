import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { CLIENT_ERROR_CODES } from './scholarship-eligibility';
import {
  AGE_AS_OF_KINDS,
  CRITERION_IMPACTS,
  CRITERION_TYPES,
  DIPLOMAS,
  ELIGIBLE_LEVELS,
  EXPERIENCE_BANDS,
  FIELDS_SCOPES,
  GRADE_BANDS,
  LANGUAGE_BANDS,
  LANGUAGE_TEST_TYPES,
  NATIONALITY_APPLIES_TO,
  NATIONALITY_MODES,
} from './scholarship-eligibility-types';

// Ce que l'éditeur d'éligibilité, le compteur de couverture et l'aperçu
// affichent existe dans les deux langues, avec les mêmes variables. Sur le
// modèle de `scholarship-opening.messages.test.ts`.

type Messages = Record<string, unknown>;
const load = (locale: string): Messages =>
  JSON.parse(readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'));
const fr = load('fr');
const en = load('en');

function lookup(messages: Messages, key: string): unknown {
  return key
    .split('.')
    .reduce<unknown>(
      (current, part) =>
        current && typeof current === 'object' ? (current as Messages)[part] : undefined,
      messages,
    );
}

function leafKeys(value: unknown, prefix = ''): string[] {
  if (value && typeof value === 'object') {
    return Object.entries(value as Messages).flatMap(([key, child]) =>
      leafKeys(child, prefix ? `${prefix}.${key}` : key),
    );
  }
  return [prefix];
}

const E = 'scholarships.eligibility';

function expectInBothLocales(key: string) {
  expect({ key, fr: typeof lookup(fr, key) }).toEqual({ key, fr: 'string' });
  expect({ key, en: typeof lookup(en, key) }).toEqual({ key, en: 'string' });
}

/** Fichiers relus pour y trouver chaque clé, préfixes `${E}`, `${P}`, `${C}` résolus. */
const SOURCES: Array<[string[], Record<string, string>]> = [
  [['components', 'scholarships', 'ScholarshipEligibilityEditor.tsx'], { E }],
  [['components', 'scholarships', 'MatchPreviewDrawer.tsx'], { P: `${E}.preview` }],
  [['components', 'scholarships', 'EligibilityCoverageCard.tsx'], { C: `${E}.coverage` }],
  [['app', 'scholarships', 'page.tsx'], {}],
  [['app', 'cases', 'page.tsx'], {}],
];

describe('messages de l’éligibilité structurée', () => {
  it('donnent les mêmes clés en français et en anglais', () => {
    expect(leafKeys(lookup(fr, E)).sort()).toEqual(leafKeys(lookup(en, E)).sort());
  });

  it('gardent les mêmes variables `{…}` dans les deux langues', () => {
    const variables = (text: unknown) =>
      [...String(text).matchAll(/\{(\w+)\}/g)].map((match) => match[1]).sort();
    for (const key of leafKeys(lookup(fr, E), E)) {
      expect({ key, vars: variables(lookup(en, key)) }).toEqual({
        key,
        vars: variables(lookup(fr, key)),
      });
    }
  });

  it('ne laissent aucun texte vide', () => {
    for (const messages of [fr, en]) {
      for (const key of leafKeys(lookup(messages, E), E)) {
        const text = lookup(messages, key);
        expect({ key, ok: typeof text === 'string' && text.trim() !== '' }).toEqual({ key, ok: true });
      }
    }
  });

  it('couvrent chaque clé écrite en toutes lettres dans les écrans', () => {
    const used = new Set<string>();
    for (const [parts, prefixes] of SOURCES) {
      const source = readFileSync(join(__dirname, '..', ...parts), 'utf8');
      for (const match of source.matchAll(/`\$\{(\w)\}\.([A-Za-z_.]+)`/g)) {
        const prefix = prefixes[match[1]];
        // Un préfixe (`${P}.diploma_`) est complété ailleurs : vérifié par énumération.
        if (prefix && !/[._]$/.test(match[2])) used.add(`${prefix}.${match[2]}`);
      }
      // (Une constante de préfixe, `const P = '…preview';`, n'est pas une clé.)
      for (const match of source.matchAll(/(?<!= )'((?:scholarships\.eligibility\.|cases\.linked)[A-Za-z_.]+)'/g)) {
        // Un préfixe (`…level_`) est complété ailleurs : vérifié par énumération.
        if (!/[._]$/.test(match[1])) used.add(match[1]);
      }
    }
    expect(used.size).toBeGreaterThan(80);
    for (const key of used) expectInBothLocales(key);
  });

  it('ont un libellé pour chaque valeur d’énumération affichée', () => {
    for (const type of CRITERION_TYPES) expectInBothLocales(`${E}.type_${type}`);
    for (const impact of CRITERION_IMPACTS) expectInBothLocales(`${E}.impact_${impact}`);
    for (const value of NATIONALITY_APPLIES_TO) expectInBothLocales(`${E}.appliesTo_${value}`);
    for (const mode of NATIONALITY_MODES) expectInBothLocales(`${E}.mode_${mode}`);
    for (const kind of AGE_AS_OF_KINDS) expectInBothLocales(`${E}.asOf_${kind}`);
    for (const level of ELIGIBLE_LEVELS) expectInBothLocales(`${E}.level_${level}`);
    for (const scope of FIELDS_SCOPES) expectInBothLocales(`${E}.fieldsScope_${scope}`);
    for (const test of LANGUAGE_TEST_TYPES) expectInBothLocales(`${E}.test_${test}`);
    for (const code of CLIENT_ERROR_CODES) expectInBothLocales(`${E}.error_${code}`);
    for (const state of ['fresh', 'stale', 'unstructured', 'not_analyzed']) {
      expectInBothLocales(`${E}.cell_${state}`);
      expectInBothLocales(`${E}.state_${state}`);
    }
    for (const status of ['eligible', 'to_verify', 'not_eligible', 'suspended', 'not_analyzed']) {
      expectInBothLocales(`${E}.preview.status_${status}`);
    }
    for (const value of DIPLOMAS) expectInBothLocales(`${E}.preview.diploma_${value}`);
    for (const value of GRADE_BANDS) expectInBothLocales(`${E}.preview.grade_${value}`);
    for (const value of LANGUAGE_BANDS) expectInBothLocales(`${E}.preview.languageBand_${value}`);
    for (const value of EXPERIENCE_BANDS) expectInBothLocales(`${E}.preview.experience_${value}`);
  });

  it('rappellent que le dépôt fait foi sur les fiches du catalogue', () => {
    expect(String(lookup(fr, `${E}.catalogWarning`))).toContain('le dépôt fait foi');
    expect(String(lookup(en, `${E}.catalogWarning`))).toContain('source of truth');
  });

  it('ne parlent jamais de « chances » (le test ne promet rien)', () => {
    for (const [messages, banned] of [
      [fr, /chance/i],
      [en, /chance|odds/i],
    ] as const) {
      for (const key of leafKeys(lookup(messages, E), E)) {
        expect({ key, banned: banned.test(String(lookup(messages, key))) }).toEqual({
          key,
          banned: false,
        });
      }
    }
  });
});
