import {
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import { ORIENTATION_FIELDS } from '../orientation/orientation-fields.data';
import { PrismaService } from '../prisma/prisma.service';
import { ALGORITHM_VERSION } from './assess';
import {
  CandidateSnapshotService,
  MATCH_CLOCK,
  snapshotReadinessOptions,
  type CandidateSnapshot,
  type MatchClock,
} from './candidate-snapshot';
import { countryName, countryOptions, type CountryOption, type MatchLang } from './countries';
import type { CreateMatchRunDto } from './dto/create-match-run.dto';
import { parseLang, parseMatchAnswers, parseTrigger, type MatchAnswersPatch } from './match-answers';
import {
  normaliseProfile,
  prefill,
  profileHash,
  readiness,
  stableHash,
  type MatchProfile,
  type MatchProfileSource,
  type PrefillSuggestion,
  type Readiness,
} from './match-inputs';
import {
  levelCatalogLabel,
  precisionLimitedBy,
  renderExcludedSummary,
  renderItem,
  storedItems,
  type RenderedExcludedSummary,
  type RenderedItem,
  type RunInputsSummary,
  type StoredRunItem,
} from './match-presenter';
import { matchScholarships, MAX_RESULTS, type ExcludedSummary } from './rank';

/**
 * « Mes 10 bourses » — l'API élève.
 *
 * - `state` : ce qui manque, les suggestions, les listes servies, le dernier
 *   run (rendu) et s'il est périmé ;
 * - `createRun` : DANS UNE TRANSACTION, enregistre les réponses sur le profil
 *   (tolérant : jeton inconnu abandonné), horodate la confirmation, écrit les
 *   anciens champs quand la correspondance est univoque, calcule, garde le run
 *   et élague aux 5 derniers. Un échec n'importe où annule tout, réponses
 *   comprises. Profil incomplet : rien n'est écrit ;
 * - `setAlerts` : l'opt-in explicite au push hebdomadaire.
 */

/** Runs gardés par élève (les plus récents). */
export const RUNS_KEPT = 5;

export type StaleReason = 'profile' | 'catalog' | 'algorithm';

/** Les colonnes du profil lues par le test. */
const PROFILE_SELECT = {
  id: true,
  countryOfResidence: true,
  birthDate: true,
  guardianConsentedAt: true,
  guardianName: true,
  guardianContact: true,
  nationalityCode: true,
  secondNationalityCode: true,
  highestDiploma: true,
  scholarshipTargetLevel: true,
  fieldIds: true,
  targetCountryIds: true,
  gradeBandOn20: true,
  englishLevel: true,
  frenchLevel: true,
  languageTests: true,
  workExperienceBand: true,
  scholarshipProfileConfirmedAt: true,
  scholarshipMatchAlertsOptInAt: true,
  currentLevel: true,
  targetLevel: true,
  languageLevel: true,
  gradeRange: true,
} satisfies Prisma.UserProfileSelect;

type ProfileRow = Prisma.UserProfileGetPayload<{ select: typeof PROFILE_SELECT }>;

const RUN_ORDER: Prisma.ScholarshipMatchRunOrderByWithRelationInput[] = [
  { createdAt: 'desc' },
  { id: 'desc' },
];

interface RunRow {
  id: string;
  createdAt: Date;
  algorithmVersion: string;
  trigger: string;
  profileHash: string;
  catalogHash: string;
  inputsSummary: unknown;
  items: unknown;
  excludedSummary: unknown;
  eligibleCount: number;
  toVerifyCount: number;
  excludedCount: number;
  candidateCount: number;
  notAnalyzedCount: number;
}

export interface RenderedRun {
  id: string;
  createdAt: string;
  algorithmVersion: string;
  trigger: string;
  counts: {
    eligible: number;
    toVerify: number;
    excluded: number;
    notAnalyzed: number;
    candidates: number;
  };
  /** Au plus 10, jamais une bourse `not_eligible`. Compatibles d'abord. */
  items: RenderedItem[];
  excludedSummary: RenderedExcludedSummary;
  /** « 1 bourse doctorale dans notre catalogue pour l'instant » (sinon null). */
  levelCatalog: { level: string; count: number; label: string | null } | null;
  /** Quand ≥ la moitié est « à vérifier » : qui limite la précision. */
  precisionLimitedBy: 'kpb' | 'answers' | null;
}

export interface RunDiff {
  previousRunId: string | null;
  /** Vides au premier run : rien n'est « nouveau » sans point de comparaison. */
  addedIds: string[];
  removedIds: string[];
}

export type CreateRunResponse =
  | { status: 'profile_incomplete'; readiness: Readiness }
  | { status: 'ok'; run: RenderedRun; diff: RunDiff };

export interface MatchOptions {
  version: string;
  countries: CountryOption[];
  destinations: Array<{ id: string; name: string }>;
  fields: Array<{ id: string; name: string }>;
}

export interface MatchStateResponse {
  algorithmVersion: string;
  readiness: Readiness;
  prefill: PrefillSuggestion[];
  /** Les valeurs actuelles (jetons connus seulement), pour le récapitulatif. */
  answers: ReturnType<typeof answersView>;
  options: MatchOptions;
  latestRun: RenderedRun | null;
  isStale: boolean;
  staleReasons: StaleReason[];
  /** Bourses analysées (« On analyse 29 bourses… »). */
  catalogSize: number;
  alertsOptIn: boolean;
}

function asStoredItems(value: unknown): StoredRunItem[] {
  if (!Array.isArray(value)) return [];
  return value.filter(
    (item): item is StoredRunItem =>
      typeof item === 'object' &&
      item !== null &&
      typeof (item as StoredRunItem).scholarshipId === 'string',
  );
}

function asExcludedSummary(value: unknown): ExcludedSummary | null {
  if (typeof value !== 'object' || value === null) return null;
  const summary = value as ExcludedSummary;
  return Array.isArray(summary.groups) ? summary : null;
}

function asInputsSummary(value: unknown): Partial<RunInputsSummary> {
  return typeof value === 'object' && value !== null ? (value as Partial<RunInputsSummary>) : {};
}

function isoDay(date: Date | null): string | null {
  return date ? date.toISOString().slice(0, 10) : null;
}

function answersView(profile: MatchProfile, row: ProfileRow) {
  return {
    nationalityCode: profile.nationalities[0] ?? null,
    secondNationalityCode: profile.nationalities[1] ?? null,
    residence: profile.residenceCode,
    birthDate: isoDay(profile.birthDate),
    guardianConsented: profile.guardianConsented,
    highestDiploma: profile.highestDiploma,
    scholarshipTargetLevel: profile.targetLevel,
    fieldIds: profile.fieldIds,
    targetCountryIds: profile.targetCountryIds,
    gradeBandOn20: profile.gradeBand,
    englishLevel: profile.englishLevel,
    frenchLevel: profile.frenchLevel,
    languageTests: profile.languageTests,
    workExperienceBand: profile.workExperienceBand,
    confirmedAt: row.scholarshipProfileConfirmedAt?.toISOString() ?? null,
  };
}

/** Le profil vu comme « confirmé » : sert à comparer les VALEURS, confirmation mise à part. */
function valuesHash(source: MatchProfileSource): string {
  return profileHash(
    normaliseProfile({ ...source, scholarshipProfileConfirmedAt: new Date(0) }),
  );
}

@Injectable()
export class ScholarshipMatchService {
  private readonly logger = new Logger(ScholarshipMatchService.name);
  private readonly clock: MatchClock;

  constructor(
    private readonly prismaService: PrismaService,
    private readonly snapshots: CandidateSnapshotService,
    @Optional() @Inject(MATCH_CLOCK) clock?: MatchClock,
  ) {
    this.clock = clock ?? (() => new Date());
  }

  private assertDb(): void {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException('Database is not configured. Set DATABASE_URL.');
    }
  }

  private async snapshot(): Promise<CandidateSnapshot> {
    const snapshot = await this.snapshots.get();
    if (!snapshot) {
      throw new ServiceUnavailableException('Database is not configured. Set DATABASE_URL.');
    }
    return snapshot;
  }

  private readinessOptions(snapshot: CandidateSnapshot) {
    return snapshotReadinessOptions(snapshot);
  }

  // ── GET /scholarships/match/state ────────────────────────────────────────

  async state(userId: string, langInput?: unknown): Promise<MatchStateResponse> {
    this.assertDb();
    const lang = parseLang(langInput);
    const snapshot = await this.snapshot();
    const now = this.clock();

    const found = await this.prismaService.execute(async (prisma) => {
      const profile = await prisma.userProfile.findUnique({
        where: { id: userId },
        select: PROFILE_SELECT,
      });
      if (!profile) return null;
      const runs = await prisma.scholarshipMatchRun.findMany({
        where: { userId },
        orderBy: RUN_ORDER,
        take: 2,
      });
      return { profile, runs };
    });
    if (!found) throw new NotFoundException('Profile not found.');

    const { profile, runs } = found;
    const normalised = normaliseProfile(profile);
    const latest = runs[0] ?? null;
    const previous = runs[1] ?? null;

    const staleReasons: StaleReason[] = [];
    if (latest) {
      if (latest.profileHash !== profileHash(normalised)) staleReasons.push('profile');
      if (latest.catalogHash !== snapshot.catalogHash) staleReasons.push('catalog');
      if (latest.algorithmVersion !== ALGORITHM_VERSION) staleReasons.push('algorithm');
    }

    return {
      algorithmVersion: ALGORITHM_VERSION,
      readiness: readiness(normalised, now, this.readinessOptions(snapshot)),
      prefill: prefill(profile, normalised),
      answers: answersView(normalised, profile),
      options: this.options(snapshot, lang),
      latestRun: latest
        ? this.renderRun(latest, previous ? asStoredItems(previous.items) : null, snapshot, lang, now)
        : null,
      isStale: staleReasons.length > 0,
      staleReasons,
      catalogSize: snapshot.candidates.length,
      alertsOptIn: profile.scholarshipMatchAlertsOptInAt !== null,
    };
  }

  /** Listes servies : pays, destinations du catalogue, domaines ; et leur version. */
  options(snapshot: CandidateSnapshot, lang: MatchLang): MatchOptions {
    const countries = countryOptions(lang);
    const destinationNames = new Map<string, string>();
    for (const candidate of snapshot.candidates) {
      const id = candidate.scholarship.countryId;
      if (!id || destinationNames.has(id)) continue;
      const served = lang === 'fr' ? candidate.display.countryNameFr : candidate.display.countryNameEn;
      destinationNames.set(id, served || (id === 'int' ? '' : countryName(id, lang)) || id);
    }
    const collator = new Intl.Collator(lang, { sensitivity: 'base' });
    const destinations = [...destinationNames.entries()]
      .map(([id, name]) => ({ id, name }))
      .sort((a, b) => collator.compare(a.name, b.name) || a.id.localeCompare(b.id));
    const fields = ORIENTATION_FIELDS.map((field) => ({
      id: field.id,
      name: lang === 'fr' ? field.nameFr : field.nameEn,
    }));
    return {
      version: stableHash({ lang, countries, destinations, fields }).slice(0, 16),
      countries,
      destinations,
      fields,
    };
  }

  // ── POST /scholarships/match/runs ────────────────────────────────────────

  async createRun(userId: string, body: CreateMatchRunDto): Promise<CreateRunResponse> {
    this.assertDb();
    const lang = parseLang(body?.lang);
    const trigger = parseTrigger(body?.trigger);
    const confirm = body?.confirm === true;
    const snapshot = await this.snapshot();
    const now = this.clock();
    const readinessOptions = this.readinessOptions(snapshot);

    const outcome = await this.prismaService.execute((prisma) =>
      prisma.$transaction(
        async (tx) => {
          const profile = await tx.userProfile.findUnique({
            where: { id: userId },
            select: PROFILE_SELECT,
          });
          if (!profile) return { kind: 'missing' as const };

          const { patch, ignored } = parseMatchAnswers(body?.answers, now, profile.countryOfResidence);
          if (ignored.length > 0) {
            // Les CLÉS seulement, jamais les valeurs (nationalité, date de naissance).
            this.logger.log(`Scholarship match answers ignored: ${ignored.join(', ')}`);
          }
          const data = this.profileWrites(profile, patch, confirm, now);
          const merged: MatchProfileSource = { ...profile, ...data } as MatchProfileSource;
          const normalised = normaliseProfile(merged);
          const ready = readiness(normalised, now, readinessOptions);
          if (!ready.ready) return { kind: 'incomplete' as const, readiness: ready };

          if (Object.keys(data).length > 0) {
            await tx.userProfile.update({ where: { id: userId }, data });
          }

          const result = matchScholarships(
            normalised,
            snapshot.candidates.map((candidate) => candidate.scholarship),
            now,
          );
          const items = storedItems(result, result.entries, snapshot);
          const previous = await tx.scholarshipMatchRun.findFirst({
            where: { userId },
            orderBy: RUN_ORDER,
            select: { id: true, items: true },
          });
          const inputsSummary: RunInputsSummary = {
            targetLevel: normalised.targetLevel,
            fieldCount: normalised.fieldIds.length,
            boosters: {
              targetCountries: normalised.targetCountryIds.length > 0,
              languageTests: normalised.languageTests.length > 0,
              frenchLevel: normalised.frenchLevel !== null,
              secondNationality: normalised.nationalities.length > 1,
            },
            confirmed: normalised.confirmed,
            levelCandidateCount: normalised.targetLevel
              ? snapshot.candidates.filter((candidate) =>
                  candidate.scholarship.eligibleLevels.includes(normalised.targetLevel!),
                ).length
              : null,
          };
          const run = await this.persistRun(tx, {
            userId,
            algorithmVersion: ALGORITHM_VERSION,
            trigger,
            profileHash: profileHash(normalised),
            catalogHash: snapshot.catalogHash,
            inputsSummary: inputsSummary as unknown as Prisma.InputJsonValue,
            items: items as unknown as Prisma.InputJsonValue,
            excludedSummary: result.excludedSummary as unknown as Prisma.InputJsonValue,
            eligibleCount: result.eligibleCount,
            toVerifyCount: result.toVerifyCount,
            excludedCount: result.excludedCount,
            candidateCount: result.candidateCount,
            notAnalyzedCount: result.notAnalyzedCount,
            createdAt: now,
          });
          await this.prune(tx, userId);
          return {
            kind: 'ok' as const,
            run,
            previous: previous ? asStoredItems(previous.items) : null,
            previousRunId: previous?.id ?? null,
          };
        },
        { maxWait: 5_000, timeout: 15_000 },
      ),
    );

    if (!outcome) {
      throw new ServiceUnavailableException('Database is not configured. Set DATABASE_URL.');
    }
    if (outcome.kind === 'missing') throw new NotFoundException('Profile not found.');
    if (outcome.kind === 'incomplete') {
      return { status: 'profile_incomplete', readiness: outcome.readiness };
    }

    const currentIds = asStoredItems(outcome.run.items).map((item) => item.scholarshipId);
    const previousIds = outcome.previous?.map((item) => item.scholarshipId) ?? [];
    return {
      status: 'ok',
      run: this.renderRun(outcome.run, outcome.previous, snapshot, lang, now),
      diff: {
        previousRunId: outcome.previousRunId,
        addedIds: outcome.previous ? currentIds.filter((id) => !previousIds.includes(id)) : [],
        removedIds: previousIds.filter((id) => !currentIds.includes(id)),
      },
    };
  }

  /**
   * Ce que les réponses écrivent sur le profil.
   *
   * - `confirm: true` horodate la confirmation (le SERVEUR, jamais l'app) ;
   * - une valeur CHANGÉE sans `confirm` retire la confirmation : une réponse
   *   que l'élève n'a pas relue ne doit pas pouvoir exclure une bourse ;
   * - l'accord du représentant légal est horodaté une fois, jamais réécrit.
   */
  private profileWrites(
    profile: ProfileRow,
    patch: MatchAnswersPatch,
    confirm: boolean,
    now: Date,
  ): Prisma.UserProfileUpdateInput {
    const { guardianConsent, languageTests, ...plain } = patch;
    const data: Prisma.UserProfileUpdateInput & Record<string, unknown> = { ...plain };
    if (languageTests !== undefined) {
      data.languageTests = languageTests as unknown as Prisma.InputJsonValue;
    }
    if (guardianConsent && !profile.guardianConsentedAt) {
      data.guardianConsentedAt = now;
    }
    if (confirm) {
      data.scholarshipProfileConfirmedAt = now;
    } else if (profile.scholarshipProfileConfirmedAt) {
      const before = valuesHash(profile);
      const after = valuesHash({ ...profile, ...data } as MatchProfileSource);
      if (before !== after) data.scholarshipProfileConfirmedAt = null;
    }
    return data;
  }

  /** Point d'extension des tests d'atomicité : l'écriture du run. */
  protected persistRun(
    tx: Prisma.TransactionClient,
    data: Prisma.ScholarshipMatchRunUncheckedCreateInput,
  ): Promise<RunRow> {
    return tx.scholarshipMatchRun.create({ data });
  }

  /** Garde les `RUNS_KEPT` runs les plus récents, dans la même transaction. */
  private async prune(tx: Prisma.TransactionClient, userId: string): Promise<void> {
    const stale = await tx.scholarshipMatchRun.findMany({
      where: { userId },
      orderBy: RUN_ORDER,
      skip: RUNS_KEPT,
      select: { id: true },
    });
    if (stale.length > 0) {
      await tx.scholarshipMatchRun.deleteMany({
        where: { id: { in: stale.map((row) => row.id) } },
      });
    }
  }

  private renderRun(
    row: RunRow,
    previousItems: StoredRunItem[] | null,
    snapshot: CandidateSnapshot,
    lang: MatchLang,
    now: Date,
  ): RenderedRun {
    const items = asStoredItems(row.items);
    const previousIds = new Set((previousItems ?? []).map((item) => item.scholarshipId));
    const summary = asInputsSummary(row.inputsSummary);
    const level = summary.targetLevel ?? null;
    const levelCount = typeof summary.levelCandidateCount === 'number' ? summary.levelCandidateCount : null;
    return {
      id: row.id,
      createdAt: row.createdAt.toISOString(),
      algorithmVersion: row.algorithmVersion,
      trigger: row.trigger,
      counts: {
        eligible: row.eligibleCount,
        toVerify: row.toVerifyCount,
        excluded: row.excludedCount,
        notAnalyzed: row.notAnalyzedCount,
        candidates: row.candidateCount,
      },
      items: items.map((item) =>
        renderItem(
          item,
          snapshot,
          lang,
          now,
          previousItems !== null && !previousIds.has(item.scholarshipId),
        ),
      ),
      excludedSummary: renderExcludedSummary(asExcludedSummary(row.excludedSummary), snapshot, lang),
      levelCatalog:
        level && levelCount !== null
          ? { level, count: levelCount, label: levelCatalogLabel(level, levelCount, lang, MAX_RESULTS) }
          : null,
      precisionLimitedBy: precisionLimitedBy(items),
    };
  }

  // ── PUT /scholarships/match/alerts ───────────────────────────────────────

  async setAlerts(
    userId: string,
    enabled: boolean,
  ): Promise<{ enabled: boolean; optedInAt: string | null }> {
    this.assertDb();
    const now = this.clock();
    const updated = await this.prismaService.execute(async (prisma) => {
      const current = await prisma.userProfile.findUnique({
        where: { id: userId },
        select: { scholarshipMatchAlertsOptInAt: true },
      });
      if (!current) return null;
      // Un opt-in déjà posé garde sa date (preuve du consentement d'origine).
      const optedInAt = enabled ? (current.scholarshipMatchAlertsOptInAt ?? now) : null;
      if (optedInAt?.getTime() !== current.scholarshipMatchAlertsOptInAt?.getTime()) {
        await prisma.userProfile.update({
          where: { id: userId },
          data: { scholarshipMatchAlertsOptInAt: optedInAt },
        });
      }
      return { optedInAt };
    });
    if (!updated) throw new NotFoundException('Profile not found.');
    return { enabled, optedInAt: updated.optedInAt?.toISOString() ?? null };
  }
}
