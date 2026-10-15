// ─────────────────────────────────────────────────────────────────────────────
// FcmSenderService — envoi push direct par Firebase Cloud Messaging (API v1).
//
// Pourquoi FCM en direct plutôt qu'un intermédiaire : l'envoi est gratuit et
// sans plafond, Firebase est déjà dans l'application (Analytics, Crashlytics),
// et le backend calcule déjà lui-même les audiences, les heures de silence et le
// plafond quotidien. Un intermédiaire ne faisait que relier « utilisateur KPB »
// à « appareil » — c'est désormais la table `DeviceToken`, alimentée par
// l'application via `POST /device-tokens`.
//
// Aucune dépendance ajoutée : le jeton d'accès Google s'obtient en signant un
// JWT RS256 avec la clé du compte de service (`jsonwebtoken`, déjà présent).
//
// Dégradation : sans `FCM_SERVICE_ACCOUNT_JSON`, `isConfigured` vaut `false` et
// le routeur (`PushSenderService`) se rabat sur OneSignal.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from '@nestjs/common';
import * as jwt from 'jsonwebtoken';

import { PrismaService } from '../prisma/prisma.service';

const OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const REQUEST_TIMEOUT_MS = 10_000;
/** Doit correspondre au canal créé par l'application (PushService). */
export const ANDROID_CHANNEL_ID = 'kpb_default';

/** Un journal n'est pas une décharge : on garde de quoi diagnostiquer. */
const MAX_LOGGED_BODY = 500;

/**
 * - `delivered`  : au moins un appareil a accepté le message ;
 * - `no_device`  : aucun jeton connu (ou tous révoqués pendant l'envoi) — le
 *   routeur peut alors tenter OneSignal (anciennes versions de l'application) ;
 * - `failed`     : des jetons existent, mais FCM a refusé ou n'a pas répondu ;
 * - `unconfigured` : pas de compte de service.
 */
export type FcmSendResult =
  | 'delivered'
  | 'no_device'
  | 'failed'
  | 'unconfigured';

/**
 * Motif borné d'un envoi qui n'a pas abouti (jamais un texte du fournisseur) :
 * - `auth` : pas de jeton d'accès Google ;
 * - `http_429`, `http_5xx`, `http_4xx` : refus de FCM ;
 * - `abort` : délai de 10 s dépassé ; `network` : autre échec de `fetch` ;
 * - `tokens_revoked` : tous les jetons de l'élève étaient révoqués.
 */
export type FcmFailureReason =
  | 'auth'
  | 'http_429'
  | 'http_5xx'
  | 'http_4xx'
  | 'abort'
  | 'network'
  | 'tokens_revoked';

export interface FcmDetailedResult {
  result: FcmSendResult;
  /** `null` quand `delivered`, ou `no_device` faute de jeton. */
  reason: FcmFailureReason | null;
}

/** L'issue d'un envoi à UN jeton, sans journal : l'appelant décide. */
type TokenAttempt =
  | { kind: 'ok' }
  | { kind: 'dead' }
  | { kind: 'http_error'; status: number; text: string }
  | { kind: 'thrown'; aborted: boolean; reason: string };

/** L'issue d'un envoi à un élève, sans journal. */
interface UserAttempt {
  result: FcmSendResult;
  reason: FcmFailureReason | null;
  /** Jetons révoqués supprimés pendant l'envoi. */
  revoked: number;
  /** Les échecs par jeton, pour le journal de `sendToUser` seulement. */
  failures: TokenAttempt[];
}

function failureReason(attempt: TokenAttempt): FcmFailureReason | null {
  switch (attempt.kind) {
    case 'http_error':
      if (attempt.status === 429) return 'http_429';
      return attempt.status >= 500 ? 'http_5xx' : 'http_4xx';
    case 'thrown':
      return attempt.aborted ? 'abort' : 'network';
    default:
      return null;
  }
}

/**
 * - `collapseKey` : `android.notification.tag` et `apns-collapse-id`. Un renvoi
 *   après un crash (bail perdu entre l'acceptation et l'écriture de l'état)
 *   REMPLACE alors la notification déjà affichée au lieu de s'empiler. Tiré de
 *   la clé déterministe de l'envoi, jamais d'un identifiant tiré au hasard à
 *   chaque tentative ; 64 octets au plus (limite APNs).
 */
export interface FcmSendOptions {
  collapseKey?: string;
}

