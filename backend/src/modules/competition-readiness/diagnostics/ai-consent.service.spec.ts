import type { PrismaService } from "../../prisma/prisma.service";
import type { FeatureAccessService } from "../common/feature-access.service";
import { AiConsentService } from "./ai-consent.service";

describe("AiConsentService", () => {
  const previousEnabled = process.env.KPB_AI_DIAGNOSTIC_ENABLED;
  const previousKillSwitch = process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH;
  const previousMinimumAge = process.env.KPB_AI_DIAGNOSTIC_MIN_AGE;
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const evaluate = jest.fn().mockResolvedValue({ allowed: true });
  const featureAccess = { evaluate } as unknown as FeatureAccessService;
  const service = new AiConsentService(prisma, featureAccess);

  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(new Date("2026-07-17T12:00:00.000Z"));
    jest.clearAllMocks();
    process.env.KPB_AI_DIAGNOSTIC_ENABLED = "true";
    process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH = "false";
    process.env.KPB_AI_DIAGNOSTIC_MIN_AGE = "13";
    evaluate.mockResolvedValue({ allowed: true });
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  afterAll(() => {
    restore("KPB_AI_DIAGNOSTIC_ENABLED", previousEnabled);
    restore("KPB_AI_DIAGNOSTIC_KILL_SWITCH", previousKillSwitch);
    restore("KPB_AI_DIAGNOSTIC_MIN_AGE", previousMinimumAge);
  });

  it("publishes a stable immutable notice contract", async () => {
    const first = await service.getNotice("student-1", "en");
    const second = await service.getNotice("student-1", "en");

    expect(first).toEqual(second);
    expect(first).toMatchObject({
      purpose: "ai_third_party",
      version: "ai-diagnostic-v1",
      languageCode: "en",
    });
    expect(first.contentHash).toMatch(/^[a-f0-9]{64}$/);
    expect(execute).not.toHaveBeenCalled();
  });

  it("creates a guardian-linked receipt for an eligible minor", async () => {
    const contract = await service.getNotice("student-minor", "fr");
    const tx = {
      $executeRaw: jest.fn(),
      userProfile: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ birthDate: new Date("2010-01-01T00:00:00Z") }),
      },
      guardianAuthorization: {
        findFirst: jest.fn().mockResolvedValue({ id: "guardian-1" }),
      },
      consentNotice: {
        upsert: jest.fn().mockResolvedValue({
          id: "notice-1",
          contentHash: contract.contentHash,
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
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

    const result = await service.grant("student-minor", {
      accepted: true,
      languageCode: "fr",
      noticeVersion: "ai-diagnostic-v1",
    });

    expect(result.receiptId).toBe("receipt-1");
    expect(tx.consentReceipt.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          guardianAuthorizationId: "guardian-1",
        }),
      }),
    );
  });

  it("blocks processing below the configured minimum age before provider use", async () => {
    process.env.KPB_AI_DIAGNOSTIC_MIN_AGE = "16";
    const tx = {
      $executeRaw: jest.fn(),
      userProfile: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ birthDate: new Date("2012-01-01T00:00:00Z") }),
      },
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.grant("student-child", {
        accepted: true,
        languageCode: "fr",
        noticeVersion: "ai-diagnostic-v1",
      }),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: "GUARDIAN_CONSENT_REQUIRED" }),
    });
  });

  it("fails closed while the AI kill switch is active", async () => {
    process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH = "true";

    await expect(service.getNotice("student-1", "fr")).rejects.toMatchObject({
      status: 404,
    });
    expect(execute).not.toHaveBeenCalled();
  });
});

function restore(key: string, value: string | undefined) {
  if (value === undefined) delete process.env[key];
  else process.env[key] = value;
}
