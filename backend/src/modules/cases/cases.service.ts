import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
  ServiceUnavailableException,
} from "@nestjs/common";
import { ModuleRef } from "@nestjs/core";
import type { Prisma } from "@prisma/client";
import { randomUUID } from "node:crypto";

import { CaseStatus } from "../../common/enums/case-status.enum";
import { InternalRole } from "../../common/enums/internal-role.enum";
import { PushSenderService } from "../notifications/push-sender.service";
import { PrismaService } from "../prisma/prisma.service";
import { ReferralCreditsService } from "../referrals/referral-credits.service";
import { CaseLeadMailService } from "./case-lead-mail.service";
import { CaseMessagingGateway } from "./case-messaging.gateway";
import { AssignCaseDto } from "./dto/assign-case.dto";
import { CreateCaseDto } from "./dto/create-case.dto";
import { CreateCaseInternalNoteDto } from "./dto/create-case-internal-note.dto";
import {
  CLIENT_MESSAGE_ID_PATTERN,
  MAX_CASE_MESSAGE_LENGTH,
} from "./dto/create-case-message.dto";
import { CreateCaseTaskDto } from "./dto/create-case-task.dto";
import { CreateCaseTimelineEventDto } from "./dto/create-case-timeline-event.dto";
import {
  ADMIN_CASES_MAX_PAGE_SIZE,
  ADMIN_CASES_PAGE_SIZE,
} from "./dto/list-admin-cases.query.dto";
import { UpdateCaseDto } from "./dto/update-case.dto";
import { UploadCaseDocumentDto } from "./dto/upload-case-document.dto";

/**
 * Le résumé de la bourse accompagnée (« Mes 10 bourses » → « Être
 * accompagné »), lu avec le dossier par la relation : une requête groupée par
 * lecture, jamais une par dossier. Servi aux seules lectures staff (admin,
 * conseiller) : nom pour la file, lien officiel pour le conseiller.
 */
const CASE_SCHOLARSHIP_SELECT = {
  id: true,
  nameFr: true,
  nameEn: true,
  sourceUrl: true,
  applicationUrl: true,
} as const;

const CASE_INCLUDE = {
  user: true,
  scholarship: { select: CASE_SCHOLARSHIP_SELECT },
  // Un fil de discussion se lit de haut en bas : le plus ancien d'abord, le
  // message qu'on vient d'envoyer en dernier, sous les yeux de l'élève (revue
  // avant la 58, constat 37). Le reste de l'historique reste antéchronologique.
  messages: { orderBy: { createdAt: "asc" as const } },
  timelineEvents: { orderBy: { createdAt: "desc" as const } },
  tasks: { orderBy: { createdAt: "desc" as const } },
  documents: { orderBy: { createdAt: "desc" as const } },
  internalNotes: { orderBy: { createdAt: "desc" as const } },
};

/** Ce que l'administration lit de l'élève : trois champs, pas tout le profil. */
const ADMIN_CASE_USER_SELECT = {
  fullName: true,
  email: true,
  preferredLanguage: true,
} as const;

/**
 * Liste de l'administration : AUCUNE relation en liste (tâches, événements,
 * pièces, notes, messages). Avant, chaque ouverture de la page chargeait
 * celles de tous les dossiers — plus de 80 000 événements en production pour
 * environ 1 250 dossiers (audit avant la 59). Elles se lisent pour le seul
 * dossier ouvert (`findOneForAdmin`).
 */
const ADMIN_LIST_INCLUDE = {
  user: { select: ADMIN_CASE_USER_SELECT },
  scholarship: { select: CASE_SCHOLARSHIP_SELECT },
} as const;

/** Événements d'historique rendus pour le dossier ouvert (les plus récents). */
export const ADMIN_DETAIL_TIMELINE_LIMIT = 200;

/** Le dossier ouvert : ses relations, sans le fil (paginé à part). */
const ADMIN_DETAIL_INCLUDE = {
  ...ADMIN_LIST_INCLUDE,
  timelineEvents: {
    orderBy: [{ createdAt: "desc" as const }, { id: "desc" as const }],
    // Un de plus que la limite : c'est lui qui dit s'il en reste.
    take: ADMIN_DETAIL_TIMELINE_LIMIT + 1,
  },
  tasks: { orderBy: { createdAt: "desc" as const } },
  documents: { orderBy: { createdAt: "desc" as const } },
  internalNotes: { orderBy: { createdAt: "desc" as const } },
};

/** Filtres de `GET /admin/cases` (voir `ListAdminCasesQueryDto`). */
export interface AdminCaseListFilters {
  cursor?: string;
  limit?: number;
  status?: CaseStatus;
  advisor?: string;
  unassigned?: boolean;
  q?: string;
  awaiting?: boolean;
}

/**
 * Curseur de la liste : la date de création et l'identifiant du dernier
 * dossier rendu. Les deux, parce que deux dossiers peuvent porter la même
 * date et qu'une page ne doit ni en sauter un ni le rendre deux fois. Il ne
 * dépend pas de l'existence du dossier : supprimé entre deux pages, la suite
 * se lit quand même.
 */
export function encodeCaseCursor(row: { createdAt: Date; id: string }): string {
  return Buffer.from(
    `${row.createdAt.toISOString()}|${row.id}`,
    "utf8",
  ).toString("base64url");
}

export function decodeCaseCursor(cursor: string): {
  createdAt: Date;
  id: string;
} {
  const raw = Buffer.from(cursor, "base64url").toString("utf8");
  const at = raw.indexOf("|");
  const createdAt = new Date(at > 0 ? raw.slice(0, at) : "");
  const id = at > 0 ? raw.slice(at + 1) : "";
  if (Number.isNaN(createdAt.getTime()) || !/^[A-Za-z0-9_-]{1,64}$/.test(id)) {
    throw new BadRequestException("Invalid cursor.");
  }
  return { createdAt, id };
}

/**
 * Une demande identique du même élève dans cette fenêtre est un RENVOI, pas
 * une seconde demande (voir `create`). 24 h et non quelques minutes : l'app
 * ne renvoie un dossier resté local qu'à sa synchronisation suivante, qui est
 * souvent sa prochaine ouverture — le lendemain.
 */
export const DUPLICATE_CASE_WINDOW_MS = 24 * 60 * 60 * 1000;

/** Un dossier clos ne retient pas une nouvelle demande, même identique. */
const CLOSED_CASE_STATUSES = [
  CaseStatus.Completed,
  CaseStatus.Rejected,
  CaseStatus.Cancelled,
];

export interface CaseMessagingActor {
  userId: string;
  role: "student" | InternalRole;
  fullName?: string;
}

export type StaffActor = { id: string; role: string; fullName: string };

