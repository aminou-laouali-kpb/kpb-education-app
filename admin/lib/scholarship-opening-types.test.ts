import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  CYCLE_OPENING_SKIP_REASONS,
  OPENING_AUDIENCE_SCOPES,
  OPENING_AUDIT_ACTIONS,
  OPENING_ERROR_CODES,
  OPENING_EVENT_OUTCOMES,
  OPENING_NOTIFICATION_REASONS,
  OPENING_NOTIFICATION_STATES,
  SCHOLARSHIP_OPENING_MODES,
} from './scholarship-opening-types';

// Les types de l'annonce d'ouverture sont une copie manuelle du contrat
// backend. Une copie dérive : un état ou un code d'erreur ajouté au serveur et
// absent d'ici serait affiché comme « inconnu », ou pire, pris pour un autre.
// Ce test relit le fichier backend (le dépôt est extrait en entier en CI) et
// compare chaque vocabulaire.

const contract = readFileSync(
  join(
    __dirname,
    '..',
    '..',
    'backend',
    'src',
    'modules',
    'scholarships-index',
    'opening',
    'scholarship-opening.contract.ts',
  ),
  'utf8',
);

/** Les chaînes de `export const NAME = [ … ] as const;` dans le contrat backend, ou `null`. */
function backendListOrNull(name: string): string[] | null {
  const match = new RegExp(
    `export const ${name} = \\[([\\s\\S]*?)\\] as const;`,
  ).exec(contract);
  return match ? [...match[1].matchAll(/'([^']+)'/g)].map(([, value]) => value) : null;
}

function backendList(name: string): string[] {
  const list = backendListOrNull(name);
  if (!list) throw new Error(`${name} introuvable dans le contrat backend`);
  return list;
}

describe('scholarship-opening-types — aligné sur le contrat backend', () => {
  it.each([
    ['SCHOLARSHIP_OPENING_MODES', SCHOLARSHIP_OPENING_MODES],
    ['OPENING_AUDIENCE_SCOPES', OPENING_AUDIENCE_SCOPES],
    ['OPENING_ERROR_CODES', OPENING_ERROR_CODES],
    ['OPENING_NOTIFICATION_STATES', OPENING_NOTIFICATION_STATES],
    ['OPENING_NOTIFICATION_REASONS', OPENING_NOTIFICATION_REASONS],
    ['CYCLE_OPENING_SKIP_REASONS', CYCLE_OPENING_SKIP_REASONS],
    ['OPENING_AUDIT_ACTIONS', OPENING_AUDIT_ACTIONS],
  ] as const)('%s', (name, mirror) => {
    expect([...mirror]).toEqual(backendList(name));
  });
});

// Vocabulaire ajouté en même temps des deux côtés (issue des événements) : le
// lot backend le déclare dans le contrat sous ce nom. Tant qu'il n'y est pas
// (branche admin seule), la comparaison est SAUTÉE, et se voit comme telle ;
// dès qu'il y est, elle s'applique comme les autres.
describe('scholarship-opening-types — vocabulaires ajoutés avec le backend', () => {
  it.skipIf(backendListOrNull('OPENING_EVENT_OUTCOMES') === null)(
    'OPENING_EVENT_OUTCOMES',
    () => {
      expect([...OPENING_EVENT_OUTCOMES]).toEqual(backendList('OPENING_EVENT_OUTCOMES'));
    },
  );
});
