import {
  burstMembers,
  computeQualification,
  type QualificationInput,
  type QualificationReferee,
  type QualificationSignal,
} from './campaign-qualification';
import { DEFAULT_QUALIFICATION_RULE } from './campaign-rules';
import { campaignWindowFromDays } from './campaign-time';

/**
 * Le comptage de la compétition : qualification (décision du 17/10/2026),
 * fenêtre UTC+1, anti-fraude, mineurs non autorisés, idempotence.
 */
const WINDOW = campaignWindowFromDays('2026-11-01', '2026-11-10', 'Africa/Lagos');
const T = (iso: string) => new Date(iso);
const NOW = T('2026-11-05T12:00:00Z');

function referee(id: string, over: Partial<QualificationReferee> = {}): QualificationReferee {
  return {
    id,
    email: `${id}@gmail.com`,
    supabaseUserId: `sup-${id}`,
    createdAt: T('2026-11-02T10:00:00Z'),
    profileCompletedAt: T('2026-11-02T10:20:00Z'),
    accountType: 'student',
    consentedAt: T('2026-11-02T10:20:00Z'),
    phone: '+227 90 00 00 00',
    birthDate: T('2005-01-01T00:00:00Z'),
    guardianConsentedAt: null,
    fieldIds: ['d01'],
    targetCountryIds: ['fr'],
    ...over,
  };
}

function baseInput(over: Partial<QualificationInput> = {}): QualificationInput {
  return {
    window: WINDOW,
    rule: { ...DEFAULT_QUALIFICATION_RULE },
    now: NOW,
    participants: [
      {
        id: 'P1',
        profileId: 'amb1',
        status: 'active',
        minorStatus: 'adult',
        parentalAuthStatus: 'not_required',
        ambassadorApproved: true,
        enrolledAt: T('2026-10-20T00:00:00Z'),
      },
      {
        id: 'P2',
        profileId: 'amb2',
        status: 'active',
        minorStatus: 'adult',
        parentalAuthStatus: 'not_required',
        ambassadorApproved: true,
        enrolledAt: T('2026-10-21T00:00:00Z'),
      },
    ],
    attributions: [],
    referees: new Map(),
    signals: new Map(),
    decisions: new Map(),
    ...over,
  };
}

function withReferees(
  list: Array<{ r: QualificationReferee; to: string; at: string; signal?: Partial<QualificationSignal> }>,
  over: Partial<QualificationInput> = {},
): QualificationInput {
  return baseInput({
    attributions: list.map((x) => ({
      refereeProfileId: x.r.id,
      referrerProfileId: x.to,
      attachedAt: T(x.at),
    })),
    referees: new Map(list.map((x) => [x.r.id, x.r])),
    signals: new Map(
      list
        .filter((x) => x.signal)
        .map((x) => [
          x.r.id,
          { ipHash: null, ipBlockHash: null, deviceHashes: [], clientDeviceHash: null, ...x.signal },
        ]),
    ),
    ...over,
  });
}