/** Une seule alerte e-mail à l'équipe par rafale de messages d'un élève. */
export const STAFF_ALERT_QUIET_MS = 30 * 60 * 1000;

/** Une seule notification à l'élève par rafale de réponses de l'équipe. */
export const REPLY_PUSH_QUIET_MS = 2 * 60 * 1000;

/** Dossiers attribués à un conseiller : profil conseiller lié OU nom d'affectation. */
function counselorCaseScope(staff: StaffActor) {
  return {
    OR: [
      { counsellor: { adminUserId: staff.id } },
      {
        assignedAdvisorName: {
          equals: staff.fullName.trim(),
          mode: "insensitive" as const,
        },
      },
    ],
  };
}

@Injectable()
export class CasesService {
  private readonly logger = new Logger(CasesService.name);

  /** La dernière alerte lancée (e-mail ou push), pour les tests. */
  pendingAlert: Promise<void> = Promise.resolve();

  constructor(
    private readonly prismaService: PrismaService,
    private readonly moduleRef: ModuleRef,
    private readonly pushService: PushSenderService,
    @Optional() private readonly leadMail?: CaseLeadMailService,
  ) {}

  private broadcastCaseUpdate(
    caseId: string,
    payload: Record<string, unknown>,
  ) {
    try {
      const gateway = this.moduleRef.get(CaseMessagingGateway, {
        strict: false,
      });
      gateway.emitCaseUpdated(caseId, payload);
    } catch {
      // Gateway may be unavailable in isolated tests.
    }
  }

