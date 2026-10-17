/**
 * Communauté — types, règles d'affichage et appels de la console admin.
 *
 * Miroir des routes `/admin/community/*` de `docs/community-api-contract.md`
 * (community-api v1, §8 et §9). Les règles dupliquées ici (motif obligatoire,
 * durée de lecture seule, transitions possibles) ne servent qu'à griser des
 * boutons et à guider la saisie : le serveur reste seul juge.
 *
 * Tolérance : le contrat est « additif » (§ en-tête). Toute valeur
 * d'énumération inconnue (drapeau, motif, statut, badge) s'affiche sous sa
 * forme brute au lieu de casser l'écran, et une route absente (backend plus
 * ancien) se lit comme « bientôt » plutôt que comme une erreur.
 */
import { apiFetch, type ApiError } from './api-client';
import { AdminCapability, hasAdminCapability } from './admin-capabilities';

// ── Modèles (contrat §5 et §8.1) ───────────────────────────────────────────

export type PostType = 'question' | 'experience' | 'advice';
export type ContentStatus = 'visible' | 'pending_review' | 'hidden' | 'deleted';
export type AuthorKind = 'member' | 'kpb_team' | 'kpb_advisor' | 'kpb_assistant';
export type MentionType = 'scholarship' | 'country' | 'institution' | 'program';
export type ReportReason =
  | 'scam'
  | 'harassment'
  | 'inappropriate'
  | 'spam'
  | 'personal_info'
  | 'misinformation'
  | 'other';
export type ReportStatus = 'open' | 'actioned' | 'dismissed';
export type SanctionKind = 'warning' | 'read_only' | 'ban';
export type ContentAction = 'restore' | 'hide' | 'delete' | 'dismiss_reports';
export type QueueKind = 'all' | 'auto_hidden' | 'reported' | 'members';
export type TeamIdentity = 'kpb_team' | 'kpb_advisor';

export interface Mention {
  type: MentionType | string;
  id: string;
  label: string;
  countryId?: string | null;
}

/**
 * Segment de contenu (§5.3) : `text`, `mention`, `hashtag`, `link`. Forme
 * volontairement lâche — un `kind` inconnu est rendu par son `text` s'il en a.
 */
export interface Segment {
  kind: 'text' | 'mention' | 'hashtag' | 'link' | string;
  text?: string;
  type?: string;
  id?: string;
  label?: string;
  tag?: string;
  display?: string;
  url?: string;
}

export interface Hashtag {
  tag: string;
  display: string;
}

export interface AdminAuthor {
  kind: AuthorKind | string;
  memberId: string | null;
  displayName: string;
  countryName: string | null;
  badges: string[];
  userId?: string | null;
  fullName?: string | null;
  email?: string | null;
  isMinor?: boolean | null;
  /** Compte de moins de 7 jours (révision 1) ; à défaut, dérivé de `accountCreatedAt`. */
  isNewAccount?: boolean | null;
  accountCreatedAt?: string | null;
  adminId?: string | null;
}

export interface AdminPost {
  id: string;
  type: PostType | string;
  title: string;
  excerpt?: string;
  body?: string;
  segments?: Segment[];
  author: AdminAuthor;
  createdAt: string;
  editedAt?: string | null;
  lastActivityAt?: string;
  replyCount?: number;
  helpfulCount?: number;
  hasVerifiedAnswer?: boolean;
  isPinned?: boolean;
  mentions?: Mention[];
  hashtags?: Hashtag[];
  status: ContentStatus | string;
  statusReason: string | null;
  filterFlags?: string[];
  openReportCount?: number;
  deletedAt?: string | null;
  pinnedAt?: string | null;
}

export interface AdminReply {
  id: string;
  postId: string;
  body: string;
  segments?: Segment[];
  mentions?: Mention[];
  author: AdminAuthor;
  createdAt: string;
  editedAt?: string | null;
  helpfulCount?: number;
  isVerified?: boolean;
  verifiedAt?: string | null;
  status: ContentStatus | string;
  statusReason: string | null;
  filterFlags?: string[];
  openReportCount?: number;
  deletedAt?: string | null;
}

export interface AdminReport {
  id: string;
  targetType: 'post' | 'reply' | 'member' | string;
  targetId: string;
  reason: ReportReason | string;
  status: ReportStatus | string;
  createdAt: string;
  details?: string | null;
  reporter?: { memberId: string; displayName: string } | null;
  resolvedAt?: string | null;
  resolvedBy?: string | null;
  resolutionNote?: string | null;
}

export interface Sanction {
  id: string;
  kind: SanctionKind | string;
  reason: string;
  endsAt: string | null;
  createdAt: string;
  createdBy?: { adminId: string; name: string } | null;
  revokedAt: string | null;
  revokedBy?: string | null;
  active: boolean;
}

/** Ligne de `GET /admin/community/sanctions` (révision 1, §8.5). */
export interface SanctionWithMember extends Sanction {
  member: AdminAuthor;
}

export interface Restriction {
  kind: 'read_only' | 'ban' | string;
  until: string | null;
  reason: string;
}

export interface MemberStats {
  helpfulAnswersCount: number;
  postsCount: number;
  repliesCount: number;
}

