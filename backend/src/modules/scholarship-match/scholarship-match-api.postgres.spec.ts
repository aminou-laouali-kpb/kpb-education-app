import { randomUUID } from 'node:crypto';

import { AccountType, PrismaClient, type Prisma } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import { ProfilesService } from '../profiles/profiles.service';
import { ScholarshipAlertsService } from '../scholarships-index/scholarship-alerts.service';
import type { StorageService } from '../storage/storage.service';
import { CandidateSnapshotService } from './candidate-snapshot';
import { RUNS_KEPT, ScholarshipMatchService } from './scholarship-match.service';

/**
 * L'API élève de « Mes 10 bourses » contre un vrai PostgreSQL (chantier D2).
 *
 * Ce que seule une base réelle prouve :
 * - les candidates sont les fiches PUBLIQUES (une fiche en attente, inactive,
 *   jamais vérifiée ou à la date limite passée n'est jamais analysée) ;
 * - le run est écrit et élagué aux 5 derniers dans la même transaction ;
 * - réponses + run sont ATOMIQUES : un run qui échoue annule les réponses ;
 * - l'export RGPD contient les runs et les cloches, la suppression du compte
 *   les emporte (cascade) ;
 * - « Suivre les N compatibles » ignore les fiches non publiées.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

describePostgres('« Mes 10 bourses » — API élève (intégration PostgreSQL)', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID().slice(0, 8);
  const userId = `match-api-user-${suffix}`;
  const ids = {
    open: `match-api-open-${suffix}`,
    master: `match-api-master-${suffix}`,
    pending: `match-api-pending-${suffix}`,
    inactive: `match-api-inactive-${suffix}`,
    unverified: `match-api-unverified-${suffix}`,
    expired: `match-api-expired-${suffix}`,
  };
  const allIds = Object.values(ids);
  const DAY = 24 * 60 * 60 * 1000;
  const start = new Date();

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) => operation(prisma),
    tryExecute: async <T>(operation: (client: PrismaClient) => Promise<T>) => operation(prisma),
  } as unknown as PrismaService;

  let clock = start;
  const now = () => clock;
  const snapshots = new CandidateSnapshotService(prismaService, now);
  const service = new ScholarshipMatchService(prismaService, snapshots, now);

  function scholarship(id: string, overrides: Partial<Prisma.ScholarshipUncheckedCreateInput>) {
    return {
      id,
      nameFr: `Bourse ${id}`,
      nameEn: `Scholarship ${id}`,
      countryId: 'fra',
      countryNameFr: 'France',
      countryNameEn: 'France',
      levelEligibleFr: 'Licence',
      levelEligibleEn: 'Bachelor',
      typeOfFundingFr: 'Complète',
      typeOfFundingEn: 'Full',
      fundingType: 'fully_funded' as const,
      deadlineLabelFr: 'Janvier',
      deadlineLabelEn: 'January',
      keyRequirementsFr: [],
      keyRequirementsEn: [],
      relatedFieldIds: [],
      isActive: true,
      moderationStatus: 'approved' as const,
      lastVerifiedAt: new Date(start.getTime() - DAY),
      deadlineAt: new Date(start.getTime() + 90 * DAY),
      eligibleLevels: ['bachelor' as const],
      fieldsScope: 'all' as const,
      eligibilityCriteria: [],
      eligibilityStructuredAt: new Date(start.getTime() - 10 * DAY),
      eligibilityStructuredBy: 'spec',
      ...overrides,
    };
  }

  beforeAll(async () => {
    await prisma.scholarship.deleteMany({ where: { id: { in: allIds } } });
    await prisma.scholarship.createMany({
      data: [
        scholarship(ids.open, {}),
        scholarship(ids.master, { eligibleLevels: ['master'], levelEligibleFr: 'Master' }),
        scholarship(ids.pending, { moderationStatus: 'pending' }),
        scholarship(ids.inactive, { isActive: false }),
        scholarship(ids.unverified, { lastVerifiedAt: null }),
        scholarship(ids.expired, { deadlineAt: new Date(start.getTime() - DAY) }),
      ],
    });
    await prisma.userProfile.create({
      data: {
        id: userId,
        accountType: AccountType.student,
        preferredLanguage: 'fr',
        fullName: 'Élève Mes 10 bourses',
        email: `${userId}@example.org`,
        phone: '+22790000000',
        countryOfResidence: 'Niger',
        birthDate: new Date('2005-03-01T00:00:00.000Z'),
        nationalityCode: 'ner',
        highestDiploma: 'bac',
        scholarshipTargetLevel: 'bachelor',
        fieldIds: ['d01'],
        gradeBandOn20: '12_14',
        englishLevel: 'b1',
        languageLevel: 'Intermediate',
        gradeRange: '12 - 14/20',
      },
    });
  });

  afterAll(async () => {
    try {
      await prisma.scholarshipMatchRun.deleteMany({ where: { userId } });
      await prisma.scholarshipAlertSubscription.deleteMany({ where: { userId } });
      await prisma.savedItem.deleteMany({ where: { userId } });
      await prisma.userProfile.deleteMany({ where: { id: userId } });
      await prisma.scholarship.deleteMany({ where: { id: { in: allIds } } });
    } finally {
      await prisma.$disconnect();
    }
  });

  it('n’analyse que les fiches publiques', async () => {
    const snapshot = await snapshots.get();
    expect(snapshot?.byId.has(ids.open)).toBe(true);
    expect(snapshot?.byId.has(ids.master)).toBe(true);
    for (const hidden of [ids.pending, ids.inactive, ids.unverified, ids.expired]) {
      expect(snapshot?.byId.has(hidden)).toBe(false);
    }
  });

  it('profil non confirmé : profile_incomplete, rien n’est écrit', async () => {
    const response = await service.createRun(userId, { answers: { englishLevel: 'b2' } });

    expect(response.status).toBe('profile_incomplete');
    expect(await prisma.scholarshipMatchRun.count({ where: { userId } })).toBe(0);
    const profile = await prisma.userProfile.findUniqueOrThrow({ where: { id: userId } });
    expect(profile.englishLevel).toBe('b1');
    expect(profile.scholarshipProfileConfirmedAt).toBeNull();
  });

  it('atomicité : un run qui échoue annule les réponses et la confirmation', async () => {
    class FailingRunService extends ScholarshipMatchService {
      protected override async persistRun(
        tx: Prisma.TransactionClient,
        data: Prisma.ScholarshipMatchRunUncheckedCreateInput,
      ) {
        const row = await super.persistRun(tx, data);
        if (row) throw new Error('run write failed');
        return row;
      }
    }
    const failing = new FailingRunService(prismaService, snapshots, now);

    await expect(
      failing.createRun(userId, { confirm: true, answers: { englishLevel: 'c1_c2', gradeBandOn20: '10_12' } }),
    ).rejects.toThrow('run write failed');

    const profile = await prisma.userProfile.findUniqueOrThrow({ where: { id: userId } });
    expect(profile).toMatchObject({
      englishLevel: 'b1',
      gradeBandOn20: '12_14',
      languageLevel: 'Intermediate',
      gradeRange: '12 - 14/20',
      scholarshipProfileConfirmedAt: null,
    });
    expect(await prisma.scholarshipMatchRun.count({ where: { userId } })).toBe(0);
  });

  it('écrit les réponses, la confirmation et le run ; élague aux 5 derniers', async () => {
    const created: string[] = [];
    for (let i = 0; i < RUNS_KEPT + 2; i += 1) {
      clock = new Date(start.getTime() + (i + 1) * 1_000);
      const response = await service.createRun(userId, {
        confirm: true,
        trigger: i === 0 ? 'wizard' : 'rerun',
        answers: i === 0 ? { englishLevel: 'c1_c2', gradeBandOn20: '10_12', unknownKey: 1 } : undefined,
      });
      if (response.status !== 'ok') throw new Error(`run ${i}: ${response.status}`);
      expect(response.run.items.map((item) => item.scholarshipId)).toContain(ids.open);
      expect(response.run.items.map((item) => item.scholarshipId)).not.toContain(ids.master);
      created.push(response.run.id);
    }

    const kept = await prisma.scholarshipMatchRun.findMany({
      where: { userId },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
    expect(kept.map((run) => run.id)).toEqual(created.slice(-RUNS_KEPT).reverse());
    expect(kept[0]).toMatchObject({ algorithmVersion: 'sm-1', trigger: 'rerun' });

    const profile = await prisma.userProfile.findUniqueOrThrow({ where: { id: userId } });
    expect(profile).toMatchObject({
      englishLevel: 'c1_c2',
      languageLevel: 'Advanced',
      gradeBandOn20: '10_12',
      gradeRange: '10 - 12/20',
    });
    expect(profile.scholarshipProfileConfirmedAt).toBeInstanceOf(Date);

    const state = await service.state(userId, 'fr');
    expect(state.latestRun?.id).toBe(created[created.length - 1]);
  });

  it('« Suivre les N compatibles » ignore les fiches non publiées', async () => {
    const alerts = new ScholarshipAlertsService(prismaService);

    const result = await alerts.subscribeMany(userId, [ids.open, ids.pending, ids.inactive, 'missing']);

    expect(result).toEqual({
      subscribedIds: [ids.open],
      skippedIds: [ids.pending, ids.inactive, 'missing'],
    });
    const rows = await prisma.scholarshipAlertSubscription.findMany({ where: { userId } });
    expect(rows.map((row) => row.scholarshipId)).toEqual([ids.open]);
  });

  it('export RGPD : runs et cloches inclus ; suppression du compte : tout part en cascade', async () => {
    await service.setAlerts(userId, true);
    const storage = {
      keyFromUrl: () => null,
      delete: async () => undefined,
    } as unknown as StorageService;
    const profiles = new ProfilesService(prismaService, storage);

    const exported = (await profiles.exportMe(userId)) as unknown as {
      profile: Record<string, unknown>;
      scholarshipMatchRuns: Array<{ id: string; userId: string }>;
      scholarshipAlertSubscriptions: Array<{ scholarshipId: string }>;
    };
    expect(exported.scholarshipMatchRuns).toHaveLength(RUNS_KEPT);
    expect(exported.scholarshipMatchRuns.every((run) => run.userId === userId)).toBe(true);
    expect(exported.scholarshipAlertSubscriptions.map((row) => row.scholarshipId)).toEqual([ids.open]);
    expect(exported.profile).toMatchObject({ nationalityCode: 'ner', englishLevel: 'c1_c2' });
    expect(exported.profile.scholarshipMatchAlertsOptInAt).toBeTruthy();

    await expect(profiles.deleteMe(userId)).resolves.toMatchObject({ deleted: true });

    expect(await prisma.userProfile.count({ where: { id: userId } })).toBe(0);
    expect(await prisma.scholarshipMatchRun.count({ where: { userId } })).toBe(0);
    expect(await prisma.scholarshipAlertSubscription.count({ where: { userId } })).toBe(0);
  });
});
