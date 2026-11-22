import { BadRequestException, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import type { PassService } from '../pass/pass.service';
import { ServicePackagesService } from './service-packages.service';

/**
 * Guards KPB-56: the WhatsApp sales path must create a `pending_payment`
 * ServicePurchase with NO PaymentIntent (no in-app checkout), and must be
 * idempotent per (user, package, case) so repeated CTA taps don't mint
 * duplicate rows that inflate the per-SKU demand signal.
 */
describe('ServicePackagesService — WhatsApp purchase', () => {
  const activePkg = {
    id: 'pkg-1',
    code: 'dossier_pret',
    isActive: true,
    priceXOF: 50000,
    nameFr: 'Dossier prêt',
  };

  function makeService(
    opts: { existing?: unknown; pkg?: unknown; hasPass?: boolean | Error } = {},
  ) {
    const created: Array<Record<string, unknown>> = [];
    const updated: Array<Record<string, unknown>> = [];
    let intentCalls = 0;
    const client = {
      servicePackage: {
        findUnique: async () => opts.pkg ?? activePkg,
      },
      userProfile: { findUnique: async () => ({ email: 'a@b.c', phone: '+221', fullName: 'A' }) },
      case: {
        findFirst: async ({ where }: { where: { id: string; userId: string } }) =>
          where.userId === 'u1' && where.id === 'case-own'
            ? { id: 'case-own', referenceCode: 'KPB-1', requestedCountryId: null }
            : null,
      },
      servicePurchase: {
        findFirst: async () => opts.existing ?? null,
        create: async ({ data }: { data: Record<string, unknown> }) => {
          created.push(data);
          return { id: 'sp-new', ...data, package: activePkg, case: null };
        },
        update: async ({ data }: { data: Record<string, unknown> }) => {
          updated.push(data);
          return { ...(opts.existing as object), ...data };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const payments = {
      createIntent: async () => {
        intentCalls += 1;
        return { id: 'pi-1' };
      },
    } as unknown as PaymentsService;
    const pass =
      opts.hasPass === undefined
        ? undefined
        : ({
            hasActivePass: async () => {
              if (opts.hasPass instanceof Error) throw opts.hasPass;
              return opts.hasPass;
            },
          } as unknown as PassService);
    return {
      service: new ServicePackagesService(prisma, payments, pass),
      created,
      updated,
      getIntentCalls: () => intentCalls,
    };
  }

  it('creates a pending_payment purchase with NO PaymentIntent', async () => {
    const { service, created, getIntentCalls } = makeService();
    const result = await service.createWhatsAppPurchase({
      userId: 'u1',
      packageCode: 'dossier_pret',
      source: 'service_packages',
    });
    expect(created).toHaveLength(1);
    expect(created[0].status).toBe('pending_payment');
    expect(created[0].paymentIntentId).toBeUndefined();
    expect(getIntentCalls()).toBe(0);
    expect(result).toBeTruthy();
  });

  it('is idempotent: reuses the open pending request instead of creating a duplicate', async () => {
    const existing = {
      id: 'sp-existing',
      status: 'pending_payment',
      amountXOF: 50000,
      discountPercent: 0,
      package: activePkg,
      case: null,
    };
    const { service, created } = makeService({ existing });
    const result = (await service.createWhatsAppPurchase({
      userId: 'u1',
      packageCode: 'dossier_pret',
    })) as { id: string };
    expect(created).toHaveLength(0);
    expect(result.id).toBe('sp-existing');
  });

  it('rejects an unknown / inactive package', async () => {
    const { service } = makeService({ pkg: { ...activePkg, isActive: false } });
    await expect(
      service.createWhatsAppPurchase({
        userId: 'u1',
        packageCode: 'dossier_pret',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  describe('checkout purchase', () => {
    const base = {
      userId: 'u1',
      packageCode: 'dossier_pret',
      returnUrl: 'kpb://ok',
      cancelUrl: 'kpb://ko',
    };

    it('refuses the manual provider', async () => {
      const { service, created } = makeService();
      await expect(
        service.purchase({ ...base, provider: 'manual' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(created).toHaveLength(0);
    });

    it("refuses another student's case", async () => {
      const { service, created, getIntentCalls } = makeService();
      await expect(
        service.purchase({ ...base, caseId: 'case-of-someone-else' }),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(created).toHaveLength(0);
      expect(getIntentCalls()).toBe(0);
    });

    it('creates the intent first and links it in a single insert', async () => {
      const { service, created, getIntentCalls } = makeService();
      await service.purchase({ ...base, caseId: 'case-own' });
      expect(getIntentCalls()).toBe(1);
      expect(created).toEqual([
        expect.objectContaining({ caseId: 'case-own', paymentIntentId: 'pi-1' }),
      ]);
    });
  });

  describe('remise du Pass Karatou', () => {
    it('Pass actif : −20 %, prix catalogue et motif enregistrés', async () => {
      const { service, created } = makeService({ hasPass: true });
      await service.createWhatsAppPurchase({ userId: 'u1', packageCode: 'dossier_pret' });
      expect(created[0]).toMatchObject({
        amountXOF: 40000,
        listPriceXOF: 50000,
        discountPercent: 20,
        discountReason: 'pass_karatou',
      });
      expect(String(created[0].internalNotes)).toContain('Pass Karatou actif');
    });

    it('sans Pass : prix catalogue, aucune remise', async () => {
      const { service, created } = makeService({ hasPass: false });
      await service.createWhatsAppPurchase({ userId: 'u1', packageCode: 'dossier_pret' });
      expect(created[0]).toMatchObject({
        amountXOF: 50000,
        listPriceXOF: 50000,
        discountPercent: 0,
        discountReason: null,
      });
    });

    it('une panne de lecture du Pass garde le prix catalogue', async () => {
      const { service, created } = makeService({ hasPass: new Error('db') });
      await service.createWhatsAppPurchase({ userId: 'u1', packageCode: 'dossier_pret' });
      expect(created[0]).toMatchObject({ amountXOF: 50000, discountPercent: 0 });
    });

    it('une demande encore impayée suit le Pass ouvert depuis', async () => {
      const existing = {
        id: 'sp-existing',
        status: 'pending_payment',
        amountXOF: 50000,
        discountPercent: 0,
        package: activePkg,
        case: null,
      };
      const { service, created, updated } = makeService({ existing, hasPass: true });
      const result = (await service.createWhatsAppPurchase({
        userId: 'u1',
        packageCode: 'dossier_pret',
      })) as { id: string; amountXOF: number };
      expect(created).toHaveLength(0);
      expect(updated[0]).toMatchObject({ amountXOF: 40000, discountPercent: 20 });
      expect(result).toMatchObject({ id: 'sp-existing', amountXOF: 40000 });
    });
  });
});

describe('ServicePackagesService — vente saisie dans l’admin', () => {
  const pkg = { id: 'pkg-1', code: 'dossier_pret', isActive: true, priceXOF: 50000, nameFr: 'Dossier prêt' };

  function makeService(opts: { user?: unknown; hasPass?: boolean; open?: unknown }) {
    const created: Array<Record<string, unknown>> = [];
    const client = {
      userProfile: {
        findFirst: async () =>
          opts.user === undefined ? { id: 'u1', fullName: 'Awa', email: 'awa@x.org' } : opts.user,
      },
      servicePackage: { findUnique: async () => pkg },
      servicePurchase: {
        findFirst: async () => opts.open ?? null,
        create: async ({ data }: { data: Record<string, unknown> }) => {
          created.push(data);
          return { id: 'sp-1', ...data };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const pass = { hasActivePass: async () => opts.hasPass ?? false } as unknown as PassService;
    return { service: new ServicePackagesService(prisma, {} as PaymentsService, pass), created };
  }

  it('applique −20 % à un élève qui a un Pass, et trace l’auteur', async () => {
    const { service, created } = makeService({ hasPass: true });
    await service.recordPurchaseByAdmin({
      email: ' Awa@X.org ',
      packageCode: 'dossier_pret',
      status: 'paid',
      note: 'Reçu Wave 7781',
      recordedBy: 'ventes@kpb.test',
    });
    expect(created[0]).toMatchObject({
      userId: 'u1',
      amountXOF: 40000,
      listPriceXOF: 50000,
      discountPercent: 20,
      status: 'paid',
      source: 'admin',
    });
    expect(String(created[0].internalNotes)).toContain('ventes@kpb.test');
    expect(String(created[0].internalNotes)).toContain('Reçu Wave 7781');
  });

  it('prix catalogue et statut « en attente » par défaut sans Pass', async () => {
    const { service, created } = makeService({ hasPass: false });
    await service.recordPurchaseByAdmin({ email: 'awa@x.org', packageCode: 'dossier_pret', recordedBy: 'a' });
    expect(created[0]).toMatchObject({ amountXOF: 50000, discountPercent: 0, status: 'pending_payment' });
  });

  it('refuse un e-mail sans compte (404 nommé)', async () => {
    const { service, created } = makeService({ user: null });
    await expect(
      service.recordPurchaseByAdmin({ email: 'x@y.org', packageCode: 'dossier_pret', recordedBy: 'a' }),
    ).rejects.toMatchObject({ status: 404, response: expect.objectContaining({ code: 'ACCOUNT_NOT_FOUND' }) });
    expect(created).toHaveLength(0);
  });

  describe('alerte de doublon', () => {
    const open = {
      id: 'sp-open',
      status: 'pending_payment',
      amountXOF: 50000,
      createdAt: new Date('2026-11-20T10:00:00Z'),
      source: 'service_packages',
    };

    it('refuse une seconde vente ouverte du même service (409, vente existante jointe)', async () => {
      const { service, created } = makeService({ open });
      await expect(
        service.recordPurchaseByAdmin({ email: 'awa@x.org', packageCode: 'dossier_pret', recordedBy: 'a' }),
      ).rejects.toMatchObject({
        status: 409,
        response: expect.objectContaining({
          code: 'DUPLICATE_OPEN_SALE',
          details: { existing: expect.objectContaining({ id: 'sp-open', status: 'pending_payment' }) },
        }),
      });
      expect(created).toHaveLength(0);
    });

    it('enregistre quand même après confirmation, et le note', async () => {
      const { service, created } = makeService({ open });
      await service.recordPurchaseByAdmin({
        email: 'awa@x.org',
        packageCode: 'dossier_pret',
        allowDuplicate: true,
        recordedBy: 'a',
      });
      expect(created).toHaveLength(1);
      expect(String(created[0].internalNotes)).toContain('Doublon confirmé');
    });
  });
});