export interface AdminMember extends AdminAuthor {
  charterVersion?: string | null;
  charterAcceptedAt?: string | null;
  restriction?: Restriction | null;
  stats?: MemberStats;
  sanctions?: Sanction[];
  openReportCount?: number;
}

export interface AdminMemberDetail extends AdminMember {
  recentPosts?: AdminPost[];
  recentReplies?: AdminReply[];
}

export interface ModerationLogEntry {
  id: string;
  action: string;
  targetType: 'post' | 'reply' | 'member' | string;
  targetId: string;
  reason: string | null;
  moderatorName: string | null;
  moderatorRole: string | null;
  createdAt: string;
  postId: string | null;
}

export interface QueueItem {
  key: string;
  targetType: 'post' | 'reply' | 'member' | string;
  post: AdminPost | null;
  reply: AdminReply | null;
  member: AdminMember | null;
  parentPost: { id: string; title: string; status: string } | null;
  reports: AdminReport[];
  openReportCount: number;
  flaggedAt: string;
  waitingHours: number;
}

export interface QueueResponse {
  counts: { autoHidden: number; reported: number; members: number };
  items: QueueItem[];
  nextCursor: string | null;
}

export interface Page<T> {
  items: T[];
  nextCursor: string | null;
}

export interface PostDetail {
  post: AdminPost;
  replies: AdminReply[];
  reports: AdminReport[];
  log: ModerationLogEntry[];
}

export interface CommunityStats {
  window: { from: string; to: string; days: number };
  posts: {
    total: number;
    byType: Partial<Record<string, number>>;
    byStatus: Partial<Record<string, number>>;
  };
  replies: { total: number; byTeam: number };
  helpfulReactions: number;
  reports: { opened: number; open: number; resolved: number; medianResolutionHours: number | null };
  autoHidden: number;
  /** Révision 1 : médiane création → première décision humaine (masqués auto). */
  autoHiddenMedianHandlingHours?: number | null;
  unansweredQuestions: number;
  /** Révision 1 : questions visibles sans réponse créées il y a plus de 48 h. */
  unansweredOver48h?: number;
  verifiedAnswers: number;
  activeMembers: number;
  newMembers: number;
  activeSanctions: number;
  daily: Array<{ date: string; posts: number; replies: number }>;
}

export interface FilterEntry {
  id: string;
  kind: 'allowed_domain' | 'blocked_term' | string;
  value: string;
  createdAt: string;
  createdBy: string | null;
}

export interface FiltersConfig {
  allowedDomains: { builtin: string[]; catalogHostsCount: number; custom: FilterEntry[] };
  blockedTerms: { builtinCount: number; custom: FilterEntry[] };
}

// ── Constantes du contrat ──────────────────────────────────────────────────

/** §4.2 : motif d'une action admin, 3 à 500 caractères. */
export const REASON_MIN = 3;
export const REASON_MAX = 500;
/** §8.5 : durée d'une lecture seule, 1 à 365 jours. */
export const READ_ONLY_MIN_DAYS = 1;
export const READ_ONLY_MAX_DAYS = 365;
/** §8.2 : délai d'action annoncé aux stores (À VALIDER côté contrat). */
export const MODERATION_SLA_HOURS = 24;
/** §8.6 : au plus 3 publications épinglées. */
export const PIN_LIMIT = 3;
/** §4.2 : limites de contenu (réponse de l'équipe, publication de l'équipe). */
export const REPLY_BODY_MAX = 3000;
export const POST_TITLE_MIN = 8;
export const POST_TITLE_MAX = 120;
export const POST_BODY_MIN = 20;
export const POST_BODY_MAX = 5000;

/**
 * Réglages que le contrat fixe côté serveur sans route pour les modifier
 * (§4.3, §9.3, §9.4) : affichés en lecture, marqués « bientôt modifiable ».
 */
export const SERVER_FIXED_SETTINGS = {
  reportsBeforeHide: 3,
  newAccountDays: 7,
  postsPerDayNew: 3,
  postsPerDayEstablished: 10,
  repliesPerHourNew: 10,
  repliesPerHourEstablished: 30,
  reportsPerDay: 20,
  editWindowMinutes: 15,
  charterVersion: '2026-10-v1',
} as const;

export const POST_TYPES: readonly PostType[] = ['question', 'experience', 'advice'];
export const CONTENT_STATUSES: readonly ContentStatus[] = [
  'visible',
  'pending_review',
  'hidden',
  'deleted',
];
export const QUEUE_KINDS: readonly QueueKind[] = ['all', 'auto_hidden', 'reported', 'members'];

/** Drapeaux connus du filtre (§8.1). Un drapeau inconnu s'affiche brut. */
export const FILTER_FLAGS = [
  'phone',
  'email',
  'whatsapp',
  'money_request',
  'mobile_money',
  'external_link',
  'profanity',
  'blocked_term',
  'disposable_email',
] as const;

export const REPORT_REASONS: readonly ReportReason[] = [
  'scam',
  'harassment',
  'inappropriate',
  'spam',
  'personal_info',
  'misinformation',
  'other',
];

