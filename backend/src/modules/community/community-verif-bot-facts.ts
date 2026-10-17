// ─────────────────────────────────────────────────────────────────────────────
// Bot « Vérif » (C3) — les FAITS, extraits déterministiquement du catalogue.
//
// Fonctions PURES : les lignes du catalogue arrivent déjà lues (service), avec
// l'horloge. Rien n'est inventé : un champ vide devient un fait « manquant »,
// une vérification trop ancienne un fait « à revérifier ».
//
// Les règles d'honnêteté sont celles déjà en service, pas des copies libres :
//  · statut d'une bourse : `servedCycleStatus` (cycle servi) puis la ligne de
//    statut du chantier G et l'urgence de l'app (`scholarship_urgency.dart`) —
//    jamais « ouverte » avant `opensAt`, « clôturée » seulement sur une clôture
//    CONFIRMÉE passée (ou un cycle fermé par l'équipe), une date ESTIMÉE dite
//    au mois près, jamais « clôture proche » sur une estimation ;
//  · rentrées d'une formation : la règle de `program_intakes.dart` — dates des
//    offres par campus, dédoublonnées par mois, les PASSÉES masquées, la
//    reconduction « à confirmer », repli sur les rentrées de l'école annoncées
//    comme telles, aucune date inventée ;
//  · avis visa USA : `usVisaSuspensionConfig` (la même source que /config/app).
// ─────────────────────────────────────────────────────────────────────────────

import { createHash } from 'node:crypto';

import { servedCycleStatus } from '../../common/public-scholarship-where';
import type { UsVisaSuspension } from '../config/us-visa-suspension';
import type { VerifIntent } from './community-verif-bot-detect';
import { VERIF_BOT_STALE_DAYS } from './community-verif-bot.config';

const DAY_MS = 24 * 60 * 60 * 1000;

/** « Clôture proche » : clôture CONFIRMÉE dans 14 jours ou moins (app). */
export const CLOSING_SOON_DAYS = 14;

export type FactEntityType = 'scholarship' | 'institution' | 'program' | 'country';

export interface EntityRef {
  type: FactEntityType;
  id: string;
  labelFr: string;
  labelEn: string;
  resolvedBy: 'mention' | 'name';
}

export interface FactSource {
  /** Page officielle d'où viennent les faits (fiche), ou `null`. */
  url: string | null;
  /** Dernière vérification humaine de la fiche (ISO), ou `null`. */
  verifiedAt: string | null;
  /** Vérification absente ou plus ancienne que le seuil de fraîcheur. */
  stale: boolean;
}

export interface Bilingual {
  fr: string;
  en: string;
}

export type ScholarshipStatusKind =
  | 'open'
  | 'closing_soon'
  | 'open_date_to_confirm'
  | 'opens_on'
  | 'opening_estimated'
  | 'closing_estimated'
  | 'date_to_confirm'
  | 'closed';

export interface ScholarshipFacts {
  kind: 'scholarship';
  ref: EntityRef;
  status: {
    kind: ScholarshipStatusKind;
    /** Jour (confirmé) ou mois (estimé) qui accompagne le statut. */
    date: string | null;
    academicYear: string | null;
  };
  applicationUrl: string | null;
  funding: Bilingual | null;
  documents: { fr: string[]; en: string[] };
  countryId: string | null;
  source: FactSource;
}

export interface IntakeFact {
  year: number;
  month: number | null;
  spring: boolean;
  estimated: boolean;
}

export interface IntakesFacts {
  /** Rentrées à venir, triées, dédoublonnées par mois. */
  dates: IntakeFact[];
  /** Textes que la règle ne sait pas dater, repris tels quels. */
  labels: string[];
  /** Rentrées de l'ÉCOLE (repli), pas une promesse pour la formation. */
  fromSchool: boolean;
  /** Des dates étaient connues, mais toutes passées. */
  allPast: boolean;
}

export interface InstitutionFacts {
  kind: 'institution';
  ref: EntityRef;
  isPartner: boolean;
  intakes: IntakesFacts;
  tuition: Bilingual | null;
  websiteUrl: string | null;
  countryId: string | null;
  isUs: boolean;
  source: FactSource;
}

