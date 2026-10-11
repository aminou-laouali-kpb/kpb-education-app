import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';

type ProviderName = 'cinetpay' | 'paydunya' | 'stripe' | 'manual';
type PurchaseStatus =
  | 'pending_payment'
  | 'paid'
  | 'in_progress'
  | 'delivered'
  | 'cancelled'
  | 'refunded';

const PURCHASE_STATUSES: PurchaseStatus[] = [
  'pending_payment',
  'paid',
  'in_progress',
  'delivered',
  'cancelled',
  'refunded',
];

/**
 * Catalog + purchase orchestration for Phase 3 monetized bundles.
 *
 * Two product families live here:
 *   1. "Dossier prêt" — fixed-price CV + motivation + reco-letter review
 *      bundle in FR + EN. This is the flagship SKU parents are willing to
 *      pay for.
 *   2. Scholarship / visa prep kits (10k–25k FCFA) — self-serve packets
 *      bundled with templates, checklists, and one counsellor sync-up.
 *
 * A ServicePurchase is always created first with `status: pending_payment`.
 * A PaymentIntent is then attached (CinetPay / Paydunya / manual). When the
 * payment webhook settles the intent to `paid`, `reconcilePurchase()` flips
 * the purchase to `paid` so ops can start delivery.
 *
 * We do *not* auto-refund on payment failure — ops investigates because the
 * failure mode is usually a stuck mobile-money transfer that resolves itself.
 */
const CHECKOUT_PROVIDERS: ReadonlyArray<string> = ['cinetpay', 'paydunya'];

/**
 * Projection étudiant d'un achat : jamais les notes du back-office
 * (`internalNotes`), et du dossier lié seulement l'identifiant et la
 * référence (pas les téléphones du conseiller ni les champs commerciaux).
 */
const STUDENT_PURCHASE_VIEW = {
  omit: { internalNotes: true },
  include: {
    package: true,
    case: {
      select: {
        id: true,
        referenceCode: true,
        requestedCountryId: true,
        source: true,
      },
    },
    paymentIntent: true,
  },
} as const;

@Injectable()
export class ServicePackagesService {
  private readonly logger = new Logger(ServicePackagesService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly paymentsService: PaymentsService,
  ) {}

  // ── Public catalog ────────────────────────────────────────────────────────

