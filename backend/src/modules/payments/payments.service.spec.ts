import { NotFoundException } from '@nestjs/common';

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
};

type Where = { id?: string; providerRef?: string; status?: { in: string[] } };

function setup(initial: Partial<Row> = {}) {
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
    (where.status === undefined || where.status.in.includes(row.status));
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
    },
  };
  const prisma = {
    execute: async (fn: (c: typeof client) => unknown) => fn(client),
  } as unknown as PrismaService;

  let next: WebhookParsedEvent;
  const cinetpay = {
    name: 'cinetpay',
    isConfigured: () => true,
    initiate: async () => ({ providerRef: 'x', checkoutUrl: 'x' }),
    parseWebhook: async () => next,
  } as unknown as CinetpayAdapter;
  const paydunya = { ...cinetpay, name: 'paydunya' } as unknown as PaydunyaAdapter;
  const service = new PaymentsService(prisma, cinetpay, paydunya);

  const webhook = (status: WebhookParsedEvent['status'], over: Partial<WebhookParsedEvent> = {}) => {
    next = { providerRef: 'cp_ref_1', intentId: 'pi_1', status, amountMinor: 5000, ...over };
    return service.handleWebhook('cinetpay', { body: {}, headers: {} });
  };
  return { row, webhook };
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