describe('computeQualification — qualification', () => {
  it('qualifie au moment où les trois conditions sont réunies (max des instants)', () => {
    const out = computeQualification(
      withReferees([{ r: referee('a'), to: 'amb1', at: '2026-11-02T11:00:00Z' }]),
    );
    expect(out.referrals[0]).toMatchObject({
      status: 'qualified',
      participantId: 'P1',
      qualifiedAt: T('2026-11-02T11:00:00Z'), // le rattachement est le dernier
    });
    expect(out.participants.find((p) => p.id === 'P1')).toMatchObject({
      qualifiedCount: 1,
      rank: 1,
    });
  });

  it('un profil complété APRÈS le rattachement date la qualification', () => {
    const out = computeQualification(
      withReferees([
        {
          r: referee('a', { profileCompletedAt: T('2026-11-03T09:00:00Z') }),
          to: 'amb1',
          at: '2026-11-02T11:00:00Z',
        },
      ]),
    );
    expect(out.referrals[0].qualifiedAt).toEqual(T('2026-11-03T09:00:00Z'));
  });

  it('reste en attente sans e-mail vérifié (profil non relié à Supabase)', () => {
    const out = computeQualification(
      withReferees([
        { r: referee('a', { supabaseUserId: null }), to: 'amb1', at: '2026-11-02T11:00:00Z' },
      ]),
    );
    expect(out.referrals[0].status).toBe('pending');
    expect(out.participants[0].qualifiedCount).toBe(0);
    expect(out.participants[0].rank).toBeNull();
  });

  it('reste en attente sans profil complété (pas de domaine choisi)', () => {
    const out = computeQualification(
      withReferees([
        {
          r: referee('a', { profileCompletedAt: null, fieldIds: [] }),
          to: 'amb1',
          at: '2026-11-02T11:00:00Z',
        },
      ]),
    );
    expect(out.referrals[0]).toMatchObject({ status: 'pending', profileCompletedAt: null });
    expect(out.completedNow).toEqual([]);
  });

  it('date à `now` un profil vu complet sans horodatage, et le signale pour écriture', () => {
    const out = computeQualification(
      withReferees([
        { r: referee('a', { profileCompletedAt: null }), to: 'amb1', at: '2026-11-02T11:00:00Z' },
      ]),
    );
    expect(out.completedNow).toEqual(['a']);
    expect(out.referrals[0].qualifiedAt).toEqual(NOW);
  });

  it('un filleul mineur sans accord du tuteur n’a pas un profil complété', () => {
    const out = computeQualification(
      withReferees([
        {
          r: referee('a', {
            profileCompletedAt: null,
            birthDate: T('2009-06-01T00:00:00Z'),
            guardianConsentedAt: null,
          }),
          to: 'amb1',
          at: '2026-11-02T11:00:00Z',
        },
      ]),
    );
    expect(out.referrals[0].status).toBe('pending');
  });
});

describe('computeQualification — fenêtre UTC+1', () => {
  it('ignore un rattachement hors fenêtre (avant le 1er à 00 h locale, après le 10 à minuit)', () => {
    const out = computeQualification(
      withReferees([
        { r: referee('early'), to: 'amb1', at: '2026-10-31T22:59:59Z' },
        { r: referee('late'), to: 'amb1', at: '2026-11-10T23:00:00Z' },
        { r: referee('ok'), to: 'amb1', at: '2026-11-10T22:59:00Z' },
      ]),
    );
    expect(out.referrals.map((r) => r.refereeProfileId)).toEqual(['ok']);
  });

  it('refuse un compte créé avant la fenêtre (règle par défaut)', () => {
    const out = computeQualification(
      withReferees([
        {
          r: referee('old', { createdAt: T('2026-09-01T00:00:00Z'), profileCompletedAt: T('2026-09-01T00:10:00Z') }),
          to: 'amb1',
          at: '2026-11-02T11:00:00Z',
        },
      ]),
    );
    expect(out.referrals[0].status).toBe('pending');
  });

  it('… sauf si la règle de la campagne l’autorise', () => {
    const input = withReferees([
      {
        r: referee('old', { createdAt: T('2026-09-01T00:00:00Z'), profileCompletedAt: T('2026-09-01T00:10:00Z') }),
        to: 'amb1',
        at: '2026-11-02T11:00:00Z',
      },
    ]);
    input.rule.requireAccountCreatedInWindow = false;
    expect(computeQualification(input).referrals[0].status).toBe('qualified');
  });

  it('ne qualifie pas un profil complété après la fin de la fenêtre', () => {
    const out = computeQualification(
      withReferees([
        {
          r: referee('a', { profileCompletedAt: T('2026-11-11T08:00:00Z') }),
          to: 'amb1',
          at: '2026-11-10T20:00:00Z',
        },
      ]),
    );
    expect(out.referrals[0]).toMatchObject({ status: 'pending', qualifiedAt: null });
  });
});