export const STATUS_REASONS = [
  'auto_filter',
  'reports_threshold',
  'new_account_review',
  'moderation',
  'author_deleted',
  'moderation_deleted',
] as const;

/**
 * Valeurs de `ModerationLogEntry.action` (révision 1, §8.1) : décisions
 * humaines seulement. Réponses d'équipe, épinglage et filtre vont dans
 * `AdminAuditEvent`, pas dans ce journal.
 */
export const LOG_ACTIONS = [
  'restore',
  'hide',
  'delete',
  'dismiss_reports',
  'verify_answer',
  'unverify_answer',
  'sanction_warning',
  'sanction_read_only',
  'sanction_ban',
  'sanction_revoke',
  'member_reports_dismissed',
] as const;

export const BADGES = ['kpb_team', 'kpb_advisor', 'kpb_assistant', 'verified_alumni', 'ambassador'] as const;

export const STATUS_VARIANT: Record<string, 'neutral' | 'success' | 'warning' | 'danger' | 'info'> = {
  visible: 'success',
  pending_review: 'warning',
  hidden: 'danger',
  deleted: 'neutral',
};

export const SANCTION_VARIANT: Record<string, 'warning' | 'danger' | 'info'> = {
  warning: 'info',
  read_only: 'warning',
  ban: 'danger',
};

/**
 * Clé de message d'une valeur d'énumération, ou `null` si inconnue (le
 * composant affiche alors la valeur brute, lisible : `_` → espace).
 */
export function enumMessageKey(
  group:
    | 'flag'
    | 'reportReason'
    | 'status'
    | 'statusReason'
    | 'badge'
    | 'postType'
    | 'sanction'
    | 'logAction'
    | 'target',
  value: string,
): string | null {
  const known: Record<typeof group, readonly string[]> = {
    flag: FILTER_FLAGS,
    reportReason: REPORT_REASONS,
    status: CONTENT_STATUSES,
    statusReason: STATUS_REASONS,
    badge: BADGES,
    postType: POST_TYPES,
    sanction: ['warning', 'read_only', 'ban'],
    target: ['post', 'reply', 'member'],
    logAction: LOG_ACTIONS,
  };
  return known[group].includes(value) ? `communityAdmin.enum.${group}.${value}` : null;
}

/** Valeur brute lisible (« money_request » → « money request »). */
export function rawLabel(value: string): string {
  return value.replace(/_/g, ' ');
}

// ── Rôles (présentation seulement) ─────────────────────────────────────────

export interface CommunityPermissions {
  /** R + Counselor : lire les discussions et y répondre (révision 1). */
  read: boolean;
  /** R : lire, agir sur un contenu, répondre, vérifier, épingler. */
  moderate: boolean;
  /** S : avertir, lecture seule, bannir, lever. */
  sanction: boolean;
  /** C : modifier la liste blanche et les termes filtrés. */
  configureFilters: boolean;
  /** Identité réelle (nom complet, e-mail, date du compte). */
  viewIdentity: boolean;
}

export function communityPermissions(role: string | null | undefined): CommunityPermissions {
  return {
    read: hasAdminCapability(role, AdminCapability.ReadCommunityDiscussions),
    moderate: hasAdminCapability(role, AdminCapability.ModerateCommunity),
    sanction: hasAdminCapability(role, AdminCapability.SanctionCommunityMembers),
    configureFilters: hasAdminCapability(role, AdminCapability.ConfigureCommunityFilters),
    viewIdentity: hasAdminCapability(role, AdminCapability.ViewCommunityIdentity),
  };
}

// ── Saisie : motifs et sanctions ───────────────────────────────────────────

export type ReasonError = 'reasonRequired' | 'reasonTooShort' | 'reasonTooLong';

/** Motif obligatoire (§4.2) : espaces de bord retirés, 3 à 500 caractères. */
export function validateReason(reason: string): ReasonError | null {
  const trimmed = reason.trim();
  if (!trimmed) return 'reasonRequired';
  if (trimmed.length < REASON_MIN) return 'reasonTooShort';
  if (trimmed.length > REASON_MAX) return 'reasonTooLong';
  return null;
}

export interface SanctionInput {
  kind: SanctionKind;
  reason: string;
  durationDays: string;
  hideContent: boolean;
}

export type SanctionPayload = {
  kind: SanctionKind;
  reason: string;
  durationDays?: number;
  hideContent?: boolean;
};

/**
 * Corps de `POST /admin/community/members/:id/sanctions` (§8.5), ou les
 * erreurs de saisie (clés `communityAdmin.errors.*`). `durationDays` est
 * obligatoire pour `read_only` et interdit ailleurs ; `hideContent` n'a de
 * sens que pour un bannissement.
 */
