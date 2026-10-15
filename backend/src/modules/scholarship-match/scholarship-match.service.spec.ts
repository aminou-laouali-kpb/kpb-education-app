import type { Prisma } from '@prisma/client';

import { CandidateSnapshotService, type CandidateRow } from './candidate-snapshot';
import { isHonestLabel } from './reasons';
import { RUNS_KEPT, ScholarshipMatchService, type CreateRunResponse } from './scholarship-match.service';
import { candidateRow, FakeMatchDb, type ProfileRecord } from './testing/fake-match-db';
import {
  eiffel,
  language,
  makeScholarship,
  NOW,
  other,
  uwcKenya,
} from './testing/match-fixtures';

/**
 * Le service « Mes 10 bourses » contre une base en mémoire TRANSACTIONNELLE
 * (voir testing/fake-match-db.ts) : ce qui compte est l'état final du profil
 * et des runs, et la forme de la réponse servie à l'app.
 */

const USER = 'stu-1';

function profileRecord(overrides: Partial<ProfileRecord> = {}): ProfileRecord {
  return {
    id: USER,
    countryOfResidence: 'Niger',
    birthDate: new Date('2006-05-10T00:00:00.000Z'),
    guardianConsentedAt: null,
    guardianName: null,
    guardianContact: null,
    nationalityCode: 'ner',
    secondNationalityCode: null,
    highestDiploma: 'bac',
    scholarshipTargetLevel: 'bachelor',
    fieldIds: ['d01'],
    targetCountryIds: [],
    gradeBandOn20: '12_14',
    englishLevel: 'b1',
    frenchLevel: 'c1_c2',
    languageTests: null,
    workExperienceBand: null,
    scholarshipProfileConfirmedAt: null,
    scholarshipMatchAlertsOptInAt: null,
    currentLevel: 'Terminale',
    targetLevel: 'Bachelor',
    languageLevel: 'Intermediate',
    gradeRange: '12 - 14/20',
    ...overrides,
  };
}

const IELTS_QUOTE_FR = 'IELTS 6.5 exigé ; une moyenne de 70 % est appréciée.';

function smallCatalog(): CandidateRow[] {
  return [
    candidateRow(makeScholarship({ id: 'bach-01', eligibleLevels: ['bachelor'] })),
    candidateRow(makeScholarship({ id: 'bach-02', eligibleLevels: ['bachelor'], countryId: 'can' })),
    candidateRow(
      makeScholarship({
        id: 'ielts',
        eligibleLevels: ['bachelor'],
        countryId: 'gbr',
        eligibilityCriteria: [
          {
            ...language('anglais', { tests: [{ type: 'ielts', min: 6.5 }] }),
            officialTextFr: IELTS_QUOTE_FR,
            officialTextEn: 'IELTS 6.5 required; a 70% average is welcome.',
            sourceUrl: 'https://example.org/ielts/eligibility',
          },
        ],
      }),
    ),
    candidateRow(eiffel(), { levelEligibleFr: 'Master', levelEligibleEn: 'Master' }),
    candidateRow(uwcKenya(), { countryNameFr: 'Kenya', countryNameEn: 'Kenya' }),
    candidateRow(
      makeScholarship({ id: 'non-analysee', eligibleLevels: [], eligibilityStructuredAt: null }),
    ),
  ];
}

function bigCatalog(): CandidateRow[] {
  const extra = Array.from({ length: 12 }, (_, i) =>
    candidateRow(
      makeScholarship({ id: `extra-${String(i + 1).padStart(2, '0')}`, eligibleLevels: ['bachelor'] }),
    ),
  );
  return [...smallCatalog(), ...extra];
}

function setup(options: { profile?: Partial<ProfileRecord>; catalog?: CandidateRow[] } = {}) {
  const db = new FakeMatchDb();
  db.addProfile(profileRecord(options.profile));
  db.scholarships = options.catalog ?? smallCatalog();
  const clock = { now: NOW };
  const tick = () => clock.now;
  const snapshots = new CandidateSnapshotService(db.prismaService, tick);
  const service = new ScholarshipMatchService(db.prismaService, snapshots, tick);
  return { db, clock, snapshots, service };
}

function ok(response: CreateRunResponse) {
  if (response.status !== 'ok') throw new Error(`expected ok, got ${response.status}`);
  return response;
}

