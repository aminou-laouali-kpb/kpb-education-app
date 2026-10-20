import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { PrismaClient } from '@prisma/client';

import type { PrismaService } from '../../prisma/prisma.service';
import { ProfilesService } from '../../profiles/profiles.service';
import type { StorageService } from '../../storage/storage.service';
import { ReferralsService } from '../referrals.service';
import { AmbassadorAdminService } from './ambassador-admin.service';
import { ReferralCampaignService } from './referral-campaign.service';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

const MIGRATION = join(
  __dirname,
  '../../../../prisma/migrations/20261028120000_profile_completion_without_consent/migration.sql',
);

/** `YYYY-MM-DD` du jour `offsetDays` dans le fuseau de la campagne (UTC+1, sans heure d'été). */
function lagosDay(offsetDays: number): string {
  return new Date(Date.now() + 3_600_000 + offsetDays * 86_400_000).toISOString().slice(0, 10);
}

/**
 * Audit 57, F15 : un filleul doit devenir « qualifié » par le VRAI chemin de
 * production — profil créé comme à la première connexion (sans
 * `consentedAt`, que rien n'écrit), complété par `PATCH /profiles/me`
 * (`ProfilesService.updateMe`), puis le recalcul. Aucune colonne n'est
 * injectée à la main.
 */