export interface ProgramFacts {
  kind: 'program';
  ref: EntityRef;
  institution: { id: string; labelFr: string; labelEn: string; isPartner: boolean } | null;
  intakes: IntakesFacts;
  tuition: Bilingual | null;
  applicationFeeEur: number | null;
  applicationDeadline: { date: string; passed: boolean } | null;
  documents: { fr: string[]; en: string[] };
  countryId: string | null;
  isUs: boolean;
  source: FactSource;
}

export interface CountryFacts {
  kind: 'country';
  ref: EntityRef;
  nextIntake: Bilingual | null;
  isUs: boolean;
  source: FactSource;
}

export type EntityFacts = ScholarshipFacts | InstitutionFacts | ProgramFacts | CountryFacts;

export interface UsVisaFact {
  countries: { code: string; nameFr: string; nameEn: string }[];
  visaTypes: string[];
  verifiedAt: string | null;
  sourceUrl: string;
}

export interface FactSet {
  version: 1;
  /** Heure du contrôle (exclue de l'empreinte). */
  checkedAt: string;
  entities: EntityFacts[];
  usVisa: UsVisaFact | null;
}

// ── Lignes du catalogue (forme minimale lue par le service) ─────────────────

export interface CycleRow {
  academicYear: string;
  status: string;
  dateConfidence: string;
  opensAt: Date | null;
  closesAt: Date | null;
  estimatedOpenAt: Date | null;
  estimatedCloseAt: Date | null;
  sourceUrl: string | null;
  verifiedAt: Date | null;
}

export interface ScholarshipRow {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  typeOfFundingFr: string;
  typeOfFundingEn: string;
  keyRequirementsFr: string[];
  keyRequirementsEn: string[];
  deadlineAt: Date | null;
  applicationUrl: string | null;
  sourceUrl: string | null;
  lastVerifiedAt: Date | null;
  /** Triés par année universitaire décroissante. */
  cycles: CycleRow[];
}

export interface InstitutionRow {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  isPartner: boolean;
  intakePeriods: string[];
  tuitionLabelFr: string;
  tuitionLabelEn: string;
  websiteUrl: string | null;
  sourceUrl: string | null;
  lastVerifiedAt: Date | null;
}

export interface ProgramRow {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  tuitionFr: string;
  tuitionEn: string;
  applicationFeeEur: number | null;
  applicationDeadline: Date | null;
  requirementsFr: string[];
  requirementsEn: string[];
  campusOfferings: unknown;
  sourceUrl: string | null;
  lastVerifiedAt: Date | null;
}

export interface CountryRow {
  id: string;
  code: string;
  nameFr: string;
  nameEn: string;
  nextIntakeLabelFr: string;
  nextIntakeLabelEn: string;
  sourceUrl: string | null;
  lastVerifiedAt: Date | null;
}

// ── Petits outils ───────────────────────────────────────────────────────────

function iso(date: Date | null | undefined): string | null {
  return date ? date.toISOString() : null;
}

function clean(text: string | null | undefined): string {
  return (text ?? '').replace(/\s+/g, ' ').trim();
}

function bilingual(fr: string | null | undefined, en: string | null | undefined): Bilingual | null {
  const f = clean(fr);
  const e = clean(en);
  if (!f && !e) return null;
  return { fr: f || e, en: e || f };
}

function httpUrl(url: string | null | undefined): string | null {
  const raw = (url ?? '').trim();
  if (!raw) return null;
  try {
    const parsed = new URL(raw);
    return parsed.protocol === 'https:' || parsed.protocol === 'http:' ? parsed.toString() : null;
  } catch {
    return null;
  }
}

function list(values: readonly string[] | null | undefined): string[] {
  return (values ?? []).map(clean).filter(Boolean);
}

export function isUsCountry(countryId: string | null | undefined, code?: string | null): boolean {
  const id = (countryId ?? '').toLowerCase();
  const c = (code ?? '').toUpperCase();
  return id === 'usa' || id === 'us' || c === 'US' || c === 'USA';
}