/** Tous les libellés rédigés par KPB d'une réponse (pas les citations officielles). */
function kpbLabels(response: CreateRunResponse): string[] {
  if (response.status !== 'ok') return [];
  const { run } = response;
  return [
    ...run.items.flatMap((item) => [
      ...item.reasons.map((point) => point.label),
      ...item.toVerify.map((point) => point.label),
    ]),
    ...run.excludedSummary.groups.map((group) => group.label),
    ...(run.excludedSummary.notAnalyzedLabel ? [run.excludedSummary.notAnalyzedLabel] : []),
    ...(run.levelCatalog?.label ? [run.levelCatalog.label] : []),
  ];
}

describe('ScholarshipMatchService.createRun — profil incomplet : RIEN n’est écrit', () => {
  it('profil jamais confirmé, sans `confirm` : profile_incomplete, réponses non enregistrées', async () => {
    const { db, service } = setup();

    const response = await service.createRun(USER, {
      lang: 'fr',
      trigger: 'wizard',
      answers: { englishLevel: 'b2' },
    });

    expect(response.status).toBe('profile_incomplete');
    if (response.status !== 'profile_incomplete') return;
    expect(response.readiness.ready).toBe(false);
    expect(response.readiness.toConfirm).toContain('englishLevel');
    expect(db.runsOf(USER)).toEqual([]);
    expect(db.profile(USER)).toMatchObject({
      englishLevel: 'b1',
      scholarshipProfileConfirmedAt: null,
    });
  });

  it('une clé obligatoire manque, même confirmée : rien n’est écrit, pas même la confirmation', async () => {
    const { db, service } = setup({ profile: { nationalityCode: null } });

    const response = await service.createRun(USER, {
      answers: { gradeBandOn20: '14_16' },
      confirm: true,
    });

    expect(response).toMatchObject({
      status: 'profile_incomplete',
      readiness: { ready: false, required: ['nationalityCode'] },
    });
    expect(db.runsOf(USER)).toEqual([]);
    expect(db.profile(USER)).toMatchObject({
      gradeBandOn20: '12_14',
      scholarshipProfileConfirmedAt: null,
    });
  });

  it('une valeur changée SANS `confirm` retire la confirmation : rien n’est écrit', async () => {
    const confirmedAt = new Date('2026-10-01T00:00:00.000Z');
    const { db, service } = setup({ profile: { scholarshipProfileConfirmedAt: confirmedAt } });

    const response = await service.createRun(USER, { answers: { englishLevel: 'c1_c2' } });

    expect(response.status).toBe('profile_incomplete');
    expect(db.profile(USER)).toMatchObject({
      englishLevel: 'b1',
      scholarshipProfileConfirmedAt: confirmedAt,
    });
    expect(db.runsOf(USER)).toEqual([]);
  });
});