export function buildSanctionPayload(
  input: SanctionInput,
): { ok: true; body: SanctionPayload } | { ok: false; errors: Record<string, string> } {
  const errors: Record<string, string> = {};
  const reasonError = validateReason(input.reason);
  if (reasonError) errors.reason = reasonError;
  let durationDays: number | undefined;
  if (input.kind === 'read_only') {
    const raw = input.durationDays.trim();
    const n = Number(raw);
    if (!/^\d+$/.test(raw) || n < READ_ONLY_MIN_DAYS || n > READ_ONLY_MAX_DAYS) {
      errors.durationDays = 'durationInvalid';
    } else {
      durationDays = n;
    }
  }
  if (Object.keys(errors).length) return { ok: false, errors };
  const body: SanctionPayload = { kind: input.kind, reason: input.reason.trim() };
  if (durationDays !== undefined) body.durationDays = durationDays;
  if (input.kind === 'ban' && input.hideContent) body.hideContent = true;
  return { ok: true, body };
}

/**
 * Actions de contenu proposées selon l'état (§8.4). Rétablir un contenu
 * supprimé par son auteur est refusé (409) : on ne le propose pas.
 */
export function availableContentActions(
  item: Pick<AdminPost, 'status' | 'statusReason' | 'openReportCount'>,
): ContentAction[] {
  const actions: ContentAction[] = [];
  const status = item.status;
  if (status === 'pending_review' || status === 'hidden') actions.push('restore');
  if (status === 'deleted' && item.statusReason === 'moderation_deleted') actions.push('restore');
  if (status === 'visible' || status === 'pending_review') actions.push('hide');
  if (status !== 'deleted') actions.push('delete');
  if ((item.openReportCount ?? 0) > 0 && status !== 'deleted') actions.push('dismiss_reports');
  return actions;
}

/** `notifyAuthor` n'a d'effet que pour ces actions (§8.4). */
export function actionNotifiesAuthor(action: ContentAction): boolean {
  return action !== 'dismiss_reports';
}

// ── File : urgence et ancienneté ───────────────────────────────────────────

/** Drapeaux qui signalent une tentative d'arnaque ou un contact hors plateforme. */
const SCAM_FLAGS = new Set(['money_request', 'mobile_money', 'whatsapp', 'phone', 'email']);
const SERIOUS_REPORTS = new Set(['scam', 'personal_info', 'harassment']);

export type QueueSort = 'oldest' | 'urgency';

function itemFlags(item: QueueItem): string[] {
  return item.post?.filterFlags ?? item.reply?.filterFlags ?? [];
}

function itemAuthor(item: QueueItem): AdminAuthor | null {
  return item.post?.author ?? item.reply?.author ?? item.member ?? null;
}

/**
 * Score d'urgence, simple et explicable (affiché au survol) :
 * arnaque / coordonnées (+5), signalement grave — arnaque, données
 * personnelles, harcèlement (+4), chaque signalement ouvert (+1, plafonné à
 * 5), auteur mineur (+2), délai d'action dépassé (+3).
 */
export function urgencyScore(item: QueueItem): number {
  let score = 0;
  if (itemFlags(item).some((flag) => SCAM_FLAGS.has(flag))) score += 5;
  if (item.reports.some((r) => SERIOUS_REPORTS.has(r.reason))) score += 4;
  score += Math.min(5, item.openReportCount);
  if (itemAuthor(item)?.isMinor) score += 2;
  if (isOverdue(item)) score += 3;
  return score;
}

export function isOverdue(item: Pick<QueueItem, 'waitingHours'>): boolean {
  return item.waitingHours >= MODERATION_SLA_HOURS;
}

/**
 * Le serveur trie déjà « plus ancien d'abord » (§8.2). Le tri par urgence
 * réordonne la page chargée (départage : le plus ancien d'abord).
 */
export function sortQueue(items: readonly QueueItem[], sort: QueueSort): QueueItem[] {
  const copy = [...items];
  const oldest = (a: QueueItem, b: QueueItem) =>
    b.waitingHours - a.waitingHours || a.flaggedAt.localeCompare(b.flaggedAt);
  if (sort === 'oldest') return copy.sort(oldest);
  return copy.sort((a, b) => urgencyScore(b) - urgencyScore(a) || oldest(a, b));
}

/** Contenu concerné par une ligne de file (publication ou réponse), sinon null. */
export function queueContent(
  item: QueueItem,
): { kind: 'post'; content: AdminPost } | { kind: 'reply'; content: AdminReply } | null {
  if (item.post) return { kind: 'post', content: item.post };
  if (item.reply) return { kind: 'reply', content: item.reply };
  return null;
}

/** Membre visé par une ligne de file (auteur du contenu, ou membre signalé). */
export function queueMemberId(item: QueueItem): string | null {
  return itemAuthor(item)?.memberId ?? null;
}

/** Membres les plus signalés d'abord (file `members`, §8.2). */
export function mostReportedMembers(items: readonly QueueItem[]): QueueItem[] {
  return items
    .filter((item) => item.member)
    .sort((a, b) => b.openReportCount - a.openReportCount || b.waitingHours - a.waitingHours);
}

// ── Raccourcis clavier de la file ──────────────────────────────────────────

export type QueueShortcut =
  | 'next'
  | 'previous'
  | 'restore'
  | 'hide'
  | 'delete'
  | 'dismiss_reports'
  | 'warning'
  | 'read_only'
  | 'ban';

const SHORTCUTS: Record<string, QueueShortcut> = {
  j: 'next',
  ArrowDown: 'next',
  k: 'previous',
  ArrowUp: 'previous',
  r: 'restore',
  m: 'hide',
  s: 'delete',
  c: 'dismiss_reports',
  a: 'warning',
  l: 'read_only',
  b: 'ban',
};

