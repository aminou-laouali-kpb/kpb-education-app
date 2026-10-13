import { randomUUID } from 'node:crypto';

import { AccountType, PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import { AdminAppBuildsService } from './admin-app-builds.service';
import { buildSeenUpdate } from './app-build-tracker.service';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

/**
 * L'écriture du suivi est du SQL brut : seule une base réelle dit si les
 * paramètres (texte, entier, NULL, date) passent, si `updatedAt` reste
 * intact, et si `groupBy` rend bien le groupe NULL des builds inconnues.
 *
 * Des builds et une version fictives (9 999 00x, `9.9.9-it`) : aucune autre
 * ligne de la base ne peut les porter, donc les assertions ne dépendent pas
 * des autres profils présents.
 */
describePostgres('Suivi des builds — PostgreSQL', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID();
  const ids = {
    fresh: `app-build-fresh-${suffix}`,
    old: `app-build-old-${suffix}`,
    stale: `app-build-stale-${suffix}`,
    never: `app-build-never-${suffix}`,
  };
  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as PrismaService;

  const NOW = new Date();
  const DAY = 24 * 60 * 60 * 1000;

  beforeAll(async () => {
    for (const [key, id] of Object.entries(ids)) {
      await prisma.userProfile.create({
        data: {
          id,
          accountType: AccountType.student,
          preferredLanguage: 'fr',
          fullName: `App Build ${key}`,
          email: `${id}@example.test`,
          phone: '',
          countryOfResidence: 'Niger',
        },
      });
    }
  });

  afterAll(async () => {
    await prisma.userProfile.deleteMany({
      where: { id: { in: Object.values(ids) } },
    });
    await prisma.$disconnect();
  });

  it('écrit version, build et date sans toucher à `updatedAt`', async () => {
    const before = await prisma.userProfile.findUniqueOrThrow({
      where: { id: ids.fresh },
      select: { updatedAt: true },
    });
    const seenAt = new Date(NOW.getTime() - 1000);

    const affected = await prisma.$executeRaw(
      buildSeenUpdate(ids.fresh, { version: '9.9.9-it', build: 9_999_001 }, seenAt),
    );

    expect(affected).toBe(1);
    await expect(
      prisma.userProfile.findUniqueOrThrow({
        where: { id: ids.fresh },
        select: {
          lastAppVersion: true,
          lastAppBuild: true,
          lastAppSeenAt: true,
          updatedAt: true,
        },
      }),
    ).resolves.toEqual({
      lastAppVersion: '9.9.9-it',
      lastAppBuild: 9_999_001,
      lastAppSeenAt: seenAt,
      updatedAt: before.updatedAt,
    });
  });

  it('une requête sans en-tête rafraîchit la date et garde les valeurs connues', async () => {
    const later = new Date(NOW.getTime() - 500);
    await prisma.$executeRaw(
      buildSeenUpdate(ids.fresh, { version: null, build: null }, later),
    );

    await expect(
      prisma.userProfile.findUniqueOrThrow({
        where: { id: ids.fresh },
        select: { lastAppVersion: true, lastAppBuild: true, lastAppSeenAt: true },
      }),
    ).resolves.toEqual({
      lastAppVersion: '9.9.9-it',
      lastAppBuild: 9_999_001,
      lastAppSeenAt: later,
    });
  });

  it('un compte supprimé entre-temps : aucune ligne touchée, pas d’erreur', async () => {
    await expect(
      prisma.$executeRaw(
        buildSeenUpdate(`absent-${suffix}`, { version: '2.3.0', build: 56 }, NOW),
      ),
    ).resolves.toBe(0);
  });

  it('agrège par build sur 30 jours, groupe inconnu compris', async () => {
    // Une build 53 vue aujourd'hui (aucun en-tête), une 9 999 002 vue il y a
    // 40 jours (hors fenêtre), un compte jamais vu.
    await prisma.$executeRaw(
      buildSeenUpdate(ids.old, { version: null, build: null }, NOW),
    );
    await prisma.$executeRaw(
      buildSeenUpdate(
        ids.stale,
        { version: '9.9.8-it', build: 9_999_002 },
        new Date(NOW.getTime() - 40 * DAY),
      ),
    );

    const adoption = await new AdminAppBuildsService(prismaService).getAdoption(
      NOW,
    );

    expect(adoption.byBuild).toContainEqual(
      expect.objectContaining({ build: 9_999_001, count: 1 }),
    );
    expect(adoption.byVersion).toContainEqual(
      expect.objectContaining({ version: '9.9.9-it', count: 1 }),
    );
    expect(adoption.byBuild.map((row) => row.build)).not.toContain(9_999_002);
    expect(adoption.unknownBuild.count).toBeGreaterThanOrEqual(1);
    expect(adoption.neverSeen.count).toBeGreaterThanOrEqual(1);
    expect(adoption.activeProfiles).toBe(
      adoption.byBuild.reduce((sum, row) => sum + row.count, 0) +
        adoption.unknownBuild.count,
    );
  });
});
