// ─────────────────────────────────────────────────────────────────────────────
// OneSignalSenderService — server-side push delivery via the OneSignal REST API.
//
// Targets users by their OneSignal "external id", which the Flutter app sets to
// the KPB user profile id on login (OneSignal.login). This replaces the former
// FCM/device-token path: OneSignal owns device subscriptions, so the backend no
// longer manages raw FCM tokens.
//
// Degrades gracefully: if ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY are unset,
// every send is a logged no-op instead of throwing.
// ─────────────────────────────────────────────────────────────────────────────

import { createHash } from 'node:crypto';

import { Injectable, Logger } from '@nestjs/common';

const ONESIGNAL_API_URL = 'https://onesignal.com/api/v1/notifications';

/** Un journal n'est pas une décharge : on garde de quoi diagnostiquer. */
const MAX_LOGGED_BODY = 500;

function truncate(text: string): string {
  return text.length > MAX_LOGGED_BODY
    ? `${text.slice(0, MAX_LOGGED_BODY)}… (tronqué)`
    : text;
}

/**
 * Lit le corps d'une réponse en échec sans jamais faire échouer la
 * journalisation elle-même — un corps illisible ne doit pas transformer une
 * erreur d'envoi en exception non rattrapée.
 */
async function safeBody(response: Response): Promise<string> {
  try {
    return truncate((await response.text()).trim()) || '(corps vide)';
  } catch {
    return '(corps illisible)';
  }
}

@Injectable()
export class OneSignalSenderService {
  private readonly logger = new Logger(OneSignalSenderService.name);

  private get appId(): string | undefined {
    return process.env.ONESIGNAL_APP_ID?.trim() || undefined;
  }

  private get restApiKey(): string | undefined {
    return process.env.ONESIGNAL_REST_API_KEY?.trim() || undefined;
  }

  get isConfigured(): boolean {
    return Boolean(this.appId && this.restApiKey);
  }

  /**
   * Send a push notification to one KPB user (by external id).
   * Signature mirrors the previous FirebasePushService.sendToUser so call sites
   * stay unchanged.
   */
  async sendToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<boolean> {
    const attempt = await this.attempt(userId, title, body, data, {});
    switch (attempt.kind) {
      case 'unconfigured':
        this.logger.warn(
          'OneSignal not configured (ONESIGNAL_APP_ID / ONESIGNAL_REST_API_KEY) — push skipped.',
        );
        return false;
      case 'no_user':
        return false;
      case 'http_error':
        this.logger.error(
          `OneSignal send failed with status ${attempt.status}: ` +
            `${attempt.body}`,
        );
        return false;
      case 'provider_errors':
        // La charge `errors` est le SEUL endroit où OneSignal dit pourquoi il
        // refuse. Elle était désérialisée puis jetée : le 04/09/2026, la
        // campagne « Rentree Decalee » a trouvé 2 destinataires et n'en a
        // livré aucun, et le journal de production ne contenait que « provider
        // errors » — impossible de savoir si le tort venait de l'application
        // OneSignal, des identifiants, ou de l'abonné.
        //
        // Aucun secret là-dedans : ce sont les messages du fournisseur. La
        // clé REST ne transite que dans l'en-tête, jamais dans le corps de
        // réponse. Tronqué, parce qu'un journal n'est pas une décharge.
        this.logger.error(
          `OneSignal send returned provider errors: ${truncate(JSON.stringify(attempt.errors))}`,
        );
        return false;
      case 'zero_recipients':
        // « Personne à notifier » n'est PAS un succès. Le commentaire précédent
        // annonçait vouloir distinguer ce cas, puis rendait `true` quand même —
        // et l'appelant inscrivait la livraison comme `delivered`. Un envoi qui
        // n'atteint aucun appareil doit se compter comme non livré, sinon les
        // statistiques de campagne décrivent une distribution qui n'a pas eu
        // lieu. Journalisé en `warn` et non en `debug` : c'est précisément le
        // symptôme d'une application OneSignal sans plateforme configurée, ou
        // d'un utilisateur qui a refusé les notifications.
        this.logger.warn(
          `OneSignal accepted the request but delivered to 0 device for user ${userId} ` +
            '(no subscribed device, or no delivery platform configured on the OneSignal app).',
        );
        return false;
      case 'thrown':
        // Le motif compte : un abandon sur délai ne se répare pas comme un DNS
        // qui ne résout pas. `AbortError` est le nom que `fetch` donne au
        // dépassement des 10 s armées plus bas.
        this.logger.error(`OneSignal push request failed — ${attempt.reason}`);
        return false;
      default:
        return true;
    }
  }

  /**
   * Le même envoi, avec un état par destinataire et SANS AUCUNE ligne de
   * journal. C'est le chemin de la boîte d'envoi des annonces d'ouverture : à
   * 5 000 abonnés d'anciennes builds, `sendToUser` écrirait des milliers de
   * lignes portant un identifiant d'utilisateur (et jusqu'à 500 caractères de
   * réponse du fournisseur, qui peut citer des `external_id`). Le worker ne
   * journalise que son bilan, avec les comptes par raison.
   *
   * `reason` est un code borné, jamais un texte du fournisseur.
   */
  async sendToUserDetailed(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
    options: OneSignalSendOptions = {},
  ): Promise<OneSignalDetailedResult> {
    return detailedResult(
      await this.attempt(userId, title, body, data, options),
    );
  }