export function factSource(
  type: FactEntityType,
  url: string | null | undefined,
  verifiedAt: Date | null | undefined,
  now: Date,
): FactSource {
  const stale =
    !verifiedAt || now.getTime() - verifiedAt.getTime() > VERIF_BOT_STALE_DAYS[type] * DAY_MS;
  return { url: httpUrl(url), verifiedAt: iso(verifiedAt), stale };
}

// ── Statut d'une bourse ─────────────────────────────────────────────────────

/** Le cycle COURANT : ouvert, sinon prévision, sinon le plus récent. */
export function selectCurrentCycle(cycles: readonly CycleRow[]): CycleRow | undefined {
  return cycles.find((c) => c.status === 'open') ?? cycles.find((c) => c.status === 'forecast') ?? cycles[0];
}

function calendarDaysBetween(from: Date, to: Date): number {
  const a = Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate());
  const b = Date.UTC(to.getUTCFullYear(), to.getUTCMonth(), to.getUTCDate());
  return Math.round((b - a) / DAY_MS);
}

/**
 * Le statut tel que l'app le DIT (`scholarshipUrgencyOf`), à partir des
 * lignes en base et de l'horloge. Voir l'en-tête du fichier pour les règles.
 */
export function scholarshipStatus(
  row: Pick<ScholarshipRow, 'deadlineAt' | 'cycles'>,
  now: Date,
): ScholarshipFacts['status'] {
  const ref = now.getTime();
  const raw = selectCurrentCycle(row.cycles);
  const academicYear = raw?.academicYear ?? null;
  const out = (kind: ScholarshipStatusKind, date: Date | null = null) => ({
    kind,
    date: iso(date),
    academicYear,
  });

  // La ligne de statut (resolveScholarshipStatusLine), sur le cycle SERVI.
  const cycle = raw
    ? { ...raw, status: servedCycleStatus(raw.status, raw.closesAt, raw.estimatedCloseAt, now) }
    : undefined;
  let line: { kind: 'closed' | 'open' | 'opensOn' | 'openingEstimated'; date: Date | null };
  if (!cycle) {
    if (!row.deadlineAt) return out('date_to_confirm');
    line =
      row.deadlineAt.getTime() <= ref
        ? { kind: 'closed', date: null }
        : { kind: 'open', date: row.deadlineAt };
  } else {
    const estimated = cycle.dateConfidence === 'estimated';
    const confirmedClose = cycle.closesAt ?? (estimated ? null : row.deadlineAt);
    const opensInFuture = !!cycle.opensAt && cycle.opensAt.getTime() > ref;
    if (cycle.status === 'closed' || (confirmedClose && confirmedClose.getTime() <= ref)) {
      line = { kind: 'closed', date: null };
    } else if (cycle.status === 'open') {
      line = opensInFuture ? { kind: 'opensOn', date: cycle.opensAt } : { kind: 'open', date: confirmedClose };
    } else if (opensInFuture && !estimated) {
      line = { kind: 'opensOn', date: cycle.opensAt };
    } else {
      line = { kind: 'openingEstimated', date: cycle.estimatedOpenAt ?? (opensInFuture ? cycle.opensAt : null) };
    }
  }

  switch (line.kind) {
    case 'closed':
      return isConfirmedClosed(cycle, row.deadlineAt, now) ? out('closed') : out('date_to_confirm');
    case 'open': {
      if (!line.date) return out('open_date_to_confirm');
      const days = calendarDaysBetween(now, line.date);
      return out(days <= CLOSING_SOON_DAYS ? 'closing_soon' : 'open', line.date);
    }
    case 'opensOn':
      return out('opens_on', line.date);
    case 'openingEstimated': {
      if (line.date && line.date.getTime() > ref) return out('opening_estimated', line.date);
      const estimatedClose = cycle?.estimatedCloseAt ?? cycle?.closesAt ?? null;
      if (estimatedClose && estimatedClose.getTime() > ref) return out('closing_estimated', estimatedClose);
      return out('date_to_confirm');
    }
  }
}

