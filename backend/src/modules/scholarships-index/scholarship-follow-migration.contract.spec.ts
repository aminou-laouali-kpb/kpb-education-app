import { readdirSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

/**
 * Les trois migrations du chantier C (suivre une bourse, annonce d'ouverture)
 * doivent rester appliquables sous un parc installé qu'on ne peut pas mettre à
 * jour pendant trois mois, et réversibles par simple retour à l'image
 * précédente (les migrations ne se défont pas) : de l'ADDITIF seulement.
 *
 * Elles doivent aussi tenir leur promesse de verrous. `prisma migrate deploy`
 * exécute chaque fichier dans UNE transaction implicite : tout verrou pris y
 * est tenu jusqu'à la fin du fichier. D'où le découpage que ce test fige :
 *   1. colonnes, petit index et reprises de ScholarshipCycle, `lock_timeout`
 *      en tête — l'ACCESS EXCLUSIVE de `ALTER TABLE "UserNotification"` ne
 *      doit attendre aucune construction d'index ni aucune lecture séquentielle ;
 *   2. les index des grosses tables, `IF NOT EXISTS` pour pouvoir les
 *      construire avant en CONCURRENTLY ;
 *   3. la reprise de UserNotification, seule.
 */
const MIGRATIONS = resolve(process.cwd(), 'prisma/migrations');
const FILES = {
  fanout: '20261015120000_scholarship_follow_fanout',
  indexes: '20261015120100_scholarship_follow_indexes',
  backfill: '20261015120200_scholarship_follow_notification_backfill',
} as const;
const BIG_TABLES = ['SavedItem', 'UserNotification'];

function statementsOf(directory: string): string[] {
  return readFileSync(resolve(MIGRATIONS, directory, 'migration.sql'), 'utf8')
    .split('\n')
    .filter((line) => !line.trim().startsWith('--'))
    .join('\n')
    .split(';')
    .map((statement) => statement.replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

const statements = {
  fanout: statementsOf(FILES.fanout),
  indexes: statementsOf(FILES.indexes),
  backfill: statementsOf(FILES.backfill),
};
const all = [...statements.fanout, ...statements.indexes, ...statements.backfill];

interface AddedColumn {
  table: string;
  column: string;
  sqlType: string;
  notNullDefault: string | null;
}

/** `ALTER TABLE "T" ADD COLUMN "c" TYPE [NOT NULL DEFAULT v], …` */
function addedColumns(statement: string): AddedColumn[] {
  const head = /^ALTER TABLE "(\w+)" (.*)$/.exec(statement);
  if (!head) return [];
  const [, table, clauses] = head;
  return clauses.split(/,\s*(?=ADD COLUMN)/).map((clause) => {
    const match =
      /^ADD COLUMN "(\w+)" (TIMESTAMP\(3\)|TEXT|INTEGER|BOOLEAN)(?: NOT NULL DEFAULT (\S+))?$/.exec(
        clause.trim(),
      );
    if (!match) {
      throw new Error(`Clause non additive ou inattendue : ${clause}`);
    }
    return {
      table,
      column: match[1],
      sqlType: match[2],
      notNullDefault: match[3] ?? null,
    };
  });
}

interface CreatedIndex {
  name: string;
  table: string;
  columns: string[];
  ifNotExists: boolean;
}

function createdIndex(statement: string): CreatedIndex | null {
  const match =
    /^CREATE INDEX (IF NOT EXISTS )?"(\w+)" ON "(\w+)"\(([^)]*)\)$/.exec(statement);
  if (!match) return null;
  return {
    ifNotExists: Boolean(match[1]),
    name: match[2],
    table: match[3],
    columns: match[4].split(',').map((column) => column.trim().replace(/"/g, '')),
  };
}

const schema = readFileSync(resolve(process.cwd(), 'prisma/schema.prisma'), 'utf8');

function modelBlock(model: string): string {
  const block = new RegExp(`model ${model} \\{([\\s\\S]*?)\\n\\}`).exec(schema)?.[1];
  if (!block) throw new Error(`Modèle ${model} introuvable`);
  return block;
}

const PRISMA_TYPE: Record<string, string> = {
  'TIMESTAMP(3)': 'DateTime',
  TEXT: 'String',
  INTEGER: 'Int',
  BOOLEAN: 'Boolean',
};

describe('migrations scholarship_follow — additives, verrous bornés', () => {
  it('sont les trois dernières, dans cet ordre, après le suivi des builds', () => {
    const directories = readdirSync(MIGRATIONS, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
      .sort();
    const tail = directories.slice(directories.indexOf('20261013121500_profile_last_app_build'));
    expect(tail).toEqual([
      '20261013121500_profile_last_app_build',
      FILES.fanout,
      FILES.indexes,
      FILES.backfill,
    ]);
  });

  it('ne contiennent que des instructions additives', () => {
    for (const statement of all) {
      expect(statement).toMatch(
        /^(SET LOCAL lock_timeout = '\d+s'|ALTER TABLE "\w+" ADD COLUMN .*|CREATE INDEX .*|UPDATE "\w+" .*)$/,
      );
      expect(statement).not.toMatch(
        /\b(DROP|RENAME|TRUNCATE|DELETE|ALTER COLUMN|SET NOT NULL|TYPE)\b/,
      );
    }
  });

  it('n’ajoutent que des colonnes nullables, ou NOT NULL avec un défaut constant', () => {
    const columns = all.flatMap(addedColumns);
    expect(columns).toHaveLength(22);
    for (const column of columns) {
      if (column.notNullDefault !== null) {
        expect(['false', '0']).toContain(column.notNullDefault);
      }
    }
  });

  it('fichier 1 : lock_timeout d’abord, aucun index de grosse table, aucune écriture dans UserNotification', () => {
    expect(statements.fanout[0]).toBe("SET LOCAL lock_timeout = '5s'");
    for (const statement of statements.fanout) {
      const index = createdIndex(statement);
      if (index) expect(BIG_TABLES).not.toContain(index.table);
      expect(statement).not.toMatch(/^UPDATE "UserNotification"/);
    }
    expect(
      statements.fanout.filter((statement) => statement.startsWith('UPDATE')),
    ).toEqual([
      expect.stringMatching(/^UPDATE "ScholarshipCycle" /),
      expect.stringMatching(/^UPDATE "ScholarshipCycle" /),
    ]);
  });

  it('fichier 1 : les reprises sont idempotentes (gardées par leur propre résultat)', () => {
    const [preExisting, skipped] = statements.fanout.filter((statement) =>
      statement.startsWith('UPDATE'),
    );
    expect(preExisting).toContain('"openingPreExisting" = true');
    expect(preExisting).toContain('AND "openingPreExisting" = false');
    expect(preExisting).toContain('COALESCE("openingNotifiedAt", "activatedAt")');
    expect(skipped).toContain("\"openingSkippedReason\" = 'pre_existing_open'");
    expect(skipped).toContain('AND "openingSkippedAt" IS NULL');
  });

  it('fichier 2 : uniquement les index des grosses tables, tous IF NOT EXISTS', () => {
    const indexes = statements.indexes.map(createdIndex);
    expect(indexes).not.toContain(null);
    for (const index of indexes) {
      expect(index?.ifNotExists).toBe(true);
      expect(BIG_TABLES).toContain(index?.table);
    }
    expect(indexes.map((index) => index?.name)).toEqual([
      'SavedItem_itemType_itemId_idx',
      'UserNotification_pushStatus_pushNotBefore_idx',
      'UserNotification_cycleId_kind_idx',
    ]);
    // Aucun index de grosse table ailleurs.
    for (const statement of [...statements.fanout, ...statements.backfill]) {
      const index = createdIndex(statement);
      if (index) expect(BIG_TABLES).not.toContain(index.table);
    }
  });

  it('fichier 3 : des UPDATE seulement, idempotents', () => {
    expect(statements.backfill).toHaveLength(2);
    for (const statement of statements.backfill) {
      expect(statement).toMatch(/^UPDATE /);
    }
    expect(statements.backfill[0]).toContain('AND "cycleId" IS NULL');
    expect(statements.backfill[1]).toContain('AND c."openingAudience" IS NULL');
  });

  it('restent alignées sur le schéma Prisma (types, optionnalité, défauts, index)', () => {
    for (const column of all.flatMap(addedColumns)) {
      const block = modelBlock(column.table);
      const type = PRISMA_TYPE[column.sqlType];
      const pattern =
        column.notNullDefault === null
          ? new RegExp(`^\\s*${column.column}\\s+${type}\\?\\s*$`, 'm')
          : new RegExp(
              `^\\s*${column.column}\\s+${type}\\s+@default\\(${column.notNullDefault}\\)\\s*$`,
              'm',
            );
      expect({ column: `${column.table}.${column.column}`, ok: pattern.test(block) }).toEqual({
        column: `${column.table}.${column.column}`,
        ok: true,
      });
    }
    for (const statement of all) {
      const index = createdIndex(statement);
      if (!index) continue;
      // Le nom que Prisma donnerait : la migration et le schéma ne divergent pas.
      expect(index.name).toBe(`${index.table}_${index.columns.join('_')}_idx`);
      expect(modelBlock(index.table)).toContain(`@@index([${index.columns.join(', ')}])`);
    }
  });
});
