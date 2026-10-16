// ─────────────────────────────────────────────────────────────────────────────
// Admin catalogue CRUD (Chantier B).
//
// Lets the KPB team create / edit / delete formations (Program), universités
// (Institution), bourses (Scholarship), pays (Country) and filières (Field)
// from the web back-office — no more code deploys to change content.
//
// Follows the repo's established admin-content pattern (see notifications /
// admin-users services): bodies arrive as `Record<string, unknown>` and we map
// only the fields we recognise. The global ValidationPipe skips `Object`
// bodies, so this is safe and consistent.
//
// Program degree levels are normalised to clean canonical labels on write
// (mirror of Flutter `programLevelLabel`) so "B1"/"MSc · Bac+5" never re-enter
// the catalogue.
// ─────────────────────────────────────────────────────────────────────────────

import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';

import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
} from '../../common/eef-provenance';
import type { AdminSessionUser } from '../auth/auth.service';
import {
  OFFERING_RHYTHMS,
  OFFERING_SESSIONS,
  type OfferingRhythm,
  type OfferingSession,
} from '../catalog/campus-offerings';
import { programSearchText } from '../etudes-en-france/catalog/eef-search-text';
import { PrismaService } from '../prisma/prisma.service';
import {
  ELIGIBILITY_AUDIT_ENTITY_TYPE,
  ELIGIBILITY_AUDIT_PURPOSE,
  EMPTY_ELIGIBILITY_STATE,
  hasEligibilityInput,
  pickEligibilityWrite,
  planEligibilityUpdate,
  type EligibilityPlan,
} from './scholarship-eligibility-admin';
import {
  capFairly,
  compareVerificationItems,
  countryVerificationDueWhere,
  institutionVerificationDueWhere,
  programVerificationDueWhere,
  scholarshipVerificationDueWhere,
} from './verification-due';

/// Clean canonical degree label. Mirror of the Flutter referential.
function normalizeDegreeLevel(raw: string): string {
  const s = (raw ?? '').toLowerCase();
  if (s.includes('doctorat') || s.includes('phd') || s.includes('bac+8')) {
    return 'Doctorat';
  }
  if (s.includes('mba') || s.includes('dba')) return 'MBA / DBA';
  if (
    s.includes('bac+5') || s.includes('bac +5') || s.includes('master') ||
    s.includes('msc') || s.includes('pge') || s.includes('grande ecole') ||
    s.includes('grande école') || s.includes('mastere') || s.includes('visa')
  ) {
    return 'Master';
  }
  if (s.includes('bba') || s.includes('bac+4') || s.includes('bac +4')) {
    return 'BBA';
  }
  if (
    s.includes('bac+3') || s.includes('bac +3') || s.includes('bachelor') ||
    s.includes('licence')
  ) {
    return 'Bachelor';
  }
  if (s.includes('bac+2') || s.includes('bac +2')) return 'Bac+2';
  return (raw ?? '').trim();
}

const DAY_MS = 24 * 60 * 60 * 1000;

// Exported so the reports dashboard can count due items with the SAME
// cadences as the verification queue (single source of truth).
export const VERIFICATION_POLICIES = {
  countryVisa: {
    key: 'country_visa',
    label: 'Pays: visa, couts et difficulte admission',
    cadenceDays: 30,
    owner: 'Amina KPB',
  },
  institutionScolarite: {
    key: 'institution_scolarite',
    label: 'Etablissements: frais, niveaux et exigences',
    cadenceDays: 180,
    owner: 'Fatou Admin',
  },
  programScolarite: {
    key: 'program_scolarite',
    label: 'Formations: frais, duree, langue et prerequis',
    cadenceDays: 180,
    owner: 'Fatou Admin',
  },
  scholarshipDeadline: {
    key: 'scholarship_deadline',
    label: 'Bourses: deadlines, financement et eligibilite',
    cadenceDays: 30,
    owner: 'Amina KPB',
  },
} as const;

type VerificationPolicyName = keyof typeof VERIFICATION_POLICIES;
type VerificationEntity = 'country' | 'institution' | 'program' | 'scholarship';

/// Nombre maximal d'éléments que la file de revérification RENVOIE à la page
/// admin. Elle est triée « jamais vérifié d'abord, puis le plus ancien » : ce
/// que le plafond garde est donc ce qui presse le plus.
///
/// Ce n'est pas de la prudence abstraite. La page rend un champ de saisie et
/// deux boutons par ligne, sur une réponse qui n'avait aucune borne : le jour où
/// des milliers de lignes reviennent à échéance ensemble — un lot publié en une
/// fois, dont la cadence de 180 jours tombe le même matin — la page qui sert
/// aussi à revérifier les BOURSES cesse de s'ouvrir. Le plafond borne la
/// réponse ; `total` et `truncated` disent honnêtement qu'il en reste, et le SLA
/// compte sur la file COMPLÈTE, jamais sur celle-ci.
export const VERIFICATION_QUEUE_LIMIT = 500;

interface VerificationSlaCategory {
  label: string;
  cadenceDays: number;
  overdue: number;
  neverVerified: number;
  oldestDays: number | null;
}

/// Aggregate freshness view over the verification queue (KPB-161).
export interface VerificationSlaSummary {
  generatedAt: Date;
  totalOverdue: number;
  neverVerified: number;
  byCategory: Record<string, VerificationSlaCategory>;
}

@Injectable()
export class AdminCatalogService {
  private readonly logger = new Logger(AdminCatalogService.name);

  constructor(private readonly prisma: PrismaService) {}

