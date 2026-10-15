import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  AGE_AS_OF_KINDS,
  CEFR_LEVELS,
  CRITERION_IMPACTS,
  CRITERION_TYPES,
  DIPLOMAS,
  ELIGIBLE_LEVELS,
  EXPERIENCE_BANDS,
  GRADE_BANDS,
  LANGUAGE_BANDS,
  LANGUAGE_TEST_SCALES,
  NATIONALITY_APPLIES_TO,
  NATIONALITY_MODES,
} from './scholarship-eligibility-types';

// Les énumérations de l'admin sont un MIROIR du moteur
// (`backend/src/modules/scholarship-match/`). Quand le dépôt est complet, on
// relit les sources du serveur pour qu'un jeton ajouté d'un côté se voie de
// l'autre. Dans une image qui ne contient que `admin/`, le test est sauté.

const MATCH = join(__dirname, '..', '..', 'backend', 'src', 'modules', 'scholarship-match');
const CRITERIA_FILE = join(MATCH, 'eligibility-criteria.ts');
const INPUTS_FILE = join(MATCH, 'match-inputs.ts');
const present = existsSync(CRITERIA_FILE) && existsSync(INPUTS_FILE);

function constArray(source: string, name: string): string[] {
  const match = new RegExp(`export const ${name} = \\[([^\\]]*)\\]`).exec(source);
  if (!match) throw new Error(`${name} introuvable`);
  return [...match[1].matchAll(/'([^']+)'/g)].map((m) => m[1]);
}

describe.skipIf(!present)('miroir des jetons du moteur', () => {
  const criteria = present ? readFileSync(CRITERIA_FILE, 'utf8') : '';
  const inputs = present ? readFileSync(INPUTS_FILE, 'utf8') : '';

  it.each([
    ['ELIGIBLE_LEVELS', ELIGIBLE_LEVELS],
    ['CRITERION_TYPES', CRITERION_TYPES],
    ['CRITERION_IMPACTS', CRITERION_IMPACTS],
    ['NATIONALITY_APPLIES_TO', NATIONALITY_APPLIES_TO],
    ['NATIONALITY_MODES', NATIONALITY_MODES],
    ['CEFR_LEVELS', CEFR_LEVELS],
  ] as const)('%s', (name, values) => {
    expect([...values]).toEqual(constArray(criteria, name));
  });

  it.each([
    ['DIPLOMAS', DIPLOMAS],
    ['GRADE_BANDS', GRADE_BANDS],
    ['LANGUAGE_BANDS', LANGUAGE_BANDS],
    ['EXPERIENCE_BANDS', EXPERIENCE_BANDS],
  ] as const)('%s', (name, values) => {
    expect([...values]).toEqual(constArray(inputs, name));
  });

  it('les types d’âge de référence et les échelles des tests', () => {
    for (const kind of AGE_AS_OF_KINDS) expect(criteria).toContain(`'${kind}'`);
    for (const [type, scale] of Object.entries(LANGUAGE_TEST_SCALES)) {
      expect(criteria).toContain(`${type}: { min: ${scale.min}, max: ${scale.max} }`);
    }
  });
});