export interface ServiceAccount {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

/**
 * Lit le compte de service, en JSON brut ou encodé en base64 — la clé privée
 * contient des retours à la ligne, pénibles dans un fichier `.env` ; le base64
 * tient sur une ligne. Rend `null` si la valeur est absente ou inexploitable.
 */
export function parseServiceAccount(
  raw: string | undefined,
): ServiceAccount | null {
  const text = raw?.trim();
  if (!text) return null;
  try {
    const json = text.startsWith('{')
      ? text
      : Buffer.from(text, 'base64').toString('utf8');
    const parsed = JSON.parse(json) as Record<string, unknown>;
    const projectId = parsed['project_id'];
    const clientEmail = parsed['client_email'];
    const privateKey = parsed['private_key'];
    if (
      typeof projectId !== 'string' ||
      typeof clientEmail !== 'string' ||
      typeof privateKey !== 'string' ||
      !projectId ||
      !clientEmail ||
      !privateKey
    ) {
      return null;
    }
    return { projectId, clientEmail, privateKey };
  } catch {
    return null;
  }
}

/**
 * Le jeton n'adresse plus aucun appareil : application désinstallée, jeton
 * renouvelé, ou jeton d'un autre projet Firebase. On le supprime, sinon chaque
 * envoi futur repaierait le même refus.
 */
export function isDeadTokenError(status: number, body: unknown): boolean {
  const error = (body as { error?: Record<string, unknown> } | null)?.error;
  const details = Array.isArray(error?.['details'])
    ? (error['details'] as Array<Record<string, unknown>>)
    : [];
  const codes = details
    .map((d) => d['errorCode'])
    .filter((c): c is string => typeof c === 'string');
  if (codes.includes('UNREGISTERED') || codes.includes('SENDER_ID_MISMATCH')) {
    return true;
  }
  // 400 INVALID_ARGUMENT couvre aussi une charge mal formée : on ne supprime
  // le jeton que si FCM dit explicitement que c'est LUI qui est invalide.
  const message = typeof error?.['message'] === 'string' ? error['message'] : '';
  return status === 400 && /registration token/i.test(message);
}

function truncate(text: string): string {
  return text.length > MAX_LOGGED_BODY
    ? `${text.slice(0, MAX_LOGGED_BODY)}… (tronqué)`
    : text;
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

@Injectable()
export class FcmSenderService {
  private readonly logger = new Logger(FcmSenderService.name);
  private cachedToken: { value: string; expiresAt: number } | null = null;
  // Un seul échange OAuth à la fois : la boîte d'envoi lance 8 envois en
  // parallèle, et un cache vide aurait demandé 8 jetons d'un coup.
  private tokenInFlight: Promise<string | null> | null = null;

  constructor(private readonly prisma: PrismaService) {}

  private get account(): ServiceAccount | null {
    return parseServiceAccount(process.env.FCM_SERVICE_ACCOUNT_JSON);
  }

  get isConfigured(): boolean {
    return this.account !== null;
  }

  /**
   * Chemin historique (rappels, campagnes, messagerie…) : même résultat et
   * mêmes lignes de journal qu'avant — un jeton révoqué nommant l'élève, et
   * chaque refus de FCM avec son corps tronqué.
   */
  async sendToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
    options?: FcmSendOptions,
  ): Promise<FcmSendResult> {
    const attempt = await this.attempt(userId, title, body, data, options);
    for (const failure of attempt.failures) {
      if (failure.kind === 'http_error') {
        this.logger.error(
          `FCM send failed with status ${failure.status}: ` +
            `${truncate(failure.text.trim()) || '(corps vide)'}`,
        );
      } else if (failure.kind === 'thrown') {
        this.logger.error(`FCM push request failed — ${failure.reason}`);
      }
    }
    if (attempt.revoked > 0) {
      this.logger.log(
        `FCM: ${attempt.revoked} jeton(s) révoqué(s) supprimé(s) pour ${userId}.`,
      );
    }
    return attempt.result;
  }

  /**
   * Le même envoi, avec un motif borné et SANS AUCUNE ligne de journal par
   * élève : c'est le chemin de la boîte d'envoi des annonces d'ouverture (le
   * pendant de `OneSignalSenderService.sendToUserDetailed`). À 5 000 abonnés,
   * `sendToUser` écrirait une ligne par jeton révoqué — avec l'identifiant de
   * l'élève — et une par refus ; le worker ne journalise que son bilan, avec
   * les comptes par motif. Seul l'échec de l'échange OAuth du compte de
   * service reste journalisé : il ne nomme personne et n'a lieu qu'une fois
   * par échange, partagé entre envois.
   */
  async sendToUserDetailed(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
    options?: FcmSendOptions,
  ): Promise<FcmDetailedResult> {
    const attempt = await this.attempt(userId, title, body, data, options);
    return { result: attempt.result, reason: attempt.reason };
  }

  /** Un envoi à tous les jetons de l'élève, sans journal par élève. */
  private async attempt(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string> | undefined,
    options: FcmSendOptions | undefined,
  ): Promise<UserAttempt> {
    const none = { revoked: 0, failures: [] };
    const account = this.account;
    if (!account) return { result: 'unconfigured', reason: null, ...none };
    if (!userId) return { result: 'no_device', reason: null, ...none };

    const tokens =
      (await this.prisma.execute((p) =>
        p.deviceToken.findMany({
          where: { userProfileId: userId },
          select: { token: true },
        }),
      )) ?? [];
    if (tokens.length === 0) return { result: 'no_device', reason: null, ...none };

    const accessToken = await this.accessToken(account);
    if (!accessToken) return { result: 'failed', reason: 'auth', ...none };

    const outcomes = await Promise.all(
      tokens.map(({ token }) =>
        this.sendToToken(account, accessToken, token, title, body, data, options),
      ),
    );

    const dead = tokens
      .filter((_, i) => outcomes[i].kind === 'dead')
      .map(({ token }) => token);
    if (dead.length > 0) {
      await this.prisma.execute((p) =>
        p.deviceToken.deleteMany({ where: { token: { in: dead } } }),
      );
    }
    const failures = outcomes.filter(
      (o) => o.kind === 'http_error' || o.kind === 'thrown',
    );
    const revoked = dead.length;

    if (outcomes.some((o) => o.kind === 'ok')) {
      return { result: 'delivered', reason: null, revoked, failures };
    }
    // Tous les jetons étaient morts : l'utilisateur n'a plus d'appareil FCM
    // joignable, ce qui équivaut à n'en avoir aucun.
    if (outcomes.every((o) => o.kind === 'dead')) {
      return { result: 'no_device', reason: 'tokens_revoked', revoked, failures };
    }
    const first = failures[0];
    return {
      result: 'failed',
      reason: first ? failureReason(first) : 'network',
      revoked,
      failures,
    };
  }

  private async sendToToken(
    account: ServiceAccount,
    accessToken: string,
    token: string,
    title: string,
    body: string,
    data?: Record<string, string>,
    options?: FcmSendOptions,
  ): Promise<TokenAttempt> {
    const collapseKey = options?.collapseKey;
    try {
      const response = await fetchWithTimeout(
        `https://fcm.googleapis.com/v1/projects/${account.projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            'content-type': 'application/json; charset=utf-8',
            authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title, body },
              data: data ?? {},
              android: {
                priority: 'HIGH',
                notification: {
                  channel_id: ANDROID_CHANNEL_ID,
                  ...(collapseKey ? { tag: collapseKey } : {}),
                },
              },
              apns: {
                ...(collapseKey
                  ? { headers: { 'apns-collapse-id': collapseKey } }
                  : {}),
                payload: { aps: { sound: 'default' } },
              },
            },
          }),
        },
      );
      if (response.ok) return { kind: 'ok' };

      let payload: unknown = null;
      let text = '';
      try {
        text = await response.text();
        payload = JSON.parse(text);
      } catch {
        // Corps illisible : on garde ce qu'on a.
      }
      if (response.status === 401) this.cachedToken = null;
      if (isDeadTokenError(response.status, payload)) return { kind: 'dead' };
      return { kind: 'http_error', status: response.status, text };
    } catch (error) {
      return {
        kind: 'thrown',
        aborted: error instanceof Error && error.name === 'AbortError',
        reason:
          error instanceof Error ? `${error.name}: ${error.message}` : 'unknown',
      };
    }
  }

  /**
   * Jeton OAuth2 du compte de service, gardé en cache jusqu'à 1 min avant
   * expiration. Les appels concurrents sur un cache vide partagent le même
   * échange.
   */
  private async accessToken(account: ServiceAccount): Promise<string | null> {
    if (this.cachedToken && this.cachedToken.expiresAt - 60_000 > Date.now()) {
      return this.cachedToken.value;
    }
    if (!this.tokenInFlight) {
      this.tokenInFlight = this.fetchAccessToken(account).finally(() => {
        this.tokenInFlight = null;
      });
    }
    return this.tokenInFlight;
  }

  private async fetchAccessToken(
    account: ServiceAccount,
  ): Promise<string | null> {
    const now = Date.now();
    try {
      const issuedAt = Math.floor(now / 1000);
      const assertion = jwt.sign(
        {
          iss: account.clientEmail,
          scope: FCM_SCOPE,
          aud: OAUTH_TOKEN_URL,
          iat: issuedAt,
          exp: issuedAt + 3600,
        },
        account.privateKey,
        { algorithm: 'RS256' },
      );
      const response = await fetchWithTimeout(OAUTH_TOKEN_URL, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          assertion,
        }).toString(),
      });
      if (!response.ok) {
        // Jamais la clé ni l'assertion : seulement la réponse de Google.
        let text = '';
        try {
          text = await response.text();
        } catch {
          // ignore
        }
        this.logger.error(
          `FCM: échec d'obtention du jeton d'accès (${response.status}): ` +
            `${truncate(text.trim()) || '(corps vide)'}`,
        );
        return null;
      }
      const json = (await response.json()) as {
        access_token?: string;
        expires_in?: number;
      };
      if (!json.access_token) return null;
      this.cachedToken = {
        value: json.access_token,
        expiresAt: now + (json.expires_in ?? 3600) * 1000,
      };
      return json.access_token;
    } catch (error) {
      const reason =
        error instanceof Error ? `${error.name}: ${error.message}` : 'unknown';
      this.logger.error(`FCM: jeton d'accès indisponible — ${reason}`);
      return null;
    }
  }
}