  private broadcastCaseMessage(
    caseId: string,
    message: Record<string, unknown>,
  ) {
    try {
      const gateway = this.moduleRef.get(CaseMessagingGateway, {
        strict: false,
      });
      gateway.emitCaseMessage(caseId, message);
    } catch {
      // Gateway may be unavailable in isolated tests.
    }
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        "Database is not configured. Set DATABASE_URL.",
      );
    }
  }

  private async requireDbCase(id: string, ownerUserId?: string) {
    const dbCase = await this.prismaService.execute((prisma) =>
      prisma.case.findUnique({ where: { id }, include: CASE_INCLUDE }),
    );
    // When ownerUserId is provided (student-facing path) a case owned by
    // another user must be indistinguishable from a missing case to avoid
    // leaking its existence (IDOR protection).
    if (!dbCase || (ownerUserId && dbCase.userId !== ownerUserId)) {
      throw new NotFoundException(`Case ${id} not found.`);
    }
    return dbCase;
  }

  /**
   * `filters.scholarshipId` : la vérification « un dossier existe-t-il déjà pour
   * cette bourse ? » de « Être accompagné ». Toujours DANS la portée de
   * l'appelant : un étudiant ne voit que ses dossiers, filtre ou pas.
   */
  async findAll(userId?: string, filters: { scholarshipId?: string } = {}) {
    this.assertDb();
    const where: Prisma.CaseWhereInput = {
      ...(userId ? { userId } : {}),
      ...(filters.scholarshipId
        ? { scholarshipId: filters.scholarshipId }
        : {}),
    };
    const items = await this.prismaService.execute((prisma) =>
      prisma.case.findMany({
        where: Object.keys(where).length > 0 ? where : undefined,
        include: CASE_INCLUDE,
        orderBy: { createdAt: "desc" },
      }),
    );
    // Lecture étudiante (userId fourni) : jamais de données internes.
    return (items ?? []).map((c) =>
      this.mapDbCase(c, { includeInternal: !userId }),
    );
  }

  /**
   * Une page de la liste de l'administration (50 dossiers par défaut), du plus
   * récent au plus ancien. Filtres, recherche et portée par rôle sont
   * appliqués PAR LE SERVEUR : un conseiller ne voit que SES dossiers, quel
   * que soit le filtre. `nextCursor` vaut `null` à la dernière page.
   */
  async findAllForAdmin(
    staff?: StaffActor,
    filters: AdminCaseListFilters = {},
  ) {
    this.assertDb();
    const limit = Math.min(
      Math.max(Math.trunc(filters.limit ?? ADMIN_CASES_PAGE_SIZE), 1),
      ADMIN_CASES_MAX_PAGE_SIZE,
    );
    const and: Prisma.CaseWhereInput[] = [];
    if (staff?.role === InternalRole.Counselor) {
      and.push(counselorCaseScope(staff));
    }
    if (filters.status) and.push({ status: filters.status });
    const advisor = filters.advisor?.trim();
    if (advisor) {
      and.push({
        assignedAdvisorName: { equals: advisor, mode: "insensitive" },
      });
    }
    if (filters.unassigned) {
      and.push({
        OR: [{ assignedAdvisorName: null }, { assignedAdvisorName: "" }],
      });
    }
    const q = filters.q?.replace(/\s+/g, " ").trim();
    if (q) {
      const contains = { contains: q, mode: "insensitive" as const };
      and.push({
        OR: [
          { referenceCode: contains },
          { title: contains },
          { user: { fullName: contains } },
          { user: { email: contains } },
        ],
      });
    }
    if (filters.awaiting) {
      and.push({ id: { in: await this.awaitingReplyCaseIds() } });
    }
    if (filters.cursor) {
      const after = decodeCaseCursor(filters.cursor);
      and.push({
        OR: [
          { createdAt: { lt: after.createdAt } },
          { createdAt: after.createdAt, id: { lt: after.id } },
        ],
      });
    }

    const rows =
      (await this.prismaService.execute((prisma) =>
        prisma.case.findMany({
          where: and.length > 0 ? { AND: and } : undefined,
          include: ADMIN_LIST_INCLUDE,
          orderBy: [{ createdAt: "desc" }, { id: "desc" }],
          // Un de plus que la page : c'est lui qui dit s'il y a une suite.
          take: limit + 1,
        }),
      )) ?? [];
    const page = rows.slice(0, limit);
    const lastByCase = await this.lastMessages(page.map((c) => c.id));
    return {
      items: page.map((c) => {
        // Les relations ne sont PAS chargées : les rendre vides ferait dire à
        // la liste qu'un dossier n'a ni tâche ni note.
        const {
          documentRequests: _documents,
          tasks: _tasks,
          internalNotes: _notes,
          timeline: _timeline,
          messages: _messages,
          ...summary
        } = this.mapDbCase(c, { includeInternal: true });
        return { ...summary, ...this.replyFields(lastByCase.get(c.id)) };
      }),
      nextCursor:
        rows.length > limit ? encodeCaseCursor(page[page.length - 1]) : null,
    };
  }

  /**
   * Le dossier ouvert dans l'administration, avec ses tâches, pièces, notes
   * et son historique (les `ADMIN_DETAIL_TIMELINE_LIMIT` événements les plus
   * récents). Sans le fil : il se lit page par page. Un conseiller n'ouvre
   * que SES dossiers ; pour lui, celui d'un autre n'existe pas (404).
   */
  async findOneForAdmin(id: string, staff: StaffActor) {
    this.assertDb();
    const row = await this.prismaService.execute((prisma) =>
      prisma.case.findFirst({
        where: {
          id,
          ...(staff.role === InternalRole.Counselor
            ? counselorCaseScope(staff)
            : {}),
        },
        include: ADMIN_DETAIL_INCLUDE,
      }),
    );
    if (!row) throw new NotFoundException(`Case ${id} not found.`);
    const events = row.timelineEvents ?? [];
    const { messages: _messages, ...detail } = this.mapDbCase(
      {
        ...row,
        timelineEvents: events.slice(0, ADMIN_DETAIL_TIMELINE_LIMIT),
      },
      { includeInternal: true },
    );
    const last = (await this.lastMessages([id])).get(id);
    return {
      ...detail,
      timelineTruncated: events.length > ADMIN_DETAIL_TIMELINE_LIMIT,
      ...this.replyFields(last),
    };
  }

  /**
   * Ce que la liste affiche en tête, sur TOUS les dossiers de la portée et
   * non sur la page chargée : combien d'élèves attendent une réponse, et les
   * conseillers proposés dans le filtre.
   */
  async adminCaseListSummary(staff?: StaffActor) {
    this.assertDb();
    const scope: Prisma.CaseWhereInput =
      staff?.role === InternalRole.Counselor ? counselorCaseScope(staff) : {};
    const awaitingIds = await this.awaitingReplyCaseIds();
    const [awaitingCount, advisorRows] = await Promise.all([
      awaitingIds.length === 0
        ? 0
        : this.prismaService.execute((prisma) =>
            prisma.case.count({
              where: { AND: [scope, { id: { in: awaitingIds } }] },
            }),
          ),
      this.prismaService.execute((prisma) =>
        prisma.case.findMany({
          where: { AND: [scope, { assignedAdvisorName: { not: null } }] },
          select: { assignedAdvisorName: true },
          distinct: ["assignedAdvisorName"],
        }),
      ),
    ]);
    // « Awa KPB » et « awa kpb » sont le même conseiller pour le filtre
    // (comparaison sans casse) : une seule entrée.
    const advisors = new Map<string, string>();
    for (const row of advisorRows ?? []) {
      const name = row.assignedAdvisorName?.trim();
      if (name && !advisors.has(name.toLowerCase())) {
        advisors.set(name.toLowerCase(), name);
      }
    }
    return {
      awaitingCount: awaitingCount ?? 0,
      advisors: [...advisors.values()].sort((a, b) => a.localeCompare(b, "fr")),
    };
  }

  private replyFields(last?: { senderRole: string; createdAt: Date }) {
    return {
      lastMessageAt: last ? last.createdAt.toISOString() : null,
      awaitingReply: last?.senderRole === "student",
    };
  }

  /**
   * Les dossiers dont le DERNIER message vient de l'élève. Une lecture
   * d'index par dossier (`(caseId, createdAt)`), comme `lastMessages` — mais
   * sur tous les dossiers, puisque le filtre et le compteur portent sur toute
   * la liste et non sur la page chargée. Sans portée : l'appelant recoupe
   * avec la sienne.
   */
  private async awaitingReplyCaseIds(): Promise<string[]> {
    const rows = await this.prismaService.execute(async (prisma) =>
      typeof prisma.$queryRaw !== "function"
        ? []
        : prisma.$queryRaw<Array<{ id: string }>>`SELECT c."id"
          FROM "Case" c
          JOIN LATERAL (
            SELECT m."senderRole" FROM "CaseMessage" m
            WHERE m."caseId" = c."id"
            ORDER BY m."createdAt" DESC, m."id" DESC
            LIMIT 1
          ) last ON TRUE
          WHERE last."senderRole" = 'student'`,
    );
    return (rows ?? []).map((r) => r.id);
  }

  /**
   * Le dernier message de chaque dossier, en UNE requête qui ne lit qu'une
   * ligne par dossier (index `(caseId, createdAt)`). Un `take: 1` imbriqué
   * dans `findMany` lisait tous les messages de tous les dossiers.
   */
  private async lastMessages(caseIds: string[]) {
    const out = new Map<string, { senderRole: string; createdAt: Date }>();
    if (caseIds.length === 0) return out;
    // Repli : sans cette lecture (base de test, panne), la liste se charge
    // quand même, sans badge « réponse attendue ».
    const rows = await this.prismaService.execute(async (prisma) =>
      typeof prisma.$queryRaw !== "function"
        ? []
        : prisma.$queryRaw<
            Array<{ caseId: string; senderRole: string; createdAt: Date }>
          >`SELECT DISTINCT ON ("caseId") "caseId", "senderRole", "createdAt"
          FROM "CaseMessage"
          WHERE "caseId" = ANY(${caseIds}::text[])
          ORDER BY "caseId", "createdAt" DESC, "id" DESC`,
    );
    for (const r of rows ?? []) out.set(r.caseId, r);
    return out;
  }

  /**
   * Barrière des écritures staff : un conseiller ne modifie que les dossiers
   * qui lui sont attribués (profil conseiller lié, ou nom d'affectation).
   * Les autres rôles autorisés par le contrôleur passent.
   */
  async assertStaffCanAccessCase(id: string, staff: StaffActor) {
    if (staff.role !== InternalRole.Counselor) return;
    this.assertDb();
    const found = await this.prismaService.execute((prisma) =>
      prisma.case.findFirst({
        where: { id, ...counselorCaseScope(staff) },
        select: { id: true },
      }),
    );
    if (!found) throw new NotFoundException(`Case ${id} not found.`);
  }

  async findOne(id: string, ownerUserId?: string) {
    this.assertDb();
    const dbCase = await this.requireDbCase(id, ownerUserId);
    // Student-facing reads (ownerUserId set) must not expose counselor notes.
    return this.mapDbCase(dbCase, { includeInternal: !ownerUserId });
  }

  /**
   * Shared authorization boundary for every realtime case operation. Returning
   * NotFound for both missing and forbidden cases prevents cross-case probing.
   */
  async assertCanAccessMessaging(id: string, actor: CaseMessagingActor) {
    this.assertDb();
    const caseRecord = await this.prismaService.execute((prisma) =>
      prisma.case.findUnique({
        where: { id },
        select: {
          id: true,
          userId: true,
          assignedAdvisorName: true,
          counsellor: { select: { adminUserId: true } },
        },
      }),
    );

    const isOwner =
      actor.role === "student" && caseRecord?.userId === actor.userId;
    const isGlobalStaff =
      actor.role === InternalRole.Admin ||
      actor.role === InternalRole.SuperAdmin ||
      actor.role === InternalRole.Commercial;
    // Même portée que `counselorCaseScope` : profil conseiller lié OU nom
    // d'affectation (un conseiller attribué par son nom lisait le dossier dans
    // l'admin mais n'aurait pas pu y répondre).
    const isAssignedCounselor =
      actor.role === InternalRole.Counselor &&
      (caseRecord?.counsellor?.adminUserId === actor.userId ||
        (!!actor.fullName?.trim() &&
          caseRecord?.assignedAdvisorName?.trim().toLowerCase() ===
            actor.fullName.trim().toLowerCase()));

    if (!caseRecord || (!isOwner && !isGlobalStaff && !isAssignedCounselor)) {
      throw new NotFoundException(`Case ${id} not found.`);
    }

    return { id: caseRecord.id, userId: caseRecord.userId };
  }

  /**
   * Crée le dossier — ou rend celui qui existe déjà si la même demande vient
   * d'être faite.
   *
   * Sur un réseau instable, la création arrive au serveur mais la réponse se
   * perd : l'app garde le dossier sous un identifiant local et le renvoie à sa
   * synchronisation suivante. Sans garde, l'élève se retrouvait avec deux
   * dossiers et deux conseillers (audit avant la 59). Les apps installées
   * n'envoient aucun identifiant de demande, et la validation refuse tout
   * champ inconnu : la demande est donc reconnue à son CONTENU — même élève,
   * même type, mêmes titre, description, contexte et bourse — dans les
   * `DUPLICATE_CASE_WINDOW_MS`, tant que le premier dossier n'est pas clos.
   * Le renvoi rend le dossier existant, sans seconde notification ni second
   * e-mail à l'équipe.
   */
  async create(input: CreateCaseDto, userId?: string) {
    this.assertDb();

    const outcome = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        // Le lien vers la bourse n'est gardé que si la fiche existe : un
        // identifiant inconnu (fiche retirée, app plus récente) crée le dossier
        // sans lien plutôt que d'échouer sur la clé étrangère.
        const linkedScholarship = input.scholarshipId
          ? await tx.scholarship.findUnique({
              where: { id: input.scholarshipId },
              select: { id: true },
            })
          : null;

        if (userId) {
          // Deux envois SIMULTANÉS de la même demande ne se voient pas l'un
          // l'autre : le second attend ici que le premier ait fini, puis
          // trouve son dossier. Le verrou tombe avec la transaction.
          // `$executeRaw`, pas `$queryRaw` : la fonction rend `void`, que
          // Prisma ne sait pas relire (« Failed to deserialize column of type
          // 'void' ») — avec `$queryRaw`, CHAQUE création échouait sur un
          // vrai Postgres alors que les tests unitaires passaient.
          if (typeof tx.$executeRaw === "function") {
            await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${`case-create:${userId}`}))`;
          }
          const existing = await tx.case.findFirst({
            where: {
              userId,
              type: input.type,
              title: input.title,
              description: input.description,
              contextLabel: input.contextLabel,
              scholarshipId: linkedScholarship?.id ?? null,
              status: { notIn: CLOSED_CASE_STATUSES },
              createdAt: {
                gte: new Date(Date.now() - DUPLICATE_CASE_WINDOW_MS),
              },
            },
            orderBy: { createdAt: "desc" },
            include: CASE_INCLUDE,
          });
          if (existing) return { record: existing, duplicate: true };
        }

        const activeCounsellors = await tx.counsellor.findMany({
          where: { isActive: true },
          orderBy: { createdAt: "asc" },
        });

        // Insert with a temporary unique placeholder, then derive the real
        // referenceCode from the DB-assigned `seq`. This is collision-free by
        // construction (no count()+1 race). The same monotonic `seq` is used to
        // round-robin across active counsellors.
        const c = await tx.case.create({
          data: {
            referenceCode: `PENDING-${randomUUID()}`,
            userId: userId ?? "demo-user",
            type: input.type,
            status: CaseStatus.Submitted,
            title: input.title,
            description: input.description,
            contextLabel: input.contextLabel,
            // WhatsApp par défaut : l'équipe ne répond pas dans l'app (revue avant
            // la 58, constat 34) ; « in_app » reste lisible pour les anciens dossiers.
            preferredContactMethod: input.preferredContactMethod ?? "whatsapp",
            scholarshipId: linkedScholarship?.id ?? null,
            source: "mobile_app",
            nextStepTitle: "Ton dossier est en revue",
            nextStepDescription:
              "L’équipe KPB va examiner ta demande et t’attribuer un conseiller.",
          },
        });

        const nextCounsellor =
          activeCounsellors.length > 0
            ? activeCounsellors[(c.seq - 1) % activeCounsellors.length]
            : null;

        const refCode = `KPB-${c.createdAt.getFullYear()}-${String(c.seq).padStart(3, "0")}`;
        await tx.case.update({
          where: { id: c.id },
          data: {
            referenceCode: refCode,
            ...(nextCounsellor
              ? {
                  status: CaseStatus.CounselorAssigned,
                  counsellorId: nextCounsellor.id,
                  assignedAdvisorName: nextCounsellor.fullName,
                  // Personal counsellor numbers are deliberately NOT copied
                  // onto the case: every student/parent contact goes through
                  // the official KPB WhatsApp line (anti-fraud, Item 12).
                  leadTag: "to_follow_up",
                  lastCommercialInteractionAt: new Date(),
                  nextStepTitle: "Un conseiller t’a été attribué",
                  nextStepDescription: `${nextCounsellor.fullName} suit ton dossier et te contactera bientôt.`,
                }
              : {}),
          },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: c.id,
            status: CaseStatus.Submitted,
            title: "Demande envoyée",
            description: "Ta demande a été créée depuis l’application.",
          },
        });

        if (nextCounsellor) {
          await tx.caseTimelineEvent.create({
            data: {
              caseId: c.id,
              status: CaseStatus.CounselorAssigned,
              title: "Conseiller attribué",
              description: `Ton dossier a été attribué à ${nextCounsellor.fullName}.`,
            },
          });
        }

        await tx.caseMessage.create({
          data: {
            caseId: c.id,
            senderRole: "system",
            senderName: "KPB Operations",
            body: nextCounsellor
              ? `Merci pour ta demande. ${nextCounsellor.fullName} suit ton dossier.`
              : "Merci pour ta demande. L’équipe KPB l’a bien reçue.",
          },
        });

        // Plus de pièce « Profil académique » créée d'office : aucun conseiller
        // ne l'avait demandée, l'app ne sait plus la recevoir (envoi en app
        // masqué), elle restait donc « 0/1 » pour toujours, donnait un faux
        // délai de 7 jours et plafonnait la jauge « Ton plan » (audit build 57,
        // n° 5c). Les pièces que demande un conseiller arrivent par
        // l'administration.

        return {
          record: await tx.case.findUnique({
            where: { id: c.id },
            include: CASE_INCLUDE,
          }),
          duplicate: false,
        };
      }),
    );

    const created = outcome?.record;
    if (!created) {
      throw new ServiceUnavailableException("Failed to create case.");
    }
    const mapped = this.mapDbCase(created, { includeInternal: !userId });
    if (outcome.duplicate) {
      // Tout a déjà été fait à la première création : ni notification « Demande
      // reçue », ni crédit de parrainage, ni e-mail à l'équipe une seconde fois.
      this.logger.log(
        `Duplicate case creation ignored: returned existing case ${created.id}.`,
      );
      return mapped;
    }
    if (userId) {
      // No-cash referral reward (KPB-77): if this student was referred, credit
      // their referrer on the FIRST case. Fire-and-forget and OUTSIDE the
      // case-creation transaction — a crediting failure must never roll back or
      // block the student's case. Idempotency is enforced in the service.
      void this.moduleRef
        .get(ReferralCreditsService, { strict: false })
        .creditReferrerForFirstCase(userId)
        .catch(() => this.logger.warn("Referral credit failed."));

      const advisorName = mapped.assignedAdvisorName ?? "KPB";
      // KPB-173: deliberately NOT routed through NotificationDispatchService.
      // This is transactional — the immediate receipt for an action the student
      // just took. Holding it for quiet hours, or dropping it under the daily
      // reminder cap, would make the app look broken at the exact moment it
      // must feel reliable.
      await this.pushService.sendToUser(
        userId,
        "Demande reçue ✅",
        mapped.assignedAdvisorName
          ? `Ta demande est reçue, ${advisorName} va te contacter sous peu.`
          : "Ta demande est reçue. L'équipe KPB revient vers toi rapidement.",
        {
          type: "case_created",
          caseId: created.id,
          route: `/cases/${created.id}`,
        },
      );
    }
    if (this.leadMail) {
      try {
        await this.leadMail.notifyNewCase(created);
      } catch {
        this.logger.warn(
          `Commercial lead email failed for case ${created.id}.`,
        );
      }
    }
    return mapped;
  }

  /**
   * Mise à jour par l'ÉQUIPE (`PATCH /admin/cases/:id`). Il n'y a plus de chemin
   * étudiant : voir `CasesController`.
   */
  async update(id: string, input: UpdateCaseDto) {
    this.assertDb();
    await this.requireDbCase(id);

    const updated = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const c = await tx.case.update({
          where: { id },
          data: {
            ...(input.status ? { status: input.status } : {}),
            ...(input.nextStepTitle
              ? { nextStepTitle: input.nextStepTitle }
              : {}),
            ...(input.nextStepDescription
              ? { nextStepDescription: input.nextStepDescription }
              : {}),
            ...(input.assignedAdvisorName
              ? { assignedAdvisorName: input.assignedAdvisorName }
              : {}),
            ...(input.scheduledAt
              ? { scheduledAt: new Date(input.scheduledAt) }
              : {}),
          },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status: input.status ?? c.status,
            title: "Dossier mis à jour",
            description:
              input.nextStepDescription ??
              "Le dossier a été mis à jour par l’équipe KPB.",
          },
        });

        return tx.case.findUnique({
          where: { id },
          include: CASE_INCLUDE,
        });
      }),
    );

    if (!updated) {
      throw new ServiceUnavailableException("Failed to update case.");
    }
    const mapped = this.mapDbCase(updated, { includeInternal: true });
    this.broadcastCaseUpdate(
      id,
      this.mapDbCase(updated) as Record<string, unknown>,
    );
    return mapped;
  }

  async findMessages(id: string, ownerUserId?: string) {
    this.assertDb();
    if (ownerUserId) {
      await this.requireDbCase(id, ownerUserId);
    }
    const messages = await this.prismaService.execute((prisma) =>
      prisma.caseMessage.findMany({
        where: { caseId: id },
        orderBy: { createdAt: "desc" },
      }),
    );
    return (messages ?? []).map((m) => this.toMessagePayload(m));
  }

  async createMessage(
    id: string,
    input: { body: string; clientMessageId?: string },
    actorOrOwnerUserId: CaseMessagingActor | string,
  ) {
    this.assertDb();
    if (
      typeof input.body !== "string" ||
      input.body.length > MAX_CASE_MESSAGE_LENGTH ||
      input.body.trim().length === 0
    ) {
      throw new BadRequestException(
        `Message body must contain between 1 and ${MAX_CASE_MESSAGE_LENGTH} characters.`,
      );
    }
    const clientMessageId = input.clientMessageId ?? null;
    if (
      clientMessageId !== null &&
      (typeof clientMessageId !== "string" ||
        !CLIENT_MESSAGE_ID_PATTERN.test(clientMessageId))
    ) {
      throw new BadRequestException("Invalid clientMessageId.");
    }

    const actor =
      typeof actorOrOwnerUserId === "string"
        ? { userId: actorOrOwnerUserId, role: "student" as const }
        : actorOrOwnerUserId;
    await this.assertCanAccessMessaging(id, actor);

    const body = input.body.trim();
    const effectiveRole = actor.role;
    const effectiveName =
      actor.fullName ??
      (actor.role === "student" ? "Étudiant" : "KPB Operations");

    // Idempotence : l'app renvoie depuis sa file un message dont le POST a pu
    // aboutir sans qu'elle reçoive la réponse. Le message déjà créé est rendu
    // tel quel, sans second message ni second événement de chronologie.
    const existing = await this.findMessageByClientId(id, clientMessageId);
    if (existing) return this.toMessagePayload(existing);

    let created: Awaited<ReturnType<typeof this.findMessageByClientId>>;
    try {
      created = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const msg = await tx.caseMessage.create({
            data: {
              caseId: id,
              senderName: effectiveName,
              senderRole: effectiveRole,
              body,
              clientMessageId,
            },
          });

          // Plus d'événement « Nouveau message » dans la chronologie : il
          // doublait chaque écriture et noyait les vraies étapes du dossier.
          // Le fil des messages se lit dans le fil lui-même.
          await tx.case.update({
            where: { id },
            data: { updatedAt: new Date() },
          });

          return msg;
        }),
      );
    } catch (error) {
      // Deux renvois simultanés : le second bute sur l'index unique
      // (caseId, clientMessageId). Le premier a gagné, on rend son message.
      if (
        clientMessageId !== null &&
        (error as { code?: unknown } | null)?.code === "P2002"
      ) {
        const winner = await this.findMessageByClientId(id, clientMessageId);
        if (winner) return this.toMessagePayload(winner);
      }
      throw error;
    }

    if (!created) {
      throw new ServiceUnavailableException("Failed to persist message.");
    }
    const payload = this.toMessagePayload(created);
    // Alertes lancées sans être attendues : un fournisseur d'e-mail ou de push
    // lent ne doit jamais retenir l'envoi du message (ni l'accusé du socket).
    // Chacune attrape ses propres erreurs.
    if (effectiveRole !== "student") {
      this.broadcastCaseMessage(id, payload);
      this.pendingAlert = this.notifyStudentOfReply(id, created);
    } else {
      this.pendingAlert = this.notifyStaffOfStudentMessage(
        id,
        created.createdAt,
      );
    }
    return payload;
  }

  /**
   * L'équipe a répondu : l'élève reçoit un push qui ouvre SON dossier. Hors
   * `NotificationDispatchService` (pas d'heures calmes ni de plafond) : c'est
   * la réponse à une question qu'il vient de poser. Un échec d'envoi ne
   * rejette jamais la réponse, déjà enregistrée.
   */
  private async notifyStudentOfReply(
    caseId: string,
    message: { id: string; senderName: string; body: string; createdAt: Date },
  ) {
    try {
      // Plusieurs messages de l'équipe à la suite : une seule notification
      // (aucune si un autre message de l'équipe est parti dans ce dossier
      // dans les 2 minutes qui précèdent).
      const burst = await this.prismaService.execute((prisma) =>
        prisma.caseMessage.count({
          where: {
            caseId,
            id: { not: message.id },
            senderRole: { notIn: ["student", "system"] },
            createdAt: {
              gte: new Date(message.createdAt.getTime() - REPLY_PUSH_QUIET_MS),
              lte: message.createdAt,
            },
          },
        }),
      );
      if ((burst ?? 0) > 0) return;
      const owner = await this.prismaService.execute((prisma) =>
        prisma.case.findUnique({
          where: { id: caseId },
          select: {
            userId: true,
            user: { select: { preferredLanguage: true } },
          },
        }),
      );
      if (!owner?.userId) return;
      const english = (owner.user?.preferredLanguage ?? "")
        .toLowerCase()
        .startsWith("en");
      const preview =
        message.body.length > 120
          ? `${message.body.slice(0, 117).trimEnd()}…`
          : message.body;
      await this.pushService.sendToUser(
        owner.userId,
        english
          ? `${message.senderName} replied to you`
          : `${message.senderName} t’a répondu`,
        preview,
        { type: "case_message", caseId, route: `/cases/${caseId}` },
      );
    } catch {
      this.logger.warn(`Reply push failed for case ${caseId}.`);
    }
  }

  /**
   * Un élève a écrit : le conseiller attribué (sinon les commerciaux) reçoit
   * un e-mail. Une rafale de messages ne produit qu'un e-mail : rien si un
   * autre message de l'élève est arrivé dans ce dossier dans les 30 minutes
   * qui précèdent ET après la dernière réponse de l'équipe (l'élève qui
   * répond à l'équipe déclenche toujours une alerte).
   */
  private async notifyStaffOfStudentMessage(caseId: string, at: Date) {
    if (!this.leadMail) return;
    try {
      const lastStaff = await this.prismaService.execute((prisma) =>
        prisma.caseMessage.findFirst({
          where: {
            caseId,
            senderRole: { notIn: ["student", "system"] },
            createdAt: { lt: at },
          },
          orderBy: { createdAt: "desc" },
          select: { createdAt: true },
        }),
      );
      let since = new Date(at.getTime() - STAFF_ALERT_QUIET_MS);
      if (lastStaff?.createdAt && lastStaff.createdAt > since) {
        since = lastStaff.createdAt;
      }
      const recent = await this.prismaService.execute((prisma) =>
        prisma.caseMessage.count({
          where: {
            caseId,
            senderRole: "student",
            createdAt: { gt: since, lt: at },
          },
        }),
      );
      if ((recent ?? 0) > 0) return;
      const record = await this.prismaService.execute((prisma) =>
        prisma.case.findUnique({
          where: { id: caseId },
          select: {
            id: true,
            referenceCode: true,
            title: true,
            assignedAdvisorName: true,
            user: { select: { fullName: true, email: true } },
            counsellor: { select: { email: true, isActive: true } },
          },
        }),
      );
      if (!record) return;
      await this.leadMail.notifyStudentMessage(record);
    } catch {
      this.logger.warn(`Staff message alert failed for case ${caseId}.`);
    }
  }

  /**
   * Fil d'un dossier pour l'ÉQUIPE, page par page : les `limit` messages les
   * plus récents (avant `before` s'il est donné), rendus du plus ancien au
   * plus récent. `hasMore` dit s'il en reste plus anciens.
   */
  async findMessagesForAdmin(
    id: string,
    staff: StaffActor,
    options: { before?: string; limit?: number } = {},
  ) {
    this.assertDb();
    await this.assertCanAccessMessaging(id, {
      userId: staff.id,
      role: staff.role as InternalRole,
      fullName: staff.fullName,
    });
    const limit = Math.min(Math.max(Math.trunc(options.limit ?? 50), 1), 100);
    let beforeDate: Date | undefined;
    if (options.before) {
      const anchor = await this.prismaService.execute((prisma) =>
        prisma.caseMessage.findFirst({
          where: { id: options.before, caseId: id },
          select: { createdAt: true },
        }),
      );
      if (!anchor) throw new NotFoundException("Message not found.");
      beforeDate = anchor.createdAt;
    }
    const rows = await this.prismaService.execute((prisma) =>
      prisma.caseMessage.findMany({
        where: {
          caseId: id,
          ...(beforeDate ? { createdAt: { lt: beforeDate } } : {}),
        },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        take: limit + 1,
      }),
    );
    const page = rows ?? [];
    const hasMore = page.length > limit;
    return {
      items: page
        .slice(0, limit)
        .reverse()
        .map((m) => this.toMessagePayload(m)),
      hasMore,
    };
  }

  private async findMessageByClientId(
    caseId: string,
    clientMessageId: string | null,
  ) {
    if (clientMessageId === null) return null;
    return this.prismaService.execute((prisma) =>
      prisma.caseMessage.findUnique({
        where: { caseId_clientMessageId: { caseId, clientMessageId } },
      }),
    );
  }

  private toMessagePayload(m: {
    id: string;
    senderName: string;
    senderRole: string;
    body: string;
    createdAt: Date;
    clientMessageId?: string | null;
  }) {
    return {
      id: m.id,
      senderName: m.senderName,
      senderRole: m.senderRole,
      body: m.body,
      createdAt: m.createdAt.toISOString(),
      clientMessageId: m.clientMessageId ?? null,
    };
  }

  async uploadDocument(
    id: string,
    input: UploadCaseDocumentDto,
    ownerUserId?: string,
    fileUrl?: string,
  ) {
    this.assertDb();
    await this.requireDbCase(id, ownerUserId);

    const created = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const doc = await tx.caseDocument.create({
          data: {
            caseId: id,
            title: input.title,
            isProvided: true,
            fileUrl: fileUrl ?? null,
            uploadedAt: new Date(),
          },
        });

        await tx.case.update({
          where: { id },
          data: { status: CaseStatus.UnderReview },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status: CaseStatus.UnderReview,
            title: "Document ajouté",
            description: `Le document « ${input.title} » a été ajouté au dossier.`,
          },
        });

        return doc;
      }),
    );

    if (!created) {
      throw new ServiceUnavailableException("Failed to persist document.");
    }
    return {
      id: created.id,
      title: created.title,
      isProvided: created.isProvided,
      hasFile: Boolean(created.fileUrl),
      downloadPath: created.fileUrl
        ? `/cases/${id}/documents/${created.id}/file`
        : null,
      uploadedAt: created.uploadedAt?.toISOString(),
    };
  }

  /**
   * Resolve a document for its student owner. A missing document and a document
   * belonging to another student both return 404 to avoid IDOR disclosure.
   */
  async getOwnedDocument(id: string, documentId: string, ownerUserId: string) {
    this.assertDb();
    const document = await this.prismaService.execute((prisma) =>
      prisma.caseDocument.findFirst({
        where: {
          id: documentId,
          caseId: id,
          case: { userId: ownerUserId },
        },
        select: {
          id: true,
          title: true,
          fileUrl: true,
        },
      }),
    );
    if (!document || !document.fileUrl) {
      throw new NotFoundException("Document not found.");
    }
    return document;
  }

  /**
   * Internal access is intentionally narrower than the broad admin case list:
   * only an assigned counsellor or an administrator may retrieve file bytes.
   */
  async getInternalDocument(
    id: string,
    documentId: string,
    internalUser: { role: string; fullName: string; id?: string },
  ) {
    this.assertDb();
    const document = await this.prismaService.execute((prisma) =>
      prisma.caseDocument.findFirst({
        where: { id: documentId, caseId: id },
        select: {
          id: true,
          title: true,
          fileUrl: true,
          case: {
            select: {
              assignedAdvisorName: true,
              counsellor: { select: { adminUserId: true } },
            },
          },
        },
      }),
    );
    if (!document || !document.fileUrl) {
      throw new NotFoundException("Document not found.");
    }

    const isAdministrator = [
      InternalRole.Admin,
      InternalRole.SuperAdmin,
    ].includes(internalUser.role as InternalRole);
    const isAssignedCounsellor =
      internalUser.role === InternalRole.Counselor &&
      ((!!internalUser.id &&
        document.case.counsellor?.adminUserId === internalUser.id) ||
        (!!document.case.assignedAdvisorName &&
          document.case.assignedAdvisorName.trim().toLowerCase() ===
            internalUser.fullName.trim().toLowerCase()));
    if (!isAdministrator && !isAssignedCounsellor) {
      // Return 404 rather than 403 so an internal user cannot enumerate
      // sensitive documents outside their assignment.
      throw new NotFoundException("Document not found.");
    }
    return document;
  }

  async assignCase(id: string, input: AssignCaseDto) {
    this.assertDb();
    await this.requireDbCase(id);

    const newStatus = input.scheduledAt
      ? CaseStatus.Scheduled
      : CaseStatus.CounselorAssigned;

    const assigned = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        await tx.case.update({
          where: { id },
          data: {
            status: newStatus,
            assignedAdvisorName: input.assignedAdvisorName,
            // Official-line policy (Item 12): a manual assignment clears any
            // legacy personal number instead of writing a new one.
            assignedAdvisorPhone: null,
            assignedAdvisorWhatsapp: null,
            leadTag: "to_follow_up",
            lastCommercialInteractionAt: new Date(),
            nextStepTitle:
              input.nextStepTitle ??
              (input.scheduledAt
                ? "Prépare ton rendez-vous"
                : "Un conseiller t’a été attribué"),
            nextStepDescription:
              input.nextStepDescription ??
              (input.scheduledAt
                ? "Confirme ta disponibilité et prépare tes pièces justificatives."
                : "Ton conseiller va étudier ton profil et te contactera bientôt."),
            ...(input.scheduledAt
              ? { scheduledAt: new Date(input.scheduledAt) }
              : {}),
          },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status: newStatus,
            title: input.scheduledAt
              ? "Rendez-vous programmé"
              : "Conseiller attribué",
            description: input.scheduledAt
              ? `${input.assignedAdvisorName} a programmé un point de suivi sur ton dossier.`
              : `${input.assignedAdvisorName} suit désormais ton dossier.`,
          },
        });

        return tx.case.findUnique({
          where: { id },
          include: CASE_INCLUDE,
        });
      }),
    );

    if (!assigned) {
      throw new ServiceUnavailableException("Failed to assign case.");
    }
    const mapped = this.mapDbCase(assigned, { includeInternal: true });
    this.broadcastCaseUpdate(
      id,
      this.mapDbCase(assigned) as Record<string, unknown>,
    );
    return mapped;
  }

  async createTask(id: string, input: CreateCaseTaskDto) {
    this.assertDb();
    await this.requireDbCase(id);

    const created = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const task = await tx.caseTask.create({
          data: {
            caseId: id,
            title: input.title,
            assigneeName: input.assigneeName ?? null,
            status: input.status ?? "open",
            ...(input.dueAt ? { dueAt: new Date(input.dueAt) } : {}),
          },
        });

        await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status:
              (await tx.case.findUnique({ where: { id } }))?.status ??
              CaseStatus.Submitted,
            title: "Action ajoutée",
            description: `L’action « ${input.title} » a été ajoutée à ton dossier.`,
          },
        });

        await tx.case.update({
          where: { id },
          data: { updatedAt: new Date() },
        });

        return task;
      }),
    );

    if (!created) {
      throw new ServiceUnavailableException("Failed to create task.");
    }
    return {
      id: created.id,
      title: created.title,
      assigneeName: created.assigneeName,
      assigneeRole: created.assigneeRole,
      dueAt: created.dueAt?.toISOString() ?? null,
      status: created.status,
      createdAt: created.createdAt.toISOString(),
    };
  }

  async createInternalNote(id: string, input: CreateCaseInternalNoteDto) {
    this.assertDb();
    await this.requireDbCase(id);

    const created = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const note = await tx.caseInternalNote.create({
          data: {
            caseId: id,
            authorName: input.authorName,
            authorRole: input.authorRole as any,
            body: input.body,
          },
        });

        await tx.case.update({
          where: { id },
          data: { updatedAt: new Date() },
        });

        return note;
      }),
    );

    if (!created) {
      throw new ServiceUnavailableException("Failed to create note.");
    }
    return {
      id: created.id,
      authorName: created.authorName,
      authorRole: created.authorRole,
      body: created.body,
      createdAt: created.createdAt.toISOString(),
    };
  }

  async createTimelineEvent(id: string, input: CreateCaseTimelineEventDto) {
    this.assertDb();
    const currentCase = await this.requireDbCase(id);

    const created = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const event = await tx.caseTimelineEvent.create({
          data: {
            caseId: id,
            status: input.status ?? currentCase.status ?? CaseStatus.Submitted,
            title: input.title,
            description: input.description,
          },
        });

        await tx.case.update({
          where: { id },
          data: { updatedAt: new Date() },
        });

        return event;
      }),
    );

    if (!created) {
      throw new ServiceUnavailableException("Failed to create timeline event.");
    }
    const refreshed = await this.prismaService.execute((prisma) =>
      prisma.case.findUnique({ where: { id }, include: CASE_INCLUDE }),
    );
    if (refreshed) {
      this.broadcastCaseUpdate(
        id,
        this.mapDbCase(refreshed) as Record<string, unknown>,
      );
    }
    return {
      id: created.id,
      title: created.title,
      description: created.description,
      status: created.status as CaseStatus,
      createdAt: created.createdAt.toISOString(),
    };
  }

  createNotificationTimelineEvent(
    id: string,
    title: string,
    description: string,
  ) {
    return this.createTimelineEvent(id, { title, description });
  }

  /**
   * Projection d'un dossier. Par défaut = projection ÉTUDIANT (sans notes
   * internes, téléphones conseiller ni champs commerciaux) : la room
   * Socket.IO `caseUpdated` est partagée avec l'étudiant, et un oubli d'option
   * doit fuir le moins possible. Les lectures staff passent
   * `includeInternal: true` explicitement.
   */
  private mapDbCase(c: any, opts: { includeInternal?: boolean } = {}) {
    const includeInternal = opts.includeInternal ?? false;
    return {
      id: c.id,
      userId: c.userId,
      referenceCode: c.referenceCode,
      studentName: c.user?.fullName ?? "Unknown",
      studentEmail: c.user?.email ?? "",
      preferredLanguage: c.user?.preferredLanguage ?? "fr",
      source: c.source ?? "mobile_app",
      requestedCountryId: c.requestedCountryId ?? null,
      // « Mes 10 bourses » : la bourse accompagnée (lecture seule, élève,
      // conseiller et admin).
      scholarshipId: c.scholarshipId ?? null,
      // Son nom et ses liens officiels, pour la file staff seulement (l'app
      // affiche le nom tiré de son propre run). Absent de la réponse élève et
      // de la diffusion Socket.IO `caseUpdated`.
      ...(includeInternal
        ? {
            scholarship: c.scholarship
              ? {
                  id: c.scholarship.id,
                  nameFr: c.scholarship.nameFr,
                  nameEn: c.scholarship.nameEn,
                  sourceUrl: c.scholarship.sourceUrl ?? null,
                  applicationUrl: c.scholarship.applicationUrl ?? null,
                }
              : null,
          }
        : {}),
      type: c.type,
      title: c.title,
      status: c.status as CaseStatus,
      nextStepTitle: c.nextStepTitle,
      nextStepDescription: c.nextStepDescription,
      assignedAdvisorName: c.assignedAdvisorName,
      // Counsellor contact details are internal-only: students and parents
      // must reach KPB through the official WhatsApp line, so legacy rows that
      // still carry personal numbers are not exposed on student-facing reads.
      assignedAdvisorPhone: includeInternal ? c.assignedAdvisorPhone : null,
      assignedAdvisorWhatsapp: includeInternal
        ? c.assignedAdvisorWhatsapp
        : null,
      // Marketplace counsellor id (Track B) — used by the app to attribute an
      // admission-milestone review to the right counsellor (KPB-75).
      counsellorId: c.counsellorId ?? null,
      createdAt: c.createdAt.toISOString(),
      updatedAt: c.updatedAt.toISOString(),
      description: c.description,
      contextLabel: c.contextLabel,
      preferredContactMethod: c.preferredContactMethod ?? "in_app",
      scheduledAt: c.scheduledAt?.toISOString() ?? null,
      // Whether the student has opted into sharing this case with a linked
      // parent. Surfaced so the app can render (and toggle) the share switch.
      parentCanView: c.parentCanView ?? false,
      leadTag: includeInternal ? (c.leadTag ?? null) : null,
      discussionMotive: includeInternal ? (c.discussionMotive ?? null) : null,
      lastCommercialInteractionAt: includeInternal
        ? (c.lastCommercialInteractionAt?.toISOString() ?? null)
        : null,
      documentRequests: (c.documents ?? []).map((d: any) => ({
        id: d.id,
        title: d.title,
        isProvided: d.isProvided,
        hasFile: Boolean(d.fileUrl),
        downloadPath: d.fileUrl
          ? `/cases/${c.id}/documents/${d.id}/file`
          : null,
        uploadedAt: d.uploadedAt?.toISOString(),
      })),
      tasks: (c.tasks ?? []).map((t: any) => ({
        id: t.id,
        title: t.title,
        assigneeName: t.assigneeName,
        assigneeRole: t.assigneeRole,
        dueAt: t.dueAt?.toISOString() ?? null,
        status: t.status,
        createdAt: t.createdAt.toISOString(),
      })),
      internalNotes: includeInternal
        ? (c.internalNotes ?? []).map((n: any) => ({
            id: n.id,
            authorName: n.authorName,
            authorRole: n.authorRole,
            body: n.body,
            createdAt: n.createdAt.toISOString(),
          }))
        : [],
      timeline: (c.timelineEvents ?? []).map((e: any) => ({
        id: e.id,
        title: e.title,
        description: e.description,
        status: e.status as CaseStatus,
        createdAt: e.createdAt.toISOString(),
      })),
      messages: (c.messages ?? []).map((m: any) => ({
        id: m.id,
        senderName: m.senderName,
        senderRole: m.senderRole,
        body: m.body,
        createdAt: m.createdAt.toISOString(),
        clientMessageId: m.clientMessageId ?? null,
      })),
    };
  }
}
