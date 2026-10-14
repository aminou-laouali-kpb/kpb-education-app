import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  CYCLE_OPENING_SKIP_REASONS,
  OPENING_AUDIENCE_SCOPES,
  OPENING_AUDIT_ACTIONS,
  OPENING_ERROR_CODES,
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

/** Les chaînes de `export const NAME = [ … ] as const;` dans le contrat backend. */
function backendList(name: string): string[] {
  const match = new RegExp(
    `export const ${name} = \\[([\\s\\S]*?)\\] as const;`,
  ).exec(contract);
  if (!match) throw new Error(`${name} introuvable dans le contrat backend`);
  return [...match[1].matchAll(/'([^']+)'/g)].map(([, value]) => value);
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