describe('computeQualification — anti-fraude (marquer, jamais supprimer)', () => {
  it('marque « à vérifier » un e-mail jetable', () => {
    const out = computeQualification(
      withReferees([
        { r: referee('a', { email: 'x@yopmail.com' }), to: 'amb1', at: '2026-11-02T11:00:00Z' },
      ]),
    );
    expect(out.referrals[0]).toMatchObject({ status: 'flagged', flags: ['disposable_email'] });
    expect(out.participants[0]).toMatchObject({ qualifiedCount: 0, flaggedCount: 1 });
  });

  it('un compte qualifié par appareil : le second sur le même téléphone est à vérifier', () => {
    const out = computeQualification(
      withReferees([
        { r: referee('a'), to: 'amb1', at: '2026-11-02T11:00:00Z', signal: { deviceHashes: ['dev1'] } },
        {
          r: referee('b', { createdAt: T('2026-11-03T10:00:00Z'), profileCompletedAt: T('2026-11-03T10:10:00Z') }),
          to: 'amb1',
          at: '2026-11-03T11:00:00Z',
          signal: { deviceHashes: ['dev1'] },
        },
      ]),
    );
    const byId = Object.fromEntries(out.referrals.map((r) => [r.refereeProfileId, r]));
    expect(byId.a.status).toBe('qualified');
    expect(byId.b).toMatchObject({ status: 'flagged', flags: ['device_duplicate'] });
  });

  it('relie les appareils de proche en proche (jeton push puis identifiant d’installation)', () => {
    const out = computeQualification(
      withReferees([
        { r: referee('a'), to: 'amb1', at: '2026-11-02T11:00:00Z', signal: { deviceHashes: ['push1'] } },
        {
          r: referee('b'),
          to: 'amb2',
          at: '2026-11-02T12:00:00Z',
          signal: { deviceHashes: ['push1'], clientDeviceHash: 'inst1' },
        },
        { r: referee('c'), to: 'amb2', at: '2026-11-02T13:00:00Z', signal: { clientDeviceHash: 'inst1' } },
      ]),
    );
    const flagged = out.referrals.filter((r) => r.flags.includes('device_duplicate'));
    expect(flagged.map((r) => r.refereeProfileId).sort()).toEqual(['b', 'c']);
  });

  it('détecte une rafale depuis la même IP (3 en moins d’une heure) — toutes à vérifier', () => {
    const list = ['a', 'b', 'c'].map((id, i) => ({
      r: referee(id),
      to: 'amb1',
      at: `2026-11-02T11:${String(i * 10).padStart(2, '0')}:00Z`,
      signal: { ipHash: 'ip1' },
    }));
    const out = computeQualification(withReferees(list));
    expect(out.referrals.every((r) => r.status === 'flagged' && r.flags.includes('ip_burst'))).toBe(
      true,
    );
  });

  it('pas de rafale : même IP mais étalée sur plusieurs heures', () => {
    const list = ['a', 'b', 'c'].map((id, i) => ({
      r: referee(id),
      to: 'amb1',
      at: `2026-11-02T${String(10 + i * 2).padStart(2, '0')}:00:00Z`,
      signal: { ipHash: 'ip1' },
    }));
    const out = computeQualification(withReferees(list));
    expect(out.referrals.every((r) => r.status === 'qualified')).toBe(true);
  });

  it('une rafale de vélocité (10 rattachements en 10 min sur le même code)', () => {
    const list = Array.from({ length: 10 }, (_, i) => ({
      r: referee(`v${i}`),
      to: 'amb1',
      at: `2026-11-02T11:0${i}:00Z`,
    }));
    const out = computeQualification(withReferees(list));
    expect(out.referrals.every((r) => r.flags.includes('velocity_burst'))).toBe(true);
  });

  it('un participant filleul d’un autre participant est à vérifier', () => {
    const out = computeQualification(
      withReferees([{ r: referee('amb2'), to: 'amb1', at: '2026-11-02T11:00:00Z' }]),
    );
    expect(out.referrals[0].flags).toContain('referee_is_participant');
  });

  it('l’équipe valide une ligne signalée (elle compte) ou exclut une ligne (elle ne compte plus)', () => {
    const input = withReferees([
      { r: referee('a', { email: 'x@yopmail.com' }), to: 'amb1', at: '2026-11-02T11:00:00Z' },
      { r: referee('b'), to: 'amb1', at: '2026-11-02T12:00:00Z' },
    ]);
    input.decisions = new Map([
      ['a', 'validated'],
      ['b', 'excluded'],
    ]);
    const out = computeQualification(input);
    const byId = Object.fromEntries(out.referrals.map((r) => [r.refereeProfileId, r]));
    expect(byId.a.status).toBe('qualified');
    expect(byId.a.flags).toEqual(['disposable_email']); // le signal reste visible
    expect(byId.b.status).toBe('excluded');
    expect(out.participants[0]).toMatchObject({ qualifiedCount: 1, excludedCount: 1 });
  });

  it('burstMembers : fenêtre glissante', () => {
    const m = 60_000;
    expect([...burstMembers([0, 5 * m, 9 * m, 30 * m], 3, 10 * m)].sort()).toEqual([0, 1, 2]);
    expect(burstMembers([0, 11 * m, 22 * m], 3, 10 * m).size).toBe(0);
  });
});

