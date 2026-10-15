import type { PrismaService } from '../prisma/prisma.service';
import {
  buildCandidateSnapshot,
  CandidateSnapshotService,
  MAX_CANDIDATES,
  selectServedCycle,
  SNAPSHOT_TTL_MS,
  type CandidateCycleRow,
  type CandidateRow,
} from './candidate-snapshot';
import { candidateRow } from './testing/fake-match-db';
import { date, eiffel, makeScholarship, NOW, turkiye } from './testing/match-fixtures';

function cycle(overrides: Partial<CandidateCycleRow>): CandidateCycleRow {
  return {
    id: 'c',
    academicYear: '2027-2028',
    status: 'forecast',
    dateConfidence: 'estimated',
    opensAt: null,
    closesAt: null,
    estimatedOpenAt: null,
    estimatedCloseAt: null,
    ...overrides,
  };
}

describe('selectServedCycle — même règle que l’index public', () => {
  it('un cycle ouvert, sinon une prévision, sinon le plus récent', () => {
    const latest = cycle({ id: 'latest', academicYear: '2028-2029', status: 'closed' });
    const forecast = cycle({ id: 'forecast', academicYear: '2027-2028', status: 'forecast' });
    const open = cycle({ id: 'open', academicYear: '2026-2027', status: 'open' });
    expect(selectServedCycle([latest, forecast, open])?.id).toBe('open');
    expect(selectServedCycle([latest, forecast])?.id).toBe('forecast');
    expect(selectServedCycle([latest])?.id).toBe('latest');
    expect(selectServedCycle([])).toBeNull();
  });
});

describe('buildCandidateSnapshot', () => {
  const rows = (): CandidateRow[] => [candidateRow(eiffel()), candidateRow(turkiye())];

  it('passe au moteur le cycle servi et les niveaux connus seulement', () => {
    const row = candidateRow(makeScholarship({ id: 'x' }), {
      eligibleLevels: ['bachelor', 'postdoc'],
    });
    const snapshot = buildCandidateSnapshot([row], NOW);
    const candidate = snapshot.byId.get('x')!;
    expect(candidate.scholarship.eligibleLevels).toEqual(['bachelor']);
    expect(candidate.scholarship.cycle).toMatchObject({ id: 'cycle-1', status: 'open' });
    expect(candidate.display.academicYear).toBe('2027-2028');
    expect([...candidate.criteriaByKey.keys()]).toEqual(['autres-conditions']);
  });

  it('empreinte indépendante de l’ordre de lecture', () => {
    const a = buildCandidateSnapshot(rows(), NOW).catalogHash;
    const b = buildCandidateSnapshot(rows().reverse(), NOW).catalogHash;
    expect(a).toBe(b);
  });

  it('change avec ce que le moteur lit, pas avec un nom ou une description', () => {
    const base = buildCandidateSnapshot(rows(), NOW).catalogHash;

    const renamed = rows();
    renamed[0].nameFr = 'Eiffel (nouveau nom)';
    expect(buildCandidateSnapshot(renamed, NOW).catalogHash).toBe(base);

    const restamped = rows();
    restamped[0].eligibilityStructuredAt = date('2026-10-01');
    expect(buildCandidateSnapshot(restamped, NOW).catalogHash).not.toBe(base);

    const recycled = rows();
    recycled[1].cycles[0].estimatedCloseAt = date('2027-03-01');
    expect(buildCandidateSnapshot(recycled, NOW).catalogHash).not.toBe(base);

    expect(buildCandidateSnapshot(rows().slice(1), NOW).catalogHash).not.toBe(base);
  });
});

describe('CandidateSnapshotService — cache de 60 s', () => {
  function setup(rows: CandidateRow[] = [candidateRow(eiffel())]) {
    const calls: Array<Record<string, unknown>> = [];
    let now = NOW;
    const prisma = {
      isEnabled: true,
      execute: async (fn: (client: unknown) => Promise<unknown>) =>
        fn({
          scholarship: {
            findMany: async (args: Record<string, unknown>) => {
              calls.push(args);
              return rows;
            },
          },
        }),
    } as unknown as PrismaService;
    const service = new CandidateSnapshotService(prisma, () => now);
    return {
      service,
      calls,
      advance: (ms: number) => {
        now = new Date(now.getTime() + ms);
      },
    };
  }

  it('lit les seules fiches publiques, cycles les plus récents d’abord, au plus 500', async () => {
    const { service, calls } = setup();

    const snapshot = await service.get();

    expect(snapshot?.candidates).toHaveLength(1);
    expect(calls[0]).toMatchObject({
      where: {
        isActive: true,
        moderationStatus: 'approved',
        lastVerifiedAt: { not: null },
        OR: [{ deadlineAt: null }, { deadlineAt: { gte: NOW } }],
      },
      take: MAX_CANDIDATES,
      select: { cycles: { orderBy: { academicYear: 'desc' } } },
    });
  });

  it('une lecture par minute ; une seule en vol pour des appels simultanés', async () => {
    const { service, calls, advance } = setup();

    const [a, b] = await Promise.all([service.get(), service.get()]);
    expect(a).toBe(b);
    advance(SNAPSHOT_TTL_MS - 1);
    expect(await service.get()).toBe(a);
    expect(calls).toHaveLength(1);

    advance(1);
    const c = await service.get();
    expect(c).not.toBe(a);
    expect(calls).toHaveLength(2);

    service.invalidate();
    await service.get();
    expect(calls).toHaveLength(3);
  });

  it('readFresh (aperçu admin) : même requête, relue à chaque appel, sans toucher au cache', async () => {
    const { service, calls } = setup();

    const cached = await service.get();
    const fresh = await service.readFresh(NOW);
    expect(fresh).not.toBe(cached);
    expect(calls).toHaveLength(2);
    expect(calls[1]).toEqual(calls[0]);
    expect(fresh?.catalogHash).toBe(cached?.catalogHash);

    // Le cache de l'élève est intact : pas de nouvelle lecture.
    expect(await service.get()).toBe(cached);
    expect(calls).toHaveLength(2);
    await service.readFresh(NOW);
    expect(calls).toHaveLength(3);
  });

  it('signale le plafond atteint', async () => {
    const many = Array.from({ length: MAX_CANDIDATES }, (_, i) =>
      candidateRow(makeScholarship({ id: `s-${i}` })),
    );
    const { service } = setup(many);
    expect((await service.get())?.capped).toBe(true);
  });

  it('sans base : null, sans lecture', async () => {
    const prisma = {
      isEnabled: false,
      execute: async () => null,
    } as unknown as PrismaService;
    await expect(new CandidateSnapshotService(prisma, () => NOW).get()).resolves.toBeNull();
  });
});
