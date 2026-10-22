import { randomUUID } from 'node:crypto';

import { PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import { ReferralCampaignService } from '../referrals/campaigns/referral-campaign.service';
import type { StorageService } from '../storage/storage.service';
import { ProfilesService } from './profiles.service';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

/**
 * Audit 57 — ce que la suppression du compte laissait derrière elle, et ce que
 * l'export ne rendait pas :
 * - F05 : livraisons des campagnes de l'équipe (`NotificationDelivery`, nom
 *   civil + identifiant du compte, sans cascade) ;
 * - F17 : prix NON versés et forfaits de la compétition (nom public, motif
 *   libre), et la réattribution d'un prix dont le lauréat a disparu ;
 * - F08 : journal d'audit des actions de compétition visant le compte ;
 * - F07 : données de parrainage promises par la politique (§8).
 */
describePostgres('ProfilesService — résidus de suppression et export (PostgreSQL)', () => {
  const prisma = new PrismaClient();
  const sfx = randomUUID().slice(0, 8);
  const prismaService = {
    isEnabled: true,
    execute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma),
    tryExecute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma).catch(() => null),
  } as unknown as PrismaService;
  const storage = { keyFromUrl: () => null, delete: jest.fn() } as unknown as StorageService;
  const profiles = new ProfilesService(prismaService, storage);
  const campaigns = new ReferralCampaignService(prismaService);
  const actor = { id: `admin-res-${sfx}`, role: 'admin' };

  const U = `res-u-${sfx}`; // le compte supprimé
  const V = `res-v-${sfx}`; // son parrain, autre lauréat
  const W = `res-w-${sfx}`; // son filleul
  const X = `res-x-${sfx}`; // suivant au classement
  const ids = {
    template: `res-tpl-${sfx}`,
    notif: `res-ncamp-${sfx}`,
    otherNotif: `res-ncamp2-${sfx}`,
    c1: `res-c1-${sfx}`, // prix NON versé de U
    c2: `res-c2-${sfx}`, // prix VERSÉ de U
    c3: `res-c3-${sfx}`, // forfait de U
    ambU: `res-amb-u-${sfx}`,
    ambV: `res-amb-v-${sfx}`,
    ambX: `res-amb-x-${sfx}`,
  };
  const part: Record<string, string> = {};

  async function student(id: string, fullName: string) {
    await prisma.userProfile.create({
      data: {
        id,
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName,
        email: `${id}@gmail.com`,
        supabaseUserId: `sup-${id}`,
        phone: '+227 90 00 00 00',
        countryOfResidence: 'Niger',
      },
    });
  }

  async function campaign(id: string) {
    await prisma.referralCampaign.create({
      data: {
        id,
        slug: id,
        nameFr: `Campagne ${id}`,
        nameEn: `Campaign ${id}`,
        startsAt: new Date('2026-10-31T23:00:00Z'),
        endsAt: new Date('2026-11-10T23:00:00Z'),
        status: 'frozen',
        prizes: [
          { rank: 1, amountFcfa: 100000 },
          { rank: 2, amountFcfa: 50000 },
        ],
        podiumValidatedAt: new Date('2026-11-17T10:00:00Z'),
      },
    });
  }

  async function participant(key: string, campaignId: string, ambassadorId: string, rank: number, publicName: string) {
    const p = await prisma.referralCampaignParticipant.create({
      data: { campaignId, ambassadorId, publicName, city: 'Niamey', minorStatus: 'adult', rank, qualifiedCount: 10 - rank },
    });
    part[key] = p.id;
    return p.id;
  }

  beforeAll(async () => {
    await student(U, 'Aïcha Konaté');
    await student(V, 'Moussa Diallo');
    await student(W, 'Awa Sossou');
    await student(X, 'Ibrahim Moussa');

    // F05 — une diffusion à U (push ouvert, e-mail) et à V.
    await prisma.notificationTemplate.create({
      data: {
        id: ids.template,
        name: 'Politique',
        titleFr: 'Notre politique évolue',
        titleEn: 'Our policy is changing',
        bodyFr: 'b',
        bodyEn: 'b',
        channels: ['push', 'email'],
      },
    });
    for (const id of [ids.notif, ids.otherNotif]) {
      await prisma.notificationCampaign.create({
        data: {
          id,
          templateId: id === ids.notif ? ids.template : null,
          name: id === ids.notif ? 'Notre politique évolue — 24/10' : 'Autre',
          audienceType: 'all_users',
          filters: {},
          channels: ['push', 'email'],
          status: 'completed',
          purpose: 'informational',
        },
      });
    }
    await prisma.notificationDelivery.createMany({
      data: [
        {
          campaignId: ids.notif,
          recipientId: U,
          recipientName: 'Aïcha Konaté',
          channel: 'push',
          status: 'delivered',
          deliveredAt: new Date('2026-10-24T10:00:00Z'),
          openedAt: new Date('2026-10-24T10:05:00Z'),
        },
        { campaignId: ids.notif, recipientId: U, recipientName: 'Aïcha Konaté', channel: 'email', status: 'failed' },
        { campaignId: ids.otherNotif, recipientId: U, recipientName: 'Aïcha Konaté', channel: 'push', status: 'failed' },
        {
          campaignId: ids.notif,
          recipientId: V,
          recipientName: 'Moussa Diallo',
          channel: 'push',
          status: 'delivered',
          deliveredAt: new Date('2026-10-24T10:00:00Z'),
        },
      ],
    });

    // F07 — U est filleul de V et parrain de W ; crédits gagnés et dépensés.
    await prisma.referral.create({ data: { referrerId: V, refereeProfileId: U, createdAt: new Date('2026-09-01T00:00:00Z') } });
    await prisma.referral.create({ data: { referrerId: U, refereeProfileId: W, createdAt: new Date('2026-09-05T00:00:00Z') } });
    await prisma.creditTransaction.createMany({
      data: [
        { profileId: U, amount: 1, reason: 'referralFirstCase', dedupeKey: `res-earn-${sfx}`, metadata: { refereeId: W } },
        { profileId: U, amount: -1, reason: 'reviewVoucherRedeemed', dedupeKey: `res-spend-${sfx}`, metadata: { voucherCode: 'VCH-RES-1' } },
      ],
    });

    // F17 / F08 — trois ambassadeurs, trois campagnes au podium validé.
    await prisma.ambassador.create({
      data: { id: ids.ambU, userProfileId: U, code: `KTOU-AK-${sfx}`, city: 'Niamey', payoutAccount: '+22790112233', approvedAt: new Date() },
    });
    await prisma.ambassador.create({ data: { id: ids.ambV, userProfileId: V, code: `KTOU-MD-${sfx}`, city: 'Niamey', approvedAt: new Date() } });
    await prisma.ambassador.create({ data: { id: ids.ambX, userProfileId: X, code: `KTOU-IM-${sfx}`, city: 'Niamey', approvedAt: new Date() } });
    for (const c of [ids.c1, ids.c2, ids.c3]) await campaign(c);
    // C1 : U 1er (prix NON versé), V 2e (prix VERSÉ), X 3e (sans prix).
    await participant('u1', ids.c1, ids.ambU, 1, 'Aïcha K.');
    await participant('v1', ids.c1, ids.ambV, 2, 'Moussa D.');
    await participant('x1', ids.c1, ids.ambX, 3, 'Ibrahim M.');
    await prisma.referralCampaignPrizeAward.createMany({
      data: [
        { campaignId: ids.c1, rank: 1, participantId: part.u1, publicNameSnapshot: 'Aïcha K. — Niamey', amountFcfa: 100000, note: 'Joindre Aïcha au +227 90 11 22 33' },
        {
          campaignId: ids.c1,
          rank: 2,
          participantId: part.v1,
          publicNameSnapshot: 'Moussa D. — Niamey',
          amountFcfa: 50000,
          payoutStatus: 'paid',
          payoutReference: 'WAVE-V',
          paidAmountFcfa: 50000,
          paidAt: new Date('2026-11-18T10:00:00Z'),
        },
      ],
    });
    // C2 : U 1er, prix VERSÉ — la trace comptable reste.
    await participant('u2', ids.c2, ids.ambU, 1, 'Aïcha K.');
    await prisma.referralCampaignPrizeAward.create({
      data: {
        campaignId: ids.c2,
        rank: 1,
        participantId: part.u2,
        publicNameSnapshot: 'Aïcha K. — Niamey',
        amountFcfa: 100000,
        payoutStatus: 'paid',
        payoutReference: 'WAVE-U',
        paidAmountFcfa: 100000,
        paidAt: new Date('2026-11-18T10:00:00Z'),
      },
    });
    // C3 : U déclarée forfait (motif libre), prix passé à V.
    await participant('u3', ids.c3, ids.ambU, 1, 'Aïcha K.');
    await participant('v3', ids.c3, ids.ambV, 2, 'Moussa D.');
    const forfeit = await prisma.referralCampaignPrizeForfeit.create({
      data: {
        campaignId: ids.c3,
        rank: 1,
        participantId: part.u3,
        publicNameSnapshot: 'Aïcha K. — Niamey',
        amountFcfa: 100000,
        reason: 'Injoignable depuis le 18/11, 3 appels à Aïcha',
        forfeitedByAdminId: actor.id,
        replacedByParticipantId: part.v3,
      },
    });
    // U filleule de V dans C1, exclue avec motif.
    const refRow = await prisma.referralCampaignReferral.create({
      data: {
        campaignId: ids.c1,
        participantId: part.v1,
        refereeProfileId: U,
        attachedAt: new Date('2026-11-02T00:00:00Z'),
        accountCreatedAt: new Date('2026-11-02T00:00:00Z'),
        status: 'excluded',
        adminDecision: 'excluded',
        adminDecisionReason: 'Aïcha a avoué un faux compte',
      },
    });
    const audit = (entityType: string, entityId: string, action: string, changes: object, reasonCode?: string) =>
      prisma.adminAuditEvent.create({
        data: {
          actorAdminId: actor.id,
          action,
          purposeCode: 'referral_campaign',
          entityType,
          entityId,
          requestId: randomUUID(),
          reasonCode: reasonCode ?? null,
          result: 'success',
          changes,
        },
      });
    await audit('Ambassador', ids.ambU, 'ambassador.created', { userProfileId: U, city: 'Niamey', code: `KTOU-AK-${sfx}` });
    await audit('ReferralCampaignParticipant', part.u1, 'referral_campaign.participant_updated', {
      parentalAuthNote: 'Formulaire signé par la mère de Aïcha',
      minorStatus: 'minor',
    }, 'Disqualifiée pour fraude');
    await audit('ReferralCampaignPrizeForfeit', forfeit.id, 'referral_campaign.prize_forfeited', { campaignId: ids.c3, rank: 1 }, 'Injoignable depuis le 18/11, 3 appels à Aïcha');
    await audit('ReferralCampaignReferral', refRow.id, 'referral_campaign.referral_excluded', { campaignId: ids.c1, to: 'excluded' }, 'Aïcha a avoué un faux compte');
    await audit('Ambassador', ids.ambV, 'ambassador.created', { userProfileId: V, city: 'Niamey' });
  });

  afterAll(async () => {
    const all = [U, V, W, X];
    await prisma.referralCampaign.deleteMany({ where: { id: { in: [ids.c1, ids.c2, ids.c3] } } });
    await prisma.notificationDelivery.deleteMany({ where: { campaignId: { in: [ids.notif, ids.otherNotif] } } });
    await prisma.notificationCampaign.deleteMany({ where: { id: { in: [ids.notif, ids.otherNotif] } } });
    await prisma.notificationTemplate.deleteMany({ where: { id: ids.template } });
    await prisma.adminAuditEvent.deleteMany({ where: { actorAdminId: actor.id } });
    await prisma.ambassador.deleteMany({ where: { userProfileId: { in: all } } });
    await prisma.creditTransaction.deleteMany({ where: { profileId: { in: all } } });
    await prisma.referral.deleteMany({ where: { OR: [{ referrerId: { in: all } }, { refereeProfileId: { in: all } }] } });
    await prisma.userProfile.deleteMany({ where: { id: { in: all } } });
    await prisma.$disconnect();
  });

  it('l’export rend les livraisons, le parrainage, les prix et les forfaits — sans données d’autrui', async () => {
    const out = (await profiles.exportMe(U)) as Record<string, any>;
    // F05 : livraisons, sans le nom ni les identifiants internes.
    expect(out.campaignNotifications).toHaveLength(3);
    expect(out.campaignNotifications).toContainEqual({
      campaign: { name: 'Notre politique évolue — 24/10', titleFr: 'Notre politique évolue', titleEn: 'Our policy is changing' },
      channel: 'push',
      status: 'delivered',
      sentAt: expect.any(String),
      deliveredAt: '2026-10-24T10:00:00.000Z',
      openedAt: '2026-10-24T10:05:00.000Z',
    });
    expect(JSON.stringify(out.campaignNotifications)).not.toMatch(/recipient|Konaté|res-ncamp/);
    // F07 : rattachements (dates seules), crédits, espace ambassadeur.
    expect(out.referral.asReferee).toEqual({ attachedAt: '2026-09-01T00:00:00.000Z' });
    expect(out.referral.asReferrer).toEqual({ count: 1, attachedAt: ['2026-09-05T00:00:00.000Z'] });
    expect(out.referral.creditTransactions).toEqual([
      { amount: 1, reason: 'referralFirstCase', createdAt: expect.any(String) },
      { amount: -1, reason: 'reviewVoucherRedeemed', voucherCode: 'VCH-RES-1', createdAt: expect.any(String) },
    ]);
    expect(out.referral.ambassador).toMatchObject({ code: `KTOU-AK-${sfx}`, payoutAccount: '•••• 2233' });
    // F17 : prix (versé et non versé) et forfait.
    expect(
      out.referralCampaigns.prizes.map((p: any) => [p.campaign.slug, p.rank, p.payoutStatus]).sort(),
    ).toEqual([
      [ids.c1, 1, 'pending'],
      [ids.c2, 1, 'paid'],
    ]);
    expect(out.referralCampaigns.prizeForfeits).toEqual([
      expect.objectContaining({ rank: 1, reason: 'Injoignable depuis le 18/11, 3 appels à Aïcha' }),
    ]);
    // Aucune donnée d'autrui : ni V, ni W, ni leur nom.
    const text = JSON.stringify({ referral: out.referral, campaigns: out.referralCampaigns, n: out.campaignNotifications });
    for (const other of [V, W, X, 'Moussa', 'Sossou', 'Ibrahim']) expect(text).not.toContain(other);
  });

  it('la suppression anonymise livraisons, prix non versés, forfaits et journal — garde le prix versé', async () => {
    const fetchSpy = jest.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(null, { status: 200 }));
    try {
      await profiles.deleteMe(U);
    } finally {
      fetchSpy.mockRestore();
    }

    // F05 : plus rien au nom ni à l'id de U ; les compteurs restent.
    expect(await prisma.notificationDelivery.count({ where: { recipientId: U } })).toBe(0);
    const kept = await prisma.notificationDelivery.findMany({
      where: { campaignId: { in: [ids.notif, ids.otherNotif] } },
      orderBy: { recipientName: 'asc' },
    });
    expect(kept).toHaveLength(4);
    expect(JSON.stringify(kept)).not.toContain('Aïcha');
    expect(kept.filter((d) => d.recipientId === 'compte-supprime').map((d) => d.recipientName)).toEqual([
      'Compte supprimé',
      'Compte supprimé',
      'Compte supprimé',
    ]);
    expect(kept.find((d) => d.recipientId === V)?.recipientName).toBe('Moussa Diallo');
    const stats = await prisma.notificationDelivery.count({
      where: { campaignId: ids.notif, channel: 'push', openedAt: { not: null } },
    });
    expect(stats).toBe(1);

    // F17 : prix non versé orphelin et anonymisé ; prix versé intact.
    const c1 = await prisma.referralCampaignPrizeAward.findUniqueOrThrow({
      where: { campaignId_rank: { campaignId: ids.c1, rank: 1 } },
    });
    expect(c1).toMatchObject({ participantId: null, publicNameSnapshot: 'Compte supprimé', note: null, payoutStatus: 'pending' });
    const c2 = await prisma.referralCampaignPrizeAward.findUniqueOrThrow({
      where: { campaignId_rank: { campaignId: ids.c2, rank: 1 } },
    });
    expect(c2).toMatchObject({
      participantId: null,
      publicNameSnapshot: 'Aïcha K. — Niamey',
      payoutStatus: 'paid',
      payoutReference: 'WAVE-U',
      amountFcfa: 100000,
    });
    const forfeits = await prisma.referralCampaignPrizeForfeit.findMany({ where: { campaignId: ids.c3 } });
    expect(forfeits).toEqual([
      expect.objectContaining({
        participantId: null,
        publicNameSnapshot: 'Compte supprimé',
        reason: 'Motif effacé (compte supprimé)',
        amountFcfa: 100000,
      }),
    ]);

    // F08 : le journal garde l'action, plus le lien vers le compte ni les motifs.
    const events = await prisma.adminAuditEvent.findMany({ where: { actorAdminId: actor.id } });
    const own = events.filter((e) => e.action !== 'ambassador.created' || e.entityId === ids.ambU);
    expect(own).toHaveLength(4);
    expect(JSON.stringify(own)).not.toMatch(/Aïcha|Niamey|mère|fraude|res-u-/);
    expect(own.every((e) => e.reasonCode === null)).toBe(true);
    expect(events.find((e) => e.entityId === ids.ambV)?.changes).toEqual({ userProfileId: V, city: 'Niamey' });
  });

  it('le prix orphelin se déclare forfait et passe au suivant, même après un versement', async () => {
    // Sans `participantId` : le lauréat affiché n'existe plus.
    const after = await campaigns.forfeitPrize(ids.c1, 1, { reason: 'Lauréat a supprimé son compte' }, actor, 'res-1');
    expect(after.items.map((p) => [p.rank, p.participantId, p.payoutStatus])).toEqual([
      [1, part.x1, 'pending'],
      [2, part.v1, 'paid'],
    ]);
    expect(after.forfeits).toEqual([
      expect.objectContaining({ rank: 1, participantId: null, publicNameSnapshot: 'Compte supprimé', replacedByParticipantId: part.x1 }),
    ]);
    // Rejeu (même requête, ou `participantId: null`) : rien de plus n'est écrit,
    // et le nouveau lauréat n'est pas déclaré forfait sans être nommé.
    const replay = await campaigns.forfeitPrize(
      ids.c1,
      1,
      { participantId: null, reason: 'Lauréat a supprimé son compte' },
      actor,
      'res-2',
    );
    expect(replay.forfeits).toHaveLength(1);
    expect(replay.items[0]).toMatchObject({ rank: 1, participantId: part.x1 });
    // Un prix orphelin DÉJÀ VERSÉ ne bouge jamais.
    await expect(
      campaigns.forfeitPrize(ids.c2, 1, { reason: 'Compte supprimé' }, actor, 'res-3'),
    ).rejects.toThrow('déjà versé');
    expect(
      await prisma.adminAuditEvent.count({
        where: { actorAdminId: actor.id, action: 'referral_campaign.prize_forfeited', entityType: 'ReferralCampaignPrizeForfeit' },
      }),
    ).toBe(2);
  });
});