  async listPublic(params: { category?: string } = {}) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.servicePackage.findMany({
        where: {
          isActive: true,
          ...(params.category
            ? { category: params.category as never }
            : {}),
        },
        orderBy: [{ displayOrder: 'asc' }, { priceXOF: 'asc' }],
        select: {
          id: true,
          code: true,
          nameFr: true,
          nameEn: true,
          summaryFr: true,
          summaryEn: true,
          descriptionFr: true,
          descriptionEn: true,
          category: true,
          priceXOF: true,
          deliverablesFr: true,
          deliverablesEn: true,
          turnaroundFr: true,
          turnaroundEn: true,
        },
      }),
    );
    return { items: items ?? [] };
  }

  async getPublic(code: string) {
    const pkg = await this.prismaService.execute((prisma) =>
      prisma.servicePackage.findUnique({ where: { code } }),
    );
    if (!pkg || !pkg.isActive) {
      throw new NotFoundException(`Service package ${code} not found.`);
    }
    return pkg;
  }

  // ── Purchases (student-facing) ────────────────────────────────────────────

  /**
   * Kick off a purchase. We:
   *   1. Create a ServicePurchase row (pending_payment).
   *   2. Ask PaymentsService to init a PaymentIntent for the package price.
   *   3. Link intent → purchase, return the checkout URL to the mobile app.
   *
   * Prefer CinetPay by default (broadest MoMo coverage). Student can override.
   */
  async purchase(input: {
    userId: string;
    packageCode: string;
    provider?: ProviderName;
    caseId?: string;
    returnUrl: string;
    cancelUrl: string;
    customer?: { email?: string; phone?: string; fullName?: string };
  }) {
    // `manual` n'est pas un moyen de paiement en ligne : seul le back-office
    // confirme un paiement manuel (flux WhatsApp).
    const provider = input.provider ?? 'cinetpay';
    if (!CHECKOUT_PROVIDERS.includes(provider)) {
      throw new BadRequestException(`Unsupported payment provider: ${provider}`);
    }
    if (
      typeof input.returnUrl !== 'string' ||
      typeof input.cancelUrl !== 'string' ||
      !input.returnUrl ||
      !input.cancelUrl
    ) {
      throw new BadRequestException('returnUrl and cancelUrl are required.');
    }
    const pkg = await this.getPublic(input.packageCode);
    // Comme le flux WhatsApp : un achat ne peut être rattaché qu'à un dossier
    // de l'appelant (avant, n'importe quel caseId était accepté).
    const linkedCase = input.caseId
      ? await this.getOwnedCase(input.userId, input.caseId)
      : null;

    // Resolve customer details from the stored profile. The access-token
    // payload only carries id/email, so phone/fullName passed by the
    // controller are undefined — mobile-money providers require a real phone.
    const profile = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({ where: { id: input.userId } }),
    );
    const customer = {
      email: profile?.email || input.customer?.email || '',
      phone: profile?.phone || input.customer?.phone || '',
      fullName: profile?.fullName || input.customer?.fullName || '',
    };

    // L'intent d'abord : s'il échoue (fournisseur non configuré…), aucune
    // ligne ServicePurchase orpheline ne pollue le pipeline admin.
    const intent = await this.paymentsService.createIntent({
      userId: input.userId,
      provider,
      amountMinor: pkg.priceXOF,
      currency: 'XOF',
      caseId: linkedCase?.id,
      description: `KPB — ${pkg.nameFr}`,
      customer,
      returnUrl: input.returnUrl,
      cancelUrl: input.cancelUrl,
    });
    if (!intent) {
      throw new Error('Failed to create payment intent for purchase.');
    }

    const purchase = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.create({
        data: {
          packageId: pkg.id,
          userId: input.userId,
          caseId: linkedCase?.id,
          amountXOF: pkg.priceXOF,
          status: 'pending_payment',
          source: 'checkout',
          paymentIntentId: intent.id,
        },
        ...STUDENT_PURCHASE_VIEW,
      }),
    );
    if (!purchase) {
      throw new Error('Failed to create service purchase.');
    }
    return purchase;
  }

  /**
   * WhatsApp-first sales flow: create the purchase row and let a counsellor
   * collect/confirm payment manually. No PaymentIntent or checkout URL.
   */
  async createWhatsAppPurchase(input: {
    userId: string;
    packageCode: string;
    caseId?: string;
    source?: string;
  }) {
    const pkg = await this.getPublic(input.packageCode);
    const source = this.normalizeSource(input.source);
    const linkedCase = input.caseId
      ? await this.getOwnedCase(input.userId, input.caseId)
      : null;

    const notes = [
      'Created from mobile WhatsApp CTA.',
      `SKU: ${pkg.code}`,
      `Source: ${source}`,
      linkedCase ? `Case: ${linkedCase.referenceCode}` : null,
      linkedCase?.requestedCountryId
        ? `Destination: ${linkedCase.requestedCountryId}`
        : null,
    ]
      .filter(Boolean)
      .join('\n');

    // Idempotency: tapping the WhatsApp CTA repeatedly (the normal
    // tap → WhatsApp → return → tap-again loop, or pull-to-refresh then
    // re-tap) must not mint duplicate pending rows — that would inflate the
    // per-SKU / per-destination demand + pipeline signal KPB-56 exists to make
    // legible. Reuse the open WhatsApp-arranged request for the same
    // (user, package, case) instead of creating another.
    const existing = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findFirst({
        where: {
          userId: input.userId,
          packageId: pkg.id,
          caseId: linkedCase?.id ?? null,
          status: 'pending_payment',
          source: { not: 'checkout' },
        },
        orderBy: { createdAt: 'desc' },
        ...STUDENT_PURCHASE_VIEW,
      }),
    );
    if (existing) {
      return existing;
    }

    const purchase = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.create({
        data: {
          packageId: pkg.id,
          userId: input.userId,
          caseId: linkedCase?.id,
          amountXOF: pkg.priceXOF,
          status: 'pending_payment',
          source,
          internalNotes: notes,
        },
        ...STUDENT_PURCHASE_VIEW,
      }),
    );
    if (!purchase) {
      throw new Error('Failed to create WhatsApp service purchase.');
    }
    return purchase;
  }

  /** Student's own purchase history (most-recent first). */
  async listForUser(userId: string) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        ...STUDENT_PURCHASE_VIEW,
      }),
    );
    return { items: items ?? [] };
  }

  async getForUser(userId: string, id: string) {
    const purchase = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findFirst({
        where: { id, userId },
        ...STUDENT_PURCHASE_VIEW,
      }),
    );
    if (!purchase) {
      throw new NotFoundException(`Purchase ${id} not found.`);
    }
    return purchase;
  }

  // ── Admin CRUD ────────────────────────────────────────────────────────────

  async listAdmin() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.servicePackage.findMany({
        orderBy: [{ displayOrder: 'asc' }, { createdAt: 'desc' }],
      }),
    );
    return { items: items ?? [] };
  }

  async createPackage(data: {
    code: string;
    nameFr: string;
    nameEn: string;
    summaryFr: string;
    summaryEn: string;
    descriptionFr: string;
    descriptionEn: string;
    category: string;
    priceXOF: number;
    deliverablesFr?: string[];
    deliverablesEn?: string[];
    turnaroundFr?: string;
    turnaroundEn?: string;
    displayOrder?: number;
    isActive?: boolean;
  }) {
    if (data.priceXOF < 0) {
      throw new BadRequestException('priceXOF cannot be negative.');
    }
    return this.prismaService.execute((prisma) =>
      prisma.servicePackage.create({
        data: {
          ...data,
          category: data.category as never,
          deliverablesFr: data.deliverablesFr ?? [],
          deliverablesEn: data.deliverablesEn ?? [],
        },
      }),
    );
  }

  async updatePackage(
    id: string,
    data: Partial<{
      nameFr: string;
      nameEn: string;
      summaryFr: string;
      summaryEn: string;
      descriptionFr: string;
      descriptionEn: string;
      priceXOF: number;
      deliverablesFr: string[];
      deliverablesEn: string[];
      turnaroundFr: string;
      turnaroundEn: string;
      displayOrder: number;
      isActive: boolean;
    }>,
  ) {
    return this.prismaService.execute((prisma) =>
      prisma.servicePackage.update({ where: { id }, data }),
    );
  }

  async listPurchasesAdmin(status?: string) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findMany({
        where: status ? { status: status as never } : {},
        orderBy: { createdAt: 'desc' },
        include: {
          package: true,
          user: { select: { id: true, fullName: true, email: true } },
          case: {
            select: {
              id: true,
              referenceCode: true,
              requestedCountryId: true,
              source: true,
            },
          },
          paymentIntent: true,
        },
      }),
    );
    return { items: items ?? [] };
  }

  async updatePurchaseStatus(
    id: string,
    status: string,
    internalNotes?: string,
  ) {
    if (!PURCHASE_STATUSES.includes(status as PurchaseStatus)) {
      throw new BadRequestException(`Unknown purchase status: ${status}`);
    }
    return this.prismaService.execute((prisma) =>
      prisma.servicePurchase.update({
        where: { id },
        data: {
          status: status as never,
          internalNotes,
          deliveredAt: status === 'delivered' ? new Date() : undefined,
        },
      }),
    );
  }

  /**
   * Called by the payments webhook loop: if a paid intent has a matching
   * purchase row still in `pending_payment`, advance it to `paid`. Safe to
   * call repeatedly (idempotent) since we check current status first.
   */
  async reconcilePurchase(paymentIntentId: string) {
    const purchase = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findUnique({
        where: { paymentIntentId },
        include: { paymentIntent: true },
      }),
    );
    if (!purchase) return null;
    if (purchase.status !== 'pending_payment') {
      return purchase;
    }
    if (purchase.paymentIntent?.status !== 'paid') {
      return purchase;
    }
    const updated = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.update({
        where: { id: purchase.id },
        data: { status: 'paid' },
      }),
    );
    this.logger.log(
      `Purchase ${purchase.id} reconciled → paid (intent ${paymentIntentId})`,
    );
    return updated;
  }

  private normalizeSource(source?: string) {
    const normalized = (source ?? 'service_packages')
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_-]+/g, '_')
      .slice(0, 64);
    return normalized || 'service_packages';
  }

  private async getOwnedCase(userId: string, caseId: string) {
    const linkedCase = await this.prismaService.execute((prisma) =>
      prisma.case.findFirst({
        where: { id: caseId, userId },
        select: {
          id: true,
          referenceCode: true,
          requestedCountryId: true,
          source: true,
        },
      }),
    );
    if (!linkedCase) {
      throw new NotFoundException(`Case ${caseId} not found.`);
    }
    return linkedCase;
  }
}
