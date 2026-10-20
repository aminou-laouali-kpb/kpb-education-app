import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  Prisma,
  type PrismaClient,
  type ReferralCampaign,
  type ReferralCampaignParticipant,
  type ReferralCampaignReferral,
} from '@prisma/client';
import { randomUUID } from 'node:crypto';

import type { AdminSessionUser } from '../../auth/auth.service';
import { csvRow } from '../../etudes-en-france/eef-interest-csv';
import { PrismaService } from '../../prisma/prisma.service';
import { publicNameFromFullName, publicNameIssue } from '../referral-code';
import {
  type CampaignAction,
  type CampaignPrize,
  type CampaignStatus,
  DEFAULT_QUALIFICATION_RULE,
  editableFields,
  isEligiblePlace,
  isPubliclyVisible,
  nextStatus,
  parsePrizes,
  parseQualificationRule,
  placeKey,
  unrankableReason,
} from './campaign-rules';
import {
  type ComputedReferral,
  computeQualification,
  type QualificationSignal,
} from './campaign-qualification';
import {
  campaignDaysFromWindow,
  campaignPhase,
  campaignWindowFromDays,
  DEFAULT_CAMPAIGN_TIME_ZONE,
  isValidTimeZone,
} from './campaign-time';
import type {
  CreateReferralCampaignDto,
  EnrollParticipantDto,
  ForfeitPrizeDto,
  RecordPayoutDto,
  UpdateParticipantDto,
  UpdateReferralCampaignDto,
} from './dto/referral-campaign.dto';
import { podiumAssignments, reassignAfterForfeit } from './prize-forfeit';
import { isMinorAt, PROFILE_COMPLETION_SELECT } from './profile-completion';

export type CampaignActor = Pick<AdminSessionUser, 'id' | 'role'>;

export interface RecomputeReport {
  campaignId: string;
  skipped?: 'running' | 'closed';
  created: number;
  updated: number;
  deleted: number;
  unchanged: number;
  participantsUpdated: number;
  profilesStamped: number;
  computedAt: string;
}

/** Une ligne publique du classement : nom public, ville, nombre, rang. RIEN d'autre. */
export interface PublicLeaderboardEntry {
  rank: number | null;
  name: string;
  city: string;
  qualified: number;
}

export interface PublicLeaderboard {
  campaign: {
    slug: string;
    nameFr: string;
    nameEn: string;
    status: CampaignStatus;
    phase: 'upcoming' | 'running' | 'ended';
    timeZone: string;
    startDate: string;
    endDate: string;
    startsAt: string;
    endsAt: string;
    prizes: { rank: number; amountFcfa: number }[];
    rulesUrl: string | null;
    provisional: boolean;
    updatedAt: string | null;
  };
  serverTime: string;
  cities: string[];
  entries: PublicLeaderboardEntry[];
  /**
   * Les lauréats EFFECTIFS, campagne close seulement (résultats définitifs) :
   * un prix déclaré forfait apparaît chez celui qui l'a reçu. Nom public,
   * ville, rang du prix et montant — rien d'autre. Vide avant la clôture.
   */
  winners: PublicWinner[];
}

/** Un lauréat effectif : rang du PRIX (pas du classement), nom public, ville, montant. */
export interface PublicWinner {
  prizeRank: number;
  amountFcfa: number;
  name: string;
  city: string;
}

const AUDIT_PURPOSE = 'referral_campaign';
const PUBLIC_CACHE_TTL_MS = 30_000;

type ParticipantWithAmbassador = ReferralCampaignParticipant & {
  ambassador: {
    id: string;
    code: string;
    userProfileId: string;
    approvedAt: Date | null;
  };
};

/**
 * Compétition ambassadeurs : comptage, administration, classement public.
 *
 * Le comptage (`recompute`) est un calcul pur (`computeQualification`) appliqué
 * à des lectures, dont seules les DIFFÉRENCES sont écrites : rejouer sans que
 * rien n'ait changé n'écrit aucune ligne de filleul ni de participant. Chaque
 * action de l'équipe écrit un `AdminAuditEvent` dans la même transaction.
 */
@Injectable()
export class ReferralCampaignService {
  private readonly logger = new Logger(ReferralCampaignService.name);
  private readonly running = new Set<string>();
  private readonly publicCache = new Map<string, { at: number; payload: PublicLeaderboard }>();

  constructor(private readonly prisma: PrismaService) {}

  /**
   * `execute` rend null sans base (mode démo) — ET quand l'opération elle-même
   * rend null (`findUnique` sans résultat). Le résultat est donc emballé pour
   * distinguer les deux.
   */
  private async db<T>(fn: (db: PrismaClient) => Promise<T>): Promise<T> {
    const out = await this.prisma.execute(async (client) => ({ value: await fn(client) }));
    if (out === null) throw new BadRequestException('Base de données indisponible.');
    return out.value;
  }

  // ── Comptage ──────────────────────────────────────────────────────────────

