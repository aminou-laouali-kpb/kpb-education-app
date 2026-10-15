import { servedCycleStatus } from '../../common/public-scholarship-where';
import type { Assessment } from './assess';
import type { CandidateSnapshot, MatchCandidate } from './candidate-snapshot';
import type { MatchLang } from './countries';
import type { EligibleLevel } from './eligibility-criteria';
import type { ComposedRun, ExcludedSummary, RankedEntry, ResultSection } from './rank';
import {
  renderPoint,
  topReasons,
  type ExclusionGroup,
  type MatchPoint,
  type ReasonCode,
  type ToVerifyCode,
} from './reasons';

/**
 * La forme STOCKÉE d'un run (`ScholarshipMatchRun.items` / `excludedSummary`)
 * et son rendu pour l'app, dans la langue demandée.
 *
 * Stocké : les codes ET les points (code, critère, paramètres) — un libellé se
 * corrige côté serveur sans recalcul, et l'app n'a jamais à les composer. Les
 * paramètres sont ceux que la carte affiche (âge en années, pays accepté),
 * jamais la date de naissance ni la moyenne. Le nom de la fiche est gardé pour
 * afficher « Plus disponible » quand elle a quitté le catalogue public.
 *
 * Rendu : la carte (nom, pays, financement, fenêtre de candidature lue dans le
 * catalogue COURANT), ≤ 3 raisons, les points à vérifier avec la citation
 * officielle et sa source, le résumé des bourses écartées.
 */

export interface StoredRunItem {
  scholarshipId: string;
  cycleId: string | null;
  rank: number;
  section: ResultSection;
  status: 'eligible' | 'to_verify';
  relevance: number;
  reasonCodes: ReasonCode[];
  toVerifyCodes: ToVerifyCode[];
  reasons: MatchPoint<ReasonCode>[];
  toVerify: MatchPoint<ToVerifyCode>[];
  nameFr: string;
  nameEn: string;
}

/** Ce que `inputsSummary` garde : MINIMISÉ (ni nationalité, ni date de naissance, ni moyenne). */
export interface RunInputsSummary {
  targetLevel: EligibleLevel | null;
  fieldCount: number;
  boosters: {
    targetCountries: boolean;
    languageTests: boolean;
    frenchLevel: boolean;
    secondNationality: boolean;
  };
  confirmed: boolean;
  /** Candidates qui acceptent le niveau visé : le texte « 1 bourse doctorale… ». */
  levelCandidateCount: number | null;
}

export function storedItems(composed: ComposedRun, entries: readonly RankedEntry[], snapshot: CandidateSnapshot): StoredRunItem[] {
  const byId = new Map<string, Assessment>(
    entries.map((entry) => [entry.scholarship.id, entry.assessment]),
  );
  return composed.items.map((item) => {
    const assessment = byId.get(item.scholarshipId);
    const display = snapshot.byId.get(item.scholarshipId)?.display;
    return {
      ...item,
      reasons: assessment?.reasons ?? [],
      toVerify: assessment?.toVerify ?? [],
      nameFr: display?.nameFr ?? item.scholarshipId,
      nameEn: display?.nameEn ?? item.scholarshipId,
    };
  });
}

// ── Rendu ────────────────────────────────────────────────────────────────────

export interface RenderedPoint {
  code: string;
  label: string;
}

export interface RenderedToVerify extends RenderedPoint {
  /** La condition telle que publiée (exemptée de l'invariant « % »), et sa source. */
  official: { text: string; sourceUrl: string } | null;
}

export interface RenderedItem {
  scholarshipId: string;
  cycleId: string | null;
  rank: number;
  section: ResultSection;
  status: 'eligible' | 'to_verify';
  /** Absente du run précédent (puce « Nouveau »). */
  isNew: boolean;
  /** Faux quand la fiche n'est plus publique depuis le run (« Plus disponible »). */
  available: boolean;
  name: string;
  scholarship: {
    countryId: string;
    countryName: string;
    fundingType: string;
    fundingLabel: string;
    levelLabel: string;
    deadlineAt: string | null;
    deadlineLabel: string;
    applicationUrl: string | null;
    sourceUrl: string | null;
  } | null;
  /** La fenêtre SERVIE aujourd'hui (statut recalculé à l'horloge). */
  window: {
    cycleId: string;
    academicYear: string | null;
    status: string;
    dateConfidence: string;
    opensAt: string | null;
    closesAt: string | null;
    estimatedOpenAt: string | null;
    estimatedCloseAt: string | null;
  } | null;
  reasons: RenderedPoint[];
  toVerify: RenderedToVerify[];
}

