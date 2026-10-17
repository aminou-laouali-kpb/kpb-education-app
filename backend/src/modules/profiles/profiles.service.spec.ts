import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { ProfilesService } from './profiles.service';

const originalNodeEnv = process.env.NODE_ENV;

// No files in these fixtures (caseDocument.findMany → []), so the stub is never
// actually exercised; it only satisfies the constructor signature.
const fakeStorage = {
  keyFromUrl: () => null,
  delete: async () => undefined,
} as unknown as StorageService;

/**
 * Guards the GDPR / store-required account deletion (KPB-67): the purge must run
 * as one transaction in FK-safe order (case children → case-referencing rows →
 * cases → other user-owned rows → profile last). In production, Auth deletion
 * must succeed before any local write or the request fails closed.
 */
describe('ProfilesService — account deletion & export', () => {
  const MODELS = [
    'userProfile',
    'case',
    'caseMessage',
    'caseTimelineEvent',
    'caseTask',
    'caseDocument',
    'caseInternalNote',
    'notificationDelivery',
    'appointment',
    'servicePurchase',
    'paymentIntent',
    'savedItem',
    'academyPurchase',
    'salonRegistration',
    'coachConversation',
    'orientationSession',
    'scholarshipWorkspace',
    'applicationArtifactVersion',
    'studyReviewRequest',
    'studyReviewArtifactShare',
    'outcomeEvidenceAsset',
    'outcomeEvidenceLink',
    'applicationSubmission',
    'applicationDecisionRecord',
    'fundingDecisionRecord',
    'outcomeVerificationEvent',
    'aiDiagnostic',
    'aiUsageAttempt',
    'aiBudgetTransaction',
    'aiQuotaBucket',
    'impactCohortMembership',
    'eefInterest',
    'analyticsEvent',
    'domainEventOutbox',
    'idempotencyRecord',
    'consentReceipt',
    'guardianAuthorization',
    'parentChildLink',
    'referral',
    'creditTransaction',
    'counsellorReview',
    'counsellor',
    'ambassador',
    'ambassadorReferral',
    'deviceToken',
    'partnerLead',
    'studentCredential',
    'scholarshipMatchRun',
    'scholarshipAlertSubscription',
    'referralCampaignParticipant',
    'referralCampaignReferral',
    'referralAttributionSignal',
    // Communauté (C1 + C2) : aucune fiche membre ici (findUnique → null).
    'communityMember',
    'communityReply',
    'communityReaction',
    'forumModerationAction',
  ] as const;

  function makeFakePrisma(profile: unknown) {
    const calls: string[] = [];
    const deleteManyArguments: Record<string, unknown[]> = {};
    const client: Record<string, unknown> = {
      $transaction: async (ops: unknown[]) => ops,
    };
    for (const model of MODELS) {
      client[model] = {
        findUnique: async () => (model === 'userProfile' ? profile : null),
        findMany: async () => [],
        deleteMany: (args: unknown) => {
          calls.push(`${model}.deleteMany`);
          (deleteManyArguments[model] ??= []).push(args);
          return { __op: `${model}.deleteMany` };
        },
        updateMany: () => {
          calls.push(`${model}.updateMany`);
          return { __op: `${model}.updateMany` };
        },
        delete: () => {
          calls.push(`${model}.delete`);
          return { __op: `${model}.delete` };
        },
      };
    }
    // magicLinkToken is keyed by email and only ever deleteMany'd.
    client.magicLinkToken = {
      deleteMany: () => {
        calls.push('magicLinkToken.deleteMany');
        return { __op: 'magicLinkToken.deleteMany' };
      },
    };
    return { client, calls, deleteManyArguments };
  }

  beforeEach(() => {
    delete process.env.SUPABASE_URL;
    delete process.env.SUPABASE_SERVICE_ROLE_KEY;
  });

  afterEach(() => {
    if (originalNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = originalNodeEnv;
    jest.restoreAllMocks();
  });

  it('keeps local test ergonomics while purging all rows in FK-safe order', async () => {
    const { client, calls } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: 'sup-123',
    });
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;
    const service = new ProfilesService(prisma, fakeStorage);

    const result = await service.deleteMe('user-1');

    expect(result).toEqual({ deleted: true, authIdentityRemoved: false });
    // Profile is deleted last.
    expect(calls[calls.length - 1]).toBe('userProfile.delete');
    // Case children precede the Case delete.
    expect(calls.indexOf('caseMessage.deleteMany')).toBeLessThan(
      calls.indexOf('case.deleteMany'),
    );
    // ServicePurchase (FK → PaymentIntent) precedes PaymentIntent.
    expect(calls.indexOf('servicePurchase.deleteMany')).toBeLessThan(
      calls.indexOf('paymentIntent.deleteMany'),
    );
    // Rows referencing Case precede the Case delete.
    expect(calls.indexOf('appointment.deleteMany')).toBeLessThan(
      calls.indexOf('case.deleteMany'),
    );
    expect(calls.indexOf('paymentIntent.deleteMany')).toBeLessThan(
      calls.indexOf('case.deleteMany'),
    );
    expect(calls).toContain('idempotencyRecord.deleteMany');
    expect(calls.indexOf('studyReviewArtifactShare.deleteMany')).toBeLessThan(
      calls.indexOf('consentReceipt.deleteMany'),
    );
    expect(calls.indexOf('outcomeEvidenceLink.deleteMany')).toBeLessThan(
      calls.indexOf('outcomeEvidenceAsset.deleteMany'),
    );
    expect(calls.indexOf('fundingDecisionRecord.deleteMany')).toBeLessThan(
      calls.indexOf('outcomeEvidenceAsset.deleteMany'),
    );
    expect(calls.indexOf('applicationDecisionRecord.deleteMany')).toBeLessThan(
      calls.indexOf('outcomeEvidenceAsset.deleteMany'),
    );
    expect(calls.indexOf('applicationSubmission.deleteMany')).toBeLessThan(
      calls.indexOf('outcomeEvidenceAsset.deleteMany'),
    );
    expect(calls.indexOf('outcomeEvidenceAsset.deleteMany')).toBeLessThan(
      calls.indexOf('consentReceipt.deleteMany'),
    );
    expect(calls.indexOf('consentReceipt.deleteMany')).toBeLessThan(
      calls.indexOf('guardianAuthorization.deleteMany'),
    );
  });

  it('hard-deletes Supabase Auth before the local transaction', async () => {
    process.env.SUPABASE_URL = 'https://unit-test.supabase.co/';
    process.env.SUPABASE_SERVICE_ROLE_KEY = `sb_secret_${'s'.repeat(32)}`;
    const { client, calls } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: 'sup-123',
    });
    const fetchMock = jest.spyOn(global, 'fetch').mockImplementation(async () => {
      calls.push('supabaseAuth.hardDelete');
      return { ok: true, status: 200 } as Response;
    });
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    await expect(
      new ProfilesService(prisma, fakeStorage).deleteMe('user-1'),
    ).resolves.toEqual({ deleted: true, authIdentityRemoved: true });

    expect(calls[0]).toBe('supabaseAuth.hardDelete');
    expect(fetchMock).toHaveBeenCalledWith(
      'https://unit-test.supabase.co/auth/v1/admin/users/sup-123',
      expect.objectContaining({
        method: 'DELETE',
        body: JSON.stringify({ should_soft_delete: false }),
        headers: expect.objectContaining({
          'content-type': 'application/json',
        }),
      }),
    );
    expect(fetchMock.mock.calls[0][1]?.headers).not.toEqual(
      expect.objectContaining({ apikey: '' }),
    );
  });

  it('aborts before local writes when Supabase Auth deletion fails', async () => {
    process.env.SUPABASE_URL = 'https://unit-test.supabase.co';
    process.env.SUPABASE_SERVICE_ROLE_KEY = `sb_secret_${'s'.repeat(32)}`;
    const { client, calls } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: 'sup-123',
    });
    jest
      .spyOn(global, 'fetch')
      .mockResolvedValue({ ok: false, status: 503 } as Response);
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    await expect(
      new ProfilesService(prisma, fakeStorage).deleteMe('user-1'),
    ).rejects.toThrow('Account deletion is temporarily unavailable');
    expect(calls).toEqual([]);
  });

  it('fails closed in production when the profile has no Auth link', async () => {
    process.env.NODE_ENV = 'production';
    process.env.SUPABASE_URL = 'https://unit-test.supabase.co';
    process.env.SUPABASE_SERVICE_ROLE_KEY = `sb_secret_${'s'.repeat(32)}`;
    const { client, calls } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: null,
    });
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    await expect(
      new ProfilesService(prisma, fakeStorage).deleteMe('user-1'),
    ).rejects.toThrow('Account deletion is temporarily unavailable');
    expect(calls).toEqual([]);
  });

  it('fails closed in production when the admin key is unavailable', async () => {
    process.env.NODE_ENV = 'production';
    process.env.SUPABASE_URL = 'https://unit-test.supabase.co';
    const { client, calls } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: 'sup-123',
    });
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    await expect(
      new ProfilesService(prisma, fakeStorage).deleteMe('user-1'),
    ).rejects.toThrow('Account deletion is temporarily unavailable');
    expect(calls).toEqual([]);
  });

  it('treats an already-absent Auth identity as an idempotent success', async () => {
    process.env.SUPABASE_URL = 'https://unit-test.supabase.co';
    process.env.SUPABASE_SERVICE_ROLE_KEY = `sb_secret_${'s'.repeat(32)}`;
    const { client } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: 'sup-123',
    });
    jest
      .spyOn(global, 'fetch')
      .mockResolvedValue({ ok: false, status: 404 } as Response);
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    await expect(
      new ProfilesService(prisma, fakeStorage).deleteMe('user-1'),
    ).resolves.toEqual({ deleted: true, authIdentityRemoved: true });
  });

  it('removes private artifact objects after the database purge', async () => {
    const { client } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: null,
    });
    (client.scholarshipWorkspace as { findMany: () => Promise<unknown[]> }).findMany =
      async () => [{ id: 'workspace-1' }];
    (
      client.applicationArtifactVersion as {
        findMany: () => Promise<unknown[]>;
      }
    ).findMany = async () => [
      { id: 'version-1', storageKey: '2026-07-17/file.pdf' },
    ];
    (
      client.outcomeEvidenceAsset as {
        findMany: () => Promise<unknown[]>;
      }
    ).findMany = async () => [
      { id: 'evidence-1', storageKey: '2026-07-17/outcome.pdf' },
    ];
    (
      client.guardianAuthorization as {
        findMany: () => Promise<unknown[]>;
      }
    ).findMany = async () => [
      { evidenceStorageKey: '2026-07-17/guardian.pdf' },
    ];
    const deleteFile = jest.fn().mockResolvedValue(undefined);
    const storage = {
      keyFromUrl: () => null,
      delete: deleteFile,
    } as unknown as StorageService;
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    const service = new ProfilesService(prisma, storage);
    await service.deleteMe('user-1');

    expect(deleteFile).toHaveBeenCalledWith('2026-07-17/file.pdf');
    expect(deleteFile).toHaveBeenCalledWith('2026-07-17/outcome.pdf');
    expect(deleteFile).toHaveBeenCalledWith('2026-07-17/guardian.pdf');
  });

  it('purges admin-owned pilot idempotency snapshots by participant resource ids', async () => {
    const { client, deleteManyArguments } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: null,
    });
    (
      client.impactCohortMembership as {
        findMany: () => Promise<unknown[]>;
      }
    ).findMany = async () => [
      {
        id: 'membership-1',
        assessments: [{ id: 'assessment-1' }, { id: 'assessment-2' }],
        experimentAssignment: { id: 'assignment-1' },
      },
    ];
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    await new ProfilesService(prisma, fakeStorage).deleteMe('user-1');

    expect(deleteManyArguments.idempotencyRecord).toEqual([
      {
        where: {
          OR: [
            { actorId: 'user-1' },
            {
              resourceType: 'ImpactCohortMembership',
              resourceId: { in: ['membership-1'] },
            },
            {
              resourceType: 'PilotRecord',
              resourceId: {
                in: ['assessment-1', 'assessment-2', 'assignment-1'],
              },
            },
          ],
        },
      },
    ]);
  });

  it('removes the profile photo object with the account', async () => {
    const { client } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: null,
      avatarStorageKey: '2026-08-12/avatar.jpg',
    });
    const deleteFile = jest.fn().mockResolvedValue(undefined);
    const storage = {
      keyFromUrl: () => null,
      delete: deleteFile,
    } as unknown as StorageService;
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    await new ProfilesService(prisma, storage).deleteMe('user-1');

    // Erasure must reach the image itself, not just the column pointing at it.
    expect(deleteFile).toHaveBeenCalledWith('2026-08-12/avatar.jpg');
  });

  it('reports not-deleted when there is no database', async () => {
    const prisma = {
      execute: async () => null,
    } as unknown as PrismaService;
    const service = new ProfilesService(prisma, fakeStorage);
    expect(await service.deleteMe('user-1')).toEqual({
      deleted: false,
      authIdentityRemoved: false,
    });
  });

  it('exports the profile and related collections as one document', async () => {
    const { client } = makeFakePrisma({ id: 'user-1', email: 'a@b.com' });
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;
    const service = new ProfilesService(prisma, fakeStorage);

    const out = await service.exportMe('user-1');
    expect(out.exportedAt).toBeDefined();
    expect((out as { profile?: unknown }).profile).toMatchObject({
      id: 'user-1',
    });
    expect((out as { cases?: unknown }).cases).toEqual([]);
    expect(
      (out as { scholarshipWorkspaces?: unknown }).scholarshipWorkspaces,
    ).toEqual([]);
    expect((out as { consentReceipts?: unknown }).consentReceipts).toEqual([]);
    expect((out as { aiQuotaBuckets?: unknown }).aiQuotaBuckets).toEqual([]);
    expect((out as { analyticsEvents?: unknown }).analyticsEvents).toEqual([]);

    // La déclaration d'intérêt « Études en France » DOIT figurer dans l'export.
    //
    // Elle manquait : la suppression la couvrait par la cascade, l'export non.
    // Un étudiant qui demandait ses données ne recevait ni sa déclaration, ni
    // son `consentedAt` — c'est-à-dire la preuve qu'on lui opposerait s'il
    // demandait sur quelle base on l'a rappelé.
    //
    // La clé doit être PRÉSENTE même à `null` : une clé absente ne se distingue
    // pas d'une relation qu'on aurait oublié de brancher, et c'est exactement
    // l'erreur qu'on répare ici.
    expect(out).toHaveProperty('eefInterest');
    expect((out as { eefInterest?: unknown }).eefInterest).toBeNull();
    // « Mes 10 bourses » (chantier D) : les runs calculés et les cloches
    // « M'avertir » sont des données de l'élève. Clés présentes même vides.
    expect((out as { scholarshipMatchRuns?: unknown }).scholarshipMatchRuns).toEqual([]);
    expect(
      (out as { scholarshipAlertSubscriptions?: unknown }).scholarshipAlertSubscriptions,
    ).toEqual([]);
  });

  it('never puts the avatar storage key in the GDPR export', async () => {
    const { client } = makeFakePrisma({
      id: 'user-1',
      email: 'a@b.com',
      avatarStorageKey: '2026-08-12/avatar.jpg',
    });
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    const out = await new ProfilesService(prisma, fakeStorage).exportMe(
      'user-1',
    );

    // The export is a document the student may forward anywhere.
    expect(JSON.stringify(out)).not.toContain('2026-08-12/avatar.jpg');
    expect(JSON.stringify(out)).not.toContain('avatarStorageKey');
    expect((out as { profile?: Record<string, unknown> }).profile).toMatchObject(
      { hasAvatar: true },
    );
  });
});
