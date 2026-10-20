import { randomUUID } from 'node:crypto';

import { PrismaClient } from '@prisma/client';

import type { PrismaService } from '../../prisma/prisma.service';
import { ProfilesService } from '../../profiles/profiles.service';
import type { StorageService } from '../../storage/storage.service';
import { ReferralsService } from '../referrals.service';
import { AmbassadorAdminService } from './ambassador-admin.service';
import { ReferralCampaignService } from './referral-campaign.service';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

/**
 * Scénario complet de la compétition, sur PostgreSQL :
 * campagne du 1er au 10/11/2026 (UTC+1), trois ambassadeurs (dont un mineur),
 * filleuls dans et hors fenêtre, rafale depuis une même IP, appareil réutilisé,
 * e-mail jetable, exclusion et validation par l'équipe, gel automatique,
 * podium, versements (au parent pour le mineur), clôture — et l'idempotence
 * (rejouer le calcul n'écrit rien).
 */
describePostgres('Compétition ambassadeurs — PostgreSQL', () => {
  const prisma = new PrismaClient();
  const sfx = randomUUID().slice(0, 8);
  const prismaService = {
    isEnabled: true,
    execute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma),
    tryExecute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma).catch(() => null),
  } as unknown as PrismaService;
  const referrals = new ReferralsService(prismaService);
  const ambassadors = new AmbassadorAdminService(prismaService, referrals);
  const campaigns = new ReferralCampaignService(prismaService);
  const actor = { id: `admin-${sfx}`, role: 'admin' };
  const T = (iso: string) => new Date(iso);
  let campaignId = '';
  let slug = '';
  const ids: Record<string, string> = {};

  async function profile(
    key: string,
    over: Partial<{
      createdAt: Date;
      birthDate: Date;
      guardianConsentedAt: Date | null;
      complete: boolean;
      email: string;
      verified: boolean;
      fullName: string;
      countryOfResidence: string;
      /** false : profil complet SANS `profileCompletedAt` — le recalcul doit le dater. */
      stamped: boolean;
    }> = {},
  ) {
    const complete = over.complete ?? true;
    const id = `${key}-${sfx}`;
    await prisma.userProfile.create({
      data: {
        id,
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName: over.fullName ?? `${key} Test`,
        email: over.email ?? `${key}-${sfx}@gmail.com`,
        supabaseUserId: over.verified === false ? null : `sup-${id}`,
        phone: complete ? '+227 90 00 00 00' : '',
        countryOfResidence: over.countryOfResidence ?? 'Niger',
        // `consentedAt` n'est JAMAIS posé : aucune build ni le serveur ne
        // l'écrit (audit 57, F15). L'injecter ici masquait que la production ne
        // qualifiait aucun filleul.
        consentedAt: null,
        birthDate: over.birthDate ?? T('2004-03-01T00:00:00Z'),
        guardianConsentedAt: over.guardianConsentedAt ?? null,
        fieldIds: complete ? ['d01'] : [],
        targetCountryIds: complete ? ['fr'] : [],
        createdAt: over.createdAt ?? T('2026-11-02T08:00:00Z'),
        profileCompletedAt:
          complete && over.stamped !== false ? (over.createdAt ?? T('2026-11-02T08:00:00Z')) : null,
      },
    });
    ids[key] = id;
    return id;
  }

  /** Rattache via le vrai `redeem`, puis date le rattachement (horloge de test). */
  async function attach(refKey: string, code: string, at: string, ip: string) {
    await referrals.redeem(ids[refKey], code, { ip });
    await prisma.referral.update({
      where: { refereeProfileId: ids[refKey] },
      data: { createdAt: T(at) },
    });
  }

  beforeAll(async () => {
    await profile('amb1', { fullName: 'Aïcha Konaté', createdAt: T('2026-09-01T00:00:00Z') });
    await profile('amb2', { fullName: 'Moussa Diallo', createdAt: T('2026-09-01T00:00:00Z') });
    await profile('amb3', {
      fullName: 'Awa Sossou',
      createdAt: T('2026-09-01T00:00:00Z'),
      birthDate: T('2009-05-01T00:00:00Z'),
      guardianConsentedAt: T('2026-09-01T00:00:00Z'),
      countryOfResidence: 'Bénin',
    });
  });

  afterAll(async () => {
    const all = Object.values(ids);
    await prisma.referralCampaign.deleteMany({ where: { id: campaignId } });
    await prisma.referralAttributionSignal.deleteMany({
      where: { OR: [{ refereeProfileId: { in: all } }, { referrerProfileId: { in: all } }] },
    });
    await prisma.ambassadorReferral.deleteMany({ where: { refereeProfileId: { in: all } } });
    await prisma.ambassador.deleteMany({ where: { userProfileId: { in: all } } });
    await prisma.referral.deleteMany({ where: { refereeProfileId: { in: all } } });
    await prisma.deviceToken.deleteMany({ where: { userProfileId: { in: all } } });
    await prisma.adminAuditEvent.deleteMany({ where: { actorAdminId: actor.id } });
    await prisma.userProfile.deleteMany({ where: { id: { in: all } } });
    await prisma.$disconnect();
  });

  it('active trois ambassadeurs par l’équipe et crée la campagne (UTC+1)', async () => {
    const a1 = await ambassadors.activate({ email: `amb1-${sfx}@gmail.com`, city: 'Niamey' }, actor, 'rq1');
    const a2 = await ambassadors.activate({ email: `amb2-${sfx}@gmail.com`, city: 'Maradi' }, actor, 'rq2');
    const a3 = await ambassadors.activate({ email: `amb3-${sfx}@gmail.com`, city: 'Cotonou' }, actor, 'rq3');
    expect(a1.code).toMatch(/^KTOU-AK-[0-9a-z]{6}$/);
    expect(a1.personalCode).toMatch(/^[A-Z2-9]{8}$/);
    expect(a1.cashProgramEnabled).toBe(false);
    ids.a1code = a1.code;
    ids.a2code = a2.code;
    ids.a3personal = a3.personalCode;

    slug = `ambassadeurs-test-${sfx}`;
    const c = await campaigns.create(
      {
        slug,
        nameFr: 'Compétition ambassadeurs — novembre 2026',
        nameEn: 'Ambassador challenge — November 2026',
        startDate: '2026-11-01',
        endDate: '2026-11-10',
        timeZone: 'Africa/Lagos',
        prizes: [
          { rank: 1, amountFcfa: 100000 },
          { rank: 2, amountFcfa: 50000 },
          { rank: 3, amountFcfa: 30000 },
        ],
        eligibleCities: ['Maradi', 'Niamey', 'Cotonou', 'Abidjan', 'Douala'],
        rulesUrl: 'https://kpbeducation.cloud/reglement-ambassadeurs-2026-11.html',
      },
      actor,
      'rq4',
    );
    campaignId = c.id;
    expect(c.startsAt).toBe('2026-10-31T23:00:00.000Z');
    expect(c.endsAt).toBe('2026-11-10T23:00:00.000Z');

    for (const email of ['amb1', 'amb2', 'amb3']) {
      await campaigns.enroll(campaignId, { email: `${email}-${sfx}@gmail.com` }, actor, `rq-${email}`);
    }
    const board = await campaigns.adminLeaderboard(campaignId);
    const minor = board.items.find((i) => i.city === 'Cotonou')!;
    expect(minor).toMatchObject({
      publicName: 'Awa S.',
      minorStatus: 'minor',
      parentalAuthStatus: 'pending',
      unrankableReason: 'parental_authorization_missing',
    });
    expect(board.items.find((i) => i.city === 'Niamey')!.displayName).toBe('Aïcha K. — Niamey');
    await campaigns.transition(campaignId, 'launch', actor, 'rq5');
  });

  it('refuse une ville hors liste', async () => {
    await profile('amb4', { fullName: 'Hors Liste', createdAt: T('2026-09-01T00:00:00Z') });
    await ambassadors.activate({ email: `amb4-${sfx}@gmail.com`, city: 'Lomé' }, actor, 'rq6');
    await expect(
      campaigns.enroll(campaignId, { email: `amb4-${sfx}@gmail.com` }, actor, 'rq7'),
    ).rejects.toThrow('Ville non éligible');
  });

  it('compte les filleuls dans la fenêtre, marque rafale / appareil / e-mail jetable', async () => {
    // Ambassadeur 1 (code ambassadeur, saisi en majuscules par l'app).
    const code1 = ids.a1code.toUpperCase();
    await profile('r1', { createdAt: T('2026-11-01T09:00:00Z') });
    await attach('r1', code1, '2026-11-01T10:00:00Z', '41.1.1.1');
    await profile('r2', { createdAt: T('2026-11-03T09:00:00Z') });
    await attach('r2', code1.toLowerCase(), '2026-11-03T10:00:00Z', '41.2.2.2');
    // Hors fenêtre : avant le 1er à 00 h locale, après le 10 à minuit locale.
    await profile('early', { createdAt: T('2026-10-31T22:00:00Z') });
    await attach('early', code1, '2026-10-31T22:30:00Z', '41.3.3.3');
    await profile('late', { createdAt: T('2026-11-10T23:10:00Z') });
    await attach('late', code1, '2026-11-10T23:30:00Z', '41.4.4.4');
    // Profil incomplet : en attente.
    await profile('p1', { createdAt: T('2026-11-04T09:00:00Z'), complete: false });
    await attach('p1', code1, '2026-11-04T10:00:00Z', '41.5.5.5');
    // Même téléphone (jeton push) pour d1 puis d2.
    await profile('d1', { createdAt: T('2026-11-05T09:00:00Z') });
    await prisma.deviceToken.create({
      data: { userProfileId: ids.d1, token: `tok-${sfx}`, platform: 'android' },
    });
    await attach('d1', code1, '2026-11-05T10:00:00Z', '41.6.6.6');
    await profile('d2', { createdAt: T('2026-11-06T09:00:00Z') });
    await prisma.deviceToken.update({ where: { token: `tok-${sfx}` }, data: { userProfileId: ids.d2 } });
    await attach('d2', code1, '2026-11-06T10:00:00Z', '41.7.7.7');

    // Ambassadeur 2 : rafale depuis la même IP (3 en 30 min), un isolé, un jetable.
    for (const [k, at] of [
      ['b1', '2026-11-02T12:00:00Z'],
      ['b2', '2026-11-02T12:10:00Z'],
      ['b3', '2026-11-02T12:25:00Z'],
    ] as const) {
      await profile(k, { createdAt: T('2026-11-02T11:00:00Z') });
      await attach(k, ids.a2code, at, '102.16.5.9');
    }
    await profile('b4', { createdAt: T('2026-11-07T09:00:00Z') });
    await attach('b4', ids.a2code, '2026-11-07T10:00:00Z', '102.99.1.1');
    await profile('b5', { createdAt: T('2026-11-08T09:00:00Z'), email: `b5-${sfx}@yopmail.com` });
    await attach('b5', ids.a2code, '2026-11-08T10:00:00Z', '102.98.1.1');

    // Ambassadeur 3 (mineur) : par son code PERSONNEL (codes unifiés).
    for (const [k, at] of [
      ['c1', '2026-11-02T15:00:00Z'],
      ['c2', '2026-11-03T15:00:00Z'],
      ['c3', '2026-11-04T15:00:00Z'],
    ] as const) {
      // c3 : profil complet sans date de complétion ni `consentedAt` — c'est
      // le recalcul qui le date (chemin `completedNow`).
      await profile(k, { createdAt: T('2026-11-02T14:00:00Z'), stamped: k !== 'c3' });
      await attach(k, ids.a3personal.toLowerCase(), at, `197.0.0.${k.slice(1)}`);
    }

    const report = await campaigns.recompute(campaignId, T('2026-11-09T12:00:00Z'));
    expect(report.created).toBe(13);
    expect(report.profilesStamped).toBe(1);
    const c3 = await prisma.userProfile.findUniqueOrThrow({ where: { id: ids.c3 } });
    expect(c3).toMatchObject({ consentedAt: null, profileCompletedAt: T('2026-11-09T12:00:00Z') });

    const board = await campaigns.adminLeaderboard(campaignId);
    const by = Object.fromEntries(board.items.map((i) => [i.city, i]));
    expect(by.Niamey).toMatchObject({ qualifiedCount: 3, flaggedCount: 1, pendingCount: 1, rank: 1 });
    expect(by.Maradi).toMatchObject({ qualifiedCount: 1, flaggedCount: 4, rank: 2 });
    // Le mineur a 3 filleuls qualifiés mais n'est PAS classé.
    expect(by.Cotonou).toMatchObject({ qualifiedCount: 3, rank: null });

    const maradi = await campaigns.participantReferrals(campaignId, by.Maradi.id);
    const flags = Object.fromEntries(maradi.items.map((r) => [r.refereeEmail.split('-')[0], r.flags]));
    expect(flags.b1).toContain('ip_burst');
    expect(flags.b5).toEqual(['disposable_email']);
    const niamey = await campaigns.participantReferrals(campaignId, by.Niamey.id);
    const d2 = niamey.items.find((r) => r.refereeEmail.startsWith('d2-'))!;
    expect(d2).toMatchObject({ status: 'flagged', flags: ['device_duplicate'] });
    expect(niamey.items.map((r) => r.refereeEmail.split('-')[0]).sort()).toEqual(
      ['d1', 'd2', 'p1', 'r1', 'r2'],
    );

    // Signaux hachés : aucune IP ni aucun jeton en clair.
    const signal = await prisma.referralAttributionSignal.findUnique({
      where: { refereeProfileId: ids.d2 },
    });
    expect(JSON.stringify(signal)).not.toMatch(/41\.7\.7\.7|tok-/);
    // Ligne de l'espace ambassadeur, nom « Prénom I. ».
    const ar = await prisma.ambassadorReferral.findUnique({ where: { refereeProfileId: ids.r1 } });
    expect(ar?.refereeName).toBe('R T.'); // chiffres retirés du nom affiché
  });

  it('rejouer le calcul n’écrit rien (idempotence)', async () => {
    const again = await campaigns.recompute(campaignId, T('2026-11-09T12:05:00Z'));
    expect(again).toMatchObject({
      created: 0,
      updated: 0,
      deleted: 0,
      participantsUpdated: 0,
      profilesStamped: 0,
      unchanged: 13,
    });
  });

  it('l’équipe valide une rafale légitime, exclut avec motif, vérifie l’autorisation parentale', async () => {
    const board = await campaigns.adminLeaderboard(campaignId);
    const by = Object.fromEntries(board.items.map((i) => [i.city, i]));
    const maradi = await campaigns.participantReferrals(campaignId, by.Maradi.id);
    const b1 = maradi.items.find((r) => r.refereeEmail.startsWith('b1-'))!;
    await campaigns.decide(campaignId, b1.id, 'validated', 'Atelier au lycée, même Wi-Fi', actor, 'rq8');
    const niamey = await campaigns.participantReferrals(campaignId, by.Niamey.id);
    const r2 = niamey.items.find((r) => r.refereeEmail.startsWith('r2-'))!;
    await expect(
      campaigns.decide(campaignId, r2.id, 'excluded', undefined, actor, 'rq9'),
    ).rejects.toThrow('motif');
    await campaigns.decide(campaignId, r2.id, 'excluded', 'Compte fictif signalé', actor, 'rq10');
    await campaigns.updateParticipant(
      campaignId,
      by.Cotonou.id,
      { parentalAuthStatus: 'verified', parentalAuthNote: 'Formulaire signé reçu le 05/11' },
      actor,
      'rq11',
    );

    const after = await campaigns.adminLeaderboard(campaignId);
    const a = Object.fromEntries(after.items.map((i) => [i.city, i]));
    expect(a.Niamey).toMatchObject({ qualifiedCount: 2, excludedCount: 1 });
    expect(a.Maradi).toMatchObject({ qualifiedCount: 2, flaggedCount: 3 });
    expect(a.Cotonou).toMatchObject({
      qualifiedCount: 3,
      rank: 1,
      parentalAuthStatus: 'verified',
      parentalAuthVerifiedByAdminId: actor.id,
    });
    // Égalité 2-2 : le premier à avoir atteint 2 gagne (Maradi le 07/11, Niamey le 05/11).
    expect(a.Niamey.rank).toBe(2);
    expect(a.Maradi.rank).toBe(3);

    const audit = await prisma.adminAuditEvent.findMany({
      where: { actorAdminId: actor.id, action: { startsWith: 'referral_campaign.referral_' } },
    });
    expect(audit.map((e) => e.action).sort()).toEqual([
      'referral_campaign.referral_excluded',
      'referral_campaign.referral_validated',
    ]);
    expect(audit.find((e) => e.action.endsWith('excluded'))?.reasonCode).toBe('Compte fictif signalé');
  });

  it('le classement public ne montre que nom public, ville, nombre et rang', async () => {
    const pub = await campaigns.publicLeaderboard(slug, undefined, T('2026-11-09T13:00:00Z'));
    expect(pub.entries.slice(0, 3).map((e) => `${e.rank}. ${e.name} — ${e.city} (${e.qualified})`)).toEqual([
      '1. Awa S. — Cotonou (3)',
      '2. Aïcha K. — Niamey (2)',
      '3. Moussa D. — Maradi (2)',
    ]);
    const text = JSON.stringify(pub);
    expect(text).not.toMatch(/@|sup-|KTOU|amb1-|Konaté/);
    expect(text).not.toContain(campaignId);
  });

  it('gèle automatiquement à la fin, valide le podium, note les versements, clôt', async () => {
    const reports = await campaigns.recomputeLive(T('2026-11-11T00:05:00Z'));
    expect(reports.some((r) => r.campaignId === campaignId)).toBe(true);
    expect((await campaigns.get(campaignId)).status).toBe('frozen');
    // Un rattachement après la fin ne change rien (la fenêtre est fermée).
    await profile('after', { createdAt: T('2026-11-11T08:00:00Z') });
    await attach('after', ids.a1code, '2026-11-11T08:10:00Z', '41.9.9.9');

    await expect(campaigns.transition(campaignId, 'close', actor, 'rq12')).rejects.toThrow('podium');
    await campaigns.transition(campaignId, 'validate_podium', actor, 'rq13');
    const prizes = await campaigns.prizes(campaignId);
    expect(prizes.items.map((p) => [p.rank, p.publicNameSnapshot, p.amountFcfa, p.recipient])).toEqual([
      [1, 'Awa S. — Cotonou', 100000, 'parent'],
      [2, 'Aïcha K. — Niamey', 50000, 'ambassador'],
      [3, 'Moussa D. — Maradi', 30000, 'ambassador'],
    ]);

    await expect(
      campaigns.recordPayout(campaignId, 1, { payoutReference: 'WAVE-1', recipient: 'ambassador' }, actor, 'rq14'),
    ).rejects.toThrow('parent');
    const paid = await campaigns.recordPayout(
      campaignId,
      1,
      { payoutReference: 'WAVE-TX-0001', recipient: 'parent', paidAt: '2026-11-15T10:00:00Z' },
      actor,
      'rq15',
    );
    expect(paid).toMatchObject({
      payoutStatus: 'paid',
      paidAmountFcfa: 100000,
      payoutMethod: 'wave',
      paidByAdminId: actor.id,
    });
    // Après un versement, le podium ne se revalide plus.
    await expect(campaigns.transition(campaignId, 'validate_podium', actor, 'rq16')).rejects.toThrow(
      'versement',
    );

    // ── Correctifs 57 : prix forfait réattribué APRÈS un premier versement ──
    const board = await campaigns.adminLeaderboard(campaignId);
    const pid = (name: string) => board.items.find((i) => i.publicName === name)!.id;
    // Un prix versé ne se déclare pas forfait.
    await expect(
      campaigns.forfeitPrize(campaignId, 1, { participantId: pid('Awa S.'), reason: 'Injoignable' }, actor, 'rq16a'),
    ).rejects.toThrow('versé');
    // Le lauréat affiché a changé entre-temps : refus, rien n'est écrit.
    await expect(
      campaigns.forfeitPrize(campaignId, 2, { participantId: pid('Moussa D.'), reason: 'Injoignable' }, actor, 'rq16b'),
    ).rejects.toThrow('changé');
    const after = await campaigns.forfeitPrize(
      campaignId,
      2,
      { participantId: pid('Aïcha K.'), reason: 'Injoignable 15 jours après la validation' },
      actor,
      'rq16c',
    );
    // Le 2e prix passe au suivant classé non primé (le 3e) ; le 3e prix n'a
    // plus de candidat (trois participants classés) ; le 1er, versé, ne bouge pas.
    expect(after.items.map((p) => [p.rank, p.publicNameSnapshot, p.amountFcfa, p.payoutStatus])).toEqual([
      [1, 'Awa S. — Cotonou', 100000, 'paid'],
      [2, 'Moussa D. — Maradi', 50000, 'pending'],
    ]);
    expect(after.forfeits).toHaveLength(1);
    expect(after.forfeits[0]).toMatchObject({
      rank: 2,
      participantId: pid('Aïcha K.'),
      publicNameSnapshot: 'Aïcha K. — Niamey',
      amountFcfa: 50000,
      reason: 'Injoignable 15 jours après la validation',
      forfeitedByAdminId: actor.id,
      replacedByParticipantId: pid('Moussa D.'),
    });
    // Idempotent : la même déclaration ne réécrit rien.
    const replay = await campaigns.forfeitPrize(
      campaignId,
      2,
      { participantId: pid('Aïcha K.'), reason: 'Injoignable' },
      actor,
      'rq16d',
    );
    expect(replay.forfeits).toHaveLength(1);
    expect(replay.items.map((p) => p.publicNameSnapshot)).toEqual(['Awa S. — Cotonou', 'Moussa D. — Maradi']);
    const forfeitAudit = await prisma.adminAuditEvent.findMany({
      where: { actorAdminId: actor.id, action: 'referral_campaign.prize_forfeited' },
    });
    expect(forfeitAudit).toHaveLength(1);
    expect(forfeitAudit[0]).toMatchObject({
      purposeCode: 'referral_campaign',
      reasonCode: 'Injoignable 15 jours après la validation',
    });
    // Le classement garde l'ordre réel.
    const ranks = (await campaigns.adminLeaderboard(campaignId)).items.slice(0, 3).map((i) => [i.rank, i.publicName]);
    expect(ranks).toEqual([
      [1, 'Awa S.'],
      [2, 'Aïcha K.'],
      [3, 'Moussa D.'],
    ]);
    // Avant la clôture, aucun lauréat public (podium provisoire).
    expect((await campaigns.publicLeaderboard(slug, undefined, T('2026-11-16T00:00:00Z'))).winners).toEqual([]);

    await campaigns.transition(campaignId, 'close', actor, 'rq17');
    expect((await campaigns.recompute(campaignId)).skipped).toBe('closed');
    const pub = await campaigns.publicLeaderboard(slug, undefined, T('2026-11-16T00:05:00Z'));
    expect(pub.campaign.provisional).toBe(false);
    // Résultats définitifs : les lauréats EFFECTIFS ; le classement, l'ordre réel.
    expect(pub.winners).toEqual([
      { prizeRank: 1, amountFcfa: 100000, name: 'Awa S.', city: 'Cotonou' },
      { prizeRank: 2, amountFcfa: 50000, name: 'Moussa D.', city: 'Maradi' },
    ]);
    expect(pub.entries.slice(0, 3).map((e) => e.name)).toEqual(['Awa S.', 'Aïcha K.', 'Moussa D.']);

    const csv = await campaigns.exportCsv(campaignId, 'leaderboard');
    expect(csv.split('\r\n')[0]).toContain('"rank","public_name"');
    expect(csv).toContain('"Awa S."');
  });

  it('la suppression du compte d’un filleul purge sa ligne de campagne et ses empreintes', async () => {
    const storage = { keyFromUrl: () => null, delete: jest.fn() } as unknown as StorageService;
    const profiles = new ProfilesService(prismaService, storage);
    // La CI renseigne SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY : la suppression
    // appelle alors l'API d'administration Supabase. On simule sa réponse (200)
    // pour tester la purge en base sans dépendre du réseau.
    const fetchSpy = jest
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(new Response(null, { status: 200 }));
    try {
      await profiles.deleteMe(ids.r1);
    } finally {
      fetchSpy.mockRestore();
    }
    expect(
      await prisma.referralCampaignReferral.count({ where: { refereeProfileId: ids.r1 } }),
    ).toBe(0);
    expect(
      await prisma.referralAttributionSignal.count({ where: { refereeProfileId: ids.r1 } }),
    ).toBe(0);
    delete ids.r1;
  });
});