/** « Clôturée » se mérite (même règle que `_isConfirmedClosed` de l'app). */
function isConfirmedClosed(
  cycle: (CycleRow & { status: string }) | undefined,
  deadlineAt: Date | null,
  now: Date,
): boolean {
  const ref = now.getTime();
  const estimated = cycle?.dateConfidence === 'estimated';
  const confirmedClose = cycle?.closesAt ?? (estimated ? null : deadlineAt);
  if (confirmedClose && confirmedClose.getTime() <= ref) return true;
  if (!cycle || cycle.status !== 'closed') return false;
  if (cycle.closesAt) return true;
  const estimatedClose = cycle.estimatedCloseAt;
  return !estimatedClose || estimatedClose.getTime() > ref;
}

// ── Rentrées (règle de program_intakes.dart, côté serveur) ──────────────────

const MONTHS: Record<string, number> = {
  janvier: 1, fevrier: 2, mars: 3, avril: 4, mai: 5, juin: 6, juillet: 7, aout: 8, septembre: 9,
  octobre: 10, novembre: 11, decembre: 12, january: 1, february: 2, march: 3, april: 4, may: 5,
  june: 6, july: 7, august: 8, september: 9, october: 10, november: 11, december: 12,
};

interface ParsedIntake {
  year: number;
  month: number | null;
  spring: boolean | null;
  /** Fin de validité : passé ce moment, la rentrée n'est plus disponible. */
  endsAt: number;
}

