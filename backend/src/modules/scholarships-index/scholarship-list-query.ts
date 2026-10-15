import { BadRequestException } from '@nestjs/common';

/**
 * Paramètres OPTIONNELS de `GET /scholarships` (chantier I) : recherche (`q`),
 * statut (`status`) et tri (`sort`).
 *
 * Tous facultatifs : les builds en store ne les envoient pas, et leur réponse
 * doit rester exactement celle d'avant (tri par pertinence, aucun filtre).
 * Une valeur INCONNUE, elle, est refusée (400) plutôt qu'ignorée : un filtre
 * ignoré en silence afficherait « Ouvertes » au-dessus d'une liste qui ne l'est
 * pas.
 */

/** Statuts filtrables — ceux que la ligne de statut de l'app sait dire. */
export const SCHOLARSHIP_LIST_STATUSES = ['open', 'upcoming', 'forecast'] as const;
export type ScholarshipListStatus = (typeof SCHOLARSHIP_LIST_STATUSES)[number];

/** Statut servi d'une fiche : les trois filtrables, plus `closed`. */
export type ScholarshipServedStatus = ScholarshipListStatus | 'closed';

export const SCHOLARSHIP_LIST_SORTS = [
  'relevance',
  'deadline',
  'verified',
  'title',
] as const;
export type ScholarshipListSort = (typeof SCHOLARSHIP_LIST_SORTS)[number];

export const SCHOLARSHIP_LIST_QUERY_MAX_LENGTH = 100;

/** `q` : texte libre, espaces repliés ; vide → pas de recherche. */
export function parseScholarshipListQuery(raw?: string): string | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== 'string') {
    throw new BadRequestException('Invalid q: expected a single string.');
  }
  const q = raw.replace(/\s+/g, ' ').trim();
  if (q.length === 0) return undefined;
  if (q.length > SCHOLARSHIP_LIST_QUERY_MAX_LENGTH) {
    throw new BadRequestException(
      `Invalid q: at most ${SCHOLARSHIP_LIST_QUERY_MAX_LENGTH} characters.`,
    );
  }
  return q;
}

/**
 * `status` : une ou plusieurs valeurs séparées par des virgules
 * (`open,upcoming`). Vide → pas de filtre.
 */
export function parseScholarshipListStatuses(
  raw?: string,
): ScholarshipListStatus[] | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== 'string') {
    throw new BadRequestException('Invalid status: expected a single string.');
  }
  const values = raw
    .split(',')
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
  if (values.length === 0) return undefined;
  const allowed: readonly string[] = SCHOLARSHIP_LIST_STATUSES;
  const unknown = values.filter((value) => !allowed.includes(value));
  if (unknown.length > 0) {
    throw new BadRequestException(
      `Invalid status filter: ${unknown.join(', ')}. ` +
        `Expected ${SCHOLARSHIP_LIST_STATUSES.join(' | ')}.`,
    );
  }
  return [...new Set(values)] as ScholarshipListStatus[];
}

/** `sort` : absent ou vide → `relevance` (l'ordre d'avant). */
export function parseScholarshipListSort(raw?: string): ScholarshipListSort {
  if (raw === undefined || raw === null) return 'relevance';
  if (typeof raw !== 'string') {
    throw new BadRequestException('Invalid sort: expected a single string.');
  }
  const value = raw.trim();
  if (value.length === 0) return 'relevance';
  const allowed: readonly string[] = SCHOLARSHIP_LIST_SORTS;
  if (!allowed.includes(value)) {
    throw new BadRequestException(
      `Invalid sort: ${value}. Expected ${SCHOLARSHIP_LIST_SORTS.join(' | ')}.`,
    );
  }
  return value as ScholarshipListSort;
}

/** Ce que le statut lit d'une fiche servie (le DTO public, dates ISO). */
export type ScholarshipStatusFacts = {
  deadlineAt: string | null;
  lastVerifiedAt?: string | null;
  currentCycle: {
    status: string;
    dateConfidence: string;
    opensAt: string | null;
    closesAt: string | null;
    estimatedOpenAt: string | null;
    estimatedCloseAt: string | null;
  } | null;
};

function toTime(value: string | null | undefined): number | null {
  if (!value) return null;
  const time = new Date(value).getTime();
  return Number.isFinite(time) ? time : null;
}