export interface RenderedExcludedGroup {
  group: ExclusionGroup;
  count: number;
  label: string;
  /** Au plus 20, celles encore au catalogue public. */
  scholarships: Array<{ id: string; name: string }>;
}

export interface RenderedExcludedSummary {
  groups: RenderedExcludedGroup[];
  notAnalyzedCount: number;
  notAnalyzedLabel: string | null;
}

function iso(date: Date | null | undefined): string | null {
  return date ? date.toISOString() : null;
}

function pick(lang: MatchLang, fr: string, en: string): string {
  return lang === 'fr' ? fr || en : en || fr;
}

function officialFor(
  point: MatchPoint<ToVerifyCode>,
  candidate: MatchCandidate | undefined,
  lang: MatchLang,
): RenderedToVerify['official'] {
  if (!point.criterionKey || !candidate) return null;
  const criterion = candidate.criteriaByKey.get(point.criterionKey);
  if (!criterion) return null;
  return {
    text: pick(lang, criterion.officialTextFr, criterion.officialTextEn),
    sourceUrl: criterion.sourceUrl,
  };
}

export function renderItem(
  item: StoredRunItem,
  snapshot: CandidateSnapshot,
  lang: MatchLang,
  now: Date,
  isNew: boolean,
): RenderedItem {
  const candidate = snapshot.byId.get(item.scholarshipId);
  const display = candidate?.display;
  const cycle = candidate?.scholarship.cycle ?? null;
  return {
    scholarshipId: item.scholarshipId,
    cycleId: item.cycleId,
    rank: item.rank,
    section: item.section,
    status: item.status,
    isNew,
    available: candidate !== undefined,
    name: display
      ? pick(lang, display.nameFr, display.nameEn)
      : pick(lang, item.nameFr, item.nameEn),
    scholarship:
      candidate && display
        ? {
            countryId: candidate.scholarship.countryId,
            countryName: pick(lang, display.countryNameFr, display.countryNameEn),
            fundingType: candidate.scholarship.fundingType,
            fundingLabel: pick(lang, display.typeOfFundingFr, display.typeOfFundingEn),
            levelLabel: pick(lang, display.levelEligibleFr, display.levelEligibleEn),
            deadlineAt: iso(candidate.scholarship.deadlineAt),
            deadlineLabel: pick(lang, display.deadlineLabelFr, display.deadlineLabelEn),
            applicationUrl: display.applicationUrl,
            sourceUrl: display.sourceUrl,
          }
        : null,
    window: cycle
      ? {
          cycleId: cycle.id,
          academicYear: display?.academicYear ?? null,
          status: servedCycleStatus(cycle.status, cycle.closesAt, cycle.estimatedCloseAt, now),
          dateConfidence: cycle.dateConfidence,
          opensAt: iso(cycle.opensAt),
          closesAt: iso(cycle.closesAt),
          estimatedOpenAt: iso(cycle.estimatedOpenAt),
          estimatedCloseAt: iso(cycle.estimatedCloseAt),
        }
      : null,
    reasons: topReasons(item.reasons ?? []).map((point) => ({
      code: point.code,
      label: renderPoint(point, lang),
    })),
    toVerify: (item.toVerify ?? []).map((point) => ({
      code: point.code,
      label: renderPoint(point, lang),
      official: officialFor(point, candidate, lang),
    })),
  };
}

// ── Résumé des bourses écartées ─────────────────────────────────────────────

const GROUP_LABELS: Record<
  ExclusionGroup,
  { fr: (n: number) => string; en: (n: number) => string }
> = {
  level: {
    fr: (n) => (n > 1 ? `${n} visent un autre niveau` : `${n} vise un autre niveau`),
    en: (n) => (n > 1 ? `${n} are for another level` : `${n} is for another level`),
  },
  nationality: {
    fr: (n) =>
      n > 1
        ? `${n} sont réservées à d’autres nationalités ou pays de résidence`
        : `${n} est réservée à d’autres nationalités ou pays de résidence`,
    en: (n) =>
      n > 1
        ? `${n} are only for other nationalities or countries of residence`
        : `${n} is only for other nationalities or countries of residence`,
  },
  age: {
    fr: (n) =>
      n > 1
        ? `${n} ont une limite d’âge qui ne correspond pas à ton âge`
        : `${n} a une limite d’âge qui ne correspond pas à ton âge`,
    en: (n) =>
      n > 1 ? `${n} have an age limit that does not fit your age` : `${n} has an age limit that does not fit your age`,
  },
  experience: {
    fr: (n) =>
      n > 1
        ? `${n} demandent plus d’expérience professionnelle`
        : `${n} demande plus d’expérience professionnelle`,
    en: (n) => (n > 1 ? `${n} require more work experience` : `${n} requires more work experience`),
  },
  suspended: {
    fr: (n) =>
      n > 1 ? `${n} sont suspendues par l’organisme` : `${n} est suspendue par l’organisme`,
    en: (n) =>
      n > 1 ? `${n} are suspended by the organisation` : `${n} is suspended by the organisation`,
  },
};