  async recompute(campaignId: string, now: Date = new Date()): Promise<RecomputeReport> {
    const empty: RecomputeReport = {
      campaignId,
      created: 0,
      updated: 0,
      deleted: 0,
      unchanged: 0,
      participantsUpdated: 0,
      profilesStamped: 0,
      computedAt: now.toISOString(),
    };
    if (this.running.has(campaignId)) return { ...empty, skipped: 'running' };
    this.running.add(campaignId);
    try {
      return await this.db(async (db) => {
        const campaign = await db.referralCampaign.findUnique({ where: { id: campaignId } });
        if (!campaign) throw new NotFoundException('Campagne introuvable.');
        // Close = résultats définitifs : plus aucun recalcul.
        if (campaign.status === 'closed') return { ...empty, skipped: 'closed' as const };

        const participants = (await db.referralCampaignParticipant.findMany({
          where: { campaignId },
          include: {
            ambassador: {
              select: { id: true, code: true, userProfileId: true, approvedAt: true },
            },
          },
        })) as ParticipantWithAmbassador[];
        const profileIds = participants.map((p) => p.ambassador.userProfileId);
        const attributions = profileIds.length
          ? await db.referral.findMany({
              where: {
                referrerId: { in: profileIds },
                createdAt: { gte: campaign.startsAt, lt: campaign.endsAt },
              },
              select: { referrerId: true, refereeProfileId: true, createdAt: true },
            })
          : [];
        const refereeIds = attributions.map((a) => a.refereeProfileId);
        const [referees, signals, existing] = await Promise.all([
          refereeIds.length
            ? db.userProfile.findMany({
                where: { id: { in: refereeIds } },
                select: {
                  id: true,
                  email: true,
                  supabaseUserId: true,
                  createdAt: true,
                  profileCompletedAt: true,
                  ...PROFILE_COMPLETION_SELECT,
                },
              })
            : Promise.resolve([]),
          refereeIds.length
            ? db.referralAttributionSignal.findMany({
                where: { refereeProfileId: { in: refereeIds } },
              })
            : Promise.resolve([]),
          db.referralCampaignReferral.findMany({ where: { campaignId } }),
        ]);

        const decisions = new Map<string, 'validated' | 'excluded'>();
        for (const row of existing) {
          if (row.adminDecision === 'validated' || row.adminDecision === 'excluded') {
            decisions.set(row.refereeProfileId, row.adminDecision);
          }
        }
        const out = computeQualification({
          window: { startsAt: campaign.startsAt, endsAt: campaign.endsAt },
          rule: parseQualificationRule(campaign.qualificationRule),
          now,
          participants: participants.map((p) => ({
            id: p.id,
            profileId: p.ambassador.userProfileId,
            status: p.status,
            minorStatus: p.minorStatus,
            parentalAuthStatus: p.parentalAuthStatus,
            ambassadorApproved: p.ambassador.approvedAt !== null,
            enrolledAt: p.enrolledAt,
          })),
          attributions: attributions.map((a) => ({
            refereeProfileId: a.refereeProfileId,
            referrerProfileId: a.referrerId,
            attachedAt: a.createdAt,
          })),
          referees: new Map(referees.map((r) => [r.id, r])),
          signals: new Map<string, QualificationSignal>(
            signals.map((s) => [s.refereeProfileId, s]),
          ),
          decisions,
        });

        const report = { ...empty };
        const existingByReferee = new Map(existing.map((e) => [e.refereeProfileId, e]));
        const toCreate: ComputedReferral[] = [];
        const toUpdate: { id: string; row: ComputedReferral }[] = [];
        for (const row of out.referrals) {
          const prev = existingByReferee.get(row.refereeProfileId);
          if (!prev) toCreate.push(row);
          else if (referralChanged(prev, row)) toUpdate.push({ id: prev.id, row });
          else report.unchanged += 1;
          existingByReferee.delete(row.refereeProfileId);
        }
        const toDelete = [...existingByReferee.values()].map((e) => e.id);
        const participantUpdates = participants
          .map((p) => ({ p, c: out.participants.find((c) => c.id === p.id)! }))
          .filter(({ p, c }) => participantChanged(p, c));

        await db.$transaction(
          async (tx) => {
            if (out.completedNow.length) {
              const stamped = await tx.userProfile.updateMany({
                where: { id: { in: out.completedNow }, profileCompletedAt: null },
                data: { profileCompletedAt: now },
              });
              report.profilesStamped = stamped.count;
            }
            if (toCreate.length) {
              await tx.referralCampaignReferral.createMany({
                data: toCreate.map((row) => ({ campaignId, ...referralData(row) })),
                skipDuplicates: true,
              });
              report.created = toCreate.length;
            }
            for (const { id, row } of toUpdate) {
              await tx.referralCampaignReferral.update({ where: { id }, data: referralData(row) });
            }
            report.updated = toUpdate.length;
            if (toDelete.length) {
              await tx.referralCampaignReferral.deleteMany({ where: { id: { in: toDelete } } });
              report.deleted = toDelete.length;
            }
            for (const { p, c } of participantUpdates) {
              await tx.referralCampaignParticipant.update({
                where: { id: p.id },
                data: {
                  qualifiedCount: c.qualifiedCount,
                  flaggedCount: c.flaggedCount,
                  pendingCount: c.pendingCount,
                  excludedCount: c.excludedCount,
                  reachedCountAt: c.reachedCountAt,
                  rank: c.rank,
                },
              });
            }
            report.participantsUpdated = participantUpdates.length;
            await tx.referralCampaign.update({
              where: { id: campaignId },
              data: { lastComputedAt: now },
            });
          },
          { timeout: 60_000 },
        );
        this.invalidatePublic(campaign.slug);
        return report;
      });
    } finally {
      this.running.delete(campaignId);
    }
  }

  /**
   * Tâche planifiée : recalcule les campagnes `live` ; une campagne dont la
   * fenêtre est passée reçoit un dernier calcul puis est GELÉE (`frozen`).
   */
  async recomputeLive(now: Date = new Date()): Promise<RecomputeReport[]> {
    const live = await this.db((db) =>
      db.referralCampaign.findMany({ where: { status: 'live' }, select: { id: true, endsAt: true } }),
    );
    const reports: RecomputeReport[] = [];
    for (const c of live) {
      try {
        reports.push(await this.recompute(c.id, now));
        if (now.getTime() >= c.endsAt.getTime()) {
          await this.autoFreeze(c.id, now);
        }
      } catch (error) {
        this.logger.error(
          `Recalcul de la campagne ${c.id} en échec : ${error instanceof Error ? error.message : 'erreur'}`,
        );
      }
    }
    return reports;
  }

  private async autoFreeze(campaignId: string, now: Date): Promise<void> {
    await this.db((db) =>
      db.$transaction(async (tx) => {
        const res = await tx.referralCampaign.updateMany({
          where: { id: campaignId, status: 'live' },
          data: { status: 'frozen', frozenAt: now },
        });
        if (res.count === 0) return;
        await this.audit(tx, {
          action: 'referral_campaign.frozen_auto',
          entityType: 'ReferralCampaign',
          entityId: campaignId,
          actor: null,
          requestId: randomUUID(),
          changes: { status: { from: 'live', to: 'frozen' } },
        });
      }),
    );
  }

  /** Purge des empreintes anti-fraude au-delà de la durée de conservation. */
  async purgeSignals(now: Date = new Date()): Promise<number> {
    const days = signalRetentionDays();
    const res = await this.db((db) =>
      db.referralAttributionSignal.deleteMany({
        where: { createdAt: { lt: new Date(now.getTime() - days * 86_400_000) } },
      }),
    );
    return res.count;
  }

  // ── Campagnes (admin) ─────────────────────────────────────────────────────

  async list() {
    const rows = await this.db((db) =>
      db.referralCampaign.findMany({
        orderBy: { startsAt: 'desc' },
        include: { _count: { select: { participants: true, referrals: true } } },
      }),
    );
    return { items: rows.map((c) => ({ ...this.presentCampaign(c), counts: c._count })) };
  }

  async get(id: string) {
    const c = await this.db((db) => db.referralCampaign.findUnique({ where: { id } }));
    if (!c) throw new NotFoundException('Campagne introuvable.');
    return this.presentCampaign(c);
  }

