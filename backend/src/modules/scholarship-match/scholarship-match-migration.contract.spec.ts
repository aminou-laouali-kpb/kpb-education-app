import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

/**
 * La migration du chantier D doit rester appliquable sous un parc installé
 * qu'on ne peut pas mettre à jour, et réversible par simple retour à l'image
 * précédente (les migrations ne se défont pas) : de l'ADDITIF seulement. La
 * reprise des niveaux ne doit jamais tamponner la structuration (sinon un
 * niveau tiré des tags, relu par personne, pourrait exclure un élève).
 */
describe('migration scholarship_match_v1 — additive', () => {
  const statements = readFileSync(
    resolve(
      process.cwd(),
      'prisma/migrations/20261020120000_scholarship_match_v1/migration.sql',
    ),
    'utf8',
  )
    .split('\n')
    .filter((line) => !line.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((statement) => statement.replace(/\s+/g, ' ').trim())
    .filter(Boolean);

  it('ne supprime, ne renomme et ne retype rien', () => {
    for (const statement of statements) {
      // Les actions référentielles d'une clé étrangère ne sont pas des suppressions.
      const body = statement.replace(/ON (DELETE|UPDATE) (SET NULL|CASCADE)/g, '');
      expect(body).not.toMatch(/\b(DROP|RENAME|ALTER COLUMN|TRUNCATE|DELETE)\b/i);
    }
  });

  it('chaque colonne ajoutée est nullable ou a un défaut', () => {
    const added = statements
      .filter((statement) => /^ALTER TABLE "\w+" ADD COLUMN/.test(statement))
      .flatMap((statement) => statement.replace(/^ALTER TABLE "\w+" /, '').split(/,\s*(?=ADD COLUMN)/));
    expect(added.length).toBe(17);
    for (const clause of added) {
      if (/NOT NULL/.test(clause)) expect(clause).toMatch(/NOT NULL DEFAULT /);
    }
  });

  it('la reprise ne vise que `catalog:%` et ne pose aucun tampon', () => {
    const updates = statements.filter((statement) => /^UPDATE\b/.test(statement));
    expect(updates).toHaveLength(1);
    expect(updates[0]).toContain(`LIKE 'catalog:%'`);
    expect(updates[0]).toMatch(/^UPDATE "Scholarship" AS s SET "eligibleLevels" = ARRAY\(/);
    expect(updates[0]).not.toMatch(/eligibilityStructured/);
  });
});
