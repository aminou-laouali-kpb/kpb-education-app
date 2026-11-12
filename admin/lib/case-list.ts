/**
 * Liste des dossiers, côté admin.
 *
 * Contrat backend :
 * - `GET /admin/cases?status=&advisor=&unassigned=true&q=&awaiting=true&cursor=`
 *   → `{ items, nextCursor }`, 50 dossiers par page, du plus récent au plus
 *   ancien. Les filtres et la recherche sont appliqués par le serveur ;
 *   `cursor` est le `nextCursor` de la page précédente. Les éléments ne
 *   portent ni tâches, ni historique, ni notes.
 * - `GET /admin/cases/summary` → `{ awaitingCount, advisors }`, sur tous les
 *   dossiers visibles par l'agent (pas sur la page chargée).
 * - `GET /admin/cases/:id` → le dossier ouvert, avec ses tâches, ses notes et
 *   son historique.
 *
 * Avant, la page recevait TOUS les dossiers avec toutes leurs relations
 * (environ 1 250 dossiers et plus de 80 000 événements en production) et
 * triait dans le navigateur. Tout ce qui se teste sans navigateur vit ici.
 */

import type { CaseReplyFields } from './case-messages';
import type { CaseScholarshipFields } from './case-scholarship';

export interface CaseTaskItem {
  id: string;
  title: string;
  assigneeName: string | null;
  status: string;
  dueAt: string | null;
}

export interface CaseNoteItem {
  id: string;
  authorName: string;
  authorRole: string;
  body: string;
  createdAt: string;
}

export interface CaseTimelineItem {
  id: string;
  title: string;
  description: string;
  status: string;
  createdAt: string;
}

/** Une ligne de la liste : ce que le tableau affiche, rien de plus. */
export interface AdminCaseListItem extends CaseScholarshipFields, CaseReplyFields {
  id: string;
  referenceCode: string;
  studentName: string;
  studentEmail: string;
  preferredLanguage: string;
  type: string;
  status: string;
  contextLabel: string;
  assignedAdvisorName: string | null;
  nextStepTitle: string;
  nextStepDescription: string;
}

/** Le dossier ouvert : la ligne, plus ses relations. */
export interface AdminCaseDetail extends AdminCaseListItem {
  tasks: CaseTaskItem[];
  internalNotes: CaseNoteItem[];
  timeline: CaseTimelineItem[];
  /** Vrai si l'historique dépasse ce que le serveur rend (les plus récents). */
  timelineTruncated?: boolean;
}

export interface CaseListFilters {
  /** Statut exact, ou '' pour tous. */
  status: string;
  /** Nom du conseiller, `UNASSIGNED_ADVISOR`, ou '' pour tous. */
  advisor: string;
  /** Texte recherché, ou ''. */
  q: string;
  /** Seulement les dossiers où l'élève attend une réponse. */
  awaiting: boolean;
}

export const EMPTY_CASE_LIST_FILTERS: CaseListFilters = {
  status: '',
  advisor: '',
  q: '',
  awaiting: false,
};

/**
 * Valeur du sélecteur pour « Sans conseiller ». Elle n'est jamais envoyée
 * comme un nom : elle devient `unassigned=true`.
 */
export const UNASSIGNED_ADVISOR = '__unassigned__';

/**
 * Le nom à afficher dans la colonne « Conseiller », ou `null` si le dossier
 * n'en a pas. Un nom vide ou fait d'espaces compte comme « sans conseiller » :
 * c'est ce que fait le filtre `unassigned=true` côté serveur, et la colonne
 * restait blanche au lieu de dire « Non assigné ».
 */
export function displayedAdvisorName(
  name: string | null | undefined,
): string | null {
  const trimmed = name?.trim();
  return trimmed ? trimmed : null;
}

export const CASE_LIST_SUMMARY_PATH = '/admin/cases/summary';

export function caseDetailPath(caseId: string): string {
  return `/admin/cases/${encodeURIComponent(caseId)}`;
}

/**
 * Chemin d'une page de la liste. Un filtre vide n'est pas envoyé : le serveur
 * refuse tout paramètre inconnu ou vide de sens, et « tous les statuts » se
 * dit en n'envoyant rien.
 */
export function caseListPath(
  filters: CaseListFilters,
  cursor?: string | null,
): string {
  const params = new URLSearchParams();
  if (filters.status) params.set('status', filters.status);
  if (filters.advisor === UNASSIGNED_ADVISOR) {
    params.set('unassigned', 'true');
  } else if (filters.advisor.trim()) {
    params.set('advisor', filters.advisor.trim());
  }
  const q = normalizeCaseSearch(filters.q);
  if (q) params.set('q', q);
  if (filters.awaiting) params.set('awaiting', 'true');
  if (cursor) params.set('cursor', cursor);
  const query = params.toString();
  return query ? `/admin/cases?${query}` : '/admin/cases';
}

