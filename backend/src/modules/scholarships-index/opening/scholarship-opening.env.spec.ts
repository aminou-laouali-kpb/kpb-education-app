import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import {
  OPENING_TUNABLE_ENV,
  PUSH_OUTBOX_ENABLED_ENV,
  SCHOLARSHIP_OPENING_MODE_ENV,
} from './scholarship-opening.contract';

/**
 * `docker-compose.yml` ne relaie au conteneur que les variables qu'il liste :
 * une variable posée dans le `.env` du VPS mais absente de la liste ne change
 * RIEN, en silence (c'est arrivé aux tâches planifiées). Chaque variable que le
 * code de l'annonce d'ouverture lit doit donc être relayée, et documentée.
 */
const compose = readFileSync(resolve(process.cwd(), '../docker-compose.yml'), 'utf8');
const backendEnvExample = readFileSync(resolve(process.cwd(), '.env.example'), 'utf8');

const NAMES = [
  SCHOLARSHIP_OPENING_MODE_ENV,
  PUSH_OUTBOX_ENABLED_ENV,
  ...Object.values(OPENING_TUNABLE_ENV).map((spec) => spec.name),
  // Lues par le dispatcher et par le worker (heures calmes).
  'KPB_PUSH_QUIET_START',
  'KPB_PUSH_QUIET_END',
];

describe('annonce d’ouverture — variables d’environnement', () => {
  it.each(NAMES)('docker-compose relaie %s', (name) => {
    expect(compose).toMatch(new RegExp(`^\\s+- ${name}=\\$\\{${name}:-[^}]*\\}$`, 'm'));
  });

  it('les défauts relayés laissent le comportement d’avant', () => {
    expect(compose).toContain(
      `- ${SCHOLARSHIP_OPENING_MODE_ENV}=\${${SCHOLARSHIP_OPENING_MODE_ENV}:-legacy}`,
    );
    expect(compose).toContain(`- ${PUSH_OUTBOX_ENABLED_ENV}=\${${PUSH_OUTBOX_ENABLED_ENV}:-true}`);
  });

  it.each(NAMES)('backend/.env.example documente %s', (name) => {
    expect(backendEnvExample).toMatch(new RegExp(`^${name}=`, 'm'));
  });
});