  async create(dto: CreateReferralCampaignDto, actor: CampaignActor, requestId: string) {
    const timeZone = dto.timeZone ?? DEFAULT_CAMPAIGN_TIME_ZONE;
    const window = this.windowOrThrow(dto.startDate, dto.endDate, timeZone);
    const prizes = this.prizesOrThrow(dto.prizes ?? []);
    const rule = parseQualificationRule(dto.qualificationRule ?? {});
    try {
      const created = await this.db((db) =>
        db.$transaction(async (tx) => {
          const c = await tx.referralCampaign.create({
            data: {
              slug: dto.slug,
              nameFr: dto.nameFr.trim(),
              nameEn: dto.nameEn.trim(),
              timeZone,
              startsAt: window.startsAt,
              endsAt: window.endsAt,
              prizes: prizes as unknown as Prisma.InputJsonValue,
              rulesText: dto.rulesText?.trim() || null,
              rulesUrl: dto.rulesUrl?.trim() || null,
              eligibleCities: cleanList(dto.eligibleCities),
              eligibleCountries: cleanList(dto.eligibleCountries),
              qualificationRule: rule as unknown as Prisma.InputJsonValue,
              createdByAdminId: actor.id,
            },
          });
          await this.audit(tx, {
            action: 'referral_campaign.created',
            entityType: 'ReferralCampaign',
            entityId: c.id,
            actor,
            requestId,
            changes: { slug: c.slug, startsAt: c.startsAt.toISOString(), endsAt: c.endsAt.toISOString() },
          });
          return c;
        }),
      );
      return this.presentCampaign(created);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Ce slug est déjà utilisé.');
      }
      throw error;
    }
  }

  async update(id: string, dto: UpdateReferralCampaignDto, actor: CampaignActor, requestId: string) {
    const current = await this.db((db) => db.referralCampaign.findUnique({ where: { id } }));
    if (!current) throw new NotFoundException('Campagne introuvable.');
    const allowed = editableFields(current.status as CampaignStatus);
    const sent = Object.keys(dto).filter((k) => (dto as Record<string, unknown>)[k] !== undefined);
    const refused = sent.filter((k) => !allowed.includes(k));
    if (refused.length) {
      throw new BadRequestException({
        code: 'campaign_field_locked',
        message: `Champs figés au statut « ${current.status} » : ${refused.join(', ')}.`,
      });
    }
    const data: Prisma.ReferralCampaignUpdateInput = {};
    if (dto.nameFr !== undefined) data.nameFr = dto.nameFr.trim();
    if (dto.nameEn !== undefined) data.nameEn = dto.nameEn.trim();
    if (dto.rulesText !== undefined) data.rulesText = dto.rulesText.trim() || null;
    if (dto.rulesUrl !== undefined) {
      const url = dto.rulesUrl.trim();
      if (url && !/^https:\/\/[^\s]+$/.test(url)) {
        throw new BadRequestException('rulesUrl doit être une adresse https.');
      }
      data.rulesUrl = url || null;
    }
    if (dto.startDate !== undefined || dto.endDate !== undefined || dto.timeZone !== undefined) {
      const tz = dto.timeZone ?? current.timeZone;
      const days = campaignDaysFromWindow(current, current.timeZone);
      const window = this.windowOrThrow(dto.startDate ?? days.startDate, dto.endDate ?? days.endDate, tz);
      data.timeZone = tz;
      data.startsAt = window.startsAt;
      data.endsAt = window.endsAt;
    }
    if (dto.prizes !== undefined) {
      data.prizes = this.prizesOrThrow(dto.prizes) as unknown as Prisma.InputJsonValue;
    }
    if (dto.eligibleCities !== undefined) data.eligibleCities = cleanList(dto.eligibleCities);
    if (dto.eligibleCountries !== undefined) data.eligibleCountries = cleanList(dto.eligibleCountries);
    if (dto.qualificationRule !== undefined) {
      data.qualificationRule = parseQualificationRule(dto.qualificationRule) as unknown as Prisma.InputJsonValue;
    }
    const updated = await this.db((db) =>
      db.$transaction(async (tx) => {
        const c = await tx.referralCampaign.update({ where: { id }, data });
        await this.audit(tx, {
          action: 'referral_campaign.updated',
          entityType: 'ReferralCampaign',
          entityId: id,
          actor,
          requestId,
          changes: { fields: sent },
        });
        return c;
      }),
    );
    this.invalidatePublic(updated.slug);
    return this.presentCampaign(updated);
  }

  async transition(id: string, action: CampaignAction, actor: CampaignActor, requestId: string) {
    const current = await this.db((db) => db.referralCampaign.findUnique({ where: { id } }));
    if (!current) throw new NotFoundException('Campagne introuvable.');
    const to = nextStatus(current.status as CampaignStatus, action);
    if (!to) {
      throw new ConflictException({
        code: 'campaign_transition_refused',
        message: `Action « ${action} » impossible au statut « ${current.status} ».`,
      });
    }
    const now = new Date();
    if (action === 'launch') {
      const prizes = parsePrizes(current.prizes);
      if (!prizes || prizes.length === 0) {
        throw new BadRequestException('Définis au moins un prix avant de lancer.');
      }
    }
    if (action === 'unfreeze' && current.podiumValidatedAt) {
      throw new ConflictException('Podium déjà validé : la campagne ne peut plus être rouverte.');
    }
    if (action === 'close' && !current.podiumValidatedAt) {
      throw new ConflictException('Valide le podium avant de clore.');
    }
    if (action === 'validate_podium') {
      return this.validatePodium(current, actor, requestId, now);
    }
    const data: Prisma.ReferralCampaignUpdateInput = { status: to };
    if (action === 'launch') data.launchedAt = now;
    if (action === 'freeze') data.frozenAt = now;
    if (action === 'unfreeze') data.frozenAt = null;
    if (action === 'close') data.closedAt = now;
    // Gel : un dernier calcul AVANT de figer.
    if (action === 'freeze') await this.recompute(id, now);
    const updated = await this.db((db) =>
      db.$transaction(async (tx) => {
        const res = await tx.referralCampaign.updateMany({
          where: { id, status: current.status },
          data: data as Prisma.ReferralCampaignUpdateManyMutationInput,
        });
        if (res.count === 0) throw new ConflictException('La campagne a changé entre-temps.');
        await this.audit(tx, {
          action: `referral_campaign.${action}`,
          entityType: 'ReferralCampaign',
          entityId: id,
          actor,
          requestId,
          changes: { status: { from: current.status, to } },
        });
        return tx.referralCampaign.findUniqueOrThrow({ where: { id } });
      }),
    );
    this.invalidatePublic(updated.slug);
    return this.presentCampaign(updated);
  }

  /**
   * Validation du podium (campagne gelée) : un dernier calcul, puis une ligne
   * de prix par rang primé, figée avec le nom public du lauréat. Refusé dès
   * qu'un versement a été noté.
   */
  private async validatePodium(
    current: ReferralCampaign,
    actor: CampaignActor,
    requestId: string,
    now: Date,
  ) {
    const prizes = parsePrizes(current.prizes) ?? [];
    await this.recompute(current.id, now);
    const updated = await this.db((db) =>
      db.$transaction(async (tx) => {
        const paid = await tx.referralCampaignPrizeAward.count({
          where: { campaignId: current.id, payoutStatus: 'paid' },
        });
        if (paid > 0) throw new ConflictException('Un versement est déjà noté : podium figé.');
        // Un participant déjà déclaré forfait ne reprend pas un prix à la
        // revalidation : le suivant classé le reçoit (`podiumAssignments`).
        const forfeited = new Set(
          (
            await tx.referralCampaignPrizeForfeit.findMany({
              where: { campaignId: current.id },
              select: { participantId: true },
            })
          )
            .map((f) => f.participantId)
            .filter((id): id is string => id !== null),
        );
        const ranked = await tx.referralCampaignParticipant.findMany({
          where: { campaignId: current.id, rank: { not: null } },
          orderBy: { rank: 'asc' },
          take: prizes.length + forfeited.size,
        });
        await tx.referralCampaignPrizeAward.deleteMany({ where: { campaignId: current.id } });
        const byId = new Map(ranked.map((r) => [r.id, r]));
        const assignment = new Map(
          podiumAssignments(
            prizes.map((p) => p.rank),
            forfeited,
            ranked.map((r) => ({ id: r.id, rank: r.rank! })),
          ).map((a) => [a.rank, a.participantId]),
        );
        const awards = prizes
          .map((prize) => {
            const id = assignment.get(prize.rank);
            return { prize, winner: id ? byId.get(id) : undefined };
          })
          .filter((a) => a.winner);
        if (awards.length) {
          await tx.referralCampaignPrizeAward.createMany({
            data: awards.map(({ prize, winner }) => ({
              campaignId: current.id,
              rank: prize.rank,
              participantId: winner!.id,
              publicNameSnapshot: displayName(winner!.publicName, winner!.city),
              amountFcfa: prize.amountFcfa,
              recipient: winner!.minorStatus === 'minor' ? 'parent' : 'ambassador',
            })),
          });
        }
        await tx.referralCampaign.update({
          where: { id: current.id },
          data: { podiumValidatedAt: now, podiumValidatedByAdminId: actor.id },
        });
        await this.audit(tx, {
          action: 'referral_campaign.validate_podium',
          entityType: 'ReferralCampaign',
          entityId: current.id,
          actor,
          requestId,
          changes: {
            podium: awards.map(({ prize, winner }) => ({
              rank: prize.rank,
              participantId: winner!.id,
              qualified: winner!.qualifiedCount,
              amountFcfa: prize.amountFcfa,
            })),
          },
        });
        return tx.referralCampaign.findUniqueOrThrow({ where: { id: current.id } });
      }),
    );
    this.invalidatePublic(updated.slug);
    return this.presentCampaign(updated);
  }

  // ── Participants ──────────────────────────────────────────────────────────

  async enroll(campaignId: string, dto: EnrollParticipantDto, actor: CampaignActor, requestId: string) {
    const campaign = await this.campaignOrThrow(campaignId);
    if (campaign.status === 'frozen' || campaign.status === 'closed') {
      throw new ConflictException('Inscriptions fermées pour cette campagne.');
    }
    if (!dto.ambassadorId && !dto.email) {
      throw new BadRequestException('Indique l’ambassadeur (id) ou l’e-mail de son compte.');
    }
    const participant = await this.db(async (db) => {
      const ambassador = dto.ambassadorId
        ? await db.ambassador.findUnique({ where: { id: dto.ambassadorId } })
        : await db.ambassador.findFirst({
            where: { userProfileId: (await db.userProfile.findUnique({
              where: { email: dto.email!.trim().toLowerCase() },
              select: { id: true },
            }))?.id ?? '__none__' },
          });
      if (!ambassador) {
        throw new NotFoundException('Ambassadeur introuvable : active-le d’abord (Ambassadeurs).');
      }
      if (!ambassador.approvedAt) {
        throw new ConflictException('Cet ambassadeur n’est pas activé par l’équipe.');
      }
      const profile = await db.userProfile.findUnique({
        where: { id: ambassador.userProfileId },
        select: { fullName: true, birthDate: true, countryOfResidence: true },
      });
      const city = (dto.city ?? ambassador.city ?? '').trim();
      const country = (dto.country ?? profile?.countryOfResidence ?? '').trim();
      if (!isEligiblePlace(city, campaign.eligibleCities)) {
        throw new BadRequestException(`Ville non éligible pour cette campagne : « ${city || '—'} ».`);
      }
      if (!isEligiblePlace(country, campaign.eligibleCountries)) {
        throw new BadRequestException(`Pays non éligible pour cette campagne : « ${country || '—'} ».`);
      }
      const publicName = (dto.publicName ?? publicNameFromFullName(profile?.fullName ?? ambassador.displayName)).trim();
      const issue = publicNameIssue(publicName);
      if (issue) throw new BadRequestException({ code: issue, message: 'Nom public invalide.' });
      const minorStatus =
        dto.minorStatus ??
        (profile?.birthDate ? (isMinorAt(profile.birthDate, campaign.startsAt) ? 'minor' : 'adult') : 'unknown');
      try {
        return await db.$transaction(async (tx) => {
          const p = await tx.referralCampaignParticipant.create({
            data: {
              campaignId,
              ambassadorId: ambassador.id,
              publicName,
              city,
              country,
              minorStatus,
              parentalAuthStatus: minorStatus === 'minor' ? 'pending' : 'not_required',
              enrolledByAdminId: actor.id,
            },
          });
          await this.audit(tx, {
            action: 'referral_campaign.participant_enrolled',
            entityType: 'ReferralCampaignParticipant',
            entityId: p.id,
            actor,
            requestId,
            changes: { campaignId, ambassadorId: ambassador.id, publicName, city, minorStatus },
          });
          return p;
        });
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
          throw new ConflictException('Déjà inscrit à cette campagne.');
        }
        throw error;
      }
    });
    await this.recompute(campaignId);
    return participant;
  }

  async updateParticipant(
    campaignId: string,
    participantId: string,
    dto: UpdateParticipantDto,
    actor: CampaignActor,
    requestId: string,
  ) {
    const campaign = await this.campaignOrThrow(campaignId);
    if (campaign.status === 'closed') throw new ConflictException('Campagne close.');
    const current = await this.db((db) =>
      db.referralCampaignParticipant.findFirst({ where: { id: participantId, campaignId } }),
    );
    if (!current) throw new NotFoundException('Participant introuvable.');
    const data: Prisma.ReferralCampaignParticipantUpdateInput = {};
    if (dto.publicName !== undefined) {
      const issue = publicNameIssue(dto.publicName);
      if (issue) throw new BadRequestException({ code: issue, message: 'Nom public invalide.' });
      data.publicName = dto.publicName.trim();
    }
    if (dto.city !== undefined) {
      if (!isEligiblePlace(dto.city, campaign.eligibleCities)) {
        throw new BadRequestException(`Ville non éligible : « ${dto.city} ».`);
      }
      data.city = dto.city.trim();
    }
    if (dto.country !== undefined) {
      if (!isEligiblePlace(dto.country, campaign.eligibleCountries)) {
        throw new BadRequestException(`Pays non éligible : « ${dto.country} ».`);
      }
      data.country = dto.country.trim();
    }
    if (dto.status !== undefined) {
      if (dto.status !== 'active' && !dto.statusReason?.trim()) {
        throw new BadRequestException('Un motif est requis pour retirer ou disqualifier.');
      }
      data.status = dto.status;
      data.statusReason = dto.status === 'active' ? null : dto.statusReason!.trim();
    }
    const minor = dto.minorStatus ?? current.minorStatus;
    if (dto.minorStatus !== undefined) data.minorStatus = dto.minorStatus;
    let parental = dto.parentalAuthStatus ?? current.parentalAuthStatus;
    if (minor === 'adult') parental = 'not_required';
    else if (parental === 'not_required') parental = 'pending';
    if (parental !== current.parentalAuthStatus) data.parentalAuthStatus = parental;
    if (parental === 'verified' && current.parentalAuthStatus !== 'verified') {
      data.parentalAuthVerifiedAt = new Date();
      data.parentalAuthVerifiedByAdminId = actor.id;
    } else if (parental !== 'verified' && current.parentalAuthStatus === 'verified') {
      data.parentalAuthVerifiedAt = null;
      data.parentalAuthVerifiedByAdminId = null;
    }
    if (dto.parentalAuthNote !== undefined) data.parentalAuthNote = dto.parentalAuthNote.trim() || null;

    const updated = await this.db((db) =>
      db.$transaction(async (tx) => {
        const p = await tx.referralCampaignParticipant.update({ where: { id: participantId }, data });
        await this.audit(tx, {
          action: 'referral_campaign.participant_updated',
          entityType: 'ReferralCampaignParticipant',
          entityId: participantId,
          actor,
          requestId,
          reasonCode: dto.statusReason?.trim() || undefined,
          changes: jsonSafe(data),
        });
        return p;
      }),
    );
    await this.recompute(campaignId);
    return updated;
  }

  /** Classement complet pour l'équipe (y compris non classables), filtres ville/pays. */
  async adminLeaderboard(campaignId: string, filters: { city?: string; country?: string } = {}) {
    const campaign = await this.campaignOrThrow(campaignId);
    const rows = await this.db((db) =>
      db.referralCampaignParticipant.findMany({
        where: { campaignId },
        include: {
          ambassador: {
            select: { id: true, code: true, userProfileId: true, approvedAt: true, city: true },
          },
        },
      }),
    );
    const profiles = await this.db((db) =>
      db.userProfile.findMany({
        where: { id: { in: rows.map((r) => r.ambassador.userProfileId) } },
        select: { id: true, fullName: true, email: true, referralCode: true },
      }),
    );
    const byId = new Map(profiles.map((p) => [p.id, p]));
    const items = rows
      .filter((r) => !filters.city || placeKey(r.city) === placeKey(filters.city))
      .filter((r) => !filters.country || placeKey(r.country) === placeKey(filters.country))
      .map((r) => {
        const profile = byId.get(r.ambassador.userProfileId);
        return {
          id: r.id,
          ambassadorId: r.ambassador.id,
          ambassadorCode: r.ambassador.code,
          personalCode: profile?.referralCode ?? null,
          fullName: profile?.fullName ?? '',
          email: profile?.email ?? '',
          publicName: r.publicName,
          displayName: displayName(r.publicName, r.city),
          city: r.city,
          country: r.country,
          status: r.status,
          statusReason: r.statusReason,
          minorStatus: r.minorStatus,
          parentalAuthStatus: r.parentalAuthStatus,
          parentalAuthVerifiedAt: r.parentalAuthVerifiedAt,
          parentalAuthVerifiedByAdminId: r.parentalAuthVerifiedByAdminId,
          parentalAuthNote: r.parentalAuthNote,
          qualifiedCount: r.qualifiedCount,
          flaggedCount: r.flaggedCount,
          pendingCount: r.pendingCount,
          excludedCount: r.excludedCount,
          reachedCountAt: r.reachedCountAt,
          rank: r.rank,
          unrankableReason: unrankableReason({
            status: r.status,
            minorStatus: r.minorStatus,
            parentalAuthStatus: r.parentalAuthStatus,
            ambassadorApproved: r.ambassador.approvedAt !== null,
          }),
          enrolledAt: r.enrolledAt,
        };
      })
      .sort(
        (a, b) =>
          (a.rank ?? Number.MAX_SAFE_INTEGER) - (b.rank ?? Number.MAX_SAFE_INTEGER) ||
          b.qualifiedCount - a.qualifiedCount ||
          a.publicName.localeCompare(b.publicName),
      );
    return {
      campaign: this.presentCampaign(campaign),
      cities: [...new Set(rows.map((r) => r.city).filter(Boolean))].sort(),
      countries: [...new Set(rows.map((r) => r.country).filter(Boolean))].sort(),
      items,
    };
  }

  /** Les filleuls d'un participant, avec leur statut et leurs signaux. */
  async participantReferrals(campaignId: string, participantId: string) {
    const rows = await this.db((db) =>
      db.referralCampaignReferral.findMany({
        where: { campaignId, participantId },
        orderBy: { attachedAt: 'asc' },
      }),
    );
    const profiles = await this.db((db) =>
      db.userProfile.findMany({
        where: { id: { in: rows.map((r) => r.refereeProfileId) } },
        select: { id: true, fullName: true, email: true },
      }),
    );
    const byId = new Map(profiles.map((p) => [p.id, p]));
    return {
      items: rows.map((r) => ({
        id: r.id,
        refereeName: byId.get(r.refereeProfileId)?.fullName ?? '',
        refereeEmail: byId.get(r.refereeProfileId)?.email ?? '',
        attachedAt: r.attachedAt,
        accountCreatedAt: r.accountCreatedAt,
        profileCompletedAt: r.profileCompletedAt,
        qualifiedAt: r.qualifiedAt,
        status: r.status,
        flags: r.flags,
        adminDecision: r.adminDecision,
        adminDecisionReason: r.adminDecisionReason,
        adminDecisionAt: r.adminDecisionAt,
      })),
    };
  }

  /** Validation ou exclusion manuelle d'un filleul (motif requis pour exclure). */
  async decide(
    campaignId: string,
    referralId: string,
    decision: 'validated' | 'excluded' | 'clear',
    reason: string | undefined,
    actor: CampaignActor,
    requestId: string,
  ) {
    const campaign = await this.campaignOrThrow(campaignId);
    if (campaign.status === 'closed') throw new ConflictException('Campagne close.');
    if (decision === 'excluded' && (!reason || reason.trim().length < 3)) {
      throw new BadRequestException('Un motif est requis pour exclure un filleul.');
    }
    const row = await this.db((db) =>
      db.referralCampaignReferral.findFirst({ where: { id: referralId, campaignId } }),
    );
    if (!row) throw new NotFoundException('Filleul introuvable dans cette campagne.');
    await this.db((db) =>
      db.$transaction(async (tx) => {
        await tx.referralCampaignReferral.update({
          where: { id: referralId },
          data:
            decision === 'clear'
              ? {
                  adminDecision: null,
                  adminDecisionReason: null,
                  adminDecisionByAdminId: null,
                  adminDecisionAt: null,
                }
              : {
                  adminDecision: decision,
                  adminDecisionReason: reason?.trim() || null,
                  adminDecisionByAdminId: actor.id,
                  adminDecisionAt: new Date(),
                },
        });
        await this.audit(tx, {
          action: `referral_campaign.referral_${decision}`,
          entityType: 'ReferralCampaignReferral',
          entityId: referralId,
          actor,
          requestId,
          reasonCode: reason?.trim() || undefined,
          changes: { campaignId, from: row.adminDecision, to: decision === 'clear' ? null : decision },
        });
      }),
    );
    // Le recalcul applique la décision (statut, compteurs, rang).
    await this.recompute(campaignId);
    return { ok: true };
  }

  // ── Prix et versements ────────────────────────────────────────────────────

  async prizes(campaignId: string) {
    await this.campaignOrThrow(campaignId);
    const rows = await this.db((db) =>
      db.referralCampaignPrizeAward.findMany({ where: { campaignId }, orderBy: { rank: 'asc' } }),
    );
    const forfeits = await this.db((db) =>
      db.referralCampaignPrizeForfeit.findMany({
        where: { campaignId },
        orderBy: [{ forfeitedAt: 'asc' }, { id: 'asc' }],
      }),
    );
    return { items: rows, forfeits };
  }

  /**
   * « Déclarer le prix forfait et réattribuer » (correctifs 57) — règlement :
   * lauréat injoignable ou sans informations de versement 15 jours après la
   * validation ⇒ il perd son prix, qui passe au suivant.
   *
   * - podium validé exigé ; refusé si le prix de ce rang est DÉJÀ VERSÉ ;
   * - le lauréat est marqué forfait (motif, date, admin) et ne pourra plus
   *   recevoir de prix dans cette campagne, même à une revalidation ;
   * - les prix non versés à partir de ce rang sont redistribués aux suivants
   *   classés non primés (`reassignAfterForfeit`) ; un prix versé ne bouge
   *   jamais ; plus de candidat ⇒ le prix reste non attribué ;
   * - le classement (ordre réel, rangs) ne change pas ;
   * - idempotent : redéclarer le même lauréat rend l'état actuel sans rien
   *   écrire ; un lauréat qui a changé entre-temps ⇒ 409 ;
   * - prix ORPHELIN (lauréat qui a supprimé son compte avant le versement,
   *   `participantId` NULL, nom « Compte supprimé ») : déclaré sans
   *   `participantId`, il passe au suivant de la même façon (audit 57, F17) ;
   * - audit `referral_campaign.prize_forfeited` dans la même transaction.
   */
  async forfeitPrize(
    campaignId: string,
    rank: number,
    dto: ForfeitPrizeDto,
    actor: CampaignActor,
    requestId: string,
  ) {
    const campaign = await this.campaignOrThrow(campaignId);
    if (!campaign.podiumValidatedAt) throw new ConflictException('Podium non validé.');
    const prizes = parsePrizes(campaign.prizes) ?? [];
    const prize = prizes.find((p) => p.rank === rank);
    if (!prize) throw new NotFoundException('Aucun prix à ce rang.');
    const participantId = dto.participantId?.trim() || null;
    const reason = dto.reason.trim();
    if (reason.length < 3) throw new BadRequestException('Un motif est requis pour déclarer un prix forfait.');

    try {
      const outcome = await this.db((db) =>
        db.$transaction(async (tx) => {
          const award = await tx.referralCampaignPrizeAward.findUnique({
            where: { campaignId_rank: { campaignId, rank } },
          });
          // Rejeu : ce lauréat est déjà forfait — ou, sans lauréat, un forfait
          // orphelin existe à ce rang et le prix n'est plus orphelin.
          const already = participantId
            ? await tx.referralCampaignPrizeForfeit.findFirst({ where: { campaignId, participantId } })
            : award && award.participantId === null
              ? null
              : await tx.referralCampaignPrizeForfeit.findFirst({
                  where: { campaignId, rank, participantId: null },
                });
          if (already) return { replayed: true as const };

          if (!award) throw new NotFoundException('Aucun lauréat à ce rang.');
          if (award.payoutStatus === 'paid') {
            throw new ConflictException('Ce prix est déjà versé : il ne peut plus être déclaré forfait.');
          }
          if (award.participantId === null && participantId) {
            throw new NotFoundException('Aucun lauréat à ce rang.');
          }
          if (award.participantId !== participantId) {
            throw new ConflictException({
              code: 'prize_holder_changed',
              message: 'Le lauréat de ce rang a changé entre-temps : recharge la page.',
            });
          }

          const [awards, forfeits, ranked] = await Promise.all([
            tx.referralCampaignPrizeAward.findMany({ where: { campaignId } }),
            tx.referralCampaignPrizeForfeit.findMany({
              where: { campaignId },
              select: { participantId: true },
            }),
            tx.referralCampaignParticipant.findMany({
              where: { campaignId, rank: { not: null } },
              orderBy: { rank: 'asc' },
            }),
          ]);
          const forfeited = new Set(
            forfeits.map((f) => f.participantId).filter((id): id is string => id !== null),
          );
          if (participantId) forfeited.add(participantId);
          const awardByRank = new Map(awards.map((a) => [a.rank, a]));
          const slots = prizes.map((p) => {
            const a = awardByRank.get(p.rank);
            return {
              rank: p.rank,
              participantId: a?.participantId ?? null,
              paid: a?.payoutStatus === 'paid',
            };
          });
          const plan = reassignAfterForfeit(
            slots,
            rank,
            forfeited,
            ranked.map((r) => ({ id: r.id, rank: r.rank! })),
          );
          const byId = new Map(ranked.map((r) => [r.id, r]));
          const amountOf = new Map(prizes.map((p) => [p.rank, p.amountFcfa]));

          const forfeit = await tx.referralCampaignPrizeForfeit.create({
            data: {
              campaignId,
              rank,
              participantId,
              publicNameSnapshot: award.publicNameSnapshot,
              amountFcfa: award.amountFcfa,
              reason,
              forfeitedByAdminId: actor.id,
              replacedByParticipantId: plan.find((a) => a.rank === rank)?.participantId ?? null,
            },
          });

          const changes: { rank: number; from: string | null; to: string | null }[] = [];
          for (const target of plan) {
            const existing = awardByRank.get(target.rank) ?? null;
            const from = existing?.participantId ?? null;
            if (from === target.participantId) continue;
            changes.push({ rank: target.rank, from, to: target.participantId });
            const winner = target.participantId ? byId.get(target.participantId) : undefined;
            if (!winner) {
              // Plus de candidat : le prix reste non attribué.
              if (existing) await tx.referralCampaignPrizeAward.delete({ where: { id: existing.id } });
              continue;
            }
            const data = {
              participantId: winner.id,
              publicNameSnapshot: displayName(winner.publicName, winner.city),
              amountFcfa: amountOf.get(target.rank) ?? existing?.amountFcfa ?? 0,
              recipient: winner.minorStatus === 'minor' ? 'parent' : 'ambassador',
              payoutStatus: 'pending',
              payoutReference: null,
              paidAmountFcfa: null,
              paidAt: null,
              paidByAdminId: null,
              note: null,
            };
            if (existing) {
              await tx.referralCampaignPrizeAward.update({ where: { id: existing.id }, data });
            } else {
              await tx.referralCampaignPrizeAward.create({
                data: { campaignId, rank: target.rank, ...data },
              });
            }
          }

          await this.audit(tx, {
            action: 'referral_campaign.prize_forfeited',
            entityType: 'ReferralCampaignPrizeForfeit',
            entityId: forfeit.id,
            actor,
            requestId,
            reasonCode: reason,
            changes: {
              campaignId,
              rank,
              forfeitedParticipantId: participantId,
              amountFcfa: award.amountFcfa,
              reassigned: changes,
            },
          });
          return { replayed: false as const };
        }),
      );
      if (!outcome.replayed) this.invalidatePublic(campaign.slug);
    } catch (error) {
      // Deux déclarations simultanées du même lauréat : la seconde bute sur
      // l'unicité (campagne, participant) — c'est un rejeu, pas une erreur.
      const replay =
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002' &&
        JSON.stringify(error.meta ?? {}).includes('participantId');
      if (!replay) throw error;
    }
    return this.prizes(campaignId);
  }

  async recordPayout(
    campaignId: string,
    rank: number,
    dto: RecordPayoutDto,
    actor: CampaignActor,
    requestId: string,
  ) {
    const campaign = await this.campaignOrThrow(campaignId);
    if (!campaign.podiumValidatedAt) throw new ConflictException('Podium non validé.');
    const award = await this.db((db) =>
      db.referralCampaignPrizeAward.findUnique({
        where: { campaignId_rank: { campaignId, rank } },
        include: { participant: { select: { minorStatus: true } } },
      }),
    );
    if (!award) throw new NotFoundException('Aucun prix à ce rang.');
    const recipient = dto.recipient ?? award.recipient;
    if (award.participant?.minorStatus === 'minor' && recipient !== 'parent') {
      throw new BadRequestException('Lauréat mineur : le prix est versé au parent.');
    }
    const updated = await this.db((db) =>
      db.$transaction(async (tx) => {
        const a = await tx.referralCampaignPrizeAward.update({
          where: { id: award.id },
          data: {
            payoutStatus: 'paid',
            payoutReference: dto.payoutReference.trim(),
            payoutMethod: dto.payoutMethod ?? 'wave',
            paidAmountFcfa: dto.paidAmountFcfa ?? award.amountFcfa,
            paidAt: dto.paidAt ? new Date(dto.paidAt) : new Date(),
            paidByAdminId: actor.id,
            recipient,
            note: dto.note?.trim() || null,
          },
        });
        await this.audit(tx, {
          action: 'referral_campaign.payout_recorded',
          entityType: 'ReferralCampaignPrizeAward',
          entityId: award.id,
          actor,
          requestId,
          changes: {
            campaignId,
            rank,
            amountFcfa: a.paidAmountFcfa,
            method: a.payoutMethod,
            reference: a.payoutReference,
            recipient,
          },
        });
        return a;
      }),
    );
    return updated;
  }

  // ── Export ────────────────────────────────────────────────────────────────

  async exportCsv(campaignId: string, scope: 'leaderboard' | 'referrals'): Promise<string> {
    if (scope === 'referrals') {
      const rows = await this.db((db) =>
        db.referralCampaignReferral.findMany({
          where: { campaignId },
          orderBy: [{ participantId: 'asc' }, { attachedAt: 'asc' }],
          include: { participant: { select: { publicName: true, city: true } } },
        }),
      );
      const profiles = await this.db((db) =>
        db.userProfile.findMany({
          where: { id: { in: rows.map((r) => r.refereeProfileId) } },
          select: { id: true, fullName: true, email: true },
        }),
      );
      const byId = new Map(profiles.map((p) => [p.id, p]));
      const header = [
        'ambassador_public_name',
        'ambassador_city',
        'referee_name',
        'referee_email',
        'attached_at',
        'account_created_at',
        'profile_completed_at',
        'qualified_at',
        'status',
        'flags',
        'admin_decision',
        'admin_decision_reason',
      ];
      const lines = rows.map((r) =>
        csvRow([
          r.participant.publicName,
          r.participant.city,
          byId.get(r.refereeProfileId)?.fullName ?? '',
          byId.get(r.refereeProfileId)?.email ?? '',
          iso(r.attachedAt),
          iso(r.accountCreatedAt),
          iso(r.profileCompletedAt),
          iso(r.qualifiedAt),
          r.status,
          r.flags.join(' '),
          r.adminDecision ?? '',
          r.adminDecisionReason ?? '',
        ]),
      );
      return '﻿' + [csvRow(header), ...lines].join('\r\n') + '\r\n';
    }
    const board = await this.adminLeaderboard(campaignId);
    const header = [
      'rank',
      'public_name',
      'city',
      'country',
      'qualified',
      'to_review',
      'pending',
      'excluded',
      'reached_count_at',
      'rankable',
      'unrankable_reason',
      'minor_status',
      'parental_auth_status',
      'ambassador_code',
      'personal_code',
      'full_name',
      'email',
    ];
    const lines = board.items.map((i) =>
      csvRow([
        i.rank ?? '',
        i.publicName,
        i.city,
        i.country,
        i.qualifiedCount,
        i.flaggedCount,
        i.pendingCount,
        i.excludedCount,
        iso(i.reachedCountAt),
        i.unrankableReason ? 'no' : 'yes',
        i.unrankableReason ?? '',
        i.minorStatus,
        i.parentalAuthStatus,
        i.ambassadorCode,
        i.personalCode ?? '',
        i.fullName,
        i.email,
      ]),
    );
    return '﻿' + [csvRow(header), ...lines].join('\r\n') + '\r\n';
  }

  // ── Public ────────────────────────────────────────────────────────────────

  /**
   * Classement public : nom public (« Prénom I. »), ville, nombre de filleuls
   * qualifiés, rang. JAMAIS d'e-mail, d'identifiant interne ni de donnée de
   * filleul — la liste des champs est fermée (`PublicLeaderboardEntry`).
   * Seuls les participants classables apparaissent (un mineur sans
   * autorisation parentale vérifiée n'apparaît pas).
   */
  async publicLeaderboard(
    slug: string,
    city: string | undefined,
    now: Date = new Date(),
  ): Promise<PublicLeaderboard> {
    const cacheKey = `${slug}\u0000${placeKey(city ?? '')}`;
    const cached = this.publicCache.get(cacheKey);
    if (cached && now.getTime() - cached.at < PUBLIC_CACHE_TTL_MS) {
      return { ...cached.payload, serverTime: now.toISOString() };
    }
    const campaign = await this.db((db) => db.referralCampaign.findUnique({ where: { slug } }));
    if (!campaign || !isPubliclyVisible(campaign.status as CampaignStatus)) {
      throw new NotFoundException('Campagne introuvable.');
    }
    const rows = await this.db((db) =>
      db.referralCampaignParticipant.findMany({
        where: { campaignId: campaign.id },
        include: { ambassador: { select: { approvedAt: true } } },
      }),
    );
    const rankable = rows.filter(
      (r) =>
        unrankableReason({
          status: r.status,
          minorStatus: r.minorStatus,
          parentalAuthStatus: r.parentalAuthStatus,
          ambassadorApproved: r.ambassador.approvedAt !== null,
        }) === null,
    );
    const entries: PublicLeaderboardEntry[] = rankable
      .filter((r) => !city || placeKey(r.city) === placeKey(city))
      .sort(
        (a, b) =>
          (a.rank ?? Number.MAX_SAFE_INTEGER) - (b.rank ?? Number.MAX_SAFE_INTEGER) ||
          b.qualifiedCount - a.qualifiedCount ||
          a.publicName.localeCompare(b.publicName, 'fr'),
      )
      .map((r) => ({
        rank: r.qualifiedCount > 0 ? r.rank : null,
        name: r.publicName,
        city: r.city,
        qualified: r.qualifiedCount,
      }));
    // Résultats définitifs : les lauréats effectifs, prix forfait réattribués
    // compris. Avant la clôture, rien (la page montre le podium provisoire).
    const winners: PublicWinner[] =
      campaign.status === 'closed'
        ? (
            await this.db((db) =>
              db.referralCampaignPrizeAward.findMany({
                where: { campaignId: campaign.id, participantId: { not: null } },
                orderBy: { rank: 'asc' },
                include: { participant: { select: { publicName: true, city: true } } },
              }),
            )
          )
            .filter((a) => a.participant)
            .map((a) => ({
              prizeRank: a.rank,
              amountFcfa: a.amountFcfa,
              name: a.participant!.publicName,
              city: a.participant!.city,
            }))
        : [];
    const days = campaignDaysFromWindow(campaign, campaign.timeZone);
    const payload: PublicLeaderboard = {
      campaign: {
        slug: campaign.slug,
        nameFr: campaign.nameFr,
        nameEn: campaign.nameEn,
        status: campaign.status as CampaignStatus,
        phase: campaignPhase(campaign, now),
        timeZone: campaign.timeZone,
        startDate: days.startDate,
        endDate: days.endDate,
        startsAt: campaign.startsAt.toISOString(),
        endsAt: campaign.endsAt.toISOString(),
        prizes: (parsePrizes(campaign.prizes) ?? []).map((p) => ({
          rank: p.rank,
          amountFcfa: p.amountFcfa,
        })),
        rulesUrl: campaign.rulesUrl,
        provisional: campaign.status !== 'closed',
        updatedAt: campaign.lastComputedAt?.toISOString() ?? null,
      },
      serverTime: now.toISOString(),
      cities: [...new Set(rankable.map((r) => r.city).filter(Boolean))].sort((a, b) =>
        a.localeCompare(b, 'fr'),
      ),
      entries,
      winners,
    };
    this.publicCache.set(cacheKey, { at: now.getTime(), payload });
    return payload;
  }

  /**
   * Position de l'élève connecté (préparé pour la build 57 : écran classement
   * in-app). Rien pour un compte qui n'est pas participant.
   */
  async myStanding(profileId: string, now: Date = new Date()) {
    const rows = await this.db((db) =>
      db.referralCampaignParticipant.findMany({
        where: {
          ambassador: { userProfileId: profileId },
          campaign: { status: { in: ['live', 'frozen', 'closed'] } },
        },
        include: {
          campaign: true,
          ambassador: { select: { approvedAt: true, code: true } },
        },
        orderBy: { campaign: { startsAt: 'desc' } },
        take: 1,
      }),
    );
    const p = rows[0];
    if (!p) return { participating: false as const };
    return {
      participating: true as const,
      campaign: {
        slug: p.campaign.slug,
        nameFr: p.campaign.nameFr,
        nameEn: p.campaign.nameEn,
        status: p.campaign.status,
        phase: campaignPhase(p.campaign, now),
        startsAt: p.campaign.startsAt.toISOString(),
        endsAt: p.campaign.endsAt.toISOString(),
        provisional: p.campaign.status !== 'closed',
      },
      me: {
        publicName: p.publicName,
        city: p.city,
        code: p.ambassador.code,
        rank: p.rank,
        qualified: p.qualifiedCount,
        toReview: p.flaggedCount,
        pending: p.pendingCount,
        rankable:
          unrankableReason({
            status: p.status,
            minorStatus: p.minorStatus,
            parentalAuthStatus: p.parentalAuthStatus,
            ambassadorApproved: p.ambassador.approvedAt !== null,
          }) === null,
      },
      serverTime: now.toISOString(),
    };
  }

  // ── Aides ─────────────────────────────────────────────────────────────────

  private async campaignOrThrow(id: string): Promise<ReferralCampaign> {
    const c = await this.db((db) => db.referralCampaign.findUnique({ where: { id } }));
    if (!c) throw new NotFoundException('Campagne introuvable.');
    return c;
  }

  private windowOrThrow(startDate: string, endDate: string, timeZone: string) {
    if (!isValidTimeZone(timeZone)) throw new BadRequestException('Fuseau horaire inconnu.');
    try {
      return campaignWindowFromDays(startDate, endDate, timeZone);
    } catch (error) {
      throw new BadRequestException(error instanceof Error ? error.message : 'Dates invalides.');
    }
  }

  private prizesOrThrow(raw: unknown[]): CampaignPrize[] {
    const prizes = parsePrizes(raw);
    if (!prizes) {
      throw new BadRequestException('Prix invalides : rangs 1, 2, 3… sans trou, montants entiers ≥ 0.');
    }
    return prizes;
  }

  private presentCampaign(c: ReferralCampaign) {
    const days = campaignDaysFromWindow(c, c.timeZone);
    return {
      id: c.id,
      slug: c.slug,
      nameFr: c.nameFr,
      nameEn: c.nameEn,
      timeZone: c.timeZone,
      startDate: days.startDate,
      endDate: days.endDate,
      startsAt: c.startsAt.toISOString(),
      endsAt: c.endsAt.toISOString(),
      status: c.status,
      prizes: parsePrizes(c.prizes) ?? [],
      rulesText: c.rulesText,
      rulesUrl: c.rulesUrl,
      eligibleCities: c.eligibleCities,
      eligibleCountries: c.eligibleCountries,
      qualificationRule: { ...DEFAULT_QUALIFICATION_RULE, ...parseQualificationRule(c.qualificationRule) },
      lastComputedAt: c.lastComputedAt?.toISOString() ?? null,
      launchedAt: c.launchedAt?.toISOString() ?? null,
      frozenAt: c.frozenAt?.toISOString() ?? null,
      podiumValidatedAt: c.podiumValidatedAt?.toISOString() ?? null,
      podiumValidatedByAdminId: c.podiumValidatedByAdminId,
      closedAt: c.closedAt?.toISOString() ?? null,
      publicPath: `/classement/?c=${encodeURIComponent(c.slug)}`,
    };
  }

  private invalidatePublic(slug: string): void {
    for (const key of this.publicCache.keys()) {
      if (key.startsWith(`${slug}\u0000`)) this.publicCache.delete(key);
    }
  }

  private async audit(
    tx: Prisma.TransactionClient,
    input: {
      action: string;
      entityType: string;
      entityId: string;
      actor: CampaignActor | null;
      requestId: string;
      reasonCode?: string;
      changes: Prisma.InputJsonValue;
    },
  ): Promise<void> {
    await tx.adminAuditEvent.create({
      data: {
        actorAdminId: input.actor?.id ?? null,
        action: input.action,
        purposeCode: AUDIT_PURPOSE,
        entityType: input.entityType,
        entityId: input.entityId,
        requestId: input.requestId || randomUUID(),
        reasonCode: input.reasonCode?.slice(0, 500),
        result: 'success',
        changes: input.changes,
      },
    });
  }
}