  /** Un appel, aucune journalisation : les deux méthodes publiques en décident. */
  private async attempt(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string> | undefined,
    options: OneSignalSendOptions,
  ): Promise<OneSignalAttempt> {
    if (!this.isConfigured) return { kind: 'unconfigured' };
    if (!userId) return { kind: 'no_user' };

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);
    try {
      const response = await fetch(ONESIGNAL_API_URL, {
        method: 'POST',
        headers: {
          'content-type': 'application/json; charset=utf-8',
          authorization: `Basic ${this.restApiKey}`,
        },
        body: JSON.stringify({
          app_id: this.appId,
          target_channel: 'push',
          include_aliases: { external_id: [userId] },
          headings: { en: title, fr: title },
          contents: { en: body, fr: body },
          data: data ?? {},
          // Absentes sans option : le corps de `sendToUser` reste celui d'avant.
          ...(options.idempotencyKey
            ? { idempotency_key: idempotencyUuid(options.idempotencyKey) }
            : {}),
          ...(options.collapseKey ? { collapse_id: options.collapseKey } : {}),
        }),
        signal: controller.signal,
      });

      if (!response.ok) {
        return {
          kind: 'http_error',
          status: response.status,
          body: await safeBody(response),
        };
      }

      const json = (await response.json()) as {
        id?: string;
        recipients?: number;
        errors?: unknown;
      };
      if (json.errors) return { kind: 'provider_errors', errors: json.errors };
      if (json.recipients === 0) return { kind: 'zero_recipients' };
      return { kind: 'ok' };
    } catch (error) {
      return {
        kind: 'thrown',
        aborted: error instanceof Error && error.name === 'AbortError',
        reason:
          error instanceof Error ? `${error.name}: ${error.message}` : 'unknown',
      };
    } finally {
      clearTimeout(timeout);
    }
  }
}

/**
 * État d'un envoi pour un destinataire — le vocabulaire de
 * `PushSenderService.sendWithStatus` :
 * - `accepted` : OneSignal a accepté (ce n'est PAS « reçu ») ;
 * - `no_device` : aucun abonnement joignable pour cet utilisateur ;
 * - `transient_error` : 429, 5xx, délai ou réseau — à retenter ;
 * - `permanent_error` : refus que retenter ne changera pas ;
 * - `unconfigured` : pas d'identifiants OneSignal.
 */
export type OneSignalSendStatus =
  | 'accepted'
  | 'no_device'
  | 'transient_error'
  | 'permanent_error'
  | 'unconfigured';

export type OneSignalFailureReason =
  | 'http_429'
  | 'http_5xx'
  | 'http_4xx'
  | 'abort'
  | 'network'
  | 'invalid_aliases'
  | 'not_subscribed'
  | 'zero_recipients'
  | 'provider_errors';

export interface OneSignalDetailedResult {
  status: OneSignalSendStatus;
  reason: OneSignalFailureReason | null;
}

export interface OneSignalSendOptions {
  /**
   * Clé déterministe d'un envoi : OneSignal ignore un second envoi portant la
   * même clé pendant 30 jours (relance après un crash entre l'acceptation et
   * l'écriture de l'état).
   */
  idempotencyKey?: string;
  /** `collapse_id` : un doublon remplace la notification au lieu de s'empiler. */
  collapseKey?: string;
}

type OneSignalAttempt =
  | { kind: 'unconfigured' }
  | { kind: 'no_user' }
  | { kind: 'http_error'; status: number; body: string }
  | { kind: 'provider_errors'; errors: unknown }
  | { kind: 'zero_recipients' }
  | { kind: 'ok' }
  | { kind: 'thrown'; aborted: boolean; reason: string };

function detailedResult(attempt: OneSignalAttempt): OneSignalDetailedResult {
  switch (attempt.kind) {
    case 'unconfigured':
      return { status: 'unconfigured', reason: null };
    case 'no_user':
      // Un alias vide n'adressera jamais personne.
      return { status: 'permanent_error', reason: 'invalid_aliases' };
    case 'http_error':
      if (attempt.status === 429) {
        return { status: 'transient_error', reason: 'http_429' };
      }
      if (attempt.status >= 500) {
        return { status: 'transient_error', reason: 'http_5xx' };
      }
      return { status: 'permanent_error', reason: 'http_4xx' };
    case 'provider_errors':
      return providerErrorsResult(attempt.errors);
    case 'zero_recipients':
      return { status: 'no_device', reason: 'zero_recipients' };
    case 'thrown':
      return {
        status: 'transient_error',
        reason: attempt.aborted ? 'abort' : 'network',
      };
    default:
      return { status: 'accepted', reason: null };
  }
}

/**
 * Les deux formes par lesquelles OneSignal dit « personne à joindre » :
 * `{ invalid_aliases: { external_id: [...] } }` (alias inconnu) et
 * `["All included players are not subscribed"]`. Toute autre charge
 * d'erreur est un refus.
 */
function providerErrorsResult(errors: unknown): OneSignalDetailedResult {
  if (
    errors !== null &&
    typeof errors === 'object' &&
    !Array.isArray(errors) &&
    'invalid_aliases' in errors
  ) {
    return { status: 'no_device', reason: 'invalid_aliases' };
  }
  if (
    Array.isArray(errors) &&
    errors.some(
      (entry) => typeof entry === 'string' && /not subscribed/i.test(entry),
    )
  ) {
    return { status: 'no_device', reason: 'not_subscribed' };
  }
  return { status: 'permanent_error', reason: 'provider_errors' };
}

/**
 * UUID RFC 4122 déterministe (bits de version 4 et de variante posés) tiré du
 * SHA-256 de la clé : OneSignal exige un UUID, et la même clé doit donner le
 * même UUID d'un processus à l'autre.
 */
export function idempotencyUuid(key: string): string {
  const bytes = createHash('sha256').update(key).digest().subarray(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}
