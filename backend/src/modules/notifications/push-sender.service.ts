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
}
