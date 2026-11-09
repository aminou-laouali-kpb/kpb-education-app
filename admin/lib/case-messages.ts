/**
 * Fil de messages étudiant ↔ équipe d'un dossier, côté admin.
 *
 * Contrat backend :
 * - `GET  /admin/cases/:id/messages?limit=50&before=<messageId>` →
 *   `{ items, hasMore }`, du plus ancien au plus récent ; `before` remonte
 *   dans l'historique.
 * - `POST /admin/cases/:id/messages` `{ body, clientMessageId }` → le message
 *   créé, idempotent sur `clientMessageId`.
 *
 * Tout ce qui se teste sans navigateur vit ici ; le composant ne fait que
 * l'appeler.
 */

export type CaseMessageSenderRole =
  | 'student'
  | 'system'
  | 'counselor'
  | 'commercial'
  | 'admin'
  | 'super_admin'
  | (string & {});

export interface CaseMessage {
  id: string;
  senderName: string;
  senderRole: CaseMessageSenderRole;
  body: string;
  createdAt: string;
  clientMessageId: string | null;
}

export interface CaseMessagesPage {
  items: CaseMessage[];
  hasMore: boolean;
}

export const CASE_MESSAGES_PAGE_SIZE = 50;
export const CASE_MESSAGE_MAX_LENGTH = 3000;
export const CASE_MESSAGES_POLL_MS = 20_000;

const CLIENT_MESSAGE_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

/**
 * Identifiant d'idempotence d'un brouillon, conforme à
 * `^[A-Za-z0-9_-]{1,64}$`. Un UUID n'a que des tirets en plus des
 * caractères permis ; on retire quand même tout le reste par prudence (un
 * générateur de repli pourrait en produire).
 */
export function makeClientMessageId(
  uuid: () => string = defaultUuid,
): string {
  const cleaned = uuid().replace(/[^A-Za-z0-9_-]/g, '').slice(0, 64);
  if (CLIENT_MESSAGE_ID_PATTERN.test(cleaned)) {
    return cleaned;
  }
  return fallbackId();
}

export function isValidClientMessageId(value: string): boolean {
  return CLIENT_MESSAGE_ID_PATTERN.test(value);
}

function defaultUuid(): string {
  const cryptoApi = (globalThis as { crypto?: Crypto }).crypto;
  if (cryptoApi && typeof cryptoApi.randomUUID === 'function') {
    return cryptoApi.randomUUID();
  }
  return fallbackId();
}

function fallbackId(): string {
  // Hors contexte sécurisé (HTTP non local), `randomUUID` n'existe pas.
  return `m${Date.now().toString(36)}${Math.random().toString(36).slice(2, 12)}`;
}

function compareMessages(a: CaseMessage, b: CaseMessage): number {
  const ta = Date.parse(a.createdAt);
  const tb = Date.parse(b.createdAt);
  if (ta !== tb && !Number.isNaN(ta) && !Number.isNaN(tb)) {
    return ta - tb;
  }
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

/**
 * Fusionne une page (plus ancienne, plus récente, ou la réponse d'un envoi)
 * dans le fil affiché : sans doublon (par `id`, puis par `clientMessageId`
 * pour un message déjà affiché), trié du plus ancien au plus récent. La
 * version reçue en dernier gagne.
 */
export function mergeCaseMessages(
  current: readonly CaseMessage[],
  incoming: readonly CaseMessage[],
): CaseMessage[] {
  const byId = new Map<string, CaseMessage>();
  for (const message of current) {
    byId.set(message.id, message);
  }
  for (const message of incoming) {
    if (message.clientMessageId) {
      for (const [id, existing] of byId) {
        if (id !== message.id && existing.clientMessageId === message.clientMessageId) {
          byId.delete(id);
        }
      }
    }
    byId.set(message.id, message);
  }
  return [...byId.values()].sort(compareMessages);
}

/** Paramètres de la requête de page ; `before` = id du plus ancien affiché. */
export function caseMessagesPath(caseId: string, before?: string | null): string {
  const params = new URLSearchParams({ limit: String(CASE_MESSAGES_PAGE_SIZE) });
  if (before) {
    params.set('before', before);
  }
  return `/admin/cases/${encodeURIComponent(caseId)}/messages?${params.toString()}`;
}

export type CaseMessageSide = 'student' | 'staff' | 'system';

export function messageSide(role: CaseMessageSenderRole): CaseMessageSide {
  if (role === 'student') return 'student';
  if (role === 'system') return 'system';
  return 'staff';
}

/** Un brouillon part s'il n'est pas vide (espaces exclus) et tient en 3000. */
export function canSendDraft(draft: string, sending: boolean): boolean {
  const length = draft.trim().length;
  return !sending && length > 0 && draft.length <= CASE_MESSAGE_MAX_LENGTH;
}

export function formatMessageTime(
  iso: string,
  locale: string,
  timeZone?: string,
): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) {
    return iso;
  }
  return new Intl.DateTimeFormat(locale === 'en' ? 'en-GB' : 'fr-FR', {
    dateStyle: 'short',
    timeStyle: 'short',
    ...(timeZone ? { timeZone } : {}),
  }).format(date);
}

