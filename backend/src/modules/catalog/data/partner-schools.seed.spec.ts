import * as fs from 'node:fs';
import * as path from 'node:path';

import { ORIENTATION_FIELDS } from '../../orientation/orientation-fields.data';
import {
  PARTNER_INSTITUTION_SEEDS,
  countPartnerPrograms,
} from './partner-schools.seed';

const FIELD_NAME = new Map(ORIENTATION_FIELDS.map((f) => [f.id, f.nameFr]));
const PROGRAMS = PARTNER_INSTITUTION_SEEDS.flatMap((school) => school.programs);

function fieldNameOf(programId: string): string | undefined {
  const program = PROGRAMS.find((p) => p.id === programId);
  return program && FIELD_NAME.get(program.fieldId);
}

/**
 * `Program.fieldId` n'est pas une clé étrangère : une valeur hors référentiel
 * n'échoue nulle part, la formation n'apparaît simplement sous aucun domaine.
 * C'était le cas des 76 formations de ce seed (« business »,
 * « computer_science », « engineering »).
 */
describe('seed des écoles partenaires', () => {
  it('chaque formation pointe vers un domaine du référentiel d01..d12', () => {
    const outside = PROGRAMS.filter((p) => !FIELD_NAME.has(p.fieldId)).map(
      (p) => `${p.id}=${p.fieldId}`,
    );
    expect(outside).toEqual([]);
  });

  // Le correctif se lit sur les NOMS des domaines, pas sur les identifiants :
  // c'est ce qui dit si le rangement a un sens pour l'étudiant.
  it.each([
    ['partner-p-icn-1', 'Commerce & Management'], // International BBA
    ['partner-p-sch-eu-bach-5', 'Informatique & Intelligence Artificielle'], // BS in Computer Science
    ['partner-p-sch-us-msc-5', 'Informatique & Intelligence Artificielle'], // MS in Data Science
    ['partner-p-ismagi-prep-1', 'Ingénierie & Sciences'], // Classes préparatoires intégrées
    ['partner-p-bau-7', 'Santé & Sciences de la Vie'], // Medicine
    ['partner-p-bau-8', 'Architecture & BTP'], // Architecture
    ['partner-p-bau-9', 'Design, Médias & Communication'], // Textile and Fashion Design
    ['partner-p-gbs-hnd-2', 'Informatique & Intelligence Artificielle'], // HND Cyber Security
    ['partner-p-gbs-9', 'Commerce & Management'], // ACCA
  ])('%s → %s', (programId, fieldName) => {
    expect(fieldNameOf(programId)).toBe(fieldName);
  });

  // Le garde-fou de production compte l'espace `partner-*` : un identifiant
  // hors préfixe serait écrit sans être compté.
  it('tous les identifiants sont dans l’espace partner-* et uniques', () => {
    const institutionIds = PARTNER_INSTITUTION_SEEDS.map((s) => s.id);
    const programIds = PROGRAMS.map((p) => p.id);
    expect(institutionIds.every((id) => id.startsWith('partner-'))).toBe(true);
    expect(programIds.every((id) => id.startsWith('partner-p-'))).toBe(true);
    expect(new Set(institutionIds).size).toBe(institutionIds.length);
    expect(new Set(programIds).size).toBe(programIds.length);
    expect(countPartnerPrograms()).toBe(programIds.length);
  });
});

describe('seed OMNES', () => {
  it('ne range plus aucune formation sous un domaine de démonstration', () => {
    const code = fs
      .readFileSync(
        path.join(__dirname, '../../../../scripts/seed-omnes-programs.ts'),
        'utf8',
      )
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .replace(/\/\/.*$/gm, '');
    expect(code).not.toMatch(/'(business|computer_science|engineering)'/);
    for (const [, id] of code.matchAll(/return '(d\d\d)'/g)) {
      expect(FIELD_NAME.has(id)).toBe(true);
    }
  });
});
