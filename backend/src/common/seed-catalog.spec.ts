import { seedCatalogueUnique } from '../../scripts/seed-catalogue-unique';
import { seedCountriesM5 } from '../../scripts/seed-countries-m5';
import { catalogueUniqueInstitutions } from './data/catalogue-unique.seed';
import { PRODUCTION_SEED_OVERRIDE_ENV } from './seed-safety';

/**
 * Constat d'audit n° 11 : `seed:catalog` (seed:countries-m5 puis
 * seed:catalogue-unique) faisait des upserts à mise à jour complète, sans
 * garde-fou production. Relancé, il vidait les domaines enrichis dans l'admin,
 * réactivait un pays retiré et remplaçait `programIds` par la liste du seed.
 */

type Row = Record<string, any>;

/** Prisma en mémoire, limité aux appels que font les deux seeds. */
function fakePrisma() {
  const tables: Record<string, Map<string, Row>> = {
    field: new Map(),
    country: new Map(),
    institution: new Map(),
    program: new Map(),
    countryEligibilityQuiz: new Map(),
  };
  const writes: string[] = [];
  const matches = (row: Row, where: Row = {}) =>
    Object.entries(where).every(([key, cond]) => {
      if (cond && typeof cond === 'object' && 'in' in cond) {
        return (cond.in as unknown[]).includes(row[key]);
      }
      return row[key] === cond;
    });
  const model = (name: string, key = 'id') => {
    const t = tables[name];
    return {
      count: async ({ where }: Row = {}) =>
        [...t.values()].filter((r) => matches(r, where)).length,
      findUnique: async ({ where }: Row) => t.get(where[key]) ?? null,
      findMany: async ({ where }: Row = {}) =>
        [...t.values()].filter((r) => matches(r, where)),
      create: async ({ data }: Row) => {
        writes.push(`${name}.create ${data[key]}`);
        t.set(data[key], { ...data });
        return data;
      },
      update: async ({ where, data }: Row) => {
        writes.push(`${name}.update ${where[key]} ${Object.keys(data).join(',')}`);
        const row = { ...t.get(where[key]), ...data };
        t.set(where[key], row);
        return row;
      },
      updateMany: async ({ where, data }: Row) => {
        let count = 0;
        for (const [id, row] of t) {
          if (!matches(row, where)) continue;
          writes.push(`${name}.updateMany ${id} ${Object.keys(data).join(',')}`);
          t.set(id, { ...row, ...data });
          count += 1;
        }
        return { count };
      },
      upsert: async ({ where, update, create }: Row) => {
        const existing = t.get(where[key]);
        if (existing) {
          if (Object.keys(update).length > 0) {
            writes.push(`${name}.upsert-update ${where[key]}`);
          }
          const row = { ...existing, ...update };
          t.set(where[key], row);
          return row;
        }
        writes.push(`${name}.upsert-create ${where[key]}`);
        t.set(where[key], { ...create });
        return create;
      },
    };
  };
  const client = {
    field: model('field'),
    country: model('country'),
    institution: model('institution'),
    program: model('program'),
    countryEligibilityQuiz: model('countryEligibilityQuiz', 'countryId'),
  };
  return { client: client as any, tables, writes };
}

const LOCAL_URL = 'postgresql://kpb:kpb@localhost:5432/kpb_ci?schema=public';

describe('seed:catalog — création seule, garde-fou production', () => {
  const savedEnv = { ...process.env };
  beforeEach(() => {
    process.env = { ...savedEnv, DATABASE_URL: LOCAL_URL };
    delete process.env.NODE_ENV;
    delete process.env[PRODUCTION_SEED_OVERRIDE_ENV];
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
  });
  afterEach(() => {
    process.env = savedEnv;
    jest.restoreAllMocks();
  });

  const institution = catalogueUniqueInstitutions[0];

  it('première installation : établissements créés avec leurs formations rattachées', async () => {
    const { client, tables } = fakePrisma();
    await expect(seedCatalogueUnique(client)).resolves.toBe(true);
    expect(tables.institution.get(institution.id)!.programIds).toEqual(
      institution.programIds,
    );
    expect(tables.country.get('senegal')!.isActive).toBe(true);
  });

  it('relancé, ne réécrit ni les domaines, ni le Sénégal retiré, ni programIds', async () => {
    const { client, tables, writes } = fakePrisma();
    await seedCatalogueUnique(client);

    // Éditions de l'équipe dans l'admin.
    tables.field.set('d03', {
      ...tables.field.get('d03'),
      descriptionFr: 'Description enrichie',
      relatedCountryIds: ['fra'],
    });
    tables.country.set('senegal', { ...tables.country.get('senegal'), isActive: false });
    const adminProgramIds = [...institution.programIds, 'prog_admin_ajout'];
    tables.institution.set(institution.id, {
      ...tables.institution.get(institution.id),
      programIds: adminProgramIds,
    });
    writes.length = 0;

    await expect(seedCatalogueUnique(client)).resolves.toBe(true);

    expect(writes).toEqual([]);
    expect(tables.field.get('d03')).toMatchObject({
      descriptionFr: 'Description enrichie',
      relatedCountryIds: ['fra'],
    });
    expect(tables.country.get('senegal')!.isActive).toBe(false);
    expect(tables.institution.get(institution.id)!.programIds).toEqual(adminProgramIds);
  });

  it('une formation du seed recréée est AJOUTÉE à programIds, sans rien retirer', async () => {
    const { client, tables } = fakePrisma();
    await seedCatalogueUnique(client);
    const [missing, ...rest] = institution.programIds;
    tables.program.delete(missing);
    tables.institution.set(institution.id, {
      ...tables.institution.get(institution.id),
      programIds: [...rest, 'prog_admin_ajout'],
    });

    await seedCatalogueUnique(client);

    expect(tables.institution.get(institution.id)!.programIds).toEqual([
      ...rest,
      'prog_admin_ajout',
      missing,
    ]);
  });

  it('refuse une base de production déjà semée, sans rien écrire', async () => {
    const { client, writes } = fakePrisma();
    await seedCatalogueUnique(client);
    await seedCountriesM5(client);
    writes.length = 0;

    process.env.NODE_ENV = 'production';
    await expect(seedCatalogueUnique(client)).resolves.toBe(false);
    await expect(seedCountriesM5(client)).resolves.toBe(false);
    expect(writes).toEqual([]);

    // Dérogation explicite : exécution autorisée, mais toujours sans réécriture.
    process.env[PRODUCTION_SEED_OVERRIDE_ENV] = '1';
    await expect(seedCatalogueUnique(client)).resolves.toBe(true);
    expect(writes).toEqual([]);
  });

  it('seed:countries-m5 ne réactive pas un pays retiré dans l’admin', async () => {
    const { client, tables, writes } = fakePrisma();
    await seedCountriesM5(client);
    tables.country.set('gbr', {
      ...tables.country.get('gbr'),
      isActive: false,
      taglineFr: 'Texte admin',
    });
    writes.length = 0;

    await expect(seedCountriesM5(client)).resolves.toBe(true);

    expect(tables.country.get('gbr')).toMatchObject({
      isActive: false,
      taglineFr: 'Texte admin',
    });
    // Seul le quiz (non éditable dans l'admin) est resynchronisé.
    expect(writes.filter((w) => w.startsWith('country.'))).toEqual([]);
  });
});