function stripAccents(text: string): string {
  return text.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

/**
 * « 01/10/2026 » (au jour), « 03/2027 » (au mois), « Septembre 2026 » /
 * « March 2027 » (au mois), « FALL 2027 » / « Printemps 2027 » (à l'année).
 * `null` pour un texte que la règle ne sait pas dater (« Septembre »).
 */
export function parseIntake(raw: string): ParsedIntake | null {
  const text = raw.trim();
  let m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(text);
  if (m) {
    const [day, month, year] = [Number(m[1]), Number(m[2]), Number(m[3])];
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return { year, month, spring: null, endsAt: Date.UTC(year, month - 1, day + 1) };
  }
  m = /^(\d{1,2})\/(\d{4})$/.exec(text);
  if (m) {
    const [month, year] = [Number(m[1]), Number(m[2])];
    if (month < 1 || month > 12) return null;
    return { year, month, spring: null, endsAt: Date.UTC(year, month, 1) };
  }
  const plain = stripAccents(text);
  m = /^(fall|autumn|automne|spring|printemps)\s+(\d{4})$/.exec(plain);
  if (m) {
    const year = Number(m[2]);
    return { year, month: null, spring: m[1] === 'spring' || m[1] === 'printemps', endsAt: Date.UTC(year + 1, 0, 1) };
  }
  m = /^([a-z]+)\s+(\d{4})$/.exec(plain);
  if (m && MONTHS[m[1]]) {
    const [month, year] = [MONTHS[m[1]], Number(m[2])];
    return { year, month, spring: null, endsAt: Date.UTC(year, month, 1) };
  }
  return null;
}

function offeringsOf(raw: unknown): Record<string, unknown>[] {
  if (!Array.isArray(raw)) return [];
  return raw.filter((o): o is Record<string, unknown> => !!o && typeof o === 'object' && !Array.isArray(o));
}

/** Rentrées à venir d'une formation (offres), sinon celles de l'école. */
export function upcomingIntakes(
  campusOfferings: unknown,
  schoolIntakePeriods: readonly string[],
  now: Date,
): IntakesFacts {
  const ref = now.getTime();
  const byKey = new Map<number, IntakeFact>();
  const labels: string[] = [];
  let known = 0;
  const offers = offeringsOf(campusOfferings);
  const fromSchool = offers.length === 0;
  const entries: { raw: string; session: unknown; estimated: boolean }[] = fromSchool
    ? list(schoolIntakePeriods).map((raw) => ({ raw, session: null, estimated: false }))
    : offers.flatMap((o) =>
        (typeof o.intake === 'string' ? o.intake : '')
          .split('·')
          .map((part) => part.trim())
          .filter(Boolean)
          .map((raw) => ({
            raw,
            session: o.session,
            estimated: o.intakeEstimated === true || typeof o.rolledFromIntake === 'string',
          })),
      );
  for (const entry of entries) {
    const parsed = parseIntake(entry.raw);
    if (!parsed) {
      if (!labels.includes(entry.raw)) labels.push(entry.raw);
      continue;
    }
    known += 1;
    if (parsed.endsAt <= ref) continue;
    const spring =
      entry.session === 'spring' ||
      (entry.session !== 'fall' && (parsed.spring ?? (parsed.month !== null && parsed.month <= 6)));
    const key = parsed.year * 100 + (parsed.month ?? (spring ? 3 : 9));
    const existing = byKey.get(key);
    // Une offre confirmée du même mois l'emporte sur une reconduction.
    const estimated = existing ? existing.estimated && entry.estimated : entry.estimated;
    byKey.set(key, { year: parsed.year, month: parsed.month, spring, estimated });
  }
  const dates = [...byKey.entries()].sort((a, b) => a[0] - b[0]).map(([, v]) => v);
  return { dates, labels, fromSchool, allPast: known > 0 && dates.length === 0 };
}

// ── Assemblage par entité ───────────────────────────────────────────────────

export function scholarshipFacts(row: ScholarshipRow, ref: EntityRef, now: Date): ScholarshipFacts {
  const cycle = selectCurrentCycle(row.cycles);
  // La source du cycle en cours d'abord (dates de la session), sinon la fiche.
  const sourceUrl = httpUrl(cycle?.sourceUrl) ?? httpUrl(row.sourceUrl);
  return {
    kind: 'scholarship',
    ref,
    status: scholarshipStatus(row, now),
    applicationUrl: httpUrl(row.applicationUrl),
    funding: bilingual(row.typeOfFundingFr, row.typeOfFundingEn),
    documents: { fr: list(row.keyRequirementsFr), en: list(row.keyRequirementsEn) },
    countryId: row.countryId || null,
    source: factSource('scholarship', sourceUrl, row.lastVerifiedAt, now),
  };
}

export function institutionFacts(row: InstitutionRow, ref: EntityRef, now: Date): InstitutionFacts {
  return {
    kind: 'institution',
    ref,
    isPartner: row.isPartner,
    intakes: upcomingIntakes(null, row.intakePeriods, now),
    tuition: bilingual(row.tuitionLabelFr, row.tuitionLabelEn),
    websiteUrl: httpUrl(row.websiteUrl),
    countryId: row.countryId || null,
    isUs: isUsCountry(row.countryId),
    source: factSource('institution', row.sourceUrl ?? row.websiteUrl, row.lastVerifiedAt, now),
  };
}

export function programFacts(
  row: ProgramRow,
  institution: InstitutionRow | null,
  ref: EntityRef,
  now: Date,
): ProgramFacts {
  const deadline = row.applicationDeadline;
  return {
    kind: 'program',
    ref,
    institution: institution
      ? { id: institution.id, labelFr: institution.nameFr, labelEn: institution.nameEn || institution.nameFr, isPartner: institution.isPartner }
      : null,
    intakes: upcomingIntakes(row.campusOfferings, institution?.intakePeriods ?? [], now),
    tuition: bilingual(row.tuitionFr, row.tuitionEn),
    applicationFeeEur: typeof row.applicationFeeEur === 'number' ? row.applicationFeeEur : null,
    applicationDeadline: deadline ? { date: deadline.toISOString(), passed: deadline.getTime() <= now.getTime() } : null,
    documents: { fr: list(row.requirementsFr), en: list(row.requirementsEn) },
    countryId: row.countryId || null,
    isUs: isUsCountry(row.countryId),
    source: factSource('program', row.sourceUrl, row.lastVerifiedAt, now),
  };
}

export function countryFacts(row: CountryRow, ref: EntityRef, now: Date): CountryFacts {
  return {
    kind: 'country',
    ref,
    nextIntake: bilingual(row.nextIntakeLabelFr, row.nextIntakeLabelEn),
    isUs: isUsCountry(row.id, row.code),
    source: factSource('country', row.sourceUrl, row.lastVerifiedAt, now),
  };
}

export function usVisaFact(config: UsVisaSuspension): UsVisaFact | null {
  if (!config.countries.length) return null;
  return {
    countries: config.countries.map((c) => ({ code: c.code, nameFr: c.nameFr, nameEn: c.nameEn })),
    visaTypes: [...config.visaTypes],
    verifiedAt: config.lastVerifiedAt,
    sourceUrl: config.sourceUrl,
  };
}

// ── Complétude, confiance, empreinte ────────────────────────────────────────

/** Une entité répond-elle à cet intérêt avec un fait RENSEIGNÉ ? */
export function answers(entity: EntityFacts, intent: VerifIntent, usVisa: UsVisaFact | null): boolean {
  switch (intent) {
    case 'truth':
    case 'scam':
      // Répondus par le résumé vérifié (statut, lien officiel) et la prudence.
      return true;
    case 'status':
      if (entity.kind === 'scholarship') return entity.status.kind !== 'date_to_confirm';
      if (entity.kind === 'country') return !!entity.nextIntake;
      return entity.intakes.dates.length > 0;
    case 'deadline':
      if (entity.kind === 'scholarship') {
        return ['open', 'closing_soon', 'closed'].includes(entity.status.kind);
      }
      if (entity.kind === 'program') return !!entity.applicationDeadline || entity.intakes.dates.length > 0;
      if (entity.kind === 'institution') return entity.intakes.dates.length > 0;
      return !!entity.nextIntake;
    case 'fees':
      if (entity.kind === 'scholarship') return !!entity.funding;
      if (entity.kind === 'program') return !!entity.tuition || entity.applicationFeeEur !== null;
      if (entity.kind === 'institution') return !!entity.tuition;
      return false;
    case 'documents':
      if (entity.kind === 'scholarship' || entity.kind === 'program') return entity.documents.fr.length > 0;
      return false;
    case 'partner':
      return entity.kind === 'institution' || (entity.kind === 'program' && !!entity.institution);
    case 'exists':
      return entity.kind !== 'country';
    case 'intake':
      if (entity.kind === 'country') return !!entity.nextIntake;
      if (entity.kind === 'scholarship') return false;
      return entity.intakes.dates.length > 0;
    case 'visa':
      return entity.kind !== 'scholarship' && 'isUs' in entity && entity.isUs && !!usVisa;
  }
}

export type VerifConfidence = 'high' | 'medium' | 'low';

export interface FactAssessment {
  /** Intérêts sans aucun fait renseigné (dits « non renseigné » dans le texte). */
  unanswered: VerifIntent[];
  anyStale: boolean;
  /** Tous les intérêts répondus ET aucune fiche périmée. */
  complete: boolean;
  confidence: VerifConfidence;
}

export function assessFacts(facts: FactSet, intents: readonly VerifIntent[]): FactAssessment {
  const unanswered = intents.filter((i) => !facts.entities.some((e) => answers(e, i, facts.usVisa)));
  const anyStale = facts.entities.some((e) => e.source.stale);
  const complete = facts.entities.length > 0 && unanswered.length === 0 && !anyStale;
  const allMention = facts.entities.every((e) => e.ref.resolvedBy === 'mention');
  const substantive = intents.filter((i) => i !== 'truth' && i !== 'scam');
  const nothingAnswered = substantive.length > 0 && substantive.every((i) => unanswered.includes(i));
  let confidence: VerifConfidence = 'medium';
  if (complete && allMention) confidence = 'high';
  else if (nothingAnswered || facts.entities.every((e) => e.source.stale)) confidence = 'low';
  return { unanswered, anyStale, complete, confidence };
}

/** Empreinte des faits (sans l'heure du contrôle) : change ⇒ brouillon obsolète. */
export function factsHash(facts: FactSet): string {
  const { checkedAt: _checkedAt, ...stable } = facts;
  void _checkedAt;
  return createHash('sha256').update(JSON.stringify(stable)).digest('hex').slice(0, 32);
}

/** La plus ancienne date de vérification des fiches citées (montrée dans l'app). */
export function oldestVerifiedAt(facts: FactSet): string | null {
  const dates = facts.entities.map((e) => e.source.verifiedAt).filter((d): d is string => !!d).sort();
  return dates[0] ?? null;
}