/** Touches affichées dans l'aide (même table que `shortcutFor`). */
export const SHORTCUT_KEYS: ReadonlyArray<[string, QueueShortcut]> = [
  ['j', 'next'],
  ['k', 'previous'],
  ['r', 'restore'],
  ['m', 'hide'],
  ['s', 'delete'],
  ['c', 'dismiss_reports'],
  ['a', 'warning'],
  ['l', 'read_only'],
  ['b', 'ban'],
];

/**
 * Action d'une touche, ou null. Ignorée pendant la saisie (champ, zone de
 * texte, liste) et avec un modificateur (Ctrl, Alt, Méta), pour ne jamais
 * voler un raccourci du navigateur ni une lettre tapée dans un motif.
 * Chaque action ouvre une confirmation avec motif : aucune n'agit seule.
 */
export function shortcutFor(event: {
  key: string;
  ctrlKey?: boolean;
  metaKey?: boolean;
  altKey?: boolean;
  targetTag?: string | null;
  targetEditable?: boolean;
}): QueueShortcut | null {
  if (event.ctrlKey || event.metaKey || event.altKey) return null;
  const tag = (event.targetTag ?? '').toUpperCase();
  if (event.targetEditable || tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return null;
  return SHORTCUTS[event.key] ?? SHORTCUTS[event.key.toLowerCase()] ?? null;
}

// ── Identité et affichage ──────────────────────────────────────────────────

/** Compte créé il y a moins de 7 jours (§4.3) — dérivé, pas la date exacte. */
export function isNewAccount(
  author: Pick<AdminAuthor, 'accountCreatedAt' | 'isNewAccount'>,
  now = Date.now(),
): boolean {
  if (typeof author.isNewAccount === 'boolean') return author.isNewAccount;
  if (!author.accountCreatedAt) return false;
  const created = Date.parse(author.accountCreatedAt);
  if (Number.isNaN(created)) return false;
  return now - created < SERVER_FIXED_SETTINGS.newAccountDays * 24 * 3600 * 1000;
}

/**
 * Ce que la console montre d'un auteur. Sans le droit d'identité, seuls le
 * nom public, le pays, les badges et les indicateurs dérivés (mineur, compte
 * récent) passent — jamais l'e-mail ni le nom complet.
 */
export function visibleIdentity(
  author: AdminAuthor,
  canViewIdentity: boolean,
): { fullName: string | null; email: string | null; accountCreatedAt: string | null } {
  if (!canViewIdentity) return { fullName: null, email: null, accountCreatedAt: null };
  return {
    fullName: author.fullName ?? null,
    email: author.email ?? null,
    accountCreatedAt: author.accountCreatedAt ?? null,
  };
}

/** Texte brut d'un contenu à partir de ses segments (repli : `body`). */
export function plainText(content: { segments?: Segment[]; body?: string; excerpt?: string }): string {
  if (content.segments && content.segments.length) {
    return content.segments
      .map((segment) => {
        if (segment.kind === 'mention') return `@${String(segment.label ?? '')}`;
        if (segment.kind === 'hashtag') return `#${String(segment.display ?? segment.tag ?? '')}`;
        return typeof segment.text === 'string' ? segment.text : '';
      })
      .join('');
  }
  return content.body ?? content.excerpt ?? '';
}

export function formatHours(hours: number | null | undefined, locale: 'fr' | 'en' = 'fr'): string {
  if (hours === null || hours === undefined || Number.isNaN(hours)) return '—';
  if (hours < 1) return '< 1 h';
  if (hours < 48) return `${Math.round(hours * 10) / 10} h`.replace('.', locale === 'fr' ? ',' : '.');
  const days = Math.floor(hours / 24);
  return locale === 'fr' ? `${days} j` : `${days} d`;
}

// ── Erreurs ────────────────────────────────────────────────────────────────

export interface CommunityErrorInfo {
  /** Route absente du serveur (backend plus ancien) : afficher « bientôt ». */
  unavailable: boolean;
  status: number | null;
  code: string | null;
  details: Record<string, unknown> | null;
  message: string;
}

/** Codes du contrat qui ont un message dédié (`communityAdmin.errors.<code>`). */
export const KNOWN_ERROR_CODES = [
  'community_pin_limit',
  'community_invalid_transition',
  'community_post_not_found',
  'community_reply_not_found',
  'community_member_not_found',
  'community_invalid_mention',
  'community_too_many_mentions',
  'community_too_many_hashtags',
  'community_invalid_cursor',
  // Révision 2 (bot Vérif, §8.9).
  'community_bot_draft_not_found',
  'community_bot_draft_obsolete',
] as const;

/**
 * Lit une erreur de `apiFetch`. Une 404 SANS `code` dont le message est celui
 * du routeur Nest (« Cannot GET /api/… ») signifie que la route n'existe pas
 * encore : la console affiche « bientôt » au lieu d'une alerte rouge. Une 404
 * avec un `code` du contrat (publication introuvable…) reste une vraie erreur.
 */
export function readCommunityError(error: unknown): CommunityErrorInfo {
  const apiError = error as ApiError | undefined;
  const status = typeof apiError?.status === 'number' ? apiError.status : null;
  let code: string | null = null;
  let details: Record<string, unknown> | null = null;
  let rawMessage = '';
  if (apiError?.body) {
    try {
      const parsed = JSON.parse(apiError.body) as Record<string, unknown>;
      if (typeof parsed.code === 'string') code = parsed.code;
      if (parsed.details && typeof parsed.details === 'object') {
        details = parsed.details as Record<string, unknown>;
      }
      if (typeof parsed.message === 'string') rawMessage = parsed.message;
    } catch {
      rawMessage = apiError.body;
    }
  }
  const message = error instanceof Error ? error.message : String(error ?? '');
  const unavailable =
    (status === 404 && !code && /^Cannot (GET|POST|PUT|PATCH|DELETE) /.test(rawMessage || message)) ||
    status === 501;
  return { unavailable, status, code, details, message };
}

/**
 * Clé de message à afficher pour une erreur (ou null : afficher `message`).
 * 401 est géré par `apiFetch` (retour à la connexion) ; 403 = rôle insuffisant.
 */
export function communityErrorMessageKey(info: CommunityErrorInfo): string | null {
  if (info.unavailable) return 'communityAdmin.errors.unavailable';
  if (info.code && (KNOWN_ERROR_CODES as readonly string[]).includes(info.code)) {
    return `communityAdmin.errors.${info.code}`;
  }
  if (info.status === 403) return 'communityAdmin.errors.forbidden';
  if (info.status === 429) return 'communityAdmin.errors.rateLimited';
  if (info.status === null || info.status >= 500) return 'communityAdmin.errors.server';
  return null;
}

// ── Navigation (onglets dans l'URL) ────────────────────────────────────────

export const COMMUNITY_TABS = [
  'dashboard',
  'queue',
  'content',
  'members',
  'settings',
  'log',
  'bot',
  'taxonomy',
] as const;
export type CommunityTab = (typeof COMMUNITY_TABS)[number];

export function parseCommunityTab(value: string | null | undefined): CommunityTab {
  return (COMMUNITY_TABS as readonly string[]).includes(value ?? '') ? (value as CommunityTab) : 'queue';
}

/**
 * Onglets visibles : tout pour le rôle R (les boutons d'écriture se règlent
 * ensuite action par action) ; « Contenus » seul pour le conseiller.
 */
export function visibleCommunityTabs(permissions: CommunityPermissions): CommunityTab[] {
  if (permissions.moderate) return [...COMMUNITY_TABS];
  if (permissions.read) return ['content'];
  return [];
}

// ── Appels ─────────────────────────────────────────────────────────────────

const BASE = '/admin/community';

function query(params: Record<string, string | number | null | undefined>): string {
  const q = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== '') q.set(key, String(value));
  }
  const s = q.toString();
  return s ? `?${s}` : '';
}

