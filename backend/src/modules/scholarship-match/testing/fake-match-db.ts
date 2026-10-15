import type { PrismaService } from '../../prisma/prisma.service';
import type { MatchScholarship } from '../assess';
import type { CandidateRow } from '../candidate-snapshot';

/**
 * Une base en mémoire pour les specs du service et du contrôleur « Mes 10
 * bourses » : profils, runs et fiches candidates.
 *
 * `$transaction` est TRANSACTIONNELLE : le corps travaille sur une copie de
 * l'état, publiée seulement s'il aboutit. Une exception au milieu (run qui
 * échoue après l'écriture des réponses) ne laisse donc aucune trace — c'est ce
 * que l'atomicité réponses + run doit garantir, et ce que la spec PostgreSQL
 * prouve contre une vraie base.
 */

export type ProfileRecord = Record<string, unknown> & { id: string };

export interface RunRecord extends Record<string, unknown> {
  id: string;
  userId: string;
  createdAt: Date;
}

interface DbState {
  profiles: Map<string, ProfileRecord>;
  runs: RunRecord[];
}

type Where = Record<string, unknown>;

/**
 * Copie profonde qui garde les `Date` du domaine de la spec : `structuredClone`
 * rendrait des dates d'un autre domaine (vm de Jest), que `instanceof Date`
 * ne reconnaît plus.
 */
function clone<T>(value: T): T {
  if (value instanceof Date) return new Date(value.getTime()) as T;
  if (value instanceof Map) {
    return new Map([...value.entries()].map(([k, v]) => [k, clone(v)])) as T;
  }
  if (Array.isArray(value)) return value.map((item) => clone(item)) as T;
  if (value && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(value)) out[key] = clone(item);
    return out as T;
  }
  return value;
}

function byRunOrder(a: RunRecord, b: RunRecord): number {
  const time = b.createdAt.getTime() - a.createdAt.getTime();
  if (time !== 0) return time;
  return a.id < b.id ? 1 : a.id > b.id ? -1 : 0;
}

function selectFields<T extends Record<string, unknown>>(
  row: T,
  select?: Record<string, unknown>,
): Partial<T> {
  if (!select) return clone(row);
  const out: Record<string, unknown> = {};
  for (const key of Object.keys(select)) out[key] = clone(row[key]);
  return out as Partial<T>;
}

/** Une ligne candidate (comme lue par `CandidateSnapshotService`) depuis une fiche du moteur. */
export function candidateRow(
  s: MatchScholarship,
  display: Partial<CandidateRow> = {},
): CandidateRow {
  return {
    id: s.id,
    nameFr: `Bourse ${s.id}`,
    nameEn: `${s.id} scholarship`,
    countryId: s.countryId,
    countryNameFr: '',
    countryNameEn: '',
    typeOfFundingFr: 'Financement complet',
    typeOfFundingEn: 'Fully funded',
    levelEligibleFr: 'Licence',
    levelEligibleEn: 'Bachelor',
    deadlineLabelFr: 'Janvier',
    deadlineLabelEn: 'January',
    fundingType: s.fundingType,
    relatedFieldIds: [...s.relatedFieldIds],
    applicationUrl: `https://example.org/${s.id}/apply`,
    sourceUrl: `https://example.org/${s.id}`,
    deadlineAt: s.deadlineAt,
    eligibleLevels: [...s.eligibleLevels],
    fieldsScope: s.fieldsScope,
    eligibilityCriteria: s.eligibilityCriteria,
    eligibilityStructuredAt: s.eligibilityStructuredAt,
    cycles: s.cycle
      ? [
          {
            id: s.cycle.id,
            academicYear: '2027-2028',
            status: s.cycle.status,
            dateConfidence: s.cycle.dateConfidence,
            opensAt: s.cycle.opensAt,
            closesAt: s.cycle.closesAt,
            estimatedOpenAt: s.cycle.estimatedOpenAt,
            estimatedCloseAt: s.cycle.estimatedCloseAt,
          },
        ]
      : [],
    ...display,
  };
}

export class FakeMatchDb {
  state: DbState = { profiles: new Map(), runs: [] };
  scholarships: CandidateRow[] = [];
  scholarshipReads = 0;
  transactions = 0;
  private seq = 0;

  addProfile(profile: ProfileRecord): void {
    this.state.profiles.set(profile.id, clone(profile));
  }

  profile(id: string): ProfileRecord | undefined {
    return this.state.profiles.get(id);
  }

  runsOf(userId: string): RunRecord[] {
    return this.state.runs.filter((run) => run.userId === userId).sort(byRunOrder);
  }

  private client(state: DbState, inTransaction: boolean) {
    const runsFor = (where: Where) =>
      state.runs.filter((run) => run.userId === where.userId).sort(byRunOrder);
    const client = {
      userProfile: {
        findUnique: async (args: { where: { id: string }; select?: Record<string, unknown> }) => {
          const row = state.profiles.get(args.where.id);
          return row ? selectFields(row, args.select) : null;
        },
        update: async (args: { where: { id: string }; data: Record<string, unknown> }) => {
          const row = state.profiles.get(args.where.id);
          if (!row) throw Object.assign(new Error('Record not found'), { code: 'P2025' });
          Object.assign(row, clone(args.data));
          return clone(row);
        },
      },
      scholarshipMatchRun: {
        findMany: async (args: {
          where: Where;
          skip?: number;
          take?: number;
          select?: Record<string, unknown>;
        }) => {
          const rows = runsFor(args.where).slice(args.skip ?? 0);
          return (args.take !== undefined ? rows.slice(0, args.take) : rows).map((row) =>
            selectFields(row, args.select),
          );
        },
        findFirst: async (args: { where: Where; select?: Record<string, unknown> }) => {
          const row = runsFor(args.where)[0];
          return row ? selectFields(row, args.select) : null;
        },
        create: async (args: { data: Record<string, unknown> }) => {
          this.seq += 1;
          const row: RunRecord = {
            notifiedScholarshipIds: [],
            ...clone(args.data),
            id: `run-${String(this.seq).padStart(4, '0')}`,
            userId: args.data.userId as string,
            createdAt: (args.data.createdAt as Date | undefined) ?? new Date(),
          };
          state.runs.push(row);
          return clone(row);
        },
        deleteMany: async (args: { where: { id: { in: string[] } } }) => {
          const before = state.runs.length;
          state.runs = state.runs.filter((run) => !args.where.id.in.includes(run.id));
          return { count: before - state.runs.length };
        },
      },
      scholarship: {
        findMany: async () => {
          this.scholarshipReads += 1;
          return clone(this.scholarships);
        },
      },
      $transaction: async <T>(body: (tx: unknown) => Promise<T>): Promise<T> => {
        if (inTransaction) return body(client);
        this.transactions += 1;
        const draft: DbState = clone(this.state);
        const result = await body(this.client(draft, true));
        this.state = draft;
        return result;
      },
    };
    return client;
  }

  readonly prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: unknown) => Promise<T>) =>
      operation(this.client(this.state, false)),
  } as unknown as PrismaService;
}