/**
 * Le statut tel que l'app le DIT — même règle que
 * `resolveScholarshipStatusLine` (lib/app/core/models/scholarship_follow.dart),
 * pour que « Ouvertes » côté filtre et « Ouverte · clôture … » côté carte ne
 * puissent pas se contredire :
 *
 *  · une clôture CONFIRMÉE passée, ou un cycle `closed` → `closed` ;
 *  · cycle `open` dont l'ouverture confirmée est à venir → `upcoming` (jamais
 *    « ouverte » avant `opensAt`) ;
 *  · cycle `open` sinon → `open` ;
 *  · ouverture confirmée à venir sur un cycle non estimé → `upcoming` ;
 *  · tout le reste (estimé, à confirmer) → `forecast`.
 *
 * Fiche sans cycle : une date limite (forcément future, `publicScholarshipWhere`)
 * vaut « ouverte » ; sans date du tout, « à confirmer » → `forecast`.
 */
export function scholarshipServedStatus(
  item: ScholarshipStatusFacts,
  now: Date = new Date(),
): ScholarshipServedStatus {
  const ref = now.getTime();
  const cycle = item.currentCycle;
  if (!cycle) {
    const deadline = toTime(item.deadlineAt);
    if (deadline === null) return 'forecast';
    return deadline <= ref ? 'closed' : 'open';
  }
  const estimated = cycle.dateConfidence === 'estimated';
  const confirmedClose =
    toTime(cycle.closesAt) ?? (estimated ? null : toTime(item.deadlineAt));
  if (cycle.status === 'closed' || (confirmedClose !== null && confirmedClose <= ref)) {
    return 'closed';
  }
  const opensAt = toTime(cycle.opensAt);
  const opensInFuture = opensAt !== null && opensAt > ref;
  if (cycle.status === 'open') return opensInFuture ? 'upcoming' : 'open';
  if (opensInFuture && !estimated) return 'upcoming';
  return 'forecast';
}

/**
 * La date de clôture qui sert au tri « clôture la plus proche » : confirmée
 * d'abord, sinon estimée, sinon la date limite. `null` → en fin de liste.
 */
export function scholarshipClosingTime(item: ScholarshipStatusFacts): number | null {
  const cycle = item.currentCycle;
  return (
    toTime(cycle?.closesAt) ??
    toTime(cycle?.estimatedCloseAt) ??
    toTime(item.deadlineAt)
  );
}

type SortableItem = ScholarshipStatusFacts & {
  title: string;
  matchScore: number;
};

/** Compare deux nombres nullables, les `null` en dernier. */
function compareNullable(
  a: number | null,
  b: number | null,
  direction: 'asc' | 'desc',
): number {
  if (a === null && b === null) return 0;
  if (a === null) return 1;
  if (b === null) return -1;
  return direction === 'asc' ? a - b : b - a;
}

/** L'ordre d'avant : pertinence décroissante, puis date limite croissante. */
function compareRelevance(a: SortableItem, b: SortableItem): number {
  if (b.matchScore !== a.matchScore) return b.matchScore - a.matchScore;
  const left = toTime(a.deadlineAt);
  const right = toTime(b.deadlineAt);
  if (left !== null && right !== null) return left - right;
  return 0;
}

/** Trie [items] en place selon [sort], dans la langue [lang]. */
export function sortScholarshipList<T extends SortableItem>(
  items: T[],
  sort: ScholarshipListSort,
  lang: 'fr' | 'en',
): T[] {
  const byTitle = (a: T, b: T) =>
    a.title.localeCompare(b.title, lang, { sensitivity: 'base' });
  switch (sort) {
    case 'deadline':
      return items.sort(
        (a, b) =>
          compareNullable(
            scholarshipClosingTime(a),
            scholarshipClosingTime(b),
            'asc',
          ) || byTitle(a, b),
      );
    case 'verified':
      return items.sort(
        (a, b) =>
          compareNullable(
            toTime(a.lastVerifiedAt),
            toTime(b.lastVerifiedAt),
            'desc',
          ) || compareRelevance(a, b),
      );
    case 'title':
      return items.sort((a, b) => byTitle(a, b) || compareRelevance(a, b));
    case 'relevance':
    default:
      return items.sort(compareRelevance);
  }
}
