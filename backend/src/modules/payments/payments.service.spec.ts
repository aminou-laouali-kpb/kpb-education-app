import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';

import type { PrismaService } from '../prisma/prisma.service';
import type { CinetpayAdapter } from './cinetpay.adapter';
import type { PaydunyaAdapter } from './paydunya.adapter';
import type { WebhookParsedEvent } from './payment-provider.interface';
import { PaymentsService } from './payments.service';

/**
 * Audit 2026-11-22, constat 7 : un webhook tardif ou rejoué ne doit jamais
 * faire redescendre un intent `paid`, ni effacer/réécrire `paidAt`.
 *
 * Le faux client applique réellement le filtre `status: { in: [...] }` de
 * `updateMany` : c'est cette écriture conditionnelle qui protège en
 * concurrence, le test vérifie donc la garde côté « base ».
 */
type Row = {
  id: string;
  providerRef: string | null;
  status: string;
  paidAt: Date | null;
  failureReason: string | null;
  lastWebhookAt: Date | null;
  provider?: string;
  description?: string | null;
  checkoutUrl?: string | null;
};

type Where = { id?: string; providerRef?: string; status?: string | { in: string[] } };

type PurchaseRow = { id: string; paymentIntentId: string | null; status: string };

function setup(
  initial: Partial<Row> = {},
  onInitiate?: () => Promise<unknown>,
  purchaseInit: Partial<PurchaseRow> | null = null,
) {
  const row: Row = {
    id: 'pi_1',
    providerRef: 'cp_ref_1',
    status: 'pending',
    paidAt: null,
    failureReason: null,
    lastWebhookAt: null,
    ...initial,
  };
  const matches = (where: Where) =>
    (where.id === undefined || where.id === row.id) &&
    (where.providerRef === undefined || where.providerRef === row.providerRef) &&
    (where.status === undefined ||
      (typeof where.status === 'string' ? where.status === row.status : where.status.in.includes(row.status)));
  // Achat (ServicePurchase) lié à l'intent, constats 23/40.
  const purchase: PurchaseRow | null = purchaseInit
    ? { id: 'sp_1', paymentIntentId: 'pi_1', status: 'pending_payment', ...purchaseInit }
    : null;
  const purchaseWrites: string[] = [];
  const caseOwners: Record<string, string> = { case_own: 'u1', case_other: 'u2' };
  const created: Array<Record<string, unknown>> = [];
  let transactions = 0;
  const client = {
    paymentIntent: {
      updateMany: async ({ where, data }: { where: Where; data: Partial<Row> }) => {
        if (!matches(where)) return { count: 0 };
        for (const [k, v] of Object.entries(data)) {
          if (v !== undefined) (row as Record<string, unknown>)[k] = v;
        }
        return { count: 1 };
      },
      findUnique: async ({ where }: { where: Where }) => (matches(where) ? { ...row } : null),
      findFirst: async ({ where }: { where: Where & { userId?: string } }) =>
        matches(where) && (where.userId === undefined || where.userId === (row as { userId?: string }).userId)
          ? { ...row }
          : null,
      create: async ({ data }: { data: Partial<Row> }) => {
        created.push({ ...data });
        Object.assign(row, { status: 'created', providerRef: null, paidAt: null }, data);
        return { ...row, amountMinor: 5000, currency: 'XOF', description: null };
      },
    },
    servicePurchase: {
      updateMany: async ({ where, data }: { where: { paymentIntentId: string; status: string }; data: { status: string } }) => {
        if (!purchase || purchase.paymentIntentId !== where.paymentIntentId || purchase.status !== where.status) {
          return { count: 0 };
        }
        purchase.status = data.status;
        purchaseWrites.push(data.status);
        return { count: 1 };
      },
    },
    case: {
      findFirst: async ({ where }: { where: { id: string; userId: string } }) =>
        caseOwners[where.id] === where.userId ? { id: where.id } : null,
    },
  };
  const tx = {
    ...client,
    $transaction: async (fn: (c: typeof client) => unknown) => {
      transactions += 1;
      return fn(client);
    },
  };
  const prisma = {
    execute: async (fn: (c: typeof tx) => unknown) => fn(tx),
  } as unknown as PrismaService;

  let next: WebhookParsedEvent;
  const cinetpay = {
    name: 'cinetpay',
    isConfigured: () => true,
    initiate: async () => {
      await onInitiate?.();
      return { providerRef: 'cp_ref_1', checkoutUrl: 'https://pay.test/1' };
    },
    parseWebhook: async () => next,
  } as unknown as CinetpayAdapter;
  const paydunya = { ...cinetpay, name: 'paydunya' } as unknown as PaydunyaAdapter;
  const service = new PaymentsService(prisma, cinetpay, paydunya);

  const webhook = (status: WebhookParsedEvent['status'], over: Partial<WebhookParsedEvent> = {}) => {
    next = { providerRef: 'cp_ref_1', intentId: 'pi_1', status, amountMinor: 5000, ...over };
    return service.handleWebhook('cinetpay', { body: {}, headers: {} });
  };
  const createIntent = () =>
    service.createIntent({
      userId: 'u1',
      provider: 'cinetpay',
      amountMinor: 5000,
      customer: { email: 'a@b.c', phone: '+221', fullName: 'A' },
      returnUrl: 'https://r',
      cancelUrl: 'https://c',
    });
  return {
    row,
    webhook,
    service,
    createIntent,
    purchase,
    purchaseWrites,
    created,
    transactions: () => transactions,
  };
}

