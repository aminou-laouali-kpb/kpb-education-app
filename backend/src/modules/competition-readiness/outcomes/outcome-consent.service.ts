import { createHash } from 'node:crypto';

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  featureDisabled,
  workspaceNotFound,
} from '../common/competition-readiness.errors';
import type { GrantOutcomeConsentDto } from './dto/grant-outcome-consent.dto';

const NOTICE_VERSION = 'outcome-evidence-v1';
const NOTICES = {
  fr: {
    title: 'Preuves privées de soumission et de décision',
    body: "Tu autorises KPB à stocker de façon privée les preuves que tu choisis et à les montrer uniquement aux modérateurs KPB autorisés afin de vérifier une soumission, une admission ou un financement déclaré. L’établissement ou l’organisme financeur reste le seul auteur de la décision. Ce consentement n’autorise ni publication de ton histoire, ni témoignage, ni statistique publique individuelle ; ces usages demandent des consentements séparés.",
  },
  en: {
    title: 'Private submission and decision evidence',
    body: 'You authorize KPB to privately store the evidence you choose and show it only to authorized KPB moderators to verify a reported submission, admission or funding outcome. The institution or funding body remains the sole issuer of the decision. This consent does not authorize publishing your story, a testimonial or individual public statistics; those uses require separate consent.',
  },
} as const;

@Injectable()
export class OutcomeConsentService {
  constructor(private readonly prismaService: PrismaService) {}

  async getNotice(
    userId: string,
    workspaceId: string,
    rawLanguage: string | undefined,
  ) {
    await this.assertOwnedWorkspace(userId, workspaceId);
    return this.notice(rawLanguage === 'en' ? 'en' : 'fr');
  }

  async grant(
    userId: string,
    workspaceId: string,
    input: GrantOutcomeConsentDto,
  ) {
    this.assertEnvironment();
    this.assertDb();
    if (!input.accepted || input.noticeVersion !== NOTICE_VERSION) {
      throw new CompetitionReadinessHttpException(
        'OUTCOME_EVIDENCE_REQUIRED',
        422,
        'The current outcome-evidence notice must be accepted.',
      );
    }

    const noticeContract = this.notice(input.languageCode);
    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        await tx.$executeRaw(
          Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${`outcome-consent:${userId}`}))`,
        );
        const workspace = await tx.scholarshipWorkspace.findFirst({
          where: {
            id: workspaceId,
            userId,
            status: { not: 'archived' },
            user: { accountType: 'student' },
          },
          select: { id: true },
        });
        if (!workspace) throw workspaceNotFound();

        const profile = await tx.userProfile.findUnique({
          where: { id: userId },
          select: { accountType: true, birthDate: true },
        });
        if (profile?.accountType !== 'student') {
          throw new CompetitionReadinessHttpException(
            'FORBIDDEN_SCOPE',
            403,
            'Outcome evidence is available only to student accounts.',
          );
        }
        if (!profile?.birthDate) {
          throw new CompetitionReadinessHttpException(
            'PROFILE_INCOMPLETE',
            422,
            'Birth date is required before storing private outcome evidence.',
          );
        }

        const now = new Date();
        const isMinor = this.isMinorAt(profile.birthDate, now);
        const guardian = isMinor
          ? await tx.guardianAuthorization.findFirst({
              where: {
                minorUserId: userId,
                status: 'verified',
                verifiedAt: { lte: now },
                revokedAt: null,
                OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
              },
              orderBy: { verifiedAt: 'desc' },
              select: { id: true },
            })
          : null;
        if (isMinor && !guardian) {
          throw new CompetitionReadinessHttpException(
            'GUARDIAN_CONSENT_REQUIRED',
            403,
            'Verified guardian authorization is required for a minor.',
          );
        }

        const notice = await tx.consentNotice.upsert({
          where: {
            purpose_version_languageCode: {
              purpose: 'outcome_evidence',
              version: NOTICE_VERSION,
              languageCode: input.languageCode,
            },
          },
          create: {
            purpose: 'outcome_evidence',
            version: NOTICE_VERSION,
            languageCode: input.languageCode,
            contentHash: noticeContract.contentHash,
            effectiveAt: now,
          },
          update: { retiredAt: null },
        });
        if (notice.contentHash !== noticeContract.contentHash) {
          throw new Error(
            'Outcome-evidence notice changed without a version bump.',
          );
        }
        await tx.consentNotice.updateMany({
          where: {
            purpose: 'outcome_evidence',
            languageCode: input.languageCode,
            version: { not: NOTICE_VERSION },
            retiredAt: null,
          },
          data: { retiredAt: now },
        });

        const existing = await tx.consentReceipt.findFirst({
          where: {
            userId,
            purpose: 'outcome_evidence',
            noticeId: notice.id,
            revokedAt: null,
          },
          orderBy: { grantedAt: 'desc' },
        });
        if (existing) return existing;

        await tx.consentReceipt.updateMany({
          where: { userId, purpose: 'outcome_evidence', revokedAt: null },
          data: { revokedAt: now },
        });
        return tx.consentReceipt.create({
          data: {
            userId,
            purpose: 'outcome_evidence',
            noticeId: notice.id,
            languageCode: input.languageCode,
            channel: 'mobile_success_lab',
            grantedAt: now,
            guardianAuthorizationId: guardian?.id,
          },
        });
      }),
    );
    if (!result) throw databaseUnavailable();
    return {
      receiptId: result.id,
      purpose: 'outcome_evidence' as const,
      workspaceId,
      notice: noticeContract,
      grantedAt: result.grantedAt.toISOString(),
    };
  }

  private notice(languageCode: 'fr' | 'en') {
    const notice = NOTICES[languageCode];
    const contentHash = createHash('sha256')
      .update(
        JSON.stringify({
          purpose: 'outcome_evidence',
          version: NOTICE_VERSION,
          languageCode,
          title: notice.title,
          body: notice.body,
        }),
      )
      .digest('hex');
    return {
      purpose: 'outcome_evidence' as const,
      version: NOTICE_VERSION,
      languageCode,
      title: notice.title,
      body: notice.body,
      contentHash,
    };
  }

  private async assertOwnedWorkspace(userId: string, workspaceId: string) {
    this.assertEnvironment();
    this.assertDb();
    const workspace = await this.prismaService.execute((prisma) =>
      prisma.scholarshipWorkspace.findFirst({
        where: {
          id: workspaceId,
          userId,
          status: { not: 'archived' },
          user: { accountType: 'student' },
        },
        select: { id: true },
      }),
    );
    if (!workspace) throw workspaceNotFound();
  }

  private assertEnvironment() {
    const enabled =
      process.env.KPB_COMPETITION_READINESS_ENABLED?.trim().toLowerCase() ===
        'true' &&
      process.env.KPB_SUCCESS_LAB_ENABLED?.trim().toLowerCase() === 'true' &&
      process.env.KPB_OUTCOME_EVIDENCE_ENABLED?.trim().toLowerCase() === 'true';
    if (!enabled) throw featureDisabled('outcome_evidence');
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }

  private isMinorAt(birthDate: Date, now: Date) {
    const adultThreshold = new Date(now);
    adultThreshold.setUTCFullYear(adultThreshold.getUTCFullYear() - 18);
    return birthDate > adultThreshold;
  }
}