/** Le serveur borne la recherche à 120 caractères et refuserait au-delà. */
export const CASE_SEARCH_MAX_LENGTH = 120;

export function normalizeCaseSearch(value: string): string {
  return value.replace(/\s+/g, ' ').trim().slice(0, CASE_SEARCH_MAX_LENGTH);
}

export function hasActiveCaseFilters(filters: CaseListFilters): boolean {
  return (
    filters.status !== '' ||
    filters.advisor !== '' ||
    normalizeCaseSearch(filters.q) !== '' ||
    filters.awaiting
  );
}

export interface CaseListPage<T> {
  items: T[];
  nextCursor: string | null;
}

/**
 * Lit une page. Un backend antérieur rend encore un tableau nu (tous les
 * dossiers d'un coup) : pendant un déploiement où l'admin arrive avant l'API,
 * la page l'affiche tel quel plutôt que de planter.
 */
export function normalizeCaseListPage<T>(response: unknown): CaseListPage<T> {
  if (Array.isArray(response)) {
    return { items: response as T[], nextCursor: null };
  }
  if (response && typeof response === 'object') {
    const { items, nextCursor } = response as {
      items?: unknown;
      nextCursor?: unknown;
    };
    return {
      items: Array.isArray(items) ? (items as T[]) : [],
      nextCursor:
        typeof nextCursor === 'string' && nextCursor !== '' ? nextCursor : null,
    };
  }
  return { items: [], nextCursor: null };
}

/**
 * Ajoute la page suivante. Un dossier déjà affiché n'est pas répété : il
 * garde sa place et prend les valeurs les plus récentes.
 */
export function appendCasePage<T extends { id: string }>(
  current: readonly T[],
  page: readonly T[],
): T[] {
  const incoming = new Map(page.map((item) => [item.id, item]));
  const merged = current.map((item) => incoming.get(item.id) ?? item);
  const known = new Set(current.map((item) => item.id));
  return [...merged, ...page.filter((item) => !known.has(item.id))];
}

/**
 * Après une action sur le dossier ouvert (statut, conseiller, étape), sa
 * ligne reprend les valeurs du dossier relu, sans recharger la liste : la
 * position de lecture et les pages déjà chargées sont conservées. Les champs
 * propres au détail (tâches, notes, historique) ne passent pas dans la ligne.
 */
const DETAIL_ONLY_KEYS = [
  'tasks',
  'internalNotes',
  'timeline',
  'timelineTruncated',
] as const;

export function patchCaseListItem<T extends AdminCaseListItem>(
  items: readonly T[],
  detail: AdminCaseDetail,
): T[] {
  return items.map((item) => {
    if (item.id !== detail.id) return item;
    const row: Partial<AdminCaseDetail> = { ...detail };
    for (const key of DETAIL_ONLY_KEYS) delete row[key];
    return { ...item, ...row };
  });
}

export interface CaseListSummary {
  /** Dossiers où l'élève attend une réponse, sur toute la portée de l'agent. */
  awaitingCount: number;
  /** Noms des conseillers proposés dans le filtre. */
  advisors: string[];
}

export const EMPTY_CASE_LIST_SUMMARY: CaseListSummary = {
  awaitingCount: 0,
  advisors: [],
};

export function normalizeCaseListSummary(response: unknown): CaseListSummary {
  if (!response || typeof response !== 'object') return EMPTY_CASE_LIST_SUMMARY;
  const { awaitingCount, advisors } = response as {
    awaitingCount?: unknown;
    advisors?: unknown;
  };
  return {
    awaitingCount:
      typeof awaitingCount === 'number' && Number.isFinite(awaitingCount)
        ? Math.max(0, Math.trunc(awaitingCount))
        : 0,
    advisors: Array.isArray(advisors)
      ? advisors.filter(
          (name): name is string => typeof name === 'string' && name.trim() !== '',
        )
      : [],
  };
}

/**
 * Ce que le fil ouvert a vu de « réponse attendue », dossier par dossier.
 * Quand cette valeur change (l'équipe vient de répondre, l'élève vient
 * d'écrire), le compteur du serveur n'est plus à jour : la page le relit.
 */
export function awaitingSignature(
  overrides: Readonly<Record<string, CaseReplyFields>>,
): string {
  return Object.keys(overrides)
    .sort()
    .map((id) => `${id}:${overrides[id].awaitingReply === true ? 1 : 0}`)
    .join('|');
}
