import { Injectable, Logger } from "@nestjs/common";
import { Cron } from "@nestjs/schedule";

import { CaseStatus } from "../../common/enums/case-status.enum";
import { InternalRole } from "../../common/enums/internal-role.enum";
import { PrismaService } from "../prisma/prisma.service";

// Réattribution d'un dossier dont l'étudiant attend une réponse depuis 10 h.
//
// ## Ce que ce fichier corrige (07/11/2026)
//
// L'ancienne règle réattribuait tout dossier ouvert sans message de conseiller
// DANS L'APP depuis 10 h, et la réattribution remettait `updatedAt` à zéro.
// Or les conseillers répondent sur WhatsApp, pas dans l'app : en production,
// 1 241 dossiers portaient 81 861 lignes « Dossier réattribué » (environ 66
// chacun), visibles par l'étudiant dans l'historique de son dossier, et le
// nom du conseiller changeait toutes les 10 h. Une réponse d'un `admin`, une
// attribution manuelle ou un classement commercial après un échange WhatsApp
// n'arrêtaient pas la boucle.
//
// ## La règle
//
// Un dossier est réattribué UNE fois par attente, et seulement si l'étudiant
// attend vraiment :
//   - l'attente commence à son dernier message, ou à la création du dossier
//     s'il n'a jamais écrit ;
//   - elle prend fin dès qu'un membre de l'équipe agit APRÈS ce début : un
//     message (tout rôle interne), une attribution manuelle ou un classement
//     commercial (`lastCommercialInteractionAt`), ou une réattribution déjà
//     faite pour cette attente ;
//   - au bout de 10 h sans rien de tout cela, le dossier change de conseiller,
//     puis ne bouge plus tant que l'étudiant n'a pas réécrit.

export const REASSIGN_AFTER_MS = 10 * 60 * 60 * 1000;

/// Titre de l'événement écrit à chaque réattribution, et relu pour savoir si
/// l'attente en cours a déjà été traitée.
export const REASSIGNED_EVENT_TITLE = "Dossier réattribué";

/// L'attribution automatique à la création estampille
/// `lastCommercialInteractionAt` dans la même transaction que le dossier : ce
/// n'est pas une prise en charge. Au-delà de cette marge, c'en est une.
const CREATION_STAMP_GRACE_MS = 60 * 1000;

const OPEN_STATUSES = [
  CaseStatus.CounselorAssigned,
  CaseStatus.UnderReview,
  CaseStatus.InProgress,
];

export const STAFF_MESSAGE_ROLES: readonly string[] = [
  ...Object.values(InternalRole),
  "advisor",
];

export type ReassignmentFacts = {
  createdAt: Date;
  lastStudentMessageAt?: Date | null;
  lastStaffMessageAt?: Date | null;
  lastReassignedAt?: Date | null;
  lastCommercialInteractionAt?: Date | null;
};

export function needsReassignment(
  facts: ReassignmentFacts,
  now: Date,
): boolean {
  const waitingSince = facts.lastStudentMessageAt ?? facts.createdAt;
  if (now.getTime() - waitingSince.getTime() < REASSIGN_AFTER_MS) return false;

  const commercialTouch =
    facts.lastCommercialInteractionAt &&
    facts.lastCommercialInteractionAt.getTime() - facts.createdAt.getTime() >
      CREATION_STAMP_GRACE_MS
      ? facts.lastCommercialInteractionAt
      : null;

  const handledSince = [
    facts.lastStaffMessageAt,
    facts.lastReassignedAt,
    commercialTouch,
  ].some((at) => !!at && at.getTime() >= waitingSince.getTime());

  return !handledSince;
}

@Injectable()
export class CaseReassignmentCronService {
  private readonly logger = new Logger(CaseReassignmentCronService.name);

  constructor(private readonly prismaService: PrismaService) {}

  @Cron("*/15 * * * *")
  async reassignUnresponsiveCases(now: Date = new Date()) {
    if (!this.prismaService.isEnabled) return;

    const cutoff = new Date(now.getTime() - REASSIGN_AFTER_MS);
    const candidates = await this.prismaService.execute((prisma) =>
      prisma.case.findMany({
        where: {
          counsellorId: { not: null },
          status: { in: OPEN_STATUSES },
          createdAt: { lt: cutoff },
        },
        select: {
          id: true,
          counsellorId: true,
          createdAt: true,
          lastCommercialInteractionAt: true,
          messages: {
            where: { senderRole: { in: ["student", ...STAFF_MESSAGE_ROLES] } },
            orderBy: { createdAt: "desc" },
            take: 50,
            select: { senderRole: true, createdAt: true },
          },
          timelineEvents: {
            where: { title: REASSIGNED_EVENT_TITLE },
            orderBy: { createdAt: "desc" },
            take: 1,
            select: { createdAt: true },
          },
        },
      }),
    );

    if (!candidates || candidates.length === 0) return;

    let reassigned = 0;
    for (const item of candidates) {
      const lastStudentMessageAt = item.messages.find(
        (m) => m.senderRole === "student",
      )?.createdAt;
      const lastStaffMessageAt = item.messages.find(
        (m) => m.senderRole !== "student",
      )?.createdAt;

      const due = needsReassignment(
        {
          createdAt: item.createdAt,
          lastStudentMessageAt,
          lastStaffMessageAt,
          lastReassignedAt: item.timelineEvents[0]?.createdAt,
          lastCommercialInteractionAt: item.lastCommercialInteractionAt,
        },
        now,
      );
      if (!due) continue;

      const moved = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const activeCounsellors = await tx.counsellor.findMany({
            where: {
              isActive: true,
              id: { not: item.counsellorId ?? undefined },
            },
            include: {
              _count: {
                select: { cases: { where: { status: { in: OPEN_STATUSES } } } },
              },
            },
          });

          if (activeCounsellors.length === 0) return false;

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
              updatedAt: now,
            },
          });

          await tx.caseTimelineEvent.create({
            data: {
              caseId: item.id,
              status: CaseStatus.CounselorAssigned,
              title: REASSIGNED_EVENT_TITLE,
              description: `Ton dossier a été réattribué à ${next.fullName}.`,
              createdAt: now,
            },
          });
          return true;
        }),
      );
      if (moved) reassigned += 1;
    }

    if (reassigned > 0) {
      this.logger.log(
        `Reassigned ${reassigned} case(s) whose student was waiting.`,
      );
    }
  }
}