describePostgres('Compétition — profil complété sans consentedAt (PostgreSQL)', () => {
  const prisma = new PrismaClient();
  const sfx = randomUUID().slice(0, 8);
  const prismaService = {
    isEnabled: true,
    execute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma),
    tryExecute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma).catch(() => null),
  } as unknown as PrismaService;
  const storage = { keyFromUrl: () => null, delete: jest.fn() } as unknown as StorageService;
  const referrals = new ReferralsService(prismaService);
  const ambassadors = new AmbassadorAdminService(prismaService, referrals);
  const campaigns = new ReferralCampaignService(prismaService);
  const profiles = new ProfilesService(prismaService, storage);
  const actor = { id: `admin-pc-${sfx}`, role: 'admin' };
  const ambId = `pc-amb-${sfx}`;
  const refereeId = `pc-ref-${sfx}`;
  const oldId = `pc-old-${sfx}`;
  const minorId = `pc-minor-${sfx}`;
  let campaignId = '';

  /** Comme `SupabaseAuthService.resolveProfile` à la première connexion. */
  async function firstLogin(id: string, over: { createdAt?: Date } = {}) {
    await prisma.userProfile.create({
      data: {
        id,
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName: `${id} Test`,
        email: `${id}@gmail.com`,
        supabaseUserId: `sup-${id}`,
        phone: '',
        countryOfResidence: '',
        ...(over.createdAt ? { createdAt: over.createdAt } : {}),
      },
    });
  }

  const onboarding = {
    phone: '+227 90 00 00 00',
    birthDate: '2004-03-01',
    fieldIds: ['d01'],
    targetCountryIds: ['fr'],
  };

  afterAll(async () => {
    const all = [ambId, refereeId, oldId, minorId];
    if (campaignId) await prisma.referralCampaign.deleteMany({ where: { id: campaignId } });
    await prisma.referralAttributionSignal.deleteMany({
      where: { OR: [{ refereeProfileId: { in: all } }, { referrerProfileId: { in: all } }] },
    });
    await prisma.ambassador.deleteMany({ where: { userProfileId: { in: all } } });
    await prisma.referral.deleteMany({ where: { refereeProfileId: { in: all } } });
    await prisma.adminAuditEvent.deleteMany({ where: { actorAdminId: actor.id } });
    await prisma.userProfile.deleteMany({ where: { id: { in: all } } });
    await prisma.$disconnect();
  });

  it('PATCH /profiles/me complète le profil, puis le recalcul qualifie le filleul', async () => {
    await firstLogin(ambId, { createdAt: new Date(Date.now() - 60 * 86_400_000) });
    await profiles.updateMe({ ...onboarding }, ambId);
    const amb = await ambassadors.activate({ email: `${ambId}@gmail.com`, city: 'Niamey' }, actor, 'pc1');

    const c = await campaigns.create(
      {
        slug: `pc-test-${sfx}`,
        nameFr: 'Test complétion',
        nameEn: 'Completion test',
        startDate: lagosDay(-1),
        endDate: lagosDay(1),
        timeZone: 'Africa/Lagos',
        prizes: [{ rank: 1, amountFcfa: 1 }],
        rulesUrl: 'https://kpbeducation.cloud/reglement-ambassadeurs-2026-11.html',
      },
      actor,
      'pc2',
    );
    campaignId = c.id;
    await campaigns.enroll(campaignId, { email: `${ambId}@gmail.com` }, actor, 'pc3');
    await campaigns.transition(campaignId, 'launch', actor, 'pc4');

    // Nouveau compte, code saisi AVANT de finir l'onboarding.
    await firstLogin(refereeId);
    await referrals.redeem(refereeId, amb.code, { ip: '41.10.10.10' });
    await campaigns.recompute(campaignId);
    let board = await campaigns.adminLeaderboard(campaignId);
    expect(board.items[0]).toMatchObject({ qualifiedCount: 0, pendingCount: 1, rank: null });

    // L'onboarding de l'app : exactement les champs qu'elle envoie — jamais
    // `consentedAt` (le DTO le refuserait).
    await profiles.updateMe({ ...onboarding }, refereeId);
    const after = await prisma.userProfile.findUniqueOrThrow({ where: { id: refereeId } });
    expect(after.consentedAt).toBeNull();
    expect(after.profileCompletedAt).toBeInstanceOf(Date);

    await campaigns.recompute(campaignId);
    board = await campaigns.adminLeaderboard(campaignId);
    expect(board.items[0]).toMatchObject({ qualifiedCount: 1, pendingCount: 0, rank: 1 });
    const rows = await campaigns.participantReferrals(campaignId, board.items[0].id);
    expect(rows.items).toHaveLength(1);
    expect(rows.items[0]).toMatchObject({ status: 'qualified' });
  });

  it('la migration 20261028120000 date les profils complets, sans consentedAt, une seule fois', async () => {
    // Profil déjà complet AVANT ce correctif (le rattrapage 3 de 20261022120000
    // l'avait sauté faute de `consentedAt`) ; mineur sans accord du tuteur : jamais.
    await prisma.userProfile.create({
      data: {
        id: oldId,
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName: 'Ancien Profil',
        email: `${oldId}@gmail.com`,
        supabaseUserId: `sup-${oldId}`,
        phone: '+227 91 00 00 00',
        countryOfResidence: 'Niger',
        birthDate: new Date('2003-01-01T00:00:00Z'),
        fieldIds: ['d01'],
        targetCountryIds: ['fr'],
        createdAt: new Date('2026-05-01T00:00:00Z'),
      },
    });
    await prisma.userProfile.create({
      data: {
        id: minorId,
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName: 'Jeune Profil',
        email: `${minorId}@gmail.com`,
        supabaseUserId: `sup-${minorId}`,
        phone: '+227 92 00 00 00',
        countryOfResidence: 'Niger',
        birthDate: new Date(Date.now() - 16.5 * 365.25 * 86_400_000),
        fieldIds: ['d01'],
        targetCountryIds: ['fr'],
      },
    });
    const before = await prisma.userProfile.findUniqueOrThrow({ where: { id: oldId } });
    expect(before.profileCompletedAt).toBeNull();

    // Le SQL de la migration, borné aux lignes de ce test (les autres suites
    // tournent en parallèle sur la même base).
    const sql = readFileSync(MIGRATION, 'utf8')
      .split('\n')
      .filter((line) => !line.startsWith('--'))
      .join('\n')
      .trim()
      .replace(/;\s*$/, ` AND "id" IN ('${oldId}', '${minorId}');`);
    expect(await prisma.$executeRawUnsafe(sql)).toBe(1);
    const stamped = await prisma.userProfile.findUniqueOrThrow({ where: { id: oldId } });
    expect(stamped.profileCompletedAt?.getTime()).toBe(before.updatedAt.getTime());
    expect(stamped.consentedAt).toBeNull();
    const minor = await prisma.userProfile.findUniqueOrThrow({ where: { id: minorId } });
    expect(minor.profileCompletedAt).toBeNull();
    // Idempotent : rejouer n'écrit rien.
    expect(await prisma.$executeRawUnsafe(sql)).toBe(0);
  });
});