describe('computeQualification — classement et mineurs', () => {
  it('classe par nombre, puis par l’instant où le compte a été atteint', () => {
    const out = computeQualification(
      withReferees([
        { r: referee('a'), to: 'amb1', at: '2026-11-02T11:00:00Z' },
        { r: referee('b'), to: 'amb2', at: '2026-11-02T10:30:00Z' },
      ]),
    );
    const rank = Object.fromEntries(out.participants.map((p) => [p.id, p.rank]));
    expect(rank).toEqual({ P2: 1, P1: 2 });
  });

  it('un mineur sans autorisation parentale vérifiée n’est pas classé (ses filleuls restent comptés)', () => {
    const input = withReferees([{ r: referee('a'), to: 'amb1', at: '2026-11-02T11:00:00Z' }]);
    input.participants = input.participants.map((p) =>
      p.id === 'P1' ? { ...p, minorStatus: 'minor', parentalAuthStatus: 'pending' } : p,
    );
    const p1 = computeQualification(input).participants.find((p) => p.id === 'P1')!;
    expect(p1).toMatchObject({
      qualifiedCount: 1,
      rank: null,
      unrankableReason: 'parental_authorization_missing',
    });
  });

  it('… et l’est une fois l’autorisation vérifiée', () => {
    const input = withReferees([{ r: referee('a'), to: 'amb1', at: '2026-11-02T11:00:00Z' }]);
    input.participants = input.participants.map((p) =>
      p.id === 'P1' ? { ...p, minorStatus: 'minor', parentalAuthStatus: 'verified' } : p,
    );
    expect(computeQualification(input).participants.find((p) => p.id === 'P1')!.rank).toBe(1);
  });

  it('âge inconnu, participant disqualifié ou ambassadeur désactivé : non classés', () => {
    const input = withReferees([
      { r: referee('a'), to: 'amb1', at: '2026-11-02T11:00:00Z' },
      { r: referee('b'), to: 'amb2', at: '2026-11-02T11:00:00Z' },
    ]);
    input.participants = [
      { ...input.participants[0], minorStatus: 'unknown' },
      { ...input.participants[1], ambassadorApproved: false },
    ];
    const out = computeQualification(input);
    expect(out.participants.map((p) => [p.rank, p.unrankableReason])).toEqual([
      [null, 'age_unknown'],
      [null, 'ambassador_not_approved'],
    ]);
  });
});

describe('computeQualification — idempotence', () => {
  it('même entrée → même sortie ; rejouer après écriture de `profileCompletedAt` ne change rien', () => {
    const list = [
      { r: referee('a', { profileCompletedAt: null }), to: 'amb1', at: '2026-11-02T11:00:00Z' },
      { r: referee('b'), to: 'amb2', at: '2026-11-03T11:00:00Z', signal: { ipHash: 'x' } },
    ];
    const first = computeQualification(withReferees(list));
    // L'appelant écrit profileCompletedAt = now pour les `completedNow`.
    const stamped = list.map((x) =>
      first.completedNow.includes(x.r.id) ? { ...x, r: { ...x.r, profileCompletedAt: NOW } } : x,
    );
    const second = computeQualification(withReferees(stamped, { now: T('2026-11-06T00:00:00Z') }));
    expect(second.completedNow).toEqual([]);
    expect(second.referrals).toEqual(first.referrals);
    expect(second.participants).toEqual(first.participants);
  });
});
