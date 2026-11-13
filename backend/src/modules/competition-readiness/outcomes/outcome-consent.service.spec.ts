import type { PrismaService } from '../../prisma/prisma.service';
import { OutcomeConsentService } from './outcome-consent.service';

describe('OutcomeConsentService', () => {
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const service = new OutcomeConsentService(prisma);

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.KPB_COMPETITION_READINESS_ENABLED = 'true';
    process.env.KPB_SUCCESS_LAB_ENABLED = 'true';
    process.env.KPB_OUTCOME_EVIDENCE_ENABLED = 'true';
  });

  it('keeps notice and grant unavailable unless all parent flags are enabled', async () => {
    process.env.KPB_SUCCESS_LAB_ENABLED = 'false';

    await expect(
      service.getNotice('student-1', 'workspace-1', 'fr'),
    ).rejects.toMatchObject({ status: 404 });
    expect(execute).not.toHaveBeenCalled();
  });

  it('fails the consent bootstrap closed for a non-student account', async () => {
    const tx = {
      $executeRaw: jest.fn(),
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue({ id: 'workspace-1' }),
      },
      userProfile: {
        findUnique: jest.fn().mockResolvedValue({
          accountType: 'parent',
          birthDate: new Date('1990-01-01T00:00:00.000Z'),
        }),
      },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.grant('parent-1', 'workspace-1', {
        purpose: 'outcome_evidence',
        languageCode: 'fr',
        noticeVersion: 'outcome-evidence-v1',
        accepted: true,
      }),
    ).rejects.toMatchObject({ status: 403 });
  });

  it('creates only the private outcome_evidence receipt for an adult student', async () => {
    const createReceipt = jest.fn().mockImplementation(({ data }) => ({
      id: 'receipt-1',
      ...data,
    }));
    const tx = {
      $executeRaw: jest.fn(),
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue({ id: 'workspace-1' }),
      },
      userProfile: {
        findUnique: jest.fn().mockResolvedValue({
          accountType: 'student',
          birthDate: new Date('1990-01-01T00:00:00.000Z'),
        }),
      },
      guardianAuthorization: { findFirst: jest.fn() },
      consentNotice: {
        upsert: jest.fn().mockImplementation(({ create }) => ({
          id: 'notice-1',
          ...create,
        })),
        updateMany: jest.fn(),
      },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue(null),
        updateMany: jest.fn(),
        create: createReceipt,
      },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.grant('student-1', 'workspace-1', {
      purpose: 'outcome_evidence',
      languageCode: 'fr',
      noticeVersion: 'outcome-evidence-v1',
      accepted: true,
    });

    expect(result).toMatchObject({
      receiptId: 'receipt-1',
      purpose: 'outcome_evidence',
      workspaceId: 'workspace-1',
    });
    expect(createReceipt.mock.calls[0][0].data).toMatchObject({
      userId: 'student-1',
      purpose: 'outcome_evidence',
      noticeId: 'notice-1',
    });
    expect(JSON.stringify(createReceipt.mock.calls[0][0].data)).not.toContain(
      'aggregate_impact',
    );
    expect(JSON.stringify(createReceipt.mock.calls[0][0].data)).not.toContain(
      'public_testimonial',
    );
  });
});