export const communityAdminApi = {
  queue: (kind: QueueKind, cursor?: string | null, limit = 30) =>
    apiFetch<QueueResponse>(`${BASE}/queue${query({ kind, cursor, limit })}`),
  posts: (filters: { status?: string; type?: string; q?: string; cursor?: string | null; limit?: number }) =>
    apiFetch<Page<AdminPost>>(`${BASE}/posts${query({ ...filters, limit: filters.limit ?? 20 })}`),
  post: (id: string) => apiFetch<PostDetail>(`${BASE}/posts/${encodeURIComponent(id)}`),
  member: (memberId: string) => apiFetch<AdminMemberDetail>(`${BASE}/members/${encodeURIComponent(memberId)}`),
  log: (cursor?: string | null, limit = 30) =>
    apiFetch<Page<ModerationLogEntry>>(`${BASE}/moderation-log${query({ cursor, limit })}`),
  stats: (days = 30) => apiFetch<CommunityStats>(`${BASE}/stats${query({ days })}`),
  postAction: (id: string, body: { action: ContentAction; reason: string; notifyAuthor?: boolean }) =>
    apiFetch<AdminPost>(`${BASE}/posts/${encodeURIComponent(id)}/actions`, { method: 'POST', body }),
  replyAction: (id: string, body: { action: ContentAction; reason: string; notifyAuthor?: boolean }) =>
    apiFetch<AdminReply>(`${BASE}/replies/${encodeURIComponent(id)}/actions`, { method: 'POST', body }),
  sanction: (memberId: string, body: SanctionPayload) =>
    apiFetch<Sanction>(`${BASE}/members/${encodeURIComponent(memberId)}/sanctions`, { method: 'POST', body }),
  sanctions: (status: 'active' | 'all' = 'active', cursor?: string | null, limit = 30) =>
    apiFetch<Page<SanctionWithMember>>(`${BASE}/sanctions${query({ status, cursor, limit })}`),
  dismissMemberReports: (memberId: string, reason: string) =>
    apiFetch<{ memberId: string; dismissed: number }>(
      `${BASE}/members/${encodeURIComponent(memberId)}/reports/dismiss`,
      { method: 'POST', body: { reason } },
    ),
  revokeSanction: (id: string, reason: string) =>
    apiFetch<Sanction>(`${BASE}/sanctions/${encodeURIComponent(id)}/revoke`, {
      method: 'POST',
      body: { reason },
    }),
  teamReply: (postId: string, body: { body: string; as: TeamIdentity; verified?: boolean }) =>
    apiFetch<AdminReply>(`${BASE}/posts/${encodeURIComponent(postId)}/replies`, { method: 'POST', body }),
  setVerified: (replyId: string, verified: boolean) =>
    apiFetch<AdminReply>(`${BASE}/replies/${encodeURIComponent(replyId)}/verified`, {
      method: 'PUT',
      body: { verified },
    }),
  setPinned: (postId: string, pinned: boolean) =>
    apiFetch<AdminPost>(`${BASE}/posts/${encodeURIComponent(postId)}/pin`, {
      method: 'PUT',
      body: { pinned },
    }),
  teamPost: (body: { type: PostType; title: string; body: string; as: TeamIdentity; pinned?: boolean }) =>
    apiFetch<AdminPost>(`${BASE}/posts`, { method: 'POST', body }),
  filters: () => apiFetch<FiltersConfig>(`${BASE}/filters`),
  addFilter: (kind: 'allowed_domain' | 'blocked_term', value: string) =>
    apiFetch<FilterEntry>(`${BASE}/filters`, { method: 'POST', body: { kind, value } }),
  removeFilter: (id: string) =>
    apiFetch<void>(`${BASE}/filters/${encodeURIComponent(id)}`, { method: 'DELETE' }),
  testFilter: (text: string) =>
    apiFetch<{ flags: string[]; wouldHide: boolean }>(`${BASE}/filters/test`, {
      method: 'POST',
      body: { text },
    }),
  // Bot « Vérif » (révision 2, §8.9).
  botDrafts: (status: BotDraftListStatus, cursor?: string | null, limit = 20) =>
    apiFetch<BotDraftPage>(`${BASE}/bot/drafts${query({ status, cursor, limit })}`),
  botDraft: (id: string) => apiFetch<BotDraftDetail>(`${BASE}/bot/drafts/${encodeURIComponent(id)}`),
  botPublish: (id: string, body: { text?: string; verified?: boolean }) =>
    apiFetch<{ draft: BotDraft; reply: AdminReply }>(`${BASE}/bot/drafts/${encodeURIComponent(id)}/publish`, {
      method: 'POST',
      body,
    }),
  botReject: (id: string, reason: string) =>
    apiFetch<BotDraft>(`${BASE}/bot/drafts/${encodeURIComponent(id)}/reject`, { method: 'POST', body: { reason } }),
  botRegenerate: (id: string) =>
    apiFetch<BotDraft>(`${BASE}/bot/drafts/${encodeURIComponent(id)}/regenerate`, { method: 'POST' }),
  botStats: (days = 30) => apiFetch<BotStats>(`${BASE}/bot/stats${query({ days })}`),
};