describe('PaymentsService.handleWebhook — transitions gardées', () => {
  it('pending → paid : pose paidAt', async () => {
    const { row, webhook } = setup();
    await expect(webhook('paid')).resolves.toEqual({ ok: true, intentId: 'pi_1' });
    expect(row.status).toBe('paid');
    expect(row.paidAt).toBeInstanceOf(Date);
  });

  it('un webhook failed APRÈS paid est ignoré : statut et paidAt intacts', async () => {
    const paidAt = new Date('2026-11-20T10:00:00Z');
    const { row, webhook } = setup({ status: 'paid', paidAt });
    const res = await webhook('failed', { failureReason: 'INSUFFICIENT_FUNDS' });
    expect(res).toEqual({ ok: true, intentId: 'pi_1', ignored: true });
    expect(row.status).toBe('paid');
    expect(row.paidAt).toBe(paidAt);
    expect(row.failureReason).toBeNull();
    // Trace support : la réception est quand même notée.
    expect(row.lastWebhookAt).toBeInstanceOf(Date);
  });

  it('séquence désordonnée paid puis failed (via providerRef) : reste paid', async () => {
    const { row, webhook } = setup();
    await webhook('paid', { intentId: null });
    const firstPaidAt = row.paidAt;
    await webhook('failed', { intentId: null });
    await webhook('cancelled', { intentId: null });
    await webhook('pending', { intentId: null });
    expect(row.status).toBe('paid');
    expect(row.paidAt).toBe(firstPaidAt);
  });

  it('webhook paid rejoué : idempotent, paidAt non réécrit', async () => {
    const paidAt = new Date('2026-11-20T10:00:00Z');
    const { row, webhook } = setup({ status: 'paid', paidAt });
    await expect(webhook('paid')).resolves.toMatchObject({ ok: true, ignored: true });
    expect(row.paidAt).toBe(paidAt);
  });

  it('un intent remboursé ne repasse pas paid', async () => {
    const { row, webhook } = setup({ status: 'refunded', paidAt: new Date('2026-11-01') });
    await webhook('paid');
    expect(row.status).toBe('refunded');
  });

  it('failed puis paid (notifs désordonnées) : paid gagne et efface le motif', async () => {
    const { row, webhook } = setup();
    await webhook('failed', { failureReason: 'TIMEOUT' });
    expect(row.status).toBe('failed');
    expect(row.paidAt).toBeNull();
    await webhook('paid');
    expect(row.status).toBe('paid');
    expect(row.paidAt).toBeInstanceOf(Date);
    expect(row.failureReason).toBeNull();
  });

  it('un failed tardif ne redevient pas pending', async () => {
    const { row, webhook } = setup({ status: 'failed' });
    await webhook('pending');
    expect(row.status).toBe('failed');
  });

  it('intent inconnu : 404', async () => {
    const { webhook } = setup();
    await expect(webhook('paid', { intentId: 'pi_inconnu' })).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('PaymentsService.createIntent — pas de retour à pending', () => {
  it('nominal : created → pending avec référence et URL', async () => {
    const { row, createIntent } = setup();
    const out = await createIntent();
    expect(out).toMatchObject({ status: 'pending', providerRef: 'cp_ref_1', checkoutUrl: 'https://pay.test/1' });
    expect(row.status).toBe('pending');
  });

  it('webhook paid arrivé AVANT le retour d’initiate : reste paid', async () => {
    let webhook: ReturnType<typeof setup>['webhook'] = async () => ({ ok: true });
    const ctx = setup({}, async () => {
      await webhook('paid');
    });
    webhook = ctx.webhook;
    const out = await ctx.createIntent();
    expect(ctx.row.status).toBe('paid');
    expect(ctx.row.paidAt).toBeInstanceOf(Date);
    expect(out).toMatchObject({ status: 'paid', checkoutUrl: 'https://pay.test/1' });
  });
});

describe('PaymentsService.markPaidManually — transition gardée', () => {
  it('pending → paid manuel', async () => {
    const { row, service } = setup({ provider: 'cinetpay' });
    await expect(service.markPaidManually('pi_1', 'virement')).resolves.toMatchObject({ status: 'paid' });
    expect(row.provider).toBe('manual');
    expect(row.paidAt).toBeInstanceOf(Date);
  });

  it('déjà paid : idempotent, ni paidAt ni provider réécrits', async () => {
    const paidAt = new Date('2026-11-20T10:00:00Z');
    const { row, service } = setup({ status: 'paid', paidAt, provider: 'cinetpay', description: 'orig' });
    await expect(service.markPaidManually('pi_1', 'note')).resolves.toMatchObject({ status: 'paid' });
    expect(row.paidAt).toBe(paidAt);
    expect(row.provider).toBe('cinetpay');
    expect(row.description).toBe('orig');
  });

  it('refunded ne repasse jamais paid : 409', async () => {
    const { row, service } = setup({ status: 'refunded', paidAt: new Date('2026-11-01') });
    await expect(service.markPaidManually('pi_1')).rejects.toBeInstanceOf(ConflictException);
    expect(row.status).toBe('refunded');
  });

  it('intent inconnu : 404', async () => {
    const { service } = setup();
    await expect(service.markPaidManually('pi_x')).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('Constats 23/40 — réconciliation de l’achat lié quand l’intent passe à paid', () => {
  it('webhook paid : l’achat pending_payment passe à paid dans la même transaction', async () => {
    const ctx = setup({}, undefined, {});
    await expect(ctx.webhook('paid')).resolves.toEqual({ ok: true, intentId: 'pi_1' });
    expect(ctx.row.status).toBe('paid');
    expect(ctx.purchase?.status).toBe('paid');
    expect(ctx.transactions()).toBe(1);
  });

  it('webhook paid reçu par providerRef seul : réconcilie aussi', async () => {
    const ctx = setup({}, undefined, {});
    await ctx.webhook('paid', { intentId: null });
    expect(ctx.purchase?.status).toBe('paid');
  });

  it('webhook paid rejoué : aucune nouvelle écriture sur l’achat', async () => {
    const ctx = setup({}, undefined, {});
    await ctx.webhook('paid');
    await expect(ctx.webhook('paid')).resolves.toMatchObject({ ignored: true });
    expect(ctx.purchaseWrites).toEqual(['paid']);
  });

  it('webhook ignoré (intent déjà paid, achat annulé entre-temps) : l’achat reste intact', async () => {
    const ctx = setup({ status: 'paid', paidAt: new Date('2026-11-20') }, undefined, { status: 'cancelled' });
    await ctx.webhook('paid');
    expect(ctx.purchase?.status).toBe('cancelled');
    expect(ctx.purchaseWrites).toEqual([]);
  });

  it('webhook failed / pending : l’achat reste pending_payment', async () => {
    const ctx = setup({}, undefined, {});
    await ctx.webhook('failed', { failureReason: 'TIMEOUT' });
    await ctx.webhook('cancelled');
    expect(ctx.purchase?.status).toBe('pending_payment');
    expect(ctx.purchaseWrites).toEqual([]);
  });

  it('achat déjà en livraison : jamais rétrogradé à paid', async () => {
    const ctx = setup({}, undefined, { status: 'in_progress' });
    await ctx.webhook('paid');
    expect(ctx.purchase?.status).toBe('in_progress');
  });

  it('intent sans achat lié (paiement libre) : rien à réconcilier, pas d’erreur', async () => {
    const ctx = setup();
    await expect(ctx.webhook('paid')).resolves.toEqual({ ok: true, intentId: 'pi_1' });
  });

  it('mark-paid admin : réconcilie l’achat ; un second mark-paid ne réécrit rien', async () => {
    const ctx = setup({}, undefined, {});
    await ctx.service.markPaidManually('pi_1', 'virement');
    expect(ctx.purchase?.status).toBe('paid');
    await ctx.service.markPaidManually('pi_1', 'virement');
    expect(ctx.purchaseWrites).toEqual(['paid']);
  });

  it('mark-paid refusé (refunded, 409) : l’achat n’est pas touché', async () => {
    const ctx = setup({ status: 'refunded' }, undefined, {});
    await expect(ctx.service.markPaidManually('pi_1')).rejects.toBeInstanceOf(ConflictException);
    expect(ctx.purchase?.status).toBe('pending_payment');
  });
});

describe('Constat 25 — intents côté étudiant', () => {
  it('getIntent avec userId : 404 pour l’intent d’un autre payeur', async () => {
    const ctx = setup({ userId: 'u1' } as Partial<Row>);
    await expect(ctx.service.getIntent('pi_1', 'u2')).rejects.toBeInstanceOf(NotFoundException);
    await expect(ctx.service.getIntent('pi_1', 'u1')).resolves.toMatchObject({ id: 'pi_1' });
  });

  const base = {
    userId: 'u1',
    provider: 'cinetpay' as const,
    amountMinor: 5000,
    customer: { email: 'a@b.c', phone: '+221', fullName: 'A' },
    returnUrl: 'https://r',
    cancelUrl: 'https://c',
  };

  it('refuse le fournisseur manual', async () => {
    const ctx = setup();
    await expect(ctx.service.createStudentIntent({ ...base, provider: 'manual' })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(ctx.created).toHaveLength(0);
  });

  it('refuse le dossier d’un autre utilisateur (404, aucun intent créé)', async () => {
    const ctx = setup();
    await expect(ctx.service.createStudentIntent({ ...base, caseId: 'case_other' })).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(ctx.created).toHaveLength(0);
  });

  it('accepte son propre dossier', async () => {
    const ctx = setup();
    await ctx.service.createStudentIntent({ ...base, caseId: 'case_own' });
    expect(ctx.created).toEqual([expect.objectContaining({ caseId: 'case_own', userId: 'u1' })]);
  });

  it('montant non entier ou négatif : 400', async () => {
    const ctx = setup();
    await expect(ctx.service.createStudentIntent({ ...base, amountMinor: 10.5 })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(ctx.service.createStudentIntent({ ...base, amountMinor: -1 })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(ctx.created).toHaveLength(0);
  });

  it('counsellorId venu du corps n’est jamais écrit', async () => {
    const ctx = setup();
    await ctx.service.createStudentIntent({ ...base, counsellorId: 'c_x' } as typeof base);
    expect(ctx.created[0]).not.toHaveProperty('counsellorId', 'c_x');
  });
});
