import { NotFoundException, ServiceUnavailableException } from '@nestjs/common';

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
 * Correctifs 57 — « Effacer ma nationalité » : la donnée part du profil, et les
 * résultats calculés avec elle aussi, dans la même transaction.
 */
describe('ProfilesService — effacer la nationalité', () => {
  function makePrisma(exists: boolean, isEnabled = true) {
    const calls: string[] = [];
    const tx = {
      userProfile: {
        findUnique: async () => (exists ? { id: 'user-1' } : null),
        update: async (args: { data: Record<string, unknown> }) => {
          calls.push(`update:${JSON.stringify(args.data)}`);
          return row;
        },
      },
      scholarshipMatchRun: {
        deleteMany: async (args: { where: Record<string, unknown> }) => {
          calls.push(`deleteRuns:${JSON.stringify(args.where)}`);
          return { count: 3 };
        },
      },
    };
    const client = { $transaction: async (fn: (t: typeof tx) => unknown) => fn(tx) };
    const prisma = {
      isEnabled,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { prisma, calls };
  }

  it('efface les deux nationalités et supprime les runs du test', async () => {
    const { prisma, calls } = makePrisma(true);
    const out = await new ProfilesService(prisma, fakeStorage).eraseNationality('user-1');
    expect(out).toEqual({ nationalityCode: null, secondNationalityCode: null, matchRunsDeleted: 3 });
    expect(calls).toEqual([
      'deleteRuns:{"userId":"user-1"}',
      'update:{"nationalityCode":null,"secondNationalityCode":null}',
    ]);
  });

  it('profil inconnu : 404 ; pas de base : 503', async () => {
    await expect(
      new ProfilesService(makePrisma(false).prisma, fakeStorage).eraseNationality('nope'),
    ).rejects.toBeInstanceOf(NotFoundException);
    await expect(
      new ProfilesService(makePrisma(true, false).prisma, fakeStorage).eraseNationality('user-1'),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});