// ── Bot « Vérif » (révision 2, §8.9 et §14) ────────────────────────────────

export type BotMode = 'review' | 'auto' | 'off';
export type BotDraftStatus = 'queued' | 'skipped' | 'proposed' | 'published' | 'rejected' | 'obsolete';
export type BotDraftListStatus = BotDraftStatus | 'all';

export const BOT_LIST_STATUSES: readonly BotDraftListStatus[] = [
  'proposed',
  'obsolete',
  'published',
  'rejected',
  'skipped',
  'all',
];

/** Statuts connus (clé `communityAdmin.bot.status.*`) ; inconnu : affiché brut. */
export const BOT_STATUSES: readonly BotDraftStatus[] = ['queued', 'skipped', 'proposed', 'published', 'rejected', 'obsolete'];

export const BOT_STATUS_VARIANT: Record<string, 'neutral' | 'success' | 'warning' | 'danger' | 'info'> = {
  queued: 'neutral',
  skipped: 'neutral',
  proposed: 'info',
  published: 'success',
  rejected: 'danger',
  obsolete: 'warning',
};

export interface BotSource {
  type: MentionType | string;
  id: string;
  label: string;
  url: string | null;
  verifiedAt: string | null;
  stale: boolean;
}

export interface BotDraft {
  id: string;
  postId: string;
  status: BotDraftStatus | string;
  statusReason: string | null;
  lang: 'fr' | 'en' | string;
  intents: string[];
  entities: Array<{ type: string; id: string; label: string; resolvedBy: 'mention' | 'name' | string }>;
  facts: Record<string, unknown> | null;
  sources: BotSource[];
  factsHash: string | null;
  proposedText: string | null;
  writer: 'template' | 'llm' | string | null;
  llmFallbackReason: string | null;
  confidence: 'high' | 'medium' | 'low' | string | null;
  complete: boolean;
  scamCaution: boolean;
  createdAt: string;
  generatedAt: string | null;
  processedAt: string | null;
  processedBy: { adminId: string; name: string } | null;
  rejectReason: string | null;
  publishedReplyId: string | null;
  publishedVerified: boolean;
  autoPublished: boolean;
  post?: { id: string; title: string; type: string; status: string; createdAt: string } | null;
}

