import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';
import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { AntivirusService } from '../storage/antivirus.service';

/** Captured at import time, so it is the process start and not the call time. */
const PROCESS_STARTED_AT = new Date().toISOString();
const SCAN_CACHE_MS = 30_000;

@Controller('health')
export class HealthController {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly llmService: LlmService,
    private readonly pushSender: PushSenderService,
    private readonly antivirus: AntivirusService,
  ) {}

  /** Backwards-compatible liveness endpoint: process is able to receive HTTP. */
  @Get()
  async check() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      // Boolean only — never the provider key, never the model name.
      ai: { configured: this.llmService.isConfigured },
      /**
       * Le push est-il seulement CAPABLE de partir ?
       *
       * `PushSenderService` se dégrade en silence : sans
       * `FCM_SERVICE_ACCOUNT_JSON` ni `ONESIGNAL_APP_ID` /
       * `ONESIGNAL_REST_API_KEY`, chaque envoi devient un no-op journalisé, le fil d'actualité s'écrit quand même, et le
       * dispatcher rend `push_unconfigured`. Personne ne s'en apercevait :
       * cette route annonçait l'état de l'IA et RIEN sur le push, alors que
       * les deux se désactivent de la même façon — par une variable absente.
       *
       * C'est la forme d'échec qui a envoyé la build 50 chez les testeurs sans
       * PostHog : une capacité éteinte sans le moindre signal. Un booléen ici
       * coûte une ligne et rend la panne visible de l'extérieur.
       *
       * Booléens SEULS, comme pour l'IA : les clés sont des secrets, et même
       * leur longueur n'a rien à faire sur une route non authentifiée.
       *
       * `fcm` / `oneSignal` disent quel chemin est ouvert pendant la
       * transition : FCM pour les nouvelles versions de l'application,
       * OneSignal pour celles qui ne sont pas encore mises à jour.
       */
      push: {
        configured: this.pushSender.isConfigured,
        ...this.pushSender.providers,
      },
      /**
       * `configured` ET `scanning`, parce que l'écart entre les deux EST la
       * panne du 15/08/2026 : `CLAMAV_HOST` est resté valide vingt jours
       * pendant que clamd était mort, et `AntivirusService` étant FAIL-CLOSED,
       * tout envoi de fichier repartait en 503 — documents de dossier, photos
       * de profil, pièces du Success Lab.
       *
       * Un seul booléen `configured` aurait annoncé « ✅ » pendant toute la
       * panne. C'est la raison d'être du second.
       *
       * `scanning`, pas `reachable` : un clamd qui répond au canal de contrôle
       * peut refuser INSTREAM ou tourner sans base chargée, et rendre 503 sur
       * chaque fichier. `selfTest()` fait passer le fichier de test EICAR par
       * le chemin RÉEL des envois — le mot dit ce qui est prouvé.
       *
       * `.catch` en ceinture : `selfTest()` est écrit pour ne jamais rejeter,
       * une route de santé qui rend 500 parce qu'une SONDE a levé serait
       * l'exact inverse du but — elle doit répondre surtout quand quelque
       * chose est cassé. Verrouillé par un test qui échoue sans ce catch.
       */
      antivirus: {
        configured: this.antivirus.isEnabled,
        scanning: await this.antivirusScanning(),
      },
    };
  }

  /**
   * Résultat du test EICAR mis en cache 30 s : la route est publique, et
   * chaque appel envoyait un scan à clamd. Un clamd qui meurt est vu en
   * 30 s au plus — l'objet du test (panne du 15/08/2026) reste rempli.
   */
  private scanCache: { at: number; value: Promise<boolean> } | null = null;

  private antivirusScanning(now = Date.now()): Promise<boolean> {
    if (this.scanCache && now - this.scanCache.at < SCAN_CACHE_MS) {
      return this.scanCache.value;
    }
    const value = this.antivirus.selfTest().catch(() => false);
    this.scanCache = { at: now, value };
    return value;
  }

  @Get('live')
  live() {
    return { status: 'live', timestamp: new Date().toISOString() };
  }

  /** Readiness includes PostgreSQL, so load balancers do not route to a dead API. */
  @Get('ready')
  async ready() {
    if (!(await this.prismaService.isReady())) {
      throw new ServiceUnavailableException('Database is not ready.');
    }
    return { status: 'ready', timestamp: new Date().toISOString() };
  }

  /**
   * The short SHA of the code actually serving, so "is prod on this commit?"
   * has an answer that is not a presumption. `unknown` rather than '' when the
   * build is unstamped: an empty string compares equal to too many things, and
   * reads as "no answer" instead of "no build stamp".
   *
   * Deliberately nothing else — no dependency versions, no paths. The short SHA
   * is the only information the preflight needs, and the only one worth
   * revealing on an unauthenticated route.
   */
  @Get('version')
  version() {
    return {
      sha: process.env.KPB_BUILD_SHA?.trim().slice(0, 12) || 'unknown',
      startedAt: PROCESS_STARTED_AT,
    };
  }
}