describe('ScholarshipMatchService.createRun — réponses tolérantes et run', () => {
  it('abandonne les clés et jetons inconnus, horodate la confirmation côté serveur, écrit les anciens champs', async () => {
    const { db, service } = setup({ profile: { gradeBandOn20: null, gradeRange: null } });

    const response = ok(
      await service.createRun(USER, {
        lang: 'fr',
        trigger: 'wizard',
        confirm: true,
        answers: {
          englishLevel: 'c3_quantum',
          gradeBandOn20: '12_14',
          fieldIds: ['d01', 'd99', 'd03'],
          futureAnswerKey: 'whatever',
          languageTests: [{ type: 'ielts', score: 7 }, { type: 'pte', score: 70 }],
          secondNationalityCode: 'xyz',
        },
      }),
    );

    expect(response.run.items.length).toBeGreaterThan(0);
    expect(db.profile(USER)).toMatchObject({
      englishLevel: 'b1',
      gradeBandOn20: '12_14',
      gradeRange: '12 - 14/20',
      fieldIds: ['d01', 'd03'],
      languageTests: [{ type: 'ielts', score: 7 }],
      secondNationalityCode: null,
      scholarshipProfileConfirmedAt: NOW,
    });
  });

  it('ne sert JAMAIS une bourse exclue, au plus 10, compatibles d’abord, comptes honnêtes', async () => {
    const { service } = setup({ profile: { scholarshipProfileConfirmedAt: NOW }, catalog: bigCatalog() });

    const { run } = ok(await service.createRun(USER, { trigger: 'rerun' }));

    expect(run.items).toHaveLength(10);
    expect(run.items.every((item) => item.status === 'eligible' || item.status === 'to_verify')).toBe(true);
    const ids = run.items.map((item) => item.scholarshipId);
    expect(ids).not.toContain('eiffel');
    expect(ids).not.toContain('uwc_kenya');
    expect(ids).not.toContain('non-analysee');
    expect(run.counts).toEqual({
      eligible: 14,
      toVerify: 1,
      excluded: 2,
      notAnalyzed: 1,
      candidates: 18,
    });
    expect(run.items.map((item) => item.rank)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  });

  it('rend raisons, points à vérifier (avec la citation officielle) et bourses écartées', async () => {
    const { service } = setup({ profile: { scholarshipProfileConfirmedAt: NOW } });

    const response = ok(await service.createRun(USER, { lang: 'fr' }));
    const { run } = response;

    const ielts = run.items.find((item) => item.scholarshipId === 'ielts')!;
    expect(ielts).toMatchObject({ section: 'to_verify', status: 'to_verify', available: true });
    expect(ielts.toVerify).toEqual([
      {
        code: 'language_missing',
        label: expect.stringContaining('IELTS 6.5'),
        official: { text: IELTS_QUOTE_FR, sourceUrl: 'https://example.org/ielts/eligibility' },
      },
    ]);

    const first = run.items[0];
    expect(first.section).toBe('compatible');
    expect(first.reasons.length).toBeGreaterThan(0);
    expect(first.reasons.length).toBeLessThanOrEqual(3);
    expect(first.reasons.map((reason) => reason.label)).toContain('Niveau Licence accepté');
    expect(first.window).toMatchObject({ status: 'open', dateConfidence: 'confirmed' });
    expect(first.scholarship).toMatchObject({ fundingType: 'fully_funded' });

    expect(run.excludedSummary).toEqual({
      groups: [
        {
          group: 'level',
          count: 2,
          label: '2 visent un autre niveau',
          scholarships: [
            { id: 'eiffel', name: 'Bourse eiffel' },
            { id: 'uwc_kenya', name: 'Bourse uwc_kenya' },
          ],
        },
      ],
      notAnalyzedCount: 1,
      notAnalyzedLabel: '1 bourse récente pas encore analysée par KPB',
    });

    // Invariant : aucun libellé KPB avec « % » ou « chance » — la citation
    // officielle, elle, peut citer « 70 % ».
    for (const label of kpbLabels(response)) expect(isHonestLabel(label)).toBe(true);
    expect(ielts.toVerify[0].official?.text).toContain('%');
  });

  it('rend en anglais quand lang=en', async () => {
    const { service } = setup({ profile: { scholarshipProfileConfirmedAt: NOW } });

    const { run } = ok(await service.createRun(USER, { lang: 'en' }));

    expect(run.items[0].reasons.map((reason) => reason.label)).toContain('Bachelor level accepted');
    expect(run.excludedSummary.groups[0].label).toBe('2 are for another level');
    expect(run.items[0].name).toBe('bach-01 scholarship');
  });

  it('niveau peu couvert : texte guidé par le catalogue', async () => {
    const { service } = setup({ profile: { scholarshipProfileConfirmedAt: NOW } });

    const { run } = ok(await service.createRun(USER, {}));

    expect(run.levelCatalog).toEqual({
      level: 'bachelor',
      count: 3,
      label: '3 bourses en Licence dans notre catalogue pour l’instant',
    });
  });

  it('garde un `inputsSummary` minimisé : ni nationalité, ni date de naissance, ni moyenne', async () => {
    const { db, service } = setup({ profile: { scholarshipProfileConfirmedAt: NOW } });

    await service.createRun(USER, {});

    const [stored] = db.runsOf(USER);
    const summary = JSON.stringify(stored.inputsSummary);
    expect(summary).not.toMatch(/ner|2006|12_14|b1/);
    expect(stored.inputsSummary).toMatchObject({
      targetLevel: 'bachelor',
      fieldCount: 1,
      confirmed: true,
    });
    expect(stored).toMatchObject({ algorithmVersion: 'sm-1', trigger: 'other' });
  });

  it('élague aux 5 derniers runs, dans la même transaction', async () => {
    const { db, clock, service } = setup({ profile: { scholarshipProfileConfirmedAt: NOW } });

    const created: string[] = [];
    for (let i = 0; i < RUNS_KEPT + 2; i += 1) {
      clock.now = new Date(NOW.getTime() + i * 1_000);
      const { run } = ok(await service.createRun(USER, { trigger: 'rerun' }));
      created.push(run.id);
    }

    expect(db.runsOf(USER).map((run) => run.id)).toEqual(created.slice(-RUNS_KEPT).reverse());
  });

  it('diff : rien de « nouveau » au premier run, puis ajouts et retraits', async () => {
    const { db, clock, service } = setup({ profile: { scholarshipProfileConfirmedAt: NOW } });

    const first = ok(await service.createRun(USER, {}));
    expect(first.diff).toEqual({ previousRunId: null, addedIds: [], removedIds: [] });
    expect(first.run.items.every((item) => !item.isNew)).toBe(true);

    db.scholarships = [
      ...smallCatalog().filter((row) => row.id !== 'bach-02'),
      candidateRow(makeScholarship({ id: 'bach-new', eligibleLevels: ['bachelor'] })),
    ];
    clock.now = new Date(NOW.getTime() + 61_000);

    const second = ok(await service.createRun(USER, { trigger: 'stale_refresh' }));
    expect(second.diff).toEqual({
      previousRunId: first.run.id,
      addedIds: ['bach-new'],
      removedIds: ['bach-02'],
    });
    expect(second.run.items.find((item) => item.scholarshipId === 'bach-new')?.isNew).toBe(true);
    expect(second.run.items.find((item) => item.scholarshipId === 'bach-01')?.isNew).toBe(false);
  });

  it('un mineur sans accord : l’accord donné dans le test est horodaté par le serveur', async () => {
    const { db, service } = setup({
      profile: { birthDate: new Date('2009-06-01T00:00:00.000Z'), scholarshipTargetLevel: 'secondary' },
    });

    const before = await service.createRun(USER, { confirm: true });
    expect(before).toMatchObject({
      status: 'profile_incomplete',
      readiness: { required: ['guardianConsent'] },
    });

    ok(
      await service.createRun(USER, {
        confirm: true,
        answers: { guardianConsent: true, guardianName: 'Mariama', guardianContact: '+227 90 00 00 00' },
      }),
    );
    expect(db.profile(USER)).toMatchObject({
      guardianConsentedAt: NOW,
      guardianName: 'Mariama',
      scholarshipProfileConfirmedAt: NOW,
    });
  });
});

describe('ScholarshipMatchService.createRun — atomicité réponses + run', () => {
  class FailingRunService extends ScholarshipMatchService {
    protected override async persistRun(
      tx: Prisma.TransactionClient,
      data: Prisma.ScholarshipMatchRunUncheckedCreateInput,
    ) {
      const row = await super.persistRun(tx, data);
      // Le run est écrit, PUIS l'écriture échoue : tout doit être annulé.
      if (row) throw new Error('disk full');
      return row;
    }
  }

  it('un run qui échoue annule les réponses ET la confirmation', async () => {
    const { db, snapshots } = setup();
    const failing = new FailingRunService(db.prismaService, snapshots, () => NOW);

    await expect(
      failing.createRun(USER, { confirm: true, answers: { englishLevel: 'c1_c2', gradeBandOn20: '16_plus' } }),
    ).rejects.toThrow('disk full');

    expect(db.profile(USER)).toMatchObject({
      englishLevel: 'b1',
      gradeBandOn20: '12_14',
      languageLevel: 'Intermediate',
      gradeRange: '12 - 14/20',
      scholarshipProfileConfirmedAt: null,
    });
    expect(db.runsOf(USER)).toEqual([]);
  });
});

describe('ScholarshipMatchService.state', () => {
  it('sans run : préparation, suggestions, listes servies, taille du catalogue', async () => {
    const { service } = setup({ profile: { nationalityCode: null } });

    const state = await service.state(USER, 'fr');

    expect(state.latestRun).toBeNull();
    expect(state.isStale).toBe(false);
    expect(state.staleReasons).toEqual([]);
    expect(state.catalogSize).toBe(6);
    expect(state.alertsOptIn).toBe(false);
    expect(state.readiness.required).toEqual(['nationalityCode']);
    // « Tu vis au Niger — nationalité nigérienne ? »
    expect(state.prefill).toContainEqual(
      expect.objectContaining({ key: 'nationalityCode', value: 'ner', ambiguous: true }),
    );
    expect(state.answers).toMatchObject({ residence: 'ner', birthDate: '2006-05-10', confirmedAt: null });
    expect(state.options.countries[0]).toEqual({ code: 'ner', name: 'Niger', priority: true });
    expect(state.options.destinations.map((d) => d.id).sort()).toEqual(['can', 'fra', 'gbr', 'ken']);
    expect(state.options.fields.map((f) => f.id)).toEqual(
      Array.from({ length: 12 }, (_, i) => `d${String(i + 1).padStart(2, '0')}`),
    );
    expect(state.options.version).toMatch(/^[0-9a-f]{16}$/);
  });

  it('le dernier run, puis « périmé » quand le profil ou le catalogue change', async () => {
    const { db, clock, service } = setup({ profile: { scholarshipProfileConfirmedAt: NOW } });
    const created = ok(await service.createRun(USER, { lang: 'fr' }));

    const fresh = await service.state(USER, 'fr');
    expect(fresh.latestRun).toEqual(created.run);
    expect(fresh.isStale).toBe(false);

    db.profile(USER)!.englishLevel = 'b2';
    expect((await service.state(USER, 'fr')).staleReasons).toEqual(['profile']);

    db.scholarships = smallCatalog().filter((row) => row.id !== 'bach-02');
    clock.now = new Date(NOW.getTime() + 61_000);
    const stale = await service.state(USER, 'fr');
    expect(stale.staleReasons).toEqual(['profile', 'catalog']);
    expect(stale.isStale).toBe(true);
    // Une bourse retirée du catalogue public reste listée, grisée.
    expect(stale.latestRun?.items.find((item) => item.scholarshipId === 'bach-02')).toMatchObject({
      available: false,
      name: 'Bourse bach-02',
      scholarship: null,
      window: null,
    });
  });

  it('lit le catalogue au plus une fois par minute', async () => {
    const { db, clock, service } = setup();

    await service.state(USER, 'fr');
    await service.state(USER, 'en');
    expect(db.scholarshipReads).toBe(1);

    clock.now = new Date(NOW.getTime() + 61_000);
    await service.state(USER, 'fr');
    expect(db.scholarshipReads).toBe(2);
  });
});

describe('ScholarshipMatchService.setAlerts', () => {
  it('pose l’opt-in, garde sa date d’origine, l’efface', async () => {
    const { db, clock, service } = setup();

    await expect(service.setAlerts(USER, true)).resolves.toEqual({
      enabled: true,
      optedInAt: NOW.toISOString(),
    });
    clock.now = new Date(NOW.getTime() + 86_400_000);
    await expect(service.setAlerts(USER, true)).resolves.toEqual({
      enabled: true,
      optedInAt: NOW.toISOString(),
    });
    await expect(service.setAlerts(USER, false)).resolves.toEqual({ enabled: false, optedInAt: null });
    expect(db.profile(USER)?.scholarshipMatchAlertsOptInAt).toBeNull();
  });
});

// Une condition que KPB n'a pas pu typer (« other ») ne fait jamais sortir une
// bourse : elle devient un point « à vérifier », citation officielle à l'appui.
describe('ScholarshipMatchService — condition particulière', () => {
  it('une condition « other » souple donne « à vérifier », jamais une exclusion', async () => {
    const { service } = setup({
      profile: { scholarshipProfileConfirmedAt: NOW },
      catalog: [
        candidateRow(
          makeScholarship({ id: 'other', eligibleLevels: ['bachelor'], eligibilityCriteria: [other('cond')] }),
        ),
      ],
    });

    const { run } = ok(await service.createRun(USER, {}));

    expect(run.items).toEqual([
      expect.objectContaining({ scholarshipId: 'other', status: 'to_verify' }),
    ]);
    expect(run.items[0].toVerify[0]).toMatchObject({
      code: 'condition_other',
      official: { text: 'Texte officiel.', sourceUrl: 'https://example.org/eligibility' },
    });
  });
});
