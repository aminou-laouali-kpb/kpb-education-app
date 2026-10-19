import { NotFoundException } from '@nestjs/common';

import type { PrismaService } from '../../prisma/prisma.service';
import { ReferralCampaignService } from './referral-campaign.service';

/**
 * Le classement PUBLIC ne doit rien laisser fuir : ni e-mail, ni identifiant
 * interne, ni donnée de filleul, ni participant non classable (mineur sans
 * autorisation parentale vérifiée). La liste des champs est fermée.
 */
describe('ReferralCampaignService — classement public', () => {
  const campaign = {
    id: 'camp_internal_id',
    slug: 'ambassadeurs-novembre-2026',
    nameFr: 'Compétition ambassadeurs',
    nameEn: 'Ambassador challenge',
    timeZone: 'Africa/Lagos',
    startsAt: new Date('2026-10-31T23:00:00Z'),
    endsAt: new Date('2026-11-10T23:00:00Z'),
    status: 'live',
    prizes: [
      { rank: 1, amountFcfa: 100000 },
      { rank: 2, amountFcfa: 50000 },
      { rank: 3, amountFcfa: 30000 },
    ],
    rulesText: 'secret interne',
    rulesUrl: 'https://kpbeducation.cloud/reglement.html',
    eligibleCities: [],
    eligibleCountries: [],
    qualificationRule: {},
    lastComputedAt: new Date('2026-11-05T11:55:00Z'),
    podiumValidatedByAdminId: 'admin_secret',
    createdByAdminId: 'admin_secret',
  };
  const participant = (over: Record<string, unknown>) => ({
    id: 'part_internal',
    campaignId: 'camp_internal_id',
    ambassadorId: 'amb_internal',
    publicName: 'Aïcha K.',
    city: 'Niamey',
    country: 'Niger',
    status: 'active',
    statusReason: null,
    minorStatus: 'adult',
    parentalAuthStatus: 'not_required',
    parentalAuthNote: 'note privée',
    parentalAuthVerifiedByAdminId: null,
    qualifiedCount: 0,
    flaggedCount: 4,
    pendingCount: 2,
    excludedCount: 1,
    reachedCountAt: null,
    rank: null,
    enrolledByAdminId: 'admin_secret',
    ambassador: { approvedAt: new Date('2026-10-20') },
    ...over,
  });

  function service(status = 'live', rows: unknown[] = [], awards: unknown[] = []) {
    const client = {
      referralCampaign: {
        findUnique: async ({ where }: { where: { slug: string } }) =>
          where.slug === campaign.slug ? { ...campaign, status } : null,
      },
      referralCampaignParticipant: { findMany: async () => rows },
      referralCampaignPrizeAward: { findMany: async () => awards },
    };
    const prisma = {
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return new ReferralCampaignService(prisma);
  }

  const rows = [
    participant({ id: 'p1', publicName: 'Aïcha K.', city: 'Niamey', qualifiedCount: 12, rank: 1 }),
    participant({ id: 'p2', publicName: 'Moussa D.', city: 'Maradi', qualifiedCount: 9, rank: 2 }),
    // Mineur sans autorisation : JAMAIS public, même avec plus de filleuls.
    participant({
      id: 'p3',
      publicName: 'Junior M.',
      city: 'Niamey',
      qualifiedCount: 30,
      rank: null,
      minorStatus: 'minor',
      parentalAuthStatus: 'pending',
    }),
    // Mineur AUTORISÉ : public.
    participant({
      id: 'p4',
      publicName: 'Awa S.',
      city: 'Cotonou',
      qualifiedCount: 3,
      rank: 3,
      minorStatus: 'minor',
      parentalAuthStatus: 'verified',
    }),
    participant({ id: 'p5', publicName: 'Zéro Z.', city: 'Douala', qualifiedCount: 0, rank: null }),
  ];

  it('ne rend que nom public, ville, nombre et rang', async () => {
    const out = await service('live', rows).publicLeaderboard(
      campaign.slug,
      undefined,
      new Date('2026-11-05T12:00:00Z'),
    );
    for (const entry of out.entries) {
      expect(Object.keys(entry).sort()).toEqual(['city', 'name', 'qualified', 'rank']);
    }
    expect(out.entries.map((e) => [e.rank, e.name, e.city, e.qualified])).toEqual([
      [1, 'Aïcha K.', 'Niamey', 12],
      [2, 'Moussa D.', 'Maradi', 9],
      [3, 'Awa S.', 'Cotonou', 3],
      [null, 'Zéro Z.', 'Douala', 0],
    ]);
    const text = JSON.stringify(out);
    for (const leak of [
      'camp_internal_id',
      'part_internal',
      'amb_internal',
      'admin_secret',
      'note privée',
      'secret interne',
      'Junior',
      '@',
      'flaggedCount',
      'pendingCount',
    ]) {
      expect(text).not.toContain(leak);
    }
    expect(Object.keys(out.campaign).sort()).toEqual(
      [
        'endDate',
        'endsAt',
        'nameEn',
        'nameFr',
        'phase',
        'prizes',
        'provisional',
        'rulesUrl',
        'slug',
        'startDate',
        'startsAt',
        'status',
        'timeZone',
        'updatedAt',
      ].sort(),
    );
    expect(out.campaign).toMatchObject({
      phase: 'running',
      provisional: true,
      startDate: '2026-11-01',
      endDate: '2026-11-10',
    });
    expect(out.cities).toEqual(['Cotonou', 'Douala', 'Maradi', 'Niamey']);
  });

  it('filtre par ville sans tenir compte des accents ni de la casse', async () => {
    const out = await service('live', rows).publicLeaderboard(campaign.slug, 'niamey');
    expect(out.entries.map((e) => e.name)).toEqual(['Aïcha K.']);
  });

  it('cache 30 s puis relit', async () => {
    let reads = 0;
    const client = {
      referralCampaign: { findUnique: async () => ({ ...campaign }) },
      referralCampaignParticipant: {
        findMany: async () => {
          reads += 1;
          return rows;
        },
      },
    };
    const svc = new ReferralCampaignService({
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService);
    const t0 = new Date('2026-11-05T12:00:00Z');
    await svc.publicLeaderboard(campaign.slug, undefined, t0);
    await svc.publicLeaderboard(campaign.slug, undefined, new Date(t0.getTime() + 20_000));
    expect(reads).toBe(1);
    await svc.publicLeaderboard(campaign.slug, undefined, new Date(t0.getTime() + 31_000));
    expect(reads).toBe(2);
  });

  it('un brouillon ou un slug inconnu : 404', async () => {
    await expect(service('draft', rows).publicLeaderboard(campaign.slug, undefined)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(service('live', rows).publicLeaderboard('nope', undefined)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('close : plus provisoire', async () => {
    const out = await service('closed', rows).publicLeaderboard(campaign.slug, undefined);
    expect(out.campaign.provisional).toBe(false);
  });

  // Correctifs 57 : un prix déclaré forfait passe au suivant ; les résultats
  // définitifs montrent les lauréats EFFECTIFS, le classement l'ordre réel.
  const awards = [
    {
      id: 'award_internal',
      rank: 1,
      amountFcfa: 100000,
      participantId: 'p1',
      publicNameSnapshot: 'Aïcha K. — Niamey',
      payoutReference: 'WAVE-SECRET',
      participant: { publicName: 'Aïcha K.', city: 'Niamey' },
    },
    {
      id: 'award_internal_2',
      rank: 2,
      amountFcfa: 50000,
      participantId: 'p4',
      publicNameSnapshot: 'Awa S. — Cotonou',
      payoutReference: null,
      participant: { publicName: 'Awa S.', city: 'Cotonou' },
    },
  ];

  it('close : les lauréats effectifs (rang du prix, nom public, ville, montant — rien d’autre)', async () => {
    const out = await service('closed', rows, awards).publicLeaderboard(campaign.slug, undefined);
    expect(out.winners).toEqual([
      { prizeRank: 1, amountFcfa: 100000, name: 'Aïcha K.', city: 'Niamey' },
      { prizeRank: 2, amountFcfa: 50000, name: 'Awa S.', city: 'Cotonou' },
    ]);
    // L'ordre réel du classement ne bouge pas (Moussa D. reste 2e).
    expect(out.entries.slice(0, 3).map((e) => [e.rank, e.name])).toEqual([
      [1, 'Aïcha K.'],
      [2, 'Moussa D.'],
      [3, 'Awa S.'],
    ]);
    const text = JSON.stringify(out.winners);
    for (const leak of ['award_internal', 'WAVE-SECRET', 'p1', 'p4']) {
      expect(text).not.toContain(leak);
    }
  });

  it('avant la clôture : aucun lauréat public (podium provisoire)', async () => {
    const out = await service('frozen', rows, awards).publicLeaderboard(campaign.slug, undefined);
    expect(out.winners).toEqual([]);
  });
});
