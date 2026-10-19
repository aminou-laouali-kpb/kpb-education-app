import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { ProfilesService } from './profiles.service';

const fakeStorage = {
  keyFromUrl: () => null,
  delete: async () => undefined,
} as unknown as StorageService;

const row = {
  id: 'user-1',
  accountType: 'student',
  preferredLanguage: 'fr',
  fullName: 'Test User',
  email: 't@example.test',
  phone: '',
  whatsApp: null,
  countryOfResidence: '',
  fieldIds: [],
  targetCountryIds: [],
  availableDocuments: [],
  disabledNotificationTypes: [],
  newsletterOptIn: false,
  promotionsEmailOptIn: true,
  promotionsPushOptIn: false,
  updatedAt: new Date(),
};

/**
 * Correctifs 57 — « les nouvelles et offres de KPB » par e-mail (XC-06) : la
 * preuve horodatée n'est posée qu'au vrai passage à `true`.
 */
describe('ProfilesService — consentement « nouvelles et offres de KPB »', () => {
  function makePrisma(current: boolean) {
    const updateData: Record<string, unknown>[] = [];
    const client = {
      userProfile: {
        findUnique: async () => ({ promotionsEmailOptIn: current, newsletterOptIn: false }),
        update: async (args: { data: Record<string, unknown> }) => {
          updateData.push(args.data);
          return { ...row, promotionsEmailOptIn: args.data.promotionsEmailOptIn ?? current };
        },
        updateMany: async () => ({ count: 0 }),
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: unknown) => unknown) => fn(client),
      tryExecute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { prisma, updateData };
  }

  it('horodate au passage false→true et renvoie le champ (signal pour l’app)', async () => {
    const { prisma, updateData } = makePrisma(false);
    const out = await new ProfilesService(prisma, fakeStorage).updateMe({ promotionsEmailOptIn: true }, 'user-1');
    expect(updateData[0]).toMatchObject({ promotionsEmailOptIn: true });
    expect(updateData[0].promotionsEmailConsentedAt).toBeInstanceOf(Date);
    expect(out).toMatchObject({ promotionsEmailOptIn: true });
  });

  it('ne réécrit pas la preuve quand le consentement est déjà donné', async () => {
    const { prisma, updateData } = makePrisma(true);
    await new ProfilesService(prisma, fakeStorage).updateMe({ promotionsEmailOptIn: true }, 'user-1');
    expect(updateData[0].promotionsEmailConsentedAt).toBeUndefined();
  });

  it('le retrait écrit false sans horodatage ; un PATCH sans le champ n’y touche pas', async () => {
    const { prisma, updateData } = makePrisma(true);
    const service = new ProfilesService(prisma, fakeStorage);
    await service.updateMe({ promotionsEmailOptIn: false }, 'user-1');
    expect(updateData[0]).toMatchObject({ promotionsEmailOptIn: false });
    expect(updateData[0].promotionsEmailConsentedAt).toBeUndefined();
    await service.updateMe({ fullName: 'Autre' }, 'user-1');
    expect('promotionsEmailOptIn' in updateData[1]).toBe(false);
  });
});

/**
 * Chantier juridique 57 — push promotionnel en OPT-IN (App Store 4.5.4) : même
 * mécanique que l'e-mail, preuve horodatée au seul vrai passage à `true`, et le
 * champ est renvoyé (sa présence dit à l'app que le serveur exige l'opt-in).
 */
describe('ProfilesService — consentement push « nouvelles et offres de KPB »', () => {
  function makePrisma(current: boolean) {
    const updateData: Record<string, unknown>[] = [];
    const client = {
      userProfile: {
        findUnique: async () => ({
          promotionsPushOptIn: current,
          promotionsEmailOptIn: false,
          newsletterOptIn: false,
        }),
        update: async (args: { data: Record<string, unknown> }) => {
          updateData.push(args.data);
          return { ...row, promotionsPushOptIn: args.data.promotionsPushOptIn ?? current };
        },
        updateMany: async () => ({ count: 0 }),
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: unknown) => unknown) => fn(client),
      tryExecute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { prisma, updateData };
  }

  it('horodate au passage false→true, sans toucher au consentement e-mail', async () => {
    const { prisma, updateData } = makePrisma(false);
    const out = await new ProfilesService(prisma, fakeStorage).updateMe({ promotionsPushOptIn: true }, 'user-1');
    expect(updateData[0]).toMatchObject({ promotionsPushOptIn: true });
    expect(updateData[0].promotionsPushConsentedAt).toBeInstanceOf(Date);
    expect('promotionsEmailOptIn' in updateData[0]).toBe(false);
    expect(updateData[0].promotionsEmailConsentedAt).toBeUndefined();
    expect(out).toMatchObject({ promotionsPushOptIn: true });
  });

  it('ne réécrit pas la preuve quand le consentement est déjà donné', async () => {
    const { prisma, updateData } = makePrisma(true);
    await new ProfilesService(prisma, fakeStorage).updateMe({ promotionsPushOptIn: true }, 'user-1');
    expect(updateData[0].promotionsPushConsentedAt).toBeUndefined();
  });

  it('le retrait écrit false sans horodatage ; un PATCH sans le champ n’y touche pas', async () => {
    const { prisma, updateData } = makePrisma(true);
    const service = new ProfilesService(prisma, fakeStorage);
    const out = await service.updateMe({ promotionsPushOptIn: false }, 'user-1');
    expect(updateData[0]).toMatchObject({ promotionsPushOptIn: false });
    expect(updateData[0].promotionsPushConsentedAt).toBeUndefined();
    expect(out).toMatchObject({ promotionsPushOptIn: false });
    await service.updateMe({ fullName: 'Autre' }, 'user-1');
    expect('promotionsPushOptIn' in updateData[1]).toBe(false);
  });
});