// ── Fonctions de module ─────────────────────────────────────────────────────

/** « Aïcha K. — Niamey » */
export function displayName(publicName: string, city: string): string {
  return city ? `${publicName} — ${city}` : publicName;
}

function iso(d: Date | null | undefined): string {
  return d ? d.toISOString() : '';
}

function cleanList(values: readonly string[] | undefined): string[] {
  return [...new Set((values ?? []).map((v) => v.trim()).filter(Boolean))];
}

function sameDate(a: Date | null, b: Date | null): boolean {
  return (a?.getTime() ?? null) === (b?.getTime() ?? null);
}

function referralData(row: ComputedReferral) {
  return {
    participantId: row.participantId,
    refereeProfileId: row.refereeProfileId,
    attachedAt: row.attachedAt,
    accountCreatedAt: row.accountCreatedAt,
    profileCompletedAt: row.profileCompletedAt,
    qualifiedAt: row.qualifiedAt,
    status: row.status,
    flags: row.flags,
  };
}

function referralChanged(prev: ReferralCampaignReferral, row: ComputedReferral): boolean {
  return (
    prev.participantId !== row.participantId ||
    !sameDate(prev.attachedAt, row.attachedAt) ||
    !sameDate(prev.accountCreatedAt, row.accountCreatedAt) ||
    !sameDate(prev.profileCompletedAt, row.profileCompletedAt) ||
    !sameDate(prev.qualifiedAt, row.qualifiedAt) ||
    prev.status !== row.status ||
    prev.flags.join(',') !== row.flags.join(',')
  );
}

function participantChanged(
  p: ReferralCampaignParticipant,
  c: {
    qualifiedCount: number;
    flaggedCount: number;
    pendingCount: number;
    excludedCount: number;
    reachedCountAt: Date | null;
    rank: number | null;
  },
): boolean {
  return (
    p.qualifiedCount !== c.qualifiedCount ||
    p.flaggedCount !== c.flaggedCount ||
    p.pendingCount !== c.pendingCount ||
    p.excludedCount !== c.excludedCount ||
    !sameDate(p.reachedCountAt, c.reachedCountAt) ||
    p.rank !== c.rank
  );
}

function jsonSafe(value: unknown): Prisma.InputJsonValue {
  return JSON.parse(JSON.stringify(value ?? {})) as Prisma.InputJsonValue;
}

/** Durée de conservation des empreintes anti-fraude (`REFERRAL_SIGNAL_RETENTION_DAYS`, 180). */
export function signalRetentionDays(): number {
  const n = Number(process.env.REFERRAL_SIGNAL_RETENTION_DAYS ?? 180);
  return Number.isInteger(n) && n >= 30 ? n : 180;
}
