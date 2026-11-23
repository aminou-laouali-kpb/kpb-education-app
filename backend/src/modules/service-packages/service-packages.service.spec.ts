import { BadRequestException, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
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
    opts: { existing?: unknown; pkg?: unknown; intentStatus?: string; purchaseStatus?: string } = {},
  ) {
    const created: Array<Record<string, unknown>> = [];
    const reconcileWheres: Array<Record<string, unknown>> = [];
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
        // Applique réellement le filtre conditionnel de reconcilePurchase.
        updateMany: async ({
          where,
        }: {
          where: { paymentIntentId: string; status: string; paymentIntent: { is: { status: string } } };
        }) => {
          reconcileWheres.push(where);
          const purchaseStatus = opts.purchaseStatus ?? 'pending_payment';
          const ok =
            where.paymentIntentId === 'pi-1' &&
            where.status === purchaseStatus &&
            where.paymentIntent.is.status === (opts.intentStatus ?? 'pending');
          return { count: ok ? 1 : 0 };
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
    return {
      service: new ServicePackagesService(prisma, payments),
      created,
      reconcileWheres,
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

  describe('reconcilePurchase (constats 23/40)', () => {
    it('écriture conditionnelle : achat pending_payment ET intent paid', async () => {
      const { service, reconcileWheres } = makeService({ intentStatus: 'paid' });
      await expect(service.reconcilePurchase('pi-1')).resolves.toBe(true);
      expect(reconcileWheres[0]).toEqual({
        paymentIntentId: 'pi-1',
        status: 'pending_payment',
        paymentIntent: { is: { status: 'paid' } },
      });
    });

    it('intent non payé : rien', async () => {
      const { service } = makeService({ intentStatus: 'pending' });
      // Le faux client ne matche que si l'intent est dans le statut demandé (paid).
      await expect(service.reconcilePurchase('pi-1')).resolves.toBe(false);
    });

    it('achat déjà avancé (in_progress) : rien', async () => {
      const { service } = makeService({ intentStatus: 'paid', purchaseStatus: 'in_progress' });
      await expect(service.reconcilePurchase('pi-1')).resolves.toBe(false);
    });

    it('purchase() : intent payé AVANT la création de l’achat → achat rendu paid', async () => {
      const { service } = makeService({ intentStatus: 'paid' });
      const out = (await service.purchase({
        userId: 'u1',
        packageCode: 'dossier_pret',
        returnUrl: 'kpb://ok',
        cancelUrl: 'kpb://ko',
      })) as { status: string };
      expect(out.status).toBe('paid');
    });

    it('purchase() nominal : achat rendu pending_payment', async () => {
      const { service } = makeService();
      const out = (await service.purchase({
        userId: 'u1',
        packageCode: 'dossier_pret',
        returnUrl: 'kpb://ok',
        cancelUrl: 'kpb://ko',
      })) as { status: string };
      expect(out.status).toBe('pending_payment');
    });
  });
});
