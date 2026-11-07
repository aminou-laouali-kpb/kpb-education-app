import { randomUUID } from 'node:crypto';

import { AccountType, PrismaClient } from '@prisma/client';

import { ramenerAMinuit, releverHeures } from './birthdate-backfill';

/**
 * Rattrapage des dates de naissance (T4-06) sur un vrai Postgres.
 *
 *   KPB_RUN_POSTGRES_INTEGRATION=true DATABASE_URL=… npm run test:integration:birthdates
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres(
  'rattrapage des dates de naissance — intégration PostgreSQL',
  () => {
    const prisma = new PrismaClient();
    const s = randomUUID();
    const profils: [string, string | null, string | null][] = [
      // id, valeur en base, valeur attendue
      [
        `bd-niamey-${s}`,
        '1990-03-14T23:00:00.000Z',
        '1990-03-15T00:00:00.000Z',
      ],
      [
        `bd-nairobi-${s}`,
        '2005-12-31T21:00:00.000Z',
        '2006-01-01T00:00:00.000Z',
      ],
      [`bd-ok-${s}`, '2001-07-04T00:00:00.000Z', '2001-07-04T00:00:00.000Z'],
      [`bd-null-${s}`, null, null],
    ];

    beforeAll(async () => {
      for (const [id, birthDate] of profils) {
        await prisma.userProfile.create({
          data: {
            id,
            accountType: AccountType.student,
            preferredLanguage: 'fr',
            fullName: 'Profil de rattrapage',
            email: `${id}@example.test`,
            phone: '+2270000000',
            countryOfResidence: 'NE',
            birthDate: birthDate ? new Date(birthDate) : null,
          },
        });
      }
    });

    afterAll(async () => {
      await prisma.userProfile.deleteMany({
        where: { id: { in: profils.map(([id]) => id) } },
      });
      await prisma.$disconnect();
    });

    it('ramène chaque date au minuit UTC le plus proche, sans toucher aux autres, et se rejoue à 0', async () => {
      expect((await releverHeures(prisma)).length).toBeGreaterThan(0);
      expect(await ramenerAMinuit(prisma)).toBeGreaterThanOrEqual(2);

      for (const [id, , attendu] of profils) {
        const p = await prisma.userProfile.findUniqueOrThrow({ where: { id } });
        expect(p.birthDate?.toISOString() ?? null).toBe(attendu);
      }
      expect(await releverHeures(prisma)).toEqual([]);
      expect(await ramenerAMinuit(prisma)).toBe(0);
    });
  },
);