export interface BotDraftPage {
  mode?: BotMode | string;
  items: BotDraft[];
  nextCursor: string | null;
}

export interface BotDraftDetail {
  mode?: BotMode | string;
  draft: BotDraft;
  post: AdminPost;
  live: { postVisible: boolean; factsChanged: boolean };
}

export interface BotStats {
  mode: BotMode | string;
  llmEnabled: boolean;
  window: { from: string; to: string; days: number };
  current: Partial<Record<BotDraftStatus, number>>;
  created: Partial<Record<BotDraftStatus, number>>;
  autoPublished: number;
  publishedVerified: number;
  llmWritten: number;
  medianHandlingHours: number | null;
}

/**
 * Le brouillon est-il dépassé ? Statut `obsolete`, ou contrôle en direct du
 * détail (publication plus visible, faits changés depuis la rédaction).
 */
export function isBotDraftStale(draft: Pick<BotDraft, 'status'>, live?: BotDraftDetail['live'] | null): boolean {
  if (draft.status === 'obsolete') return true;
  if (!live || draft.status !== 'proposed') return false;
  return !live.postVisible || live.factsChanged;
}

/** Boutons possibles selon l'état (le serveur reste juge). */
export function botDraftActions(
  draft: Pick<BotDraft, 'status'>,
  live?: BotDraftDetail['live'] | null,
): { publish: boolean; reject: boolean; regenerate: boolean } {
  const stale = isBotDraftStale(draft, live);
  return {
    publish: draft.status === 'proposed' && !stale,
    reject: draft.status === 'proposed' || draft.status === 'obsolete',
    regenerate: draft.status !== 'published' && draft.status !== 'queued',
  };
}

/** Texte publié : mêmes bornes qu'une réponse (§4.2). */
export function validateBotText(text: string): 'bodyRequired' | 'bodyTooLong' | null {
  return validateTeamReply(text);
}

/** Lien officiel cliquable : http(s) seulement (sources du catalogue). */
export function safeSourceUrl(url: string | null | undefined): string | null {
  if (!url) return null;
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' || parsed.protocol === 'http:' ? parsed.toString() : null;
  } catch {
    return null;
  }
}

// ── Saisie : réglages et contenus de l'équipe ──────────────────────────────

/**
 * Domaine de la liste blanche (§8.8) : hôte nu ou suffixe `*.`, en
 * minuscules. On accepte une URL collée et on n'en garde que l'hôte.
 */
export function normalizeDomainInput(value: string): string | null {
  let v = value.trim().toLowerCase();
  if (!v) return null;
  v = v.replace(/^https?:\/\//, '').replace(/[/?#].*$/, '').replace(/:\d+$/, '');
  if (v.startsWith('www.')) v = v.slice(4);
  const wildcard = v.startsWith('*.');
  const host = wildcard ? v.slice(2) : v;
  if (!/^(?=.{3,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(host)) return null;
  return wildcard ? `*.${host}` : host;
}

/** Terme filtré (§8.8) : 2 à 60 caractères. */
export function normalizeTermInput(value: string): string | null {
  const v = value.trim().replace(/\s+/g, ' ');
  return v.length >= 2 && v.length <= 60 ? v : null;
}

export function validateTeamReply(body: string): 'bodyRequired' | 'bodyTooLong' | null {
  const trimmed = body.trim();
  if (trimmed.length < 2) return 'bodyRequired';
  if (trimmed.length > REPLY_BODY_MAX) return 'bodyTooLong';
  return null;
}

export function validateTeamPost(input: { title: string; body: string }): Record<string, string> {
  const errors: Record<string, string> = {};
  const title = input.title.trim();
  const body = input.body.trim();
  if (title.length < POST_TITLE_MIN || title.length > POST_TITLE_MAX) errors.title = 'titleLength';
  if (body.length < POST_BODY_MIN || body.length > POST_BODY_MAX) errors.body = 'postBodyLength';
  return errors;
}

/**
 * Lien d'un écran de la console (onglet, discussion, membre) : l'état vit dans
 * l'URL pour qu'un lien partagé dans l'équipe ouvre le même écran.
 */
export function communityHref(target: { tab: CommunityTab; post?: string | null; member?: string | null }): string {
  const q = new URLSearchParams();
  if (target.tab !== 'queue') q.set('tab', target.tab);
  if (target.post) q.set('post', target.post);
  if (target.member) q.set('member', target.member);
  const s = q.toString();
  return s ? `/community?${s}` : '/community';
}

/**
 * Onglet effectif : une discussion ouvre « Contenus », un membre « Membres ».
 * Un onglet hors des onglets visibles retombe sur le premier visible (le
 * conseiller atterrit sur « Contenus »).
 */
export function resolveCommunityTab(
  params: { tab: string | null; post: string | null; member: string | null },
  visible: readonly CommunityTab[] = COMMUNITY_TABS,
): CommunityTab {
  const wanted: CommunityTab = params.post
    ? 'content'
    : params.member
      ? 'members'
      : parseCommunityTab(params.tab);
  return visible.includes(wanted) ? wanted : (visible[0] ?? wanted);
}
