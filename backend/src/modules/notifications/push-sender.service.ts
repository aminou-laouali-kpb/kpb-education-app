// ─────────────────────────────────────────────────────────────────────────────
// PushSenderService — point d'entrée unique de l'envoi push.
//
// Transition OneSignal → FCM (envoi direct, gratuit) :
//   1. l'utilisateur a un jeton FCM (nouvelle version de l'application) → FCM ;
//   2. il n'en a pas (ancienne version, encore abonnée chez OneSignal) →
//      OneSignal, tant que `ONESIGNAL_APP_ID` / `ONESIGNAL_REST_API_KEY` sont
//      renseignés.
//
// On ne retombe PAS sur OneSignal quand FCM échoue alors que des jetons
// existent : un utilisateur passé à la nouvelle version n'a plus le SDK
// OneSignal, et son ancien abonnement pourrait être compté « livré » par
// OneSignal sans que rien ne s'affiche. Mieux vaut un échec honnête.
//
// Retirer OneSignal = vider ses deux variables d'environnement, puis supprimer
// ce repli et `OneSignalSenderService`.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable } from '@nestjs/common';

import { FcmSenderService } from './fcm-sender.service';
import { OneSignalSenderService } from './onesignal-sender.service';

export type PushProvider = 'fcm' | 'onesignal';

export interface PushSendOutcome {
  delivered: boolean;
  /** Le fournisseur qui a porté (ou tenté) l'envoi ; `null` si aucun. */
  via: PushProvider | null;
}

/**
 * État d'un envoi pour un destinataire (`sendWithStatus`) :
 * - `accepted` : le fournisseur a accepté — jamais « reçu » ni « délivré » ;
 * - `no_device` : aucun appareil joignable ;
 * - `transient_error` : à retenter (FCM `failed`, OneSignal 429/5xx/délai) ;
 * - `permanent_error` : refus que retenter ne changera pas ;
 * - `unconfigured` : aucun fournisseur configuré.
 */
export type PushDeliveryStatus =
  | 'accepted'
  | 'no_device'
  | 'transient_error'
  | 'permanent_error'
  | 'unconfigured';

/**
 * Les deux clés sont tirées de l'ENVOI (sa `dedupeKey`, ou les identifiants
 * triés des lignes d'un groupé), jamais d'un identifiant tiré à chaque
 * tentative : un renvoi après un crash doit porter les mêmes.
 */
export interface PushSendOptions {
  /** FCM `tag` / `apns-collapse-id`, OneSignal `collapse_id` (64 octets au plus). */
  collapseKey?: string;
  /** OneSignal `idempotency_key` (UUID dérivé), 30 jours côté fournisseur. */
  idempotencyKey?: string;
}

export interface PushDeliveryOutcome {
  status: PushDeliveryStatus;
  via: PushProvider | null;
  /** Code borné pour les comptes du bilan (jamais un texte du fournisseur). */
  reason: string | null;
}

@Injectable()
export class PushSenderService {
  constructor(
    private readonly fcm: FcmSenderService,
    private readonly oneSignal: OneSignalSenderService,
  ) {}

  get isConfigured(): boolean {
    return this.fcm.isConfigured || this.oneSignal.isConfigured;
  }

  /** Booléens seuls : jamais une clé, ni même sa longueur. */
  get providers(): { fcm: boolean; oneSignal: boolean } {
    return {
      fcm: this.fcm.isConfigured,
      oneSignal: this.oneSignal.isConfigured,
    };
  }

  /** Signature historique, conservée pour tous les appelants. */
  async sendToUser(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<boolean> {
    return (await this.send(userId, title, body, data)).delivered;
  }

  async send(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>,
  ): Promise<PushSendOutcome> {
    if (!userId) return { delivered: false, via: null };

    if (this.fcm.isConfigured) {
      const result = await this.fcm.sendToUser(userId, title, body, data);
      if (result === 'delivered') return { delivered: true, via: 'fcm' };
      if (result === 'failed') return { delivered: false, via: 'fcm' };
      // 'no_device' → l'utilisateur est peut-être encore sur une ancienne
      // version de l'application : on tente OneSignal.
    }

    if (this.oneSignal.isConfigured) {
      const delivered = await this.oneSignal.sendToUser(
        userId,
        title,
        body,
        data,
      );
      return { delivered, via: 'onesignal' };
    }

    return { delivered: false, via: this.fcm.isConfigured ? 'fcm' : null };
  }

  /**
   * Même routage que `send()`, avec un état par destinataire, pour la boîte
   * d'envoi des annonces d'ouverture. `send()` et `sendToUser()` restent tels
   * quels pour leurs appelants.
   *
   * Pas de repli OneSignal quand FCM échoue avec des jetons (en-tête du
   * fichier) : l'échec est `transient_error`, borné par le nombre de
   * tentatives de la boîte d'envoi.
   */
  async sendWithStatus(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string>,
    options: PushSendOptions = {},
  ): Promise<PushDeliveryOutcome> {
    if (!userId) {
      return { status: 'permanent_error', via: null, reason: 'no_user' };
    }

    if (this.fcm.isConfigured) {
      const result = await this.fcm.sendToUser(userId, title, body, data, {
        collapseKey: options.collapseKey,
      });
      if (result === 'delivered') {
        return { status: 'accepted', via: 'fcm', reason: null };
      }
      if (result === 'failed') {
        return { status: 'transient_error', via: 'fcm', reason: 'fcm_failed' };
      }
      // 'no_device' / 'unconfigured' → peut-être une ancienne version de
      // l'application, encore abonnée chez OneSignal.
    }

    if (this.oneSignal.isConfigured) {
      const detailed = await this.oneSignal.sendToUserDetailed(
        userId,
        title,
        body,
        data,
        {
          idempotencyKey: options.idempotencyKey,
          collapseKey: options.collapseKey,
        },
      );
      return {
        status: detailed.status,
        via: 'onesignal',
        reason: detailed.reason,
      };
    }

    return this.fcm.isConfigured
      ? { status: 'no_device', via: 'fcm', reason: 'fcm_no_device' }
      : { status: 'unconfigured', via: null, reason: null };
  }
}