  private assertDb() {
    if (!this.prisma.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  // ── small typed pickers ───────────────────────────────────────────────────
  private str(v: unknown): string | undefined {
    return typeof v === 'string' ? v : undefined;
  }

  private nonEmptyStr(v: unknown): string | undefined {
    const value = this.str(v)?.trim();
    return value ? value : undefined;
  }

  private strArr(v: unknown): string[] | undefined {
    if (!Array.isArray(v)) return undefined;
    return v.filter((x): x is string => typeof x === 'string');
  }

  private bool(v: unknown): boolean | undefined {
    return typeof v === 'boolean' ? v : undefined;
  }

  private int(v: unknown): number | undefined {
    return typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : undefined;
  }

  private enumVal<T extends string>(v: unknown, allowed: readonly T[]): T | undefined {
    return typeof v === 'string' && (allowed as readonly string[]).includes(v)
      ? (v as T)
      : undefined;
  }

  private requireStr(input: Record<string, unknown>, key: string): string {
    const v = this.str(input[key]);
    if (v == null || v.trim() === '') {
      throw new BadRequestException(`Field "${key}" is required.`);
    }
    return v;
  }

  // ── strict pickers for the match-scoring columns ──────────────────────────
  //
  // These deliberately BREAK the tolerant "drop what we don't recognise" style
  // used above. `minGpaRequired`, `tuitionMinEur`, `applicationDeadline`,
  // `teachingLanguages` and `campusOfferings` feed the admission-probability
  // score (matches.service.ts) — a silently dropped value ships a program that
  // scores as a permanent `isEstimate` with nobody the wiser. A present-but-
  // wrong value must therefore fail loudly; an ABSENT key still means "leave
  // untouched", and an explicit `null` means "clear this column".

  private numOrNullAt(v: unknown, path: string): number | null {
    if (v == null) return null;
    if (typeof v !== 'number' || !Number.isFinite(v)) {
      throw new BadRequestException(`"${path}" must be a finite number or null.`);
    }
    return v;
  }

  private pickNumOrNull(
    input: Record<string, unknown>,
    key: string,
    opts: { int?: boolean } = {},
  ): number | null | undefined {
    const v = input[key];
    if (v === undefined) return undefined;
    if (v === null) return null;
    const n = this.numOrNullAt(v, key);
    return n != null && opts.int ? Math.trunc(n) : n;
  }

  /// Strict ISO-8601. `new Date(str)` is NOT good enough here: it accepts
  /// `03/01/2027` and `1 mars 2027` (parsed as LOCAL time, so they land on the
  /// previous day in UTC), and it rolls `2027-02-30` over to March 2nd. A typo
  /// would become a valid, wrong deadline — the exact silent corruption these
  /// pickers exist to prevent. A date-time must carry an explicit offset,
  /// otherwise JS reads it as local time and the stored instant depends on the
  /// server's timezone.
  private static readonly ISO_DATE_ONLY = /^(\d{4})-(\d{2})-(\d{2})$/;
  private static readonly ISO_DATE_TIME =
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,3})?)?(?:Z|[+-]\d{2}:\d{2})$/;

  private isRealCalendarDate(y: number, m: number, d: number): boolean {
    if (m < 1 || m > 12 || d < 1) return false;
    const leap = (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
    const lengths = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return d <= lengths[m - 1];
  }

  private pickDateOrNull(
    input: Record<string, unknown>,
    key: string,
  ): Date | null | undefined {
    const v = input[key];
    if (v === undefined) return undefined;
    if (v === null) return null;

    if (v instanceof Date) {
      if (Number.isNaN(v.getTime())) {
        throw new BadRequestException(`Field "${key}" is an invalid Date.`);
      }
      return v;
    }

    const raw = this.nonEmptyStr(v);
    const m =
      raw == null
        ? null
        : (AdminCatalogService.ISO_DATE_ONLY.exec(raw) ??
          AdminCatalogService.ISO_DATE_TIME.exec(raw));
    if (m == null) {
      throw new BadRequestException(
        `Field "${key}" must be ISO-8601 — "YYYY-MM-DD", or "YYYY-MM-DDTHH:mm:ssZ" ` +
          `with an explicit UTC offset — or null.`,
      );
    }
    if (
      !this.isRealCalendarDate(Number(m[1]), Number(m[2]), Number(m[3]))
    ) {
      throw new BadRequestException(
        `Field "${key}": "${raw}" is not a real calendar date.`,
      );
    }
    const parsed = new Date(raw as string);
    if (Number.isNaN(parsed.getTime())) {
      throw new BadRequestException(`Field "${key}": "${raw}" is unparseable.`);
    }
    return parsed;
  }

  /// Texte facultatif : absent = inchangé, `null` ou chaîne vide = effacé.
  private pickNullableStr(
    input: Record<string, unknown>,
    key: string,
  ): string | null | undefined {
    const v = input[key];
    if (v === undefined) return undefined;
    if (v === null) return null;
    if (typeof v !== 'string') {
      throw new BadRequestException(`Field "${key}" must be a string or null.`);
    }
    return v.trim() || null;
  }

  private pickStrArr(
    input: Record<string, unknown>,
    key: string,
  ): string[] | undefined {
    const v = input[key];
    if (v === undefined) return undefined;
    // `String[]` is not nullable, so "clear" means an empty array. Returning
    // `undefined` here would let clean() drop the key and silently keep the old
    // value — breaking the explicit-null-clears contract documented above for
    // the other four scoring columns.
    if (v === null) return [];
    if (!Array.isArray(v) || v.some((x) => typeof x !== 'string')) {
      throw new BadRequestException(
        `Field "${key}" must be an array of strings.`,
      );
    }
    return (v as string[]).map((x) => x.trim()).filter(Boolean);
  }

  /// Multi-campus offerings. Shape is pinned by the `Program.campusOfferings`
  /// schema comment: [{ campus, tuitionUpfront, tuitionInstallments, intake,
  /// session?, rhythm? }]. Unknown keys are dropped so a malformed payload
  /// can't reshape the column.
  ///
  /// `session` et `rhythm` sont GARDÉS quand ils portent une valeur connue :
  /// les perdre à la première retouche dans l'admin effacerait le libellé
  /// « Rentrée décalée » de l'app, et l'import de printemps (qui reconnaît une
  /// offre déjà là à sa session) la croirait absente.
  ///
  /// `rolledFromIntake` (date « jj/mm/aaaa ») et `intakeEstimated: true` —
  /// rentrée d'automne 2026 reconduite en 2027 (omnes-fall-roll.ts) — sont
  /// gardés aussi : l'app en tire « Date reconduite de 2026, à confirmer ».
  /// Une date CONFIRMÉE par l'école s'écrit sans eux.
  private pickCampusOfferings(
    input: Record<string, unknown>,
    key: string,
  ): Prisma.InputJsonValue | typeof Prisma.DbNull | undefined {
    const v = input[key];
    if (v === undefined) return undefined;
    if (v === null) return Prisma.DbNull;
    if (!Array.isArray(v)) {
      throw new BadRequestException(`Field "${key}" must be an array or null.`);
    }
    return v.map((raw, i) => {
      if (raw == null || typeof raw !== 'object' || Array.isArray(raw)) {
        throw new BadRequestException(`"${key}[${i}]" must be an object.`);
      }
      const row = raw as Record<string, unknown>;
      const campus = this.nonEmptyStr(row.campus);
      if (!campus) {
        throw new BadRequestException(`"${key}[${i}].campus" is required.`);
      }
      return {
        campus,
        tuitionUpfront: this.numOrNullAt(
          row.tuitionUpfront,
          `${key}[${i}].tuitionUpfront`,
        ),
        tuitionInstallments: this.numOrNullAt(
          row.tuitionInstallments,
          `${key}[${i}].tuitionInstallments`,
        ),
        intake: this.nonEmptyStr(row.intake) ?? null,
        ...(OFFERING_SESSIONS.includes(row.session as OfferingSession)
          ? { session: row.session as OfferingSession }
          : {}),
        ...(OFFERING_RHYTHMS.includes(row.rhythm as OfferingRhythm)
          ? { rhythm: row.rhythm as OfferingRhythm }
          : {}),
        ...(typeof row.rolledFromIntake === 'string' &&
        /^\d{1,2}\/\d{1,2}\/\d{4}( · \d{1,2}\/\d{1,2}\/\d{4})*$/.test(row.rolledFromIntake)
          ? { rolledFromIntake: row.rolledFromIntake }
          : {}),
        ...(row.intakeEstimated === true ? { intakeEstimated: true } : {}),
      };
    }) as Prisma.InputJsonValue;
  }

  /// Drop undefined keys so we only update what was provided.
  private clean<T extends Record<string, unknown>>(obj: T): T {
    return Object.fromEntries(
      Object.entries(obj).filter(([, v]) => v !== undefined),
    ) as T;
  }

  private verificationData(
    verified: boolean,
    sourceUrl?: unknown,
    verifier?: AdminSessionUser,
  ) {
    const srcStr = this.nonEmptyStr(sourceUrl);
    return this.clean({
      lastVerifiedAt: verified ? new Date() : null,
      verifiedById: verified ? (verifier?.id ?? 'system') : null,
      verifiedByName: verified
        ? (verifier?.fullName ?? verifier?.email ?? 'System verification')
        : null,
      ...(srcStr !== undefined ? { sourceUrl: srcStr } : {}),
    });
  }

  private buildVerificationItem(input: {
    policy: VerificationPolicyName;
    entityType: VerificationEntity;
    id: string;
    label: string;
    context?: string | null;
    lastVerifiedAt?: Date | null;
    verifiedByName?: string | null;
    sourceUrl?: string | null;
    now: Date;
  }) {
    const policy = VERIFICATION_POLICIES[input.policy];
    const dueAt = input.lastVerifiedAt
      ? new Date(input.lastVerifiedAt.getTime() + policy.cadenceDays * DAY_MS)
      : null;
    const daysSinceVerification = input.lastVerifiedAt
      ? Math.floor((input.now.getTime() - input.lastVerifiedAt.getTime()) / DAY_MS)
      : null;
    return {
      entityType: input.entityType,
      id: input.id,
      label: input.label,
      context: input.context ?? null,
      category: policy.key,
      categoryLabel: policy.label,
      cadenceDays: policy.cadenceDays,
      owner: policy.owner,
      lastVerifiedAt: input.lastVerifiedAt ?? null,
      verifiedByName: input.verifiedByName ?? null,
      sourceUrl: input.sourceUrl ?? null,
      dueAt,
      daysSinceVerification,
      isOverdue: dueAt == null || dueAt.getTime() <= input.now.getTime(),
    };
  }

  // ════════════════════════════════════════════════════════════════════════
  // VERIFICATION (data-trust signal)
  // ════════════════════════════════════════════════════════════════════════

  /// Stamp (or clear) the data-trust signal on a catalog entity. When
  /// `verified` is true, `lastVerifiedAt` is set server-side to now; an optional
  /// `sourceUrl` records where the facts were confirmed. `verified: false`
  /// clears the stamp (back to "À confirmer").
  async setVerification(
    entity: string,
    id: string,
    verified: boolean,
    sourceUrl?: unknown,
    verifier?: AdminSessionUser,
  ) {
    this.assertDb();
    const data = this.verificationData(verified, sourceUrl, verifier);
    switch (entity) {
      case 'program':
        return this.runUpdate(
          () => this.prisma.execute((db) => db.program.update({ where: { id }, data })),
          'Program',
          id,
        );
      case 'institution':
        return this.runUpdate(
          () => this.prisma.execute((db) => db.institution.update({ where: { id }, data })),
          'Institution',
          id,
        );
      case 'country':
        return this.runUpdate(
          () => this.prisma.execute((db) => db.country.update({ where: { id }, data })),
          'Country',
          id,
        );
      case 'scholarship':
        return this.runUpdate(
          () => this.prisma.execute((db) => db.scholarship.update({ where: { id }, data })),
          'Scholarship',
          id,
        );
      default:
        throw new BadRequestException(`Unknown catalog entity "${entity}".`);
    }
  }

  /// La file de revérification telle que l'ADMIN la reçoit : les éléments les
  /// plus urgents d'abord, au plus [VERIFICATION_QUEUE_LIMIT], SANS qu'une
  /// catégorie n'en chasse une autre (`capFairly`). `total` est le compte COMPLET
  /// et `truncated` dit s'il en reste : une page qui n'en montre que la moitié
  /// sans l'écrire ferait croire que la file est vide de l'autre.
  async listVerificationDue() {
    const { items, policies } = await this.collectVerificationDue();
    return {
      items: capFairly(items, VERIFICATION_QUEUE_LIMIT),
      total: items.length,
      truncated: items.length > VERIFICATION_QUEUE_LIMIT,
      policies,
    };
  }

  /// La file COMPLÈTE, triée. C'est d'elle que le SLA compte : un SLA calculé
  /// sur la version plafonnée annoncerait « 500 en retard » quand il y en a
  /// dix mille.
  private async collectVerificationDue(now = new Date()) {
    this.assertDb();
    const result = await this.prisma.execute((db) =>
      db.$transaction([
        // Les `orderBy` ne décident PAS de l'ordre de la file (le tri se fait en
        // mémoire, `compareVerificationItems`) : ils la rendent déterministe et
        // disent la même chose. Postgres range les NULL en DERNIER en tri
        // croissant — sans `nulls: 'first'`, un futur `take:` ajouté pour économiser
        // la mémoire couperait justement les jamais-vérifiés.
        db.country.findMany({
          where: countryVerificationDueWhere(
            VERIFICATION_POLICIES.countryVisa.cadenceDays,
            now,
          ),
          orderBy: [
            { lastVerifiedAt: { sort: 'asc', nulls: 'first' } },
            { displayOrder: 'asc' },
            { id: 'asc' },
          ],
          select: {
            id: true,
            nameFr: true,
            nameEn: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            sourceUrl: true,
          },
        }),
        db.institution.findMany({
          where: institutionVerificationDueWhere(
            VERIFICATION_POLICIES.institutionScolarite.cadenceDays,
            now,
          ),
          orderBy: [
            { lastVerifiedAt: { sort: 'asc', nulls: 'first' } },
            { nameFr: 'asc' },
            { id: 'asc' },
          ],
          select: {
            id: true,
            nameFr: true,
            nameEn: true,
            countryId: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            sourceUrl: true,
          },
        }),
        db.program.findMany({
          where: programVerificationDueWhere(
            VERIFICATION_POLICIES.programScolarite.cadenceDays,
            now,
          ),
          orderBy: [
            { lastVerifiedAt: { sort: 'asc', nulls: 'first' } },
            { nameFr: 'asc' },
            { id: 'asc' },
          ],
          select: {
            id: true,
            nameFr: true,
            nameEn: true,
            countryId: true,
            institutionId: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            sourceUrl: true,
          },
        }),
        db.scholarship.findMany({
          where: scholarshipVerificationDueWhere(
            VERIFICATION_POLICIES.scholarshipDeadline.cadenceDays,
            now,
          ),
          orderBy: [
            { lastVerifiedAt: { sort: 'asc', nulls: 'first' } },
            { deadlineAt: 'asc' },
            { id: 'asc' },
          ],
          select: {
            id: true,
            nameFr: true,
            nameEn: true,
            countryId: true,
            deadlineLabelFr: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            sourceUrl: true,
          },
        }),
      ]),
    );

    const [countries, institutions, programs, scholarships] =
      result ?? [[], [], [], []];
    const items = [
      ...countries.map((row) =>
        this.buildVerificationItem({
          policy: 'countryVisa',
          entityType: 'country',
          id: row.id,
          label: row.nameFr || row.nameEn,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          sourceUrl: row.sourceUrl,
          now,
        }),
      ),
      ...institutions.map((row) =>
        this.buildVerificationItem({
          policy: 'institutionScolarite',
          entityType: 'institution',
          id: row.id,
          label: row.nameFr || row.nameEn,
          context: row.countryId,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          sourceUrl: row.sourceUrl,
          now,
        }),
      ),
      ...programs.map((row) =>
        this.buildVerificationItem({
          policy: 'programScolarite',
          entityType: 'program',
          id: row.id,
          label: row.nameFr || row.nameEn,
          context: `${row.countryId} / ${row.institutionId}`,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          sourceUrl: row.sourceUrl,
          now,
        }),
      ),
      ...scholarships.map((row) =>
        this.buildVerificationItem({
          policy: 'scholarshipDeadline',
          entityType: 'scholarship',
          id: row.id,
          label: row.nameFr || row.nameEn,
          context: row.deadlineLabelFr || row.countryId,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          sourceUrl: row.sourceUrl,
          now,
        }),
      ),
    ].sort(compareVerificationItems);

    return { items, policies: Object.values(VERIFICATION_POLICIES) };
  }

  /// Aggregate the verification queue into an SLA view: how many catalog items
  /// are overdue (past their per-category cadence), split by category, with the
  /// oldest age and the count never verified. Derived from the same source as
  /// the admin queue, so counts always match what admins see.
  async verificationSlaSummary(now = new Date()): Promise<VerificationSlaSummary> {
    // La file COMPLÈTE, pas celle que la page reçoit : un SLA calculé sur la
    // version plafonnée annoncerait « 500 en retard » quand il y en a dix mille.
    const { items } = await this.collectVerificationDue(now);
    const byCategory: Record<string, VerificationSlaCategory> = {};
    for (const policy of Object.values(VERIFICATION_POLICIES)) {
      byCategory[policy.key] = {
        label: policy.label,
        cadenceDays: policy.cadenceDays,
        overdue: 0,
        neverVerified: 0,
        oldestDays: null,
      };
    }
    for (const item of items) {
      const cat = byCategory[item.category];
      if (!cat) continue;
      cat.overdue += 1;
      if (item.lastVerifiedAt == null) {
        cat.neverVerified += 1;
      } else if (item.daysSinceVerification != null) {
        cat.oldestDays = Math.max(
          cat.oldestDays ?? 0,
          item.daysSinceVerification,
        );
      }
    }
    return {
      generatedAt: now,
      totalOverdue: items.length,
      neverVerified: Object.values(byCategory).reduce(
        (n, c) => n + c.neverVerified,
        0,
      ),
      byCategory,
    };
  }

  /// Daily ops signal (KPB-161): a WARN when catalog data has drifted past its
  /// freshness cadence, so stale deadlines / costs get re-verified before they
  /// mislead a student. Stdout is the only alert channel today; wiring it to a
  /// real alerting sink is a follow-up (KPB-167 observability).
  @Cron('0 7 * * *')
  async checkVerificationSla(): Promise<void> {
    if (!this.prisma.isEnabled) return;
    try {
      const sla = await this.verificationSlaSummary();
      if (sla.totalOverdue === 0) {
        this.logger.log('Catalog freshness OK — nothing past its cadence.');
        return;
      }
      const breakdown = Object.entries(sla.byCategory)
        .filter(([, c]) => c.overdue > 0)
        .map(([key, c]) => {
          const never = c.neverVerified
            ? ` (${c.neverVerified} never verified)`
            : '';
          const oldest = c.oldestDays != null ? `, +${c.oldestDays}d` : '';
          return `${key}=${c.overdue}${never}${oldest}`;
        })
        .join('; ');
      this.logger.warn(
        `Catalog freshness SLA breach: ${sla.totalOverdue} item(s) overdue — ${breakdown}. Re-verify in the admin queue.`,
      );
    } catch (error) {
      this.logger.error(
        `Verification SLA check failed (${error instanceof Error ? error.message : 'unknown'}).`,
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // PROGRAMS (formations)
  // ════════════════════════════════════════════════════════════════════════
  /// Maintient `Institution.programIds`, liste dénormalisée que l'APP LIT.
  ///
  /// Six écrans en dépendent : le nombre de formations affiché
  /// (`explore_screen.dart:989`), l'aperçu des trois premières (:1607), la
  /// navigation depuis une fiche pays — DÉSACTIVÉE quand la liste est vide
  /// (`country_detail_screen.dart:241`) —, le comparateur qui compte et trie
  /// dessus, la première formation du profil, et le filtrage de la recherche.
  ///
  /// Rien en base ne lie cette liste aux lignes `Program` : elle doit être
  /// entretenue à la main, sinon une formation existe sans être atteignable.
  /// C'est ce qui est arrivé aux 46 formations de Mundiapolis, créées par
  /// l'import du 16/09 avec une liste vide.
  private async syncInstitutionProgramIds(institutionId: string) {
    const ids = (
      await this.prisma.execute((db) =>
        db.program.findMany({
          where: { institutionId },
          select: { id: true },
          orderBy: { id: 'asc' },
        }),
      )
    )?.map((p) => p.id);
    if (ids == null) return;
    await this.prisma.execute((db) =>
      db.institution.updateMany({
        where: { id: institutionId },
        data: { programIds: ids },
      }),
    );
  }

  /**
   * Les lignes de l'import « Études en France » ne se publient PAS par les routes
   * génériques.
   *
   * Elles ont leur porte — `admin/etudes-en-france/publication` — qui vérifie la
   * source, la procédure et le domaine, demande de confirmer le nombre et signe du
   * nom de l'administrateur connecté. `content_manager` a accès à ces routes-ci et
   * pas à celle-là : si `PATCH { isActive: true }` acceptait aussi une ligne de
   * l'import, la porte gardée ne garderait rien.
   *
   * Une ligne est de l'import par son identifiant OU par son établissement
   * (`eefProgramWhere`) : une formation saisie à la main sous une université de
   * l'import est servie par la recherche au même titre que les autres.
   *
   * Ce qui reste permis : créer ou remettre EN ATTENTE, éditer une ligne déjà
   * publiée, retirer.
   */
  private assertNotPublishingEef(input: {
    readonly what: 'program' | 'institution';
    readonly id?: string;
    readonly institutionId: string | undefined;
    readonly nextActive: boolean | undefined;
    readonly before?: { institutionId: string; isActive: boolean } | null;
  }) {
    if (input.nextActive !== true) return;
    const isEef = (id: string | undefined, institutionId: string | undefined) =>
      input.what === 'institution'
        ? (id ?? '').startsWith(EEF_INSTITUTION_ID_PREFIX)
        : (id ?? '').startsWith(EEF_PROGRAM_ID_PREFIX)
          || (institutionId ?? '').startsWith(EEF_INSTITUTION_ID_PREFIX);
    const becomesEef = isEef(input.id, input.institutionId);
    if (!becomesEef) return;
    // Déjà publiée ET déjà de l'import : rien ne change, l'éditer reste permis.
    const alreadyPublishedEef =
      input.before != null
      && input.before.isActive
      && isEef(input.id, input.before.institutionId);
    if (alreadyPublishedEef) return;
    throw new ConflictException(
      "Les lignes de l'import « Études en France » se publient par "
        + "« Publication EEF » (admin/etudes-en-france/publication), qui vérifie "
        + 'la source, la procédure et le domaine, et signe la publication.',
    );
  }

  async createProgram(input: Record<string, unknown>) {
    this.assertDb();
    const data: Prisma.ProgramCreateInput = {
      institutionId: this.requireStr(input, 'institutionId'),
      countryId: this.requireStr(input, 'countryId'),
      fieldId: this.requireStr(input, 'fieldId'),
      nameFr: this.requireStr(input, 'nameFr'),
      nameEn: this.str(input.nameEn) ?? this.requireStr(input, 'nameFr'),
      levelFr: normalizeDegreeLevel(this.str(input.levelFr) ?? ''),
      levelEn: normalizeDegreeLevel(
        this.str(input.levelEn) ?? this.str(input.levelFr) ?? '',
      ),
      durationFr: this.str(input.durationFr) ?? '',
      durationEn: this.str(input.durationEn) ?? this.str(input.durationFr) ?? '',
      tuitionFr: this.str(input.tuitionFr) ?? '',
      tuitionEn: this.str(input.tuitionEn) ?? this.str(input.tuitionFr) ?? '',
      languageFr: this.str(input.languageFr) ?? '',
      languageEn: this.str(input.languageEn) ?? this.str(input.languageFr) ?? '',
      requirementsFr: this.strArr(input.requirementsFr) ?? [],
      requirementsEn: this.strArr(input.requirementsEn) ?? [],
      recognitionFr: this.nonEmptyStr(input.recognitionFr) ?? null,
      recognitionEn:
        this.nonEmptyStr(input.recognitionEn) ??
        this.nonEmptyStr(input.recognitionFr) ??
        null,
      // Match-scoring inputs. Absent stays absent (the scorer then treats the
      // factor as neutral and flags the match `isEstimate`).
      minGpaRequired: this.pickNumOrNull(input, 'minGpaRequired'),
      tuitionMinEur: this.pickNumOrNull(input, 'tuitionMinEur', { int: true }),
      applicationDeadline: this.pickDateOrNull(input, 'applicationDeadline'),
      teachingLanguages: this.pickStrArr(input, 'teachingLanguages') ?? [],
      campusOfferings: this.pickCampusOfferings(input, 'campusOfferings'),
      // Défaut `true` : une fiche créée à la main dans l'admin l'est par
      // quelqu'un qui la relit en l'écrivant. Seul l'import de masse met en
      // attente.
      isActive: this.bool(input.isActive) ?? true,
    };
    this.assertNotPublishingEef({
      what: 'program',
      institutionId: data.institutionId,
      nextActive: data.isActive,
    });
    const created = await this.prisma.execute((db) =>
      db.program.create({ data }),
    );
    await this.syncInstitutionProgramIds(data.institutionId);
    return created;
  }

  async updateProgram(id: string, input: Record<string, unknown>) {
    this.assertDb();
    const rawLevelFr = this.str(input.levelFr);
    const rawLevelEn = this.str(input.levelEn);
    const data = this.clean<Prisma.ProgramUpdateInput>({
      institutionId: this.str(input.institutionId),
      countryId: this.str(input.countryId),
      fieldId: this.str(input.fieldId),
      nameFr: this.str(input.nameFr),
      nameEn: this.str(input.nameEn),
      levelFr: rawLevelFr != null ? normalizeDegreeLevel(rawLevelFr) : undefined,
      levelEn: rawLevelEn != null ? normalizeDegreeLevel(rawLevelEn) : undefined,
      durationFr: this.str(input.durationFr),
      durationEn: this.str(input.durationEn),
      tuitionFr: this.str(input.tuitionFr),
      tuitionEn: this.str(input.tuitionEn),
      languageFr: this.str(input.languageFr),
      languageEn: this.str(input.languageEn),
      requirementsFr: this.strArr(input.requirementsFr),
      requirementsEn: this.strArr(input.requirementsEn),
      recognitionFr: this.pickNullableStr(input, 'recognitionFr'),
      recognitionEn: this.pickNullableStr(input, 'recognitionEn'),
      minGpaRequired: this.pickNumOrNull(input, 'minGpaRequired'),
      tuitionMinEur: this.pickNumOrNull(input, 'tuitionMinEur', { int: true }),
      applicationDeadline: this.pickDateOrNull(input, 'applicationDeadline'),
      teachingLanguages: this.pickStrArr(input, 'teachingLanguages'),
      campusOfferings: this.pickCampusOfferings(input, 'campusOfferings'),
      // Le chemin de publication d'une fiche créée `isActive: false` (partenaire,
      // saisie à la main). Les lignes de l'import ont le leur : voir
      // `assertNotPublishingEef`.
      isActive: this.bool(input.isActive),
    });
    // L'établissement peut changer : les DEUX listes doivent bouger, celle
    // qu'on quitte comme celle qu'on rejoint.
    const before = await this.prisma.execute((db) =>
      db.program.findUnique({
        where: { id },
        select: {
          institutionId: true,
          isActive: true,
          campusCity: true,
          searchText: true,
        },
      }),
    );
    // Le texte cherchable (`Program.searchText`) est DÉRIVÉ de l'intitulé et de la
    // ville. Renommer une formation sans le recalculer laisse l'ancien mot
    // trouver la formation et le nouveau la manquer. Recalculé seulement pour une
    // ligne qui en porte un : les autres retombent sur la comparaison brute de la
    // recherche, et n'ont rien à garder à jour.
    if (before && before.searchText != null && typeof data.nameFr === 'string') {
      (data as Prisma.ProgramUpdateInput).searchText = programSearchText(
        data.nameFr,
        before.campusCity,
      );
    }
    if (before) {
      this.assertNotPublishingEef({
        what: 'program',
        id,
        institutionId: this.str(input.institutionId) ?? before.institutionId,
        nextActive: this.bool(input.isActive) ?? before.isActive,
        before,
      });
    }
    const updated = await this.runUpdate(
      () => this.prisma.execute((db) => db.program.update({ where: { id }, data })),
      'Program',
      id,
    );
    const after = (data as { institutionId?: string }).institutionId;
    const touched = new Set(
      [before?.institutionId, after].filter((x): x is string => x != null),
    );
    for (const institutionId of touched) {
      await this.syncInstitutionProgramIds(institutionId);
    }
    return updated;
  }

  async deleteProgram(id: string) {
    this.assertDb();
    const before = await this.prisma.execute((db) =>
      db.program.findUnique({ where: { id }, select: { institutionId: true } }),
    );
    await this.runUpdate(
      () => this.prisma.execute((db) => db.program.delete({ where: { id } })),
      'Program',
      id,
    );
    if (before?.institutionId) {
      await this.syncInstitutionProgramIds(before.institutionId);
    }
    return { id, deleted: true };
  }

  // ════════════════════════════════════════════════════════════════════════
  // INSTITUTIONS (universités)
  // ════════════════════════════════════════════════════════════════════════
  async createInstitution(input: Record<string, unknown>) {
    this.assertDb();
    const nameFr = this.requireStr(input, 'nameFr');
    const data: Prisma.InstitutionCreateInput = {
      nameFr,
      nameEn: this.str(input.nameEn) ?? nameFr,
      countryId: this.requireStr(input, 'countryId'),
      locationFr: this.str(input.locationFr) ?? '',
      locationEn: this.str(input.locationEn) ?? this.str(input.locationFr) ?? '',
      overviewFr: this.str(input.overviewFr) ?? '',
      overviewEn: this.str(input.overviewEn) ?? this.str(input.overviewFr) ?? '',
      studyLevels: (this.strArr(input.studyLevels) ?? []).map(normalizeDegreeLevel),
      tuitionLabelFr: this.str(input.tuitionLabelFr) ?? '',
      tuitionLabelEn:
        this.str(input.tuitionLabelEn) ?? this.str(input.tuitionLabelFr) ?? '',
      languageRequirementsFr: this.str(input.languageRequirementsFr) ?? '',
      languageRequirementsEn:
        this.str(input.languageRequirementsEn) ??
        this.str(input.languageRequirementsFr) ??
        '',
      intakePeriods: this.strArr(input.intakePeriods) ?? [],
      programIds: this.strArr(input.programIds) ?? [],
      isPartner: this.bool(input.isPartner) ?? false,
      // Défaut `true`, comme la formation : l'admin qui saisit une fiche la
      // relit en l'écrivant.
      isActive: this.bool(input.isActive) ?? true,
    };
    return this.prisma.execute((db) => db.institution.create({ data }));
  }

  async updateInstitution(id: string, input: Record<string, unknown>) {
    this.assertDb();
    const levels = this.strArr(input.studyLevels);
    const data = this.clean<Prisma.InstitutionUpdateInput>({
      nameFr: this.str(input.nameFr),
      nameEn: this.str(input.nameEn),
      countryId: this.str(input.countryId),
      locationFr: this.str(input.locationFr),
      locationEn: this.str(input.locationEn),
      overviewFr: this.str(input.overviewFr),
      overviewEn: this.str(input.overviewEn),
      studyLevels: levels ? levels.map(normalizeDegreeLevel) : undefined,
      tuitionLabelFr: this.str(input.tuitionLabelFr),
      tuitionLabelEn: this.str(input.tuitionLabelEn),
      languageRequirementsFr: this.str(input.languageRequirementsFr),
      languageRequirementsEn: this.str(input.languageRequirementsEn),
      intakePeriods: this.strArr(input.intakePeriods),
      programIds: this.strArr(input.programIds),
      isPartner: this.bool(input.isPartner),
      // Même rôle que sur la formation : publier une fiche créée en attente qui
      // n'est pas de l'import (voir `assertNotPublishingEef`).
      isActive: this.bool(input.isActive),
    });
    this.assertNotPublishingEef({
      what: 'institution',
      id,
      institutionId: id,
      nextActive: this.bool(input.isActive),
    });
    const nextCountryId = this.str(input.countryId);
    if (nextCountryId) {
      // Le verrou n'existait que dans l'interface (et sautait pendant le
      // chargement) : changer le pays d'un établissement qui a des formations
      // laissait ces formations rattachées à l'ancien pays, introuvables par
      // le bon filtre.
      const programsInOtherCountry = await this.prisma.execute((db) =>
        db.program.count({
          where: { institutionId: id, countryId: { not: nextCountryId } },
        }),
      );
      if ((programsInOtherCountry ?? 0) > 0) {
        throw new BadRequestException(
          `Cannot move institution ${id} to ${nextCountryId}: ${programsInOtherCountry} program(s) are still attached to another country. Move or delete them first.`,
        );
      }
    }
    return this.runUpdate(
      () =>
        this.prisma.execute((db) =>
          db.institution.update({ where: { id }, data }),
        ),
      'Institution',
      id,
    );
  }

  async deleteInstitution(id: string) {
    this.assertDb();
    // Guard: refuse to delete an institution that still has programs.
    const programCount = await this.prisma.execute((db) =>
      db.program.count({ where: { institutionId: id } }),
    );
    if ((programCount ?? 0) > 0) {
      throw new BadRequestException(
        `Cannot delete institution ${id}: ${programCount} program(s) still reference it. Reassign or delete them first.`,
      );
    }
    await this.runUpdate(
      () =>
        this.prisma.execute((db) => db.institution.delete({ where: { id } })),
      'Institution',
      id,
    );
    return { id, deleted: true };
  }

  // ════════════════════════════════════════════════════════════════════════
  // SCHOLARSHIPS (bourses) — manual entries keep sourceKey null so the scraper
  // refresh (which upserts by prefixed sourceKey) never touches them.
  // ════════════════════════════════════════════════════════════════════════
  async createScholarship(
    input: Record<string, unknown>,
    actor?: AdminSessionUser,
    requestId?: string,
  ) {
    this.assertDb();
    const nameFr = this.requireStr(input, 'nameFr');
    // Lu (et refusé s'il est invalide) AVANT toute écriture.
    const eligibility = hasEligibilityInput(input) ? pickEligibilityWrite(input) : null;
    const data: Prisma.ScholarshipCreateInput = {
      nameFr,
      nameEn: this.str(input.nameEn) ?? nameFr,
      countryId: this.requireStr(input, 'countryId'),
      countryNameFr: this.str(input.countryNameFr) ?? '',
      countryNameEn: this.str(input.countryNameEn) ?? '',
      levelEligibleFr: this.str(input.levelEligibleFr) ?? '',
      levelEligibleEn: this.str(input.levelEligibleEn) ?? '',
      typeOfFundingFr: this.str(input.typeOfFundingFr) ?? '',
      typeOfFundingEn: this.str(input.typeOfFundingEn) ?? '',
      applicationRequirement:
        this.enumVal(input.applicationRequirement, [
          'automatic',
          'separate_application',
        ] as const) ?? 'separate_application',
      deadlineLabelFr: this.str(input.deadlineLabelFr) ?? '',
      deadlineLabelEn: this.str(input.deadlineLabelEn) ?? '',
      descriptionFr: this.str(input.descriptionFr) ?? '',
      descriptionEn: this.str(input.descriptionEn) ?? '',
      advantagesFr: this.strArr(input.advantagesFr) ?? [],
      advantagesEn: this.strArr(input.advantagesEn) ?? [],
      eligibilityFr: this.strArr(input.eligibilityFr) ?? [],
      eligibilityEn: this.strArr(input.eligibilityEn) ?? [],
      keyRequirementsFr: this.strArr(input.keyRequirementsFr) ?? [],
      keyRequirementsEn: this.strArr(input.keyRequirementsEn) ?? [],
      relatedFieldIds: this.strArr(input.relatedFieldIds) ?? [],
      baseMatch: this.int(input.baseMatch) ?? 30,
      applicationUrl: this.str(input.applicationUrl) ?? null,
      sourceUrl: this.str(input.sourceUrl) ?? null,
      isActive: this.bool(input.isActive) ?? true,
      // Every manual entry passes through the same completeness gate as an
      // imported candidate. Approval is an explicit, audited admin action.
      moderationStatus: 'pending',
      tags: this.strArr(input.tags) ?? [],
      // sourceKey intentionally left null → flags this as a manual entry.
    };
    if (!eligibility) {
      return this.prisma.execute((db) => db.scholarship.create({ data }));
    }
    const plan = planEligibilityUpdate(
      EMPTY_ELIGIBILITY_STATE,
      eligibility,
      actor,
      new Date(),
    );
    return this.prisma.execute((db) =>
      db.$transaction(async (tx) => {
        const created = await tx.scholarship.create({
          data: { ...data, ...this.eligibilityColumns(plan) },
        });
        await this.auditEligibility(tx, created.id, plan, actor, requestId);
        return created;
      }),
    );
  }

  /// Les colonnes d'éligibilité d'un plan, au format Prisma (JSON des critères).
  private eligibilityColumns(plan: EligibilityPlan) {
    const { eligibilityCriteria, ...rest } = plan.data;
    return {
      ...rest,
      ...(eligibilityCriteria !== undefined
        ? {
            eligibilityCriteria:
              eligibilityCriteria as unknown as Prisma.InputJsonValue,
          }
        : {}),
    };
  }

  /// Une ligne `AdminAuditEvent` par écriture d'éligibilité (sur le modèle de
  /// l'annonce d'ouverture) : aucune donnée personnelle, des niveaux, des clés
  /// de critères et l'état du tampon.
  private async auditEligibility(
    tx: Prisma.TransactionClient,
    scholarshipId: string,
    plan: EligibilityPlan,
    actor: AdminSessionUser | undefined,
    requestId: string | undefined,
  ) {
    if (!plan.audit) return;
    await tx.adminAuditEvent.create({
      data: {
        actorAdminId: actor?.id ?? null,
        action: plan.audit.action,
        purposeCode: ELIGIBILITY_AUDIT_PURPOSE,
        entityType: ELIGIBILITY_AUDIT_ENTITY_TYPE,
        entityId: scholarshipId,
        requestId: requestId ?? randomUUID(),
        result: 'success',
        changes: plan.audit.changes,
      },
    });
  }

  async updateScholarship(
    id: string,
    input: Record<string, unknown>,
    actor?: AdminSessionUser,
    requestId?: string,
  ) {
    this.assertDb();
    const eligibility = hasEligibilityInput(input) ? pickEligibilityWrite(input) : null;
    const data = this.clean<Prisma.ScholarshipUpdateInput>({
      nameFr: this.str(input.nameFr),
      nameEn: this.str(input.nameEn),
      countryId: this.str(input.countryId),
      countryNameFr: this.str(input.countryNameFr),
      countryNameEn: this.str(input.countryNameEn),
      levelEligibleFr: this.str(input.levelEligibleFr),
      levelEligibleEn: this.str(input.levelEligibleEn),
      typeOfFundingFr: this.str(input.typeOfFundingFr),
      typeOfFundingEn: this.str(input.typeOfFundingEn),
      applicationRequirement: this.enumVal(input.applicationRequirement, [
        'automatic',
        'separate_application',
      ] as const),
      deadlineLabelFr: this.str(input.deadlineLabelFr),
      deadlineLabelEn: this.str(input.deadlineLabelEn),
      descriptionFr: this.str(input.descriptionFr),
      descriptionEn: this.str(input.descriptionEn),
      advantagesFr: this.strArr(input.advantagesFr),
      advantagesEn: this.strArr(input.advantagesEn),
      eligibilityFr: this.strArr(input.eligibilityFr),
      eligibilityEn: this.strArr(input.eligibilityEn),
      keyRequirementsFr: this.strArr(input.keyRequirementsFr),
      keyRequirementsEn: this.strArr(input.keyRequirementsEn),
      relatedFieldIds: this.strArr(input.relatedFieldIds),
      baseMatch: this.int(input.baseMatch),
      applicationUrl: this.str(input.applicationUrl),
      sourceUrl: this.str(input.sourceUrl),
      isActive: this.bool(input.isActive),
      tags: this.strArr(input.tags),
    });
    if (!eligibility) {
      return this.runUpdate(
        () =>
          this.prisma.execute((db) =>
            db.scholarship.update({ where: { id }, data }),
          ),
        'Scholarship',
        id,
      );
    }
    // Éligibilité structurée : lecture de l'état courant, plan (tampon,
    // retrait du tampon d'un contenu modifié), écriture et audit dans la même
    // transaction.
    return this.runUpdate(
      () =>
        this.prisma.execute((db) =>
          db.$transaction(async (tx) => {
            const existing = await tx.scholarship.findUnique({
              where: { id },
              select: {
                eligibleLevels: true,
                fieldsScope: true,
                eligibilityCriteria: true,
                eligibilityStructuredAt: true,
                eligibilityStructuredBy: true,
              },
            });
            if (!existing) throw new NotFoundException(`Scholarship ${id} not found.`);
            const plan = planEligibilityUpdate(existing, eligibility, actor, new Date());
            const updated = await tx.scholarship.update({
              where: { id },
              data: { ...data, ...this.eligibilityColumns(plan) },
            });
            await this.auditEligibility(tx, id, plan, actor, requestId);
            return updated;
          }),
        ),
      'Scholarship',
      id,
    );
  }

  async deleteScholarship(id: string) {
    this.assertDb();
    await this.runUpdate(
      () =>
        this.prisma.execute((db) => db.scholarship.delete({ where: { id } })),
      'Scholarship',
      id,
    );
    return { id, deleted: true };
  }

  // ── Scholarship application steps ("comment postuler") ────────────────────
  // Ordered, admin-authored steps distinct per scholarship — never scraped.
  async listApplicationSteps(scholarshipId: string) {
    this.assertDb();
    return this.prisma.execute((db) =>
      db.scholarshipApplicationStep.findMany({
        where: { scholarshipId },
        orderBy: { stepNumber: 'asc' },
      }),
    );
  }

  async createApplicationStep(
    scholarshipId: string,
    input: Record<string, unknown>,
  ) {
    this.assertDb();
    const titleFr = this.requireStr(input, 'titleFr');
    const stepNumber = this.int(input.stepNumber);
    if (stepNumber == null) {
      throw new BadRequestException('Field "stepNumber" is required.');
    }
    const data: Prisma.ScholarshipApplicationStepCreateInput = {
      scholarship: { connect: { id: scholarshipId } },
      stepNumber,
      titleFr,
      titleEn: this.str(input.titleEn) ?? titleFr,
      descriptionFr: this.str(input.descriptionFr) ?? '',
      descriptionEn: this.str(input.descriptionEn) ?? '',
      estimatedDurationDays: this.int(input.estimatedDurationDays) ?? null,
    };
    try {
      return await this.prisma.execute((db) =>
        db.scholarshipApplicationStep.create({ data }),
      );
    } catch (error) {
      throw this.mapStepUniqueError(error, scholarshipId, stepNumber);
    }
  }

  async updateApplicationStep(
    scholarshipId: string,
    stepId: string,
    input: Record<string, unknown>,
  ) {
    this.assertDb();
    const data = this.clean<Prisma.ScholarshipApplicationStepUpdateInput>({
      stepNumber: this.int(input.stepNumber),
      titleFr: this.str(input.titleFr),
      titleEn: this.str(input.titleEn),
      descriptionFr: this.str(input.descriptionFr),
      descriptionEn: this.str(input.descriptionEn),
      estimatedDurationDays: this.int(input.estimatedDurationDays),
    });
    try {
      return await this.runUpdate(
        () =>
          this.prisma.execute((db) =>
            db.scholarshipApplicationStep.update({
              where: { id: stepId },
              data,
            }),
          ),
        'ScholarshipApplicationStep',
        stepId,
      );
    } catch (error) {
      throw this.mapStepUniqueError(error, scholarshipId, data.stepNumber);
    }
  }

  async deleteApplicationStep(scholarshipId: string, stepId: string) {
    this.assertDb();
    await this.runUpdate(
      () =>
        this.prisma.execute((db) =>
          db.scholarshipApplicationStep.delete({ where: { id: stepId } }),
        ),
      'ScholarshipApplicationStep',
      stepId,
    );
    return { id: stepId, deleted: true };
  }

  /// Turns a unique-constraint violation on [scholarshipId, stepNumber] into a
  /// readable 400 instead of a raw Prisma P2002.
  private mapStepUniqueError(
    error: unknown,
    scholarshipId: string,
    stepNumber: unknown,
  ) {
    if (
      error &&
      typeof error === 'object' &&
      'code' in error &&
      (error as { code: string }).code === 'P2002'
    ) {
      return new BadRequestException(
        `A step numbered ${String(stepNumber)} already exists for scholarship ${scholarshipId}.`,
      );
    }
    return error as Error;
  }

  // ════════════════════════════════════════════════════════════════════════
  // COUNTRIES (pays)
  // ════════════════════════════════════════════════════════════════════════
  async createCountry(input: Record<string, unknown>) {
    this.assertDb();
    const nameFr = this.requireStr(input, 'nameFr');
    const data: Prisma.CountryCreateInput = {
      code: this.requireStr(input, 'code'),
      flagEmoji: this.str(input.flagEmoji) ?? '🌍',
      nameFr,
      nameEn: this.str(input.nameEn) ?? nameFr,
      whyStudyFr: this.str(input.whyStudyFr) ?? '',
      whyStudyEn: this.str(input.whyStudyEn) ?? '',
      tuitionRangeFr: this.str(input.tuitionRangeFr) ?? '',
      tuitionRangeEn: this.str(input.tuitionRangeEn) ?? '',
      livingCostRangeFr: this.str(input.livingCostRangeFr) ?? '',
      livingCostRangeEn: this.str(input.livingCostRangeEn) ?? '',
      visaOverviewFr: this.str(input.visaOverviewFr) ?? '',
      visaOverviewEn: this.str(input.visaOverviewEn) ?? '',
      admissionDifficultyFr: this.str(input.admissionDifficultyFr) ?? '',
      admissionDifficultyEn: this.str(input.admissionDifficultyEn) ?? '',
      taglineFr: this.str(input.taglineFr) ?? '',
      taglineEn: this.str(input.taglineEn) ?? '',
      popularFieldIds: this.strArr(input.popularFieldIds) ?? [],
      displayOrder: this.int(input.displayOrder) ?? 0,
      isActive: this.bool(input.isActive) ?? true,
    };
    return this.prisma.execute((db) => db.country.create({ data }));
  }

  async updateCountry(id: string, input: Record<string, unknown>) {
    this.assertDb();
    const data = this.clean<Prisma.CountryUpdateInput>({
      code: this.str(input.code),
      flagEmoji: this.str(input.flagEmoji),
      nameFr: this.str(input.nameFr),
      nameEn: this.str(input.nameEn),
      whyStudyFr: this.str(input.whyStudyFr),
      whyStudyEn: this.str(input.whyStudyEn),
      tuitionRangeFr: this.str(input.tuitionRangeFr),
      tuitionRangeEn: this.str(input.tuitionRangeEn),
      livingCostRangeFr: this.str(input.livingCostRangeFr),
      livingCostRangeEn: this.str(input.livingCostRangeEn),
      visaOverviewFr: this.str(input.visaOverviewFr),
      visaOverviewEn: this.str(input.visaOverviewEn),
      admissionDifficultyFr: this.str(input.admissionDifficultyFr),
      admissionDifficultyEn: this.str(input.admissionDifficultyEn),
      taglineFr: this.str(input.taglineFr),
      taglineEn: this.str(input.taglineEn),
      popularFieldIds: this.strArr(input.popularFieldIds),
      displayOrder: this.int(input.displayOrder),
      isActive: this.bool(input.isActive),
    });
    return this.runUpdate(
      () => this.prisma.execute((db) => db.country.update({ where: { id }, data })),
      'Country',
      id,
    );
  }

  async deleteCountry(id: string) {
    this.assertDb();
    const [programCount, institutionCount] = await Promise.all([
      this.prisma.execute((db) => db.program.count({ where: { countryId: id } })),
      this.prisma.execute((db) =>
        db.institution.count({ where: { countryId: id } }),
      ),
    ]);
    if ((programCount ?? 0) > 0 || (institutionCount ?? 0) > 0) {
      throw new BadRequestException(
        `Cannot delete country ${id}: ${programCount ?? 0} program(s) and ${institutionCount ?? 0} institution(s) still reference it. Consider deactivating (isActive=false) instead.`,
      );
    }
    await this.runUpdate(
      () => this.prisma.execute((db) => db.country.delete({ where: { id } })),
      'Country',
      id,
    );
    return { id, deleted: true };
  }

  // ════════════════════════════════════════════════════════════════════════
  // FIELDS (filières)
  // ════════════════════════════════════════════════════════════════════════
  async createField(input: Record<string, unknown>) {
    this.assertDb();
    const nameFr = this.requireStr(input, 'nameFr');
    const data: Prisma.FieldCreateInput = {
      nameFr,
      nameEn: this.str(input.nameEn) ?? nameFr,
      descriptionFr: this.str(input.descriptionFr) ?? '',
      descriptionEn: this.str(input.descriptionEn) ?? '',
      subjectsFr: this.strArr(input.subjectsFr) ?? [],
      subjectsEn: this.strArr(input.subjectsEn) ?? [],
      careersFr: this.strArr(input.careersFr) ?? [],
      careersEn: this.strArr(input.careersEn) ?? [],
      dailyLifeFr: this.strArr(input.dailyLifeFr) ?? [],
      dailyLifeEn: this.strArr(input.dailyLifeEn) ?? [],
      skillsFr: this.strArr(input.skillsFr) ?? [],
      skillsEn: this.strArr(input.skillsEn) ?? [],
      personalityTraitsFr: this.strArr(input.personalityTraitsFr) ?? [],
      personalityTraitsEn: this.strArr(input.personalityTraitsEn) ?? [],
      relatedCountryIds: this.strArr(input.relatedCountryIds) ?? [],
      relatedScholarshipIds: this.strArr(input.relatedScholarshipIds) ?? [],
      accentColorHex: this.str(input.accentColorHex) ?? null,
    };
    return this.prisma.execute((db) => db.field.create({ data }));
  }

  async updateField(id: string, input: Record<string, unknown>) {
    this.assertDb();
    const data = this.clean<Prisma.FieldUpdateInput>({
      nameFr: this.str(input.nameFr),
      nameEn: this.str(input.nameEn),
      descriptionFr: this.str(input.descriptionFr),
      descriptionEn: this.str(input.descriptionEn),
      subjectsFr: this.strArr(input.subjectsFr),
      subjectsEn: this.strArr(input.subjectsEn),
      careersFr: this.strArr(input.careersFr),
      careersEn: this.strArr(input.careersEn),
      dailyLifeFr: this.strArr(input.dailyLifeFr),
      dailyLifeEn: this.strArr(input.dailyLifeEn),
      skillsFr: this.strArr(input.skillsFr),
      skillsEn: this.strArr(input.skillsEn),
      personalityTraitsFr: this.strArr(input.personalityTraitsFr),
      personalityTraitsEn: this.strArr(input.personalityTraitsEn),
      relatedCountryIds: this.strArr(input.relatedCountryIds),
      relatedScholarshipIds: this.strArr(input.relatedScholarshipIds),
      accentColorHex: this.str(input.accentColorHex),
    });
    return this.runUpdate(
      () => this.prisma.execute((db) => db.field.update({ where: { id }, data })),
      'Field',
      id,
    );
  }

  async deleteField(id: string) {
    this.assertDb();
    await this.runUpdate(
      () => this.prisma.execute((db) => db.field.delete({ where: { id } })),
      'Field',
      id,
    );
    return { id, deleted: true };
  }

  // ── shared: translate Prisma "record not found" (P2025) → 404 ──────────────
  private async runUpdate<T>(
    op: () => Promise<T>,
    entity: string,
    id: string,
  ): Promise<T> {
    try {
      return await op();
    } catch (error) {
      if (
        error &&
        typeof error === 'object' &&
        'code' in error &&
        (error as { code: string }).code === 'P2025'
      ) {
        throw new NotFoundException(`${entity} ${id} not found.`);
      }
      throw error;
    }
  }
}