export function excludedGroupLabel(group: ExclusionGroup, count: number, lang: MatchLang): string {
  return GROUP_LABELS[group][lang](count);
}

export function notAnalyzedLabel(count: number, lang: MatchLang): string | null {
  if (count <= 0) return null;
  if (lang === 'fr') {
    return count > 1
      ? `${count} bourses récentes pas encore analysées par KPB`
      : `${count} bourse récente pas encore analysée par KPB`;
  }
  return count > 1
    ? `${count} recent scholarships not yet analysed by KPB`
    : `${count} recent scholarship not yet analysed by KPB`;
}

export function renderExcludedSummary(
  summary: ExcludedSummary | null | undefined,
  snapshot: CandidateSnapshot,
  lang: MatchLang,
): RenderedExcludedSummary {
  const groups = (summary?.groups ?? []).map((group) => ({
    group: group.group,
    count: group.count,
    label: excludedGroupLabel(group.group, group.count, lang),
    scholarships: group.scholarshipIds
      .map((id) => snapshot.byId.get(id))
      .filter((candidate): candidate is MatchCandidate => candidate !== undefined)
      .map((candidate) => ({
        id: candidate.scholarship.id,
        name: pick(lang, candidate.display.nameFr, candidate.display.nameEn),
      })),
  }));
  const notAnalyzedCount = summary?.notAnalyzedCount ?? 0;
  return {
    groups,
    notAnalyzedCount,
    notAnalyzedLabel: notAnalyzedLabel(notAnalyzedCount, lang),
  };
}

// ── Textes guidés par les données ───────────────────────────────────────────

const LEVEL_PHRASES: Record<EligibleLevel, { fr: (n: number) => string; en: string }> = {
  secondary: { fr: () => 'pour le lycée', en: 'for secondary school' },
  bachelor: { fr: () => 'en Licence', en: 'for a Bachelor' },
  master: { fr: () => 'en Master', en: 'for a Master' },
  doctorate: { fr: (n) => (n > 1 ? 'doctorales' : 'doctorale'), en: 'for a doctorate' },
};

/**
 * « 1 bourse doctorale dans notre catalogue pour l'instant » : seulement quand
 * le niveau visé compte moins de bourses que les dix promises. Jamais écrit en
 * dur dans l'app : le chiffre vient du catalogue.
 */
export function levelCatalogLabel(level: EligibleLevel, count: number, lang: MatchLang, max: number): string | null {
  if (count >= max) return null;
  const phrase = LEVEL_PHRASES[level];
  if (lang === 'fr') {
    if (count === 0) {
      return level === 'doctorate'
        ? 'Pas encore de bourse doctorale dans notre catalogue'
        : `Pas encore de bourse ${phrase.fr(0)} dans notre catalogue`;
    }
    const noun = count > 1 ? 'bourses' : 'bourse';
    return `${count} ${noun} ${phrase.fr(count)} dans notre catalogue pour l’instant`;
  }
  if (count === 0) return `No scholarship ${phrase.en} in our catalogue yet`;
  return `${count} ${count > 1 ? 'scholarships' : 'scholarship'} ${phrase.en} in our catalogue so far`;
}

/** Ce qui limite la précision quand la moitié au moins des résultats sont « à vérifier ». */
const KPB_SIDE: ReadonlySet<string> = new Set([
  'eligibility_not_structured',
  'eligibility_stale',
  'criteria_not_structured',
  'criterion_unreadable',
]);
const ANSWERS_SIDE: ReadonlySet<string> = new Set([
  'profile_unconfirmed',
  'level_missing',
  'nationality_missing',
  'residence_missing',
  'age_missing',
  'experience_missing',
  'language_missing',
  'grade_missing',
]);

export function precisionLimitedBy(items: readonly StoredRunItem[]): 'kpb' | 'answers' | null {
  const toVerify = items.filter((item) => item.status === 'to_verify');
  if (items.length === 0 || toVerify.length * 2 < items.length) return null;
  let kpb = 0;
  let answers = 0;
  for (const item of toVerify) {
    if (item.toVerifyCodes.some((code) => KPB_SIDE.has(code))) kpb += 1;
    else if (item.toVerifyCodes.some((code) => ANSWERS_SIDE.has(code))) answers += 1;
  }
  if (kpb === 0 && answers === 0) return null;
  return kpb >= answers ? 'kpb' : 'answers';
}
