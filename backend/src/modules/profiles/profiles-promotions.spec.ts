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