/** Champs ajoutés par le backend à chaque élément de `GET /admin/cases`. */
export interface CaseReplyFields {
  awaitingReply?: boolean;
  lastMessageAt?: string | null;
}

/**
 * « Réponses attendues d'abord » : les dossiers dont le dernier message vient
 * de l'étudiant passent devant, le plus ancien en attente en tête (c'est lui
 * qui attend depuis le plus longtemps). Les autres gardent l'ordre du
 * serveur. Ne modifie pas le tableau reçu.
 */
export function sortAwaitingReplyFirst<T extends CaseReplyFields>(
  cases: readonly T[],
): T[] {
  const time = (item: T) => {
    const parsed = item.lastMessageAt ? Date.parse(item.lastMessageAt) : NaN;
    return Number.isNaN(parsed) ? Number.POSITIVE_INFINITY : parsed;
  };
  return cases
    .map((item, index) => ({ item, index }))
    .sort((a, b) => {
      const wa = a.item.awaitingReply === true;
      const wb = b.item.awaitingReply === true;
      if (wa !== wb) return wa ? -1 : 1;
      if (wa) {
        const ta = time(a.item);
        const tb = time(b.item);
        if (ta !== tb) return ta < tb ? -1 : 1;
      }
      return a.index - b.index;
    })
    .map(({ item }) => item);
}

/**
 * Ce que le dernier message du fil dit de l'état du dossier dans la liste,
 * pour la mettre à jour sans la recharger.
 */
export function replyFieldsFromLatest(
  latest: CaseMessage | undefined,
): CaseReplyFields | null {
  if (!latest) return null;
  return {
    awaitingReply: latest.senderRole === 'student',
    lastMessageAt: latest.createdAt,
  };
}

/**
 * La liste des dossiers n'est pas rechargée à chaque relève du fil : l'état
 * vu dans le fil ouvert (plus frais) la recouvre, sauf si la liste a depuis
 * reçu un message plus récent que celui que le fil connaît.
 */
export function applyReplyOverride<T extends CaseReplyFields>(
  item: T,
  override: CaseReplyFields | undefined,
): T {
  if (!override) return item;
  const listTime = item.lastMessageAt ? Date.parse(item.lastMessageAt) : NaN;
  const threadTime = override.lastMessageAt ? Date.parse(override.lastMessageAt) : NaN;
  if (!Number.isNaN(listTime) && (Number.isNaN(threadTime) || listTime > threadTime)) {
    return item;
  }
  if (
    item.awaitingReply === override.awaitingReply &&
    item.lastMessageAt === override.lastMessageAt
  ) {
    return item;
  }
  return { ...item, ...override };
}

/** Vrai si deux fils affichent la même chose (évite un rendu par relève). */
export function sameThread(
  a: readonly CaseMessage[],
  b: readonly CaseMessage[],
): boolean {
  return (
    a.length === b.length &&
    a.every((message, index) => {
      const other = b[index];
      return (
        message.id === other.id &&
        message.body === other.body &&
        message.senderName === other.senderName &&
        message.createdAt === other.createdAt
      );
    })
  );
}
