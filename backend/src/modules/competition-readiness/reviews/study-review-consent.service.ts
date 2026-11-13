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
import type { GrantStudyReviewConsentDto } from "./dto/grant-study-review-consent.dto";

const NOTICE_VERSION = "advisor-document-share-v1";
const NOTICES = {
  fr: {
    title: "Partage de documents avec un conseiller KPB",
    body: "Tu choisis exactement les versions de documents transmises pour l’étude gratuite de ton dossier. Seuls les conseillers KPB autorisés peuvent les consulter pour cette demande. KPB prépare un avis et des prochaines étapes ; la décision d’admission appartient toujours à l’établissement. Tu peux retirer un document avant l’étude ou demander la fermeture de la demande.",
  },
  en: {
    title: "Share documents with a KPB counsellor",
    body: "You choose the exact document versions shared for the free application study. Only authorized KPB counsellors may access them for this request. KPB provides guidance and next steps; the institution always makes the admission decision. You may remove a document before review or ask for the request to be closed.",
  },
} as const;

@Injectable()
export class StudyReviewConsentService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly featureAccess: FeatureAccessService,
  ) {}

  async getNotice(userId: string, rawLanguage: string | undefined) {
    await this.assertAccess(userId);
    return this.notice(rawLanguage === "en" ? "en" : "fr");
  }

  async grant(userId: string, input: GrantStudyReviewConsentDto) {
    await this.assertAccess(userId);
    if (!input.accepted || input.noticeVersion !== NOTICE_VERSION) {
      throw new CompetitionReadinessHttpException(
        "PROFILE_INCOMPLETE",
        422,
        "The current document-sharing notice must be accepted.",
      );
    }
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
    const noticeContract = this.notice(input.languageCode);
    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        await tx.$executeRaw(
          Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${`review-consent:${userId}`}))`,
        );
        const profile = await tx.userProfile.findUnique({
          where: { id: userId },
          select: { birthDate: true },
        });
        if (!profile?.birthDate) {
          throw new CompetitionReadinessHttpException(
            "PROFILE_INCOMPLETE",
            422,
            "Birth date is required before sharing private documents.",
          );
        }
        const now = new Date();
        const isMinor = this.isMinorAt(profile.birthDate, now);
        const guardian = isMinor
          ? await tx.guardianAuthorization.findFirst({
              where: {
                minorUserId: userId,
                status: "verified",
                verifiedAt: { lte: now },
                revokedAt: null,
                OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
              },
              orderBy: { verifiedAt: "desc" },
              select: { id: true },
            })
          : null;
        if (isMinor && !guardian) {
          throw new CompetitionReadinessHttpException(
            "GUARDIAN_CONSENT_REQUIRED",
            403,
            "Verified guardian authorization is required for a minor.",
          );
        }

        const notice = await tx.consentNotice.upsert({
          where: {
            purpose_version_languageCode: {
              purpose: "advisor_document_share",
              version: NOTICE_VERSION,
              languageCode: input.languageCode,
            },
          },
          create: {
            purpose: "advisor_document_share",
            version: NOTICE_VERSION,
            languageCode: input.languageCode,
            contentHash: noticeContract.contentHash,
            effectiveAt: now,
          },
          update: { retiredAt: null },
        });
        if (notice.contentHash !== noticeContract.contentHash) {
          throw new Error(
            "Study-review consent notice changed without a version bump.",
          );
        }
        await tx.consentNotice.updateMany({
          where: {
            purpose: "advisor_document_share",
            languageCode: input.languageCode,
            version: { not: NOTICE_VERSION },
            retiredAt: null,
          },
          data: { retiredAt: now },
        });
        const existing = await tx.consentReceipt.findFirst({
          where: {
            userId,
            purpose: "advisor_document_share",
            noticeId: notice.id,
            revokedAt: null,
          },
          orderBy: { grantedAt: "desc" },
        });
        if (existing) return { receipt: existing, notice: noticeContract };

        await tx.consentReceipt.updateMany({
          where: {
            userId,
            purpose: "advisor_document_share",
            revokedAt: null,
          },
          data: { revokedAt: now },
        });
        const receipt = await tx.consentReceipt.create({
          data: {
            userId,
            purpose: "advisor_document_share",
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
      purpose: "advisor_document_share",
      notice: result.notice,
      grantedAt: result.receipt.grantedAt.toISOString(),
    };
  }

  private notice(languageCode: "fr" | "en") {
    const notice = NOTICES[languageCode];
    const contentHash = createHash("sha256")
      .update(
        JSON.stringify({
          purpose: "advisor_document_share",
          version: NOTICE_VERSION,
          languageCode,
          title: notice.title,
          body: notice.body,
        }),
      )
      .digest("hex");
    return {
      purpose: "advisor_document_share",
      version: NOTICE_VERSION,
      languageCode,
      title: notice.title,
      body: notice.body,
      contentHash,
    };
  }

  private async assertAccess(userId: string) {
    const envEnabled =
      process.env.KPB_APPLICATION_ARTIFACTS_ENABLED?.trim().toLowerCase() ===
        "true" &&
      process.env.KPB_STUDY_REVIEW_ENABLED?.trim().toLowerCase() === "true";
    if (!envEnabled) throw featureDisabled("study_review");
    const decision = await this.featureAccess.evaluate({
      feature: "success_lab",
      userId,
    });
    if (!decision.allowed) throw featureDisabled("success_lab");
  }

  private isMinorAt(birthDate: Date, now: Date) {
    const adultThreshold = new Date(now);
    adultThreshold.setUTCFullYear(adultThreshold.getUTCFullYear() - 18);
    return birthDate > adultThreshold;
  }
}
