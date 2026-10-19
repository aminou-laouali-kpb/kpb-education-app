import { randomUUID } from 'node:crypto';

import { PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import type { StorageService } from '../storage/storage.service';
import { ProfilesService } from './profiles.service';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

/**
 * Correctifs 57 — « Effacer ma nationalité », contre un vrai Postgres : les
 * colonnes passent à NULL, les runs du test (calculés avec la nationalité)
 * disparaissent, ceux d'un autre compte restent. Idempotent.
 */
describePostgres('Effacer la nationalité — PostgreSQL', () => {
  jest.setTimeout(60_000);
  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 10);
  const me = `it-nat-me-${sfx}`;
  const other = `it-nat-other-${sfx}`;
  const prismaService = {
    isEnabled: true,
    execute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma),
  } as unknown as PrismaService;
  const profiles = new ProfilesService(prismaService, {} as StorageService);

  const run = (userId: string) => ({
    userId,
    algorithmVersion: 'sm-1',
    trigger: 'wizard',
    profileHash: 'h',
    catalogHash: 'c',
    inputsSummary: {},
    items: [],
    excludedSummary: {},
  });

  beforeAll(async () => {
    for (const id of [me, other]) {
      await prisma.userProfile.create({
        data: {
          id,
          accountType: 'student',
          preferredLanguage: 'fr',
          fullName: 'Test',
          email: `${id}@example.test`,
          phone: '',
          countryOfResidence: 'Niger',
          nationalityCode: 'ner',
          secondNationalityCode: 'fra',
          fieldIds: [],
          targetCountryIds: [],
        },
      });
      await prisma.scholarshipMatchRun.createMany({ data: [run(id), run(id)] });
    }
  });

  afterAll(async () => {
    try {
      await prisma.userProfile.deleteMany({ where: { id: { in: [me, other] } } });
    } finally {
      await prisma.$disconnect();
    }
  });

  it('efface la nationalité et les résultats calculés avec elle, pour ce compte seulement', async () => {
    expect(await profiles.eraseNationality(me)).toEqual({
      nationalityCode: null,
      secondNationalityCode: null,
      matchRunsDeleted: 2,
    });
    const mine = await prisma.userProfile.findUniqueOrThrow({ where: { id: me } });
    expect(mine.nationalityCode).toBeNull();
    expect(mine.secondNationalityCode).toBeNull();
    expect(await prisma.scholarshipMatchRun.count({ where: { userId: me } })).toBe(0);
    const theirs = await prisma.userProfile.findUniqueOrThrow({ where: { id: other } });
    expect(theirs.nationalityCode).toBe('ner');
    expect(await prisma.scholarshipMatchRun.count({ where: { userId: other } })).toBe(2);
    expect(await profiles.getMe(me)).toMatchObject({ nationalityCode: null, secondNationalityCode: null });
  });

  it('rejouer ne change rien (idempotent)', async () => {
    expect(await profiles.eraseNationality(me)).toEqual({
      nationalityCode: null,
      secondNationalityCode: null,
      matchRunsDeleted: 0,
    });
  });
});
