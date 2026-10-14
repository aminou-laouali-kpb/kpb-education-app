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

  async sendToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
    options?: FcmSendOptions,
  ): Promise<FcmSendResult> {
    const account = this.account;
    if (!account) return 'unconfigured';
    if (!userId) return 'no_device';

    const tokens =
      (await this.prisma.execute((p) =>
        p.deviceToken.findMany({
          where: { userProfileId: userId },
          select: { token: true },
        }),
      )) ?? [];
    if (tokens.length === 0) return 'no_device';

    const accessToken = await this.accessToken(account);
    if (!accessToken) return 'failed';

    const outcomes = await Promise.all(
      tokens.map(({ token }) =>
        this.sendToToken(account, accessToken, token, title, body, data, options),
      ),
    );

    const dead = tokens
      .filter((_, i) => outcomes[i] === 'dead')
      .map(({ token }) => token);
    if (dead.length > 0) {
      await this.prisma.execute((p) =>
        p.deviceToken.deleteMany({ where: { token: { in: dead } } }),
      );
      this.logger.log(
        `FCM: ${dead.length} jeton(s) révoqué(s) supprimé(s) pour ${userId}.`,
      );
    }

    if (outcomes.includes('ok')) return 'delivered';
    // Tous les jetons étaient morts : l'utilisateur n'a plus d'appareil FCM
    // joignable, ce qui équivaut à n'en avoir aucun.
    if (outcomes.every((o) => o === 'dead')) return 'no_device';
    return 'failed';
  }

  private async sendToToken(
    account: ServiceAccount,
    accessToken: string,
    token: string,
    title: string,
    body: string,
    data?: Record<string, string>,
    options?: FcmSendOptions,
  ): Promise<'ok' | 'dead' | 'error'> {
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
      if (response.ok) return 'ok';

      let payload: unknown = null;
      let text = '';
      try {
        text = await response.text();
        payload = JSON.parse(text);
      } catch {
        // Corps illisible : on journalise ce qu'on a.
      }
      if (response.status === 401) this.cachedToken = null;
      if (isDeadTokenError(response.status, payload)) return 'dead';
      this.logger.error(
        `FCM send failed with status ${response.status}: ` +
          `${truncate(text.trim()) || '(corps vide)'}`,
      );
      return 'error';
    } catch (error) {
      const reason =
        error instanceof Error ? `${error.name}: ${error.message}` : 'unknown';
      this.logger.error(`FCM push request failed — ${reason}`);
      return 'error';
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
