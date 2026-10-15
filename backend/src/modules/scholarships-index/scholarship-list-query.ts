/**
 * Paramètres OPTIONNELS de `GET /scholarships` (chantier I) : recherche (`q`),
 * statut (`status`) et tri (`sort`).
 *
 * Tous facultatifs : les builds en store ne les envoient pas, et leur réponse
 * doit rester exactement celle d'avant (tri par pertinence, aucun filtre).
 *
 * TOLÉRANTS, comme `fundingType` ou `limit` sur la même route : une valeur
 * inconnue est IGNORÉE (statut inconnu retiré, tri inconnu → `relevance`,
 * recherche trop longue tronquée), jamais un 400. Une app plus récente que le
 * serveur (un statut ajouté plus tard) doit continuer à afficher la liste.
 * L'honnêteté passe par l'écho `query` de la réponse : il dit ce qui a été
 * réellement APPLIQUÉ, et un client qui demandait autre chose le voit.
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

/**
 * Les valeurs texte d'un paramètre de requête. Express rend un tableau quand
 * la clé est répétée (`?status=open&status=upcoming`) : on les garde toutes ;
 * tout ce qui n'est pas du texte est ignoré.
 */
function queryStrings(raw: unknown): string[] {
  if (typeof raw === 'string') return [raw];
  if (Array.isArray(raw)) {
    return raw.filter((value): value is string => typeof value === 'string');
  }
  return [];
}

/**
 * `q` : texte libre, espaces repliés, tronqué à
 * [SCHOLARSHIP_LIST_QUERY_MAX_LENGTH] ; vide → pas de recherche. Clé répétée :
 * la première valeur.
 */
export function parseScholarshipListQuery(raw?: unknown): string | undefined {
  const [first] = queryStrings(raw);
  if (first === undefined) return undefined;
  const q = first
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, SCHOLARSHIP_LIST_QUERY_MAX_LENGTH)
    .trim();
  return q.length === 0 ? undefined : q;
}

/**
 * `status` : une ou plusieurs valeurs séparées par des virgules
 * (`open,upcoming`), ou la clé répétée. Les valeurs inconnues sont retirées ;
 * s'il n'en reste aucune → pas de filtre (`query.status: null` le dit).
 */
export function parseScholarshipListStatuses(
  raw?: unknown,
): ScholarshipListStatus[] | undefined {
  const allowed: readonly string[] = SCHOLARSHIP_LIST_STATUSES;
  const values = queryStrings(raw)
    .flatMap((value) => value.split(','))
    .map((value) => value.trim())
    .filter((value) => allowed.includes(value));
  if (values.length === 0) return undefined;
  return [...new Set(values)] as ScholarshipListStatus[];
}

/**
 * `sort` : absent, vide ou inconnu → `relevance` (l'ordre d'avant). Clé
 * répétée : la première valeur connue.
 */
export function parseScholarshipListSort(raw?: unknown): ScholarshipListSort {
  const allowed: readonly string[] = SCHOLARSHIP_LIST_SORTS;
  const known = queryStrings(raw)
    .map((value) => value.trim())
    .find((value) => allowed.includes(value));
  return (known as ScholarshipListSort | undefined) ?? 'relevance';
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
 * Le statut tel que l'app le DIT — même règle que `scholarshipUrgencyOf`
 * (lib/app/features/scholarships/scholarship_urgency.dart, bâti sur
 * `resolveScholarshipStatusLine`),
 * pour que « Ouvertes » côté filtre et « Ouverte · clôture … » côté carte ne
 * puissent pas se contredire :
 *
 *  · une clôture CONFIRMÉE passée, ou un cycle fermé par l'équipe → `closed` ;
 *  · un cycle `closed` seulement parce que sa clôture ESTIMÉE est passée →
 *    `forecast` (l'app dit « Date à confirmer », pas « Clôturée ») ;
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
  if (confirmedClose !== null && confirmedClose <= ref) return 'closed';
  if (cycle.status === 'closed') {
    // Fermé par l'équipe (clôture confirmée encore à venir, ou aucune clôture
    // estimée pour l'expliquer) → `closed`. Mais `servedCycleStatus` sert
    // aussi `closed` dès qu'une clôture ESTIMÉE est passée : rien n'est alors
    // confirmé, l'app dit « Date à confirmer » — c'est `forecast`.
    if (toTime(cycle.closesAt) !== null) return 'closed';
    const estimatedClose = toTime(cycle.estimatedCloseAt);
    return estimatedClose === null || estimatedClose > ref ? 'closed' : 'forecast';
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
