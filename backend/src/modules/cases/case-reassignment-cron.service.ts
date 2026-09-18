import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { CaseStatus } from '../../common/enums/case-status.enum';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CaseReassignmentCronService {
  private readonly logger = new Logger(CaseReassignmentCronService.name);

  constructor(private readonly prismaService: PrismaService) {}

  /// Reassign stale cases every 15 minutes.
  /// MVP policy: if no advisor message was posted in 10h, move case
  /// to the active counselor currently carrying the smallest open load.
  @Cron('*/15 * * * *')
  async reassignUnresponsiveCases() {
    if (!this.prismaService.isEnabled) return;

    const tenHoursAgo = new Date(Date.now() - 10 * 60 * 60 * 1000);
    const staleCases = await this.prismaService.execute((prisma) =>
      prisma.case.findMany({
        where: {
          counsellorId: { not: null },
          status: {
            in: [
              CaseStatus.CounselorAssigned,
              CaseStatus.UnderReview,
              CaseStatus.InProgress,
            ],
          },
          updatedAt: { lt: tenHoursAgo },
        },
        include: {
          messages: {
            where: { senderRole: { in: ['commercial', 'counselor', 'advisor'] } },
            orderBy: { createdAt: 'desc' },
            take: 1,
          },
        },
      }),
    );

    if (!staleCases || staleCases.length === 0) return;

    for (const item of staleCases) {
      const lastAdvisorMessageAt = item.messages?.[0]?.createdAt;
      if (lastAdvisorMessageAt && lastAdvisorMessageAt >= tenHoursAgo) {
        continue;
      }

      await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const activeCounsellors = await tx.counsellor.findMany({
            where: {
              isActive: true,
              id: { not: item.counsellorId ?? undefined },
            },
            include: {
              _count: {
                select: {
                  cases: {
                    where: {
                      status: {
                        in: [
                          CaseStatus.CounselorAssigned,
                          CaseStatus.UnderReview,
                          CaseStatus.InProgress,
                        ],
                      },
                    },
                  },
                },
              },
            },
          });

          if (activeCounsellors.length === 0) return;

          const next = activeCounsellors.sort(
            (a, b) => a._count.cases - b._count.cases,
          )[0];

          await tx.case.update({
            where: { id: item.id },
            data: {
              counsellorId: next.id,
              assignedAdvisorName: next.fullName,
              // Official-line policy (Item 12): clear any legacy personal
              // number instead of copying the new counsellor's contact.
              assignedAdvisorPhone: null,
              assignedAdvisorWhatsapp: null,
              updatedAt: new Date(),
            },
          });

          await tx.caseTimelineEvent.create({
            data: {
              caseId: item.id,
              status: CaseStatus.CounselorAssigned,
              title: 'Dossier réattribué',
              description: `Votre dossier a été réattribué à ${next.fullName}.`,
            },
          });
        }),
      );
    }

    this.logger.log(`Processed stale case reassignment for ${staleCases.length} cases.`);
  }
}
