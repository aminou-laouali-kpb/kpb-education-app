import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import type { PaymentStatus, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { CinetpayAdapter } from './cinetpay.adapter';
import { PaydunyaAdapter } from './paydunya.adapter';
import {
  PaymentProviderAdapter,
  WebhookParsedEvent,
  WebhookRawInput,
} from './payment-provider.interface';

type ProviderName = 'cinetpay' | 'paydunya' | 'stripe' | 'manual';

/**
 * Statuts depuis lesquels un webhook peut faire passer un intent au statut
 * annoncé. `paid` gagne sur un échec/annulation antérieur (le fournisseur
 * confirme l'encaissement), mais rien ne fait quitter `paid` ni `refunded`,
 * et un échec ne redevient pas `pending`. Un webhook identique rejoué ne
 * matche pas (paid → paid exclu) : il est idempotent et ne réécrit pas paidAt.
 */
const WEBHOOK_ALLOWED_FROM: Record<
  WebhookParsedEvent['status'],
  PaymentStatus[]
> = {
  paid: ['created', 'pending', 'failed', 'cancelled'],
  failed: ['created', 'pending'],
  cancelled: ['created', 'pending'],
  pending: ['created'],
};

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);
  private readonly adapters: Record<ProviderName, PaymentProviderAdapter>;

  constructor(
    private readonly prismaService: PrismaService,
    private readonly cinetpayAdapter: CinetpayAdapter,
    private readonly paydunyaAdapter: PaydunyaAdapter,
  ) {
    this.adapters = {
      cinetpay: cinetpayAdapter,
      paydunya: paydunyaAdapter,
      // Stripe intentionally stubbed — "Stripe doesn't work here" for most
      // West African rails, but we leave the provider enum value for the
      // occasional EU-based parent paying via card.
      stripe: {
        name: 'stripe',
        isConfigured: () => false,
        initiate: async () => {
          throw new Error('Stripe adapter not implemented.');
        },
        parseWebhook: async () => {
          throw new Error('Stripe adapter not implemented.');
        },
      },
      // Manual = advisor records an offline payment (wire transfer, cash).
      // No checkout URL; status is moved to `paid` by admin directly.
      manual: {
        name: 'manual',
        isConfigured: () => true,
        initiate: async (input) => ({
          providerRef: `manual-${input.intentId}`,
          checkoutUrl: '',
        }),
        parseWebhook: async () => {
          throw new Error('Manual provider has no webhook.');
        },
      },
    };
  }

  /** Returns the list of providers actually usable right now (env-configured). */
  listAvailableProviders(): ProviderName[] {
    return (Object.keys(this.adapters) as ProviderName[]).filter((name) =>
      this.adapters[name].isConfigured(),
    );
  }

  async createIntent(input: {
    userId: string;
    provider: ProviderName;
    amountMinor: number;
    currency?: string;
    caseId?: string;
    counsellorId?: string;
    description?: string;
    customer: { email: string; phone: string; fullName: string };
    returnUrl: string;
    cancelUrl: string;
  }) {
    if (input.amountMinor <= 0) {
      throw new BadRequestException('amountMinor must be positive.');
    }

    const adapter = this.adapters[input.provider];
    if (!adapter) {
      throw new BadRequestException(`Unknown provider: ${input.provider}`);
    }
    if (!adapter.isConfigured()) {
      throw new BadRequestException(
        `Provider ${input.provider} is not configured on this environment.`,
      );
    }

    const intent = await this.prismaService.execute((prisma) =>
      prisma.paymentIntent.create({
        data: {
          userId: input.userId,
          caseId: input.caseId,
          counsellorId: input.counsellorId,
          amountMinor: input.amountMinor,
          currency: input.currency ?? 'XOF',
          provider: input.provider,
          description: input.description,
        },
      }),
    );
    if (!intent) {
      throw new Error('Failed to persist payment intent.');
    }

    const result = await adapter.initiate({
      intentId: intent.id,
      amountMinor: intent.amountMinor,
      currency: intent.currency,
      description: intent.description ?? 'KPB Education',
      customer: input.customer,
      returnUrl: input.returnUrl,
      cancelUrl: input.cancelUrl,
    });

    // Le webhook peut arriver AVANT le retour d'initiate (paiement mobile
    // money très rapide) : on ne passe à `pending` que depuis `created`, sinon
    // on enregistre seulement la référence et l'URL sans toucher au statut.
    const updated = await this.prismaService.execute(async (prisma) => {
      const { count } = await prisma.paymentIntent.updateMany({
        where: { id: intent.id, status: 'created' },
        data: {
          providerRef: result.providerRef,
          checkoutUrl: result.checkoutUrl,
          status: 'pending',
        },
      });
      if (count === 0) {
        await prisma.paymentIntent.updateMany({
          where: { id: intent.id },
          data: {
            providerRef: result.providerRef,
            checkoutUrl: result.checkoutUrl,
          },
        });
      }
      return prisma.paymentIntent.findUnique({ where: { id: intent.id } });
    });
    return updated;
  }

  /**
   * Lecture d'un intent. Côté étudiant, `userId` est obligatoire (audit
   * 2026-11-22, constat 25) : un id d'intent obtenu ailleurs (capture, URL de
   * retour) ne donne pas accès au paiement d'un autre payeur — 404 identique
   * à un id inconnu, pour ne pas révéler son existence.
   */
  /**
   * Création d'un intent demandée directement par un étudiant
   * (`POST /payments/intents`). Audit 2026-11-22, constat 25 : le corps n'est
   * pas validé, donc ici
   *   - `manual` est refusé (seul le back-office confirme un paiement hors
   *     ligne, cf. `markPaidManually`) ;
   *   - `caseId` doit être un dossier de l'appelant (même règle que
   *     `/me/purchases`), sinon 404 ;
   *   - `counsellorId` n'est pas accepté de l'étudiant (ignoré) ;
   *   - le montant doit être un entier positif. Il reste libre : cette route
   *     n'a pas de catalogue d'où le dériver, et un intent créé ici n'est lié
   *     à AUCUN achat (seul `/me/purchases` crée un ServicePurchase, au prix
   *     du catalogue) — le payer ne débloque donc rien.
   */
  async createStudentIntent(input: {
    userId: string;
    provider: ProviderName;
    amountMinor: number;
    currency?: string;
    caseId?: string;
    description?: string;
    customer: { email: string; phone: string; fullName: string };
    returnUrl: string;
    cancelUrl: string;
  }) {
    if (input.provider === 'manual') {
      throw new BadRequestException(
        'The manual provider is reserved to the back-office.',
      );
    }
    if (!Number.isInteger(input.amountMinor)) {
      throw new BadRequestException('amountMinor must be an integer.');
    }
    if (input.caseId !== undefined && input.caseId !== null) {
      const owned = await this.prismaService.execute((prisma) =>
        prisma.case.findFirst({
          where: { id: String(input.caseId), userId: input.userId },
          select: { id: true },
        }),
      );
      if (!owned) {
        throw new NotFoundException(`Case ${input.caseId} not found.`);
      }
    }
    return this.createIntent({
      userId: input.userId,
      provider: input.provider,
      amountMinor: input.amountMinor,
      currency: input.currency,
      caseId: input.caseId ?? undefined,
      description: input.description,
      customer: input.customer,
      returnUrl: input.returnUrl,
      cancelUrl: input.cancelUrl,
    });
  }

  async getIntent(id: string, userId?: string) {
    const intent = await this.prismaService.execute((prisma) =>
      prisma.paymentIntent.findFirst({
        where: { id, ...(userId !== undefined ? { userId } : {}) },
      }),
    );
    if (!intent) {
      throw new NotFoundException(`Payment intent ${id} not found.`);
    }
    return intent;
  }

  /**
   * Process an incoming webhook. Dispatches to the adapter for signature
   * verification, then updates the matching PaymentIntent. Always returns a
   * 200 response to the provider once persisted — they will retry on 5xx.
   */
  async handleWebhook(provider: ProviderName, raw: WebhookRawInput) {
    const adapter = this.adapters[provider];
    if (!adapter) {
      throw new BadRequestException(`Unknown provider: ${provider}`);
    }

    const event = await adapter.parseWebhook(raw);

    // Prefer intentId (our id in custom metadata) over providerRef when
    // available — providerRef could theoretically collide across providers.
    const where = event.intentId
      ? { id: event.intentId }
      : event.providerRef
        ? { providerRef: event.providerRef }
        : null;
    if (!where) {
      this.logger.warn(
        `Webhook with neither intentId nor providerRef from ${provider}`,
      );
      return { ok: false };
    }

    // Transitions gardées (audit 2026-11-22, constat 7) : les notifications
    // mobile money arrivent dans le désordre et sont re-livrées par les
    // fournisseurs. Un intent `paid` (ou `refunded`) ne redescend JAMAIS ;
    // `paidAt` n'est posé qu'à la première transition vers `paid`. L'écriture
    // est conditionnelle (updateMany … status in [...]) pour rester sûre
    // quand deux webhooks du même intent arrivent en même temps.
    const allowedFrom = WEBHOOK_ALLOWED_FROM[event.status];
    const now = new Date();
    const outcome = await this.prismaService.execute((client) =>
      client.$transaction(async (prisma) => {
        const { count } = await prisma.paymentIntent.updateMany({
          where: { ...where, status: { in: allowedFrom } },
          data: {
            status: event.status,
            ...(event.status === 'paid' ? { paidAt: now } : {}),
            failureReason: event.status === 'paid' ? null : event.failureReason,
            lastWebhookAt: now,
          },
        });
        const current = await prisma.paymentIntent.findUnique({ where });
        if (count === 0 && current) {
          // Rejeu ou notification tardive : on ne touche qu'à lastWebhookAt
          // (trace support), jamais au statut ni à paidAt.
          await prisma.paymentIntent.updateMany({
            where: { id: current.id },
            data: { lastWebhookAt: now },
          });
        }
        // Constats 23/40 : l'achat lié passe à `paid` dans la MÊME transaction,
        // uniquement quand cet appel a réellement fait passer l'intent à `paid`
        // (un webhook ignoré ne touche à rien).
        const settledPurchases =
          count > 0 && event.status === 'paid' && current
            ? await this.settleLinkedPurchase(prisma, current.id)
            : 0;
        return { applied: count > 0, current, settledPurchases };
      }),
    );

    if (outcome === null) {
      // Pas de base (mode démo) : rien à persister.
      this.logger.warn(`Webhook ${provider} reçu sans base de données.`);
      return { ok: false };
    }
    if (!outcome.current) {
      throw new NotFoundException('Payment intent not found for this webhook.');
    }
    const { applied, current } = outcome;
    if (!applied) {
      this.logger.warn(
        `Webhook ${provider} → intent ${current.id} : transition ${current.status} → ${event.status} ignorée (rejeu ou notification tardive)`,
      );
      return { ok: true, intentId: current.id, ignored: true };
    }

    this.logger.log(
      `Webhook ${provider} → intent ${current.id} = ${current.status}`,
    );
    if (outcome.settledPurchases > 0) {
      this.logger.log(`Achat lié à l'intent ${current.id} réconcilié → paid`);
    }
    return { ok: true, intentId: current.id };
  }

  /**
   * Admin-only: mark an intent as paid manually (offline payments).
   *
   * Transition gardée (même règle que les webhooks) : écriture conditionnelle
   * depuis created/pending/failed/cancelled. Un intent déjà `paid` est rendu
   * tel quel (idempotent : ni paidAt ni provider réécrits) ; un intent
   * `refunded` ne repasse jamais `paid` (409).
   */
  async markPaidManually(id: string, note?: string) {
    const outcome = await this.prismaService.execute((client) =>
      client.$transaction(async (prisma) => {
        const { count } = await prisma.paymentIntent.updateMany({
          where: { id, status: { in: WEBHOOK_ALLOWED_FROM.paid } },
          data: {
            status: 'paid',
            paidAt: new Date(),
            failureReason: null,
            description: note,
            provider: 'manual',
          },
        });
        // Constats 23/40 : même réconciliation que le webhook, seulement si
        // cet appel a fait la transition (un second mark-paid ne refait rien).
        if (count > 0) await this.settleLinkedPurchase(prisma, id);
        const current = await prisma.paymentIntent.findUnique({ where: { id } });
        return { applied: count > 0, current };
      }),
    );
    if (outcome === null) return null;
    const { applied, current } = outcome;
    if (!current) throw new NotFoundException(`Payment intent ${id} not found.`);
    if (!applied && current.status !== 'paid') {
      throw new ConflictException(
        `Payment intent ${id} is ${current.status}: it cannot be marked paid.`,
      );
    }
    return current;
  }

  /**
   * Audit 2026-11-22, constats 23 et 40 : quand un intent passe à `paid`,
   * l'achat (ServicePurchase) qui le référence quitte `pending_payment` pour
   * `paid` — avant, rien n'appelait `reconcilePurchase()` et un achat payé
   * en ligne restait en attente indéfiniment. Écrit ici, dans la transaction
   * de l'intent, plutôt qu'en appelant ServicePackagesService (qui dépend
   * déjà de PaymentsService : dépendance circulaire). Idempotent : seul un
   * achat encore `pending_payment` est modifié ; un achat annulé, remboursé
   * ou déjà en cours de livraison n'est jamais touché.
   */
  private async settleLinkedPurchase(
    prisma: Prisma.TransactionClient,
    intentId: string,
  ): Promise<number> {
    const { count } = await prisma.servicePurchase.updateMany({
      where: { paymentIntentId: intentId, status: 'pending_payment' },
      data: { status: 'paid' },
    });
    return count;
  }
}
