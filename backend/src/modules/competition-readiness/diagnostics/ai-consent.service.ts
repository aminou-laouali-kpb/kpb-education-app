import { createHash } from "node:crypto";

import { Injectable } from "@nestjs/common";
import { Prisma } from "@prisma/client";

import { PrismaService } from "../../prisma/prisma.service";
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  featureDisabled,
} from "../common/competition-readiness.errors";
import { FeatureAccessService } from "../common/feature-access.service";
import type { GrantAiConsentDto } from "./dto/grant-ai-consent.dto";

const NOTICE_VERSION = "ai-diagnostic-v1";
const NOTICES = {
  fr: {
    title: "Diagnostic IA de candidature",
    body: "Lorsque tu lances le diagnostic, KPB transmet au fournisseur IA uniquement un extrait limité et minimisé de ta candidature, les critères vérifiés de la bourse et l’état de ta checklist. Ton nom, ton e-mail, ton téléphone et les coordonnées de ton responsable ne doivent pas être transmis. Le résultat propose une seule amélioration prioritaire : il ne garantit jamais une admission et ne remplace pas un conseiller KPB. Tu peux retirer ce consentement ; aucun nouvel appel IA ne sera alors effectué.",
  },
  en: {
    title: "AI application diagnostic",
    body: "When you start the diagnostic, KPB sends the AI provider only a limited and minimized application excerpt, verified scholarship criteria, and checklist status. Your name, email, phone number, and guardian contact details must not be sent. The result provides one priority improvement: it never guarantees admission and does not replace a KPB counsellor. You may withdraw this consent; no new AI call will then be made.",
  },
} as const;

