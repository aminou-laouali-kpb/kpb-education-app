import type { PrismaService } from "../../prisma/prisma.service";
import type { FeatureAccessService } from "../common/feature-access.service";
import { StudyReviewConsentService } from "./study-review-consent.service";

describe("StudyReviewConsentService", () => {
  const previousArtifactsFlag = process.env.KPB_APPLICATION_ARTIFACTS_ENABLED;
  const previousReviewFlag = process.env.KPB_STUDY_REVIEW_ENABLED;
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const evaluate = jest.fn().mockResolvedValue({ allowed: true });
  const featureAccess = { evaluate } as unknown as FeatureAccessService;
  const service = new StudyReviewConsentService(prisma, featureAccess);

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.KPB_APPLICATION_ARTIFACTS_ENABLED = "true";
    process.env.KPB_STUDY_REVIEW_ENABLED = "true";
    evaluate.mockResolvedValue({ allowed: true });
  });

  afterAll(() => {
    if (previousArtifactsFlag === undefined) {
      delete process.env.KPB_APPLICATION_ARTIFACTS_ENABLED;
    } else {
      process.env.KPB_APPLICATION_ARTIFACTS_ENABLED = previousArtifactsFlag;
    }
    if (previousReviewFlag === undefined) {
      delete process.env.KPB_STUDY_REVIEW_ENABLED;
    } else {
      process.env.KPB_STUDY_REVIEW_ENABLED = previousReviewFlag;
    }
  });

  it("publishes a stable versioned notice without writing to the database", async () => {
    const first = await service.getNotice("student-1", "fr");
    const second = await service.getNotice("student-1", "fr");

    expect(first).toEqual(second);
    expect(first).toMatchObject({
      purpose: "advisor_document_share",
      version: "advisor-document-share-v1",
      languageCode: "fr",
    });
    expect(first.contentHash).toMatch(/^[a-f0-9]{64}$/);
    expect(execute).not.toHaveBeenCalled();
  });

  it("creates an active receipt for an adult and retires old notices", async () => {
    const contract = await service.getNotice("student-1", "fr");
    const tx = {
      $executeRaw: jest.fn(),
      userProfile: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ birthDate: new Date("2000-01-01T00:00:00Z") }),
      },
      guardianAuthorization: { findFirst: jest.fn() },
      consentNotice: {
        upsert: jest.fn().mockResolvedValue({
          id: "notice-1",
          contentHash: contract.contentHash,
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue(null),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        create: jest.fn().mockResolvedValue({
          id: "receipt-1",
          grantedAt: new Date("2026-07-17T12:00:00.000Z"),
        }),
      },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    const result = await service.grant("student-1", {
      accepted: true,
      languageCode: "fr",
      noticeVersion: "advisor-document-share-v1",
    });

    expect(result.receiptId).toBe("receipt-1");
    expect(tx.consentNotice.updateMany).toHaveBeenCalled();
    expect(tx.consentReceipt.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          userId: "student-1",
          purpose: "advisor_document_share",
          guardianAuthorizationId: undefined,
        }),
      }),
    );
  });

  it("requires a verified guardian before a minor can grant document sharing", async () => {
    const tx = {
      $executeRaw: jest.fn(),
      userProfile: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ birthDate: new Date("2012-01-01T00:00:00Z") }),
      },
      guardianAuthorization: { findFirst: jest.fn().mockResolvedValue(null) },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.grant("student-minor", {
        accepted: true,
        languageCode: "en",
        noticeVersion: "advisor-document-share-v1",
      }),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: "GUARDIAN_CONSENT_REQUIRED" }),
    });
  });

  it("fails closed when either required feature flag is disabled", async () => {
    process.env.KPB_APPLICATION_ARTIFACTS_ENABLED = "false";

    await expect(service.getNotice("student-1", "fr")).rejects.toMatchObject({
      status: 404,
    });
    expect(evaluate).not.toHaveBeenCalled();
  });
});
