import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

/**
 * La migration du suivi des builds doit rester appliquable sous un parc
 * installé qu'on ne peut pas mettre à jour, et réversible par simple retour à
 * l'image précédente (les migrations ne se défont pas) : trois colonnes
 * nullables, rien d'autre.
 */
describe('migration profile_last_app_build — additive', () => {
  const sql = readFileSync(
    resolve(
      process.cwd(),
      'prisma/migrations/20261013121500_profile_last_app_build/migration.sql',
    ),
    'utf8',
  );
  const statements = sql
    .split('\n')
    .filter((line) => !line.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((statement) => statement.replace(/\s+/g, ' ').trim())
    .filter(Boolean);

  it('n’ajoute que trois colonnes nullables à UserProfile', () => {
    expect(statements).toEqual([
      'ALTER TABLE "UserProfile" ADD COLUMN "lastAppVersion" TEXT',
      'ALTER TABLE "UserProfile" ADD COLUMN "lastAppBuild" INTEGER',
      'ALTER TABLE "UserProfile" ADD COLUMN "lastAppSeenAt" TIMESTAMP(3)',
    ]);
  });

  it('reste aligné sur le schéma Prisma (champs optionnels)', () => {
    const schema = readFileSync(
      resolve(process.cwd(), 'prisma/schema.prisma'),
      'utf8',
    );
    const userProfile = /model UserProfile \{([\s\S]*?)\n\}/.exec(schema)?.[1];
    expect(userProfile).toBeDefined();
    expect(userProfile).toMatch(/^\s*lastAppVersion\s+String\?\s*$/m);
    expect(userProfile).toMatch(/^\s*lastAppBuild\s+Int\?\s*$/m);
    expect(userProfile).toMatch(/^\s*lastAppSeenAt\s+DateTime\?\s*$/m);
  });
});