@Injectable()
export class AiConsentService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly featureAccess: FeatureAccessService,
  ) {}

  async getNotice(userId: string, rawLanguage: string | undefined) {
    await this.assertBaseAccess(userId);
    this.assertAiEnvironment();
    const languageCode = rawLanguage === "en" ? "en" : "fr";
    return this.notice(languageCode);
  }

  async grant(userId: string, input: GrantAiConsentDto) {
    await this.assertBaseAccess(userId);
    this.assertAiEnvironment();
    if (!input.accepted || input.noticeVersion !== NOTICE_VERSION) {
      throw new CompetitionReadinessHttpException(
        "AI_CONSENT_REQUIRED",
        422,
        "The current AI notice must be explicitly accepted.",
      );
    }
    if (!this.prismaService.isEnabled) throw databaseUnavailable();

    const noticeContract = this.notice(input.languageCode);
    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        await tx.$executeRaw(
          Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${`ai-consent:${userId}`}))`,
        );
        const profile = await tx.userProfile.findUnique({
          where: { id: userId },
          select: { birthDate: true },
        });
        if (!profile?.birthDate) {
          throw new CompetitionReadinessHttpException(
            "GUARDIAN_CONSENT_REQUIRED",
            422,
            "A birth date is required before enabling AI processing.",
          );
        }
        const age = this.ageAt(profile.birthDate, new Date());
        const minimumAge = this.minimumAge();
        if (age < minimumAge) {
          throw new CompetitionReadinessHttpException(
            "GUARDIAN_CONSENT_REQUIRED",
            403,
            "AI processing is unavailable below the configured minimum age.",
          );
        }

        const guardian =
          age < 18
            ? await tx.guardianAuthorization.findFirst({
                where: {
                  minorUserId: userId,
                  status: "verified",
                  verifiedAt: { lte: new Date() },
                  revokedAt: null,
                  OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
                },
                orderBy: { verifiedAt: "desc" },
                select: { id: true },
              })
            : null;
        if (age < 18 && !guardian) {
          throw new CompetitionReadinessHttpException(
            "GUARDIAN_CONSENT_REQUIRED",
            403,
            "Verified guardian authorization is required for a minor.",
          );
        }

        const now = new Date();
        const notice = await tx.consentNotice.upsert({
          where: {
            purpose_version_languageCode: {
              purpose: "ai_third_party",
              version: NOTICE_VERSION,
              languageCode: input.languageCode,
            },
          },
          create: {
            purpose: "ai_third_party",
            version: NOTICE_VERSION,
            languageCode: input.languageCode,
            contentHash: noticeContract.contentHash,
            effectiveAt: now,
          },
          update: { retiredAt: null },
        });
        if (notice.contentHash !== noticeContract.contentHash) {
          throw new Error(
            "AI consent notice content changed without a version bump.",
          );
        }
        await tx.consentNotice.updateMany({
          where: {
            purpose: "ai_third_party",
            languageCode: input.languageCode,
            version: { not: NOTICE_VERSION },
            retiredAt: null,
          },
          data: { retiredAt: now },
        });
        const existing = await tx.consentReceipt.findFirst({
          where: {
            userId,
            purpose: "ai_third_party",
            noticeId: notice.id,
            revokedAt: null,
          },
          orderBy: { grantedAt: "desc" },
        });
        if (existing) {
          return { receipt: existing, notice: noticeContract };
        }

        await tx.consentReceipt.updateMany({
          where: { userId, purpose: "ai_third_party", revokedAt: null },
          data: { revokedAt: now },
        });
        const receipt = await tx.consentReceipt.create({
          data: {
            userId,
            purpose: "ai_third_party",
            noticeId: notice.id,
            languageCode: input.languageCode,
            channel: "mobile_success_lab",
            grantedAt: now,
            guardianAuthorizationId: guardian?.id,
          },
        });
        return { receipt, notice: noticeContract };
      }),
    );
    if (!result) throw databaseUnavailable();
    return {
      receiptId: result.receipt.id,
      purpose: "ai_third_party",
      notice: result.notice,
      grantedAt: result.receipt.grantedAt.toISOString(),
    };
  }

  async revoke(userId: string) {
    await this.assertBaseAccess(userId);
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
    const result = await this.prismaService.execute((prisma) =>
      prisma.consentReceipt.updateMany({
        where: { userId, purpose: "ai_third_party", revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    );
    if (!result) throw databaseUnavailable();
    return { revoked: true };
  }

  private notice(languageCode: "fr" | "en") {
    const notice = NOTICES[languageCode];
    const contentHash = createHash("sha256")
      .update(
        JSON.stringify({
          purpose: "ai_third_party",
          version: NOTICE_VERSION,
          languageCode,
          title: notice.title,
          body: notice.body,
        }),
      )
      .digest("hex");
    return {
      purpose: "ai_third_party",
      version: NOTICE_VERSION,
      languageCode,
      title: notice.title,
      body: notice.body,
      contentHash,
    };
  }

  private async assertBaseAccess(userId: string) {
    const decision = await this.featureAccess.evaluate({
      feature: "success_lab",
      userId,
    });
    if (!decision.allowed) throw featureDisabled("success_lab");
  }

  private assertAiEnvironment() {
    const enabled =
      process.env.KPB_AI_DIAGNOSTIC_ENABLED?.trim().toLowerCase() === "true";
    const killed =
      process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH?.trim().toLowerCase() !==
      "false";
    if (!enabled || killed) throw featureDisabled("ai_diagnostic");
  }

  private minimumAge() {
    const configured = Number(process.env.KPB_AI_DIAGNOSTIC_MIN_AGE ?? "13");
    return Number.isInteger(configured) && configured >= 13 && configured <= 18
      ? configured
      : 13;
  }

  private ageAt(birthDate: Date, now: Date) {
    let age = now.getUTCFullYear() - birthDate.getUTCFullYear();
    if (
      now.getUTCMonth() < birthDate.getUTCMonth() ||
      (now.getUTCMonth() === birthDate.getUTCMonth() &&
        now.getUTCDate() < birthDate.getUTCDate())
    ) {
      age -= 1;
    }
    return age;
  }
}
