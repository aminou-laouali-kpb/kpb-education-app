import {
  BadRequestException,
  HttpException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import type { AdminSessionUser } from '../auth/auth.service';
import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { ActivateScholarshipDto } from './dto/activate-scholarship.dto';
import { ForecastScholarshipDto } from './dto/forecast-scholarship.dto';
import { ScholarshipOpeningAudienceService } from './opening/scholarship-opening-audience.service';
import {
  audienceScopeForMode,
  canSendAboveOpeningThreshold,
  isAboveOpeningThreshold,
  isOpeningAudienceChangeRejected,
  openingDedupeKey,
  openingError,
  OPENING_AUDIT_ENTITY_TYPE,
  OPENING_AUDIT_PURPOSE,
  readOpeningTunables,
  readScholarshipOpeningMode,
  SCHOLARSHIP_OPENED_KIND,
  scholarshipRoute,
  type ActivateScholarshipResponse,
  type OpeningActivationAuditChanges,
  type OpeningAudienceScope,
  type OpeningAuditAction,
  type OpeningNotificationReason,
  type OpeningNotificationState,
  type OpeningTunables,
  type ScholarshipOpeningMode,
} from './opening/scholarship-opening.contract';
import { ScholarshipContentQualityService } from './scholarship-content-quality.service';

/** Qui ouvre le cycle : l'audit le nomme, le seuil regarde son rôle. */
export type OpeningActor = Pick<AdminSessionUser, 'id' | 'role'>;

/** Le cycle tel que relu SOUS VERROU, avant toute écriture. */
interface LockedCycle {
  id: string;
  activatedAt: Date | null;
  openingPreExisting: boolean;
  openingNotifiedAt: Date | null;
  openingFanoutDueAt: Date | null;
}

interface LegacyRecipient {
  userId: string;
  pushEnabled: boolean;
  inAppEnabled: boolean;
  /** `followed_scholarship_updates` coupé : l'entrée d'inbox, pas le push. */
  optedOut: boolean;
  user: { preferredLanguage: string };
}

type ActivationOutcome =
  | { kind: 'rejected'; error: HttpException }
  | {
      kind: 'done';
      scholarship: { id: string; nameFr: string; nameEn: string };
      cycle: { id: string; status: string };
      firstActivation: boolean;
      subscribers: number;
      toNotify: number;
      state: OpeningNotificationState;
      reason: OpeningNotificationReason | null;
      fanoutAt: Date | null;
      legacyRecipients: LegacyRecipient[];
    };

/** Prisma 6 transmet un 55P03 (`lock_timeout`) en P2010 sur une requête brute. */
function isLockTimeout(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const candidate = error as {
    code?: unknown;
    meta?: { code?: unknown } | null;
    message?: unknown;
  };
  if (candidate.code === '55P03') return true;
  if (candidate.code === 'P2010' && candidate.meta?.code === '55P03') {
    return true;
  }
  return (
    typeof candidate.message === 'string' &&
    /55P03|lock timeout/i.test(candidate.message)
  );
}

function isUniqueConflict(error: unknown): boolean {
  return (
    error != null &&
    typeof error === 'object' &&
    'code' in error &&
    (error as { code?: unknown }).code === 'P2002'
  );
}

@Injectable()
export class ScholarshipLifecycleService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly pushSender: PushSenderService,
    private readonly contentQuality: ScholarshipContentQualityService,
    private readonly audience: ScholarshipOpeningAudienceService,
  ) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  async saveForecast(scholarshipId: string, input: ForecastScholarshipDto) {
    this.assertDb();
    const estimatedOpenAt = new Date(input.estimatedOpenAt);
    const estimatedCloseAt = new Date(input.estimatedCloseAt);
    if (estimatedCloseAt <= estimatedOpenAt) {
      throw new BadRequestException(
        'estimatedCloseAt must be after estimatedOpenAt.',
      );
    }

    const result = await this.prismaService.execute(async (prisma) => {
      const scholarship = await prisma.scholarship.findUnique({
        where: { id: scholarshipId },
        select: { id: true },
      });
      if (!scholarship) return null;
      const existing = await prisma.scholarshipCycle.findUnique({
        where: {
          scholarshipId_academicYear: {
            scholarshipId,
            academicYear: input.academicYear,
          },
        },
        select: { status: true, activatedAt: true },
      });
      const cycle = await prisma.scholarshipCycle.upsert({
        where: {
          scholarshipId_academicYear: {
            scholarshipId,
            academicYear: input.academicYear,
          },
        },
        create: {
          scholarshipId,
          academicYear: input.academicYear,
          status: 'forecast',
          dateConfidence: 'estimated',
          estimatedOpenAt,
          estimatedCloseAt,
          sourceUrl: input.sourceUrl,
          verifiedAt: new Date(),
        },
        update: {
          // Never turn an already-open cycle back into a forecast.
          status: existing?.activatedAt ? existing.status : 'forecast',
          dateConfidence: existing?.activatedAt ? 'confirmed' : 'estimated',
          estimatedOpenAt,
          estimatedCloseAt,
          sourceUrl: input.sourceUrl,
          verifiedAt: new Date(),
        },
      });
      return cycle;
    });
    if (!result) {
      throw new NotFoundException(`Scholarship ${scholarshipId} not found.`);
    }
    return {
      scholarshipId,
      cycleId: result.id,
      status: result.status,
      dateConfidence: result.dateConfidence,
    };
  }

  /**
   * Ouvre (ou corrige) le cycle d'une année et décide de son annonce
   * (`docs/api-contracts.md`, « Annonce d'ouverture des bourses suivies »).
   *
   * Hors `legacy`, RIEN n'est écrit pour les étudiants et aucun fournisseur
   * n'est appelé dans la requête : l'annonce est programmée à maintenant +
   * `KPB_OPENING_HOLD_SECONDS`, annulable d'ici là, puis envoyée par le worker.
   *
   * Une transaction, le cycle verrouillé (`FOR UPDATE`, `lock_timeout` 5 s) :
   * activate, l'annulation et le worker se suivent sans se croiser. Toutes les
   * vérifications (rétroactivité, seuil, rôle, audience confirmée) passent
   * AVANT la première écriture : un refus ne laisse rien derrière lui.
   */
  async activate(
    scholarshipId: string,
    input: ActivateScholarshipDto,
    actor: OpeningActor,
    requestId: string,
  ): Promise<ActivateScholarshipResponse> {
    this.assertDb();
    const opensAt = new Date(input.opensAt);
    const closesAt = new Date(input.closesAt);
    if (closesAt <= opensAt) {
      throw new BadRequestException('closesAt must be after opensAt.');
    }

    const now = new Date();
    await this.contentQuality.assertReady(
      scholarshipId,
      {
        academicYear: input.academicYear,
        status: 'open',
        opensAt,
        closesAt,
        sourceUrl: input.sourceUrl,
        verifiedAt: now,
      },
      now,
    );

    const mode = readScholarshipOpeningMode();
    const scope = audienceScopeForMode(mode);
    const tunables = readOpeningTunables();

    const runOnce = () =>
      this.prismaService.execute((prisma) =>
        prisma.$transaction(
          (tx) =>
            this.activateInTransaction(tx, {
              scholarshipId,
              input,
              actor,
              requestId,
              now,
              opensAt,
              closesAt,
              mode,
              scope,
              tunables,
            }),
          // Le défaut de Prisma (5 s) abandonnerait une activation qui attend
          // un envoi en cours ou qui compte une grosse audience.
          { maxWait: 5_000, timeout: 30_000 },
        ),
      );

    let outcome: ActivationOutcome | null;
    try {
      try {
        outcome = await runOnce();
      } catch (error) {
        // Deux premiers clics simultanés : l'un crée le cycle, l'autre bute
        // sur l'unicité (scholarshipId, academicYear). Une seconde passe le
        // trouve, verrouillé puis à jour.
        if (!isUniqueConflict(error)) throw error;
        outcome = await runOnce();
      }
    } catch (error) {
      if (isLockTimeout(error)) throw openingError('OPENING_BUSY');
      throw error;
    }

    if (!outcome) {
      throw new NotFoundException(`Scholarship ${scholarshipId} not found.`);
    }
    if (outcome.kind === 'rejected') throw outcome.error;

    // Mode legacy (KPB-173) : sollicité et ponctuel, envoyé dans la requête
    // comme avant ce chantier — aux destinataires de l'aperçu, sauf le push
    // de ceux qui l'ont coupé (désinscription globale ou alerte sans push).
    let pushesSent = 0;
    for (const subscriber of outcome.legacyRecipients) {
      if (!subscriber.pushEnabled || subscriber.optedOut) continue;
      const isEnglish = subscriber.user.preferredLanguage === 'en';
      const delivered = await this.pushSender.sendToUser(
        subscriber.userId,
        isEnglish ? 'Scholarship applications are open' : 'La bourse est ouverte',
        isEnglish
          ? `${outcome.scholarship.nameEn} is now accepting applications.`
          : `${outcome.scholarship.nameFr} accepte maintenant les candidatures.`,
        {
          route: scholarshipRoute(scholarshipId),
          scholarshipId,
          cycleId: outcome.cycle.id,
        },
      );
      if (delivered) pushesSent += 1;
    }

    return {
      scholarshipId,
      cycleId: outcome.cycle.id,
      status: outcome.cycle.status,
      firstActivation: outcome.firstActivation,
      subscribers: outcome.subscribers,
      pushesSent,
      academicYear: input.academicYear,
      mode,
      notification: {
        state: outcome.state,
        toNotify: outcome.toNotify,
        fanoutAt: outcome.fanoutAt?.toISOString() ?? null,
        reason: outcome.reason,
      },
    };
  }

  private async activateInTransaction(
    tx: Prisma.TransactionClient,
    ctx: {
      scholarshipId: string;
      input: ActivateScholarshipDto;
      actor: OpeningActor;
      requestId: string;
      now: Date;
      opensAt: Date;
      closesAt: Date;
      mode: ScholarshipOpeningMode;
      scope: OpeningAudienceScope;
      tunables: OpeningTunables;
    },
  ): Promise<ActivationOutcome | null> {
    const { scholarshipId, input, actor, now, mode, scope, tunables } = ctx;
    const legacy = mode === 'legacy';

    // Attendre un envoi en cours de préparation (le worker tient la ligne du
    // cycle) au plus 5 s, puis 409 OPENING_BUSY plutôt qu'une 500.
    await tx.$executeRaw`SET LOCAL lock_timeout = '5s'`;

    const scholarship = await tx.scholarship.findUnique({
      where: { id: scholarshipId },
      select: { id: true, nameFr: true, nameEn: true },
    });
    if (!scholarship) return null;

    const [existing = null] = await tx.$queryRaw<LockedCycle[]>`
      SELECT "id", "activatedAt", "openingPreExisting", "openingNotifiedAt",
             "openingFanoutDueAt"
      FROM "ScholarshipCycle"
      WHERE "scholarshipId" = ${scholarshipId}
        AND "academicYear" = ${input.academicYear}
      FOR UPDATE
    `;

    // ── Décider, avant toute écriture ───────────────────────────────────────
    const firstActivationExpected = existing?.activatedAt == null;
    const preExisting = existing?.openingPreExisting ?? false;
    if (input.notify === true && preExisting) {
      return { kind: 'rejected', error: openingError('OPENING_NOT_RETROACTIVE') };
    }
    // `notify` absent (admin déjà déployé) : la règle d'avant, annonce à la
    // première activation seulement.
    const shouldNotify =
      input.notify ?? (firstActivationExpected && !preExisting);
    const alreadyScheduled = existing?.openingFanoutDueAt != null;

    const audienceQuery = {
      scholarshipId,
      scope,
      cycleId: existing?.id ?? null,
      now,
      followSince: existing?.openingNotifiedAt ?? null,
      renotifyDays: tunables.renotifyDays,
    };
    const counts = await this.audience.countToNotify(tx, audienceQuery);

    // Ce que CET appel enverrait : le `toNotify` de l'aperçu, dans tous les
    // modes (déjà prévenus pour ce cycle, ou pour un autre cycle de la bourse
    // depuis 30 jours, exclus). En legacy, à la première activation seulement
    // (le chemin d'avant).
    const sends =
      shouldNotify && (legacy ? firstActivationExpected : !alreadyScheduled);
    const toNotify = sends ? counts.toNotify : 0;

    if (sends && isAboveOpeningThreshold(toNotify, tunables.confirmThreshold)) {
      const details = { toNotify, threshold: tunables.confirmThreshold };
      if (input.expectedRecipients === undefined) {
        return {
          kind: 'rejected',
          error: openingError('OPENING_CONFIRMATION_REQUIRED', details),
        };
      }
      if (!canSendAboveOpeningThreshold(actor.role)) {
        return {
          kind: 'rejected',
          error: openingError('OPENING_REQUIRES_ADMIN', details),
        };
      }
    }
    if (
      sends &&
      input.expectedRecipients !== undefined &&
      isOpeningAudienceChangeRejected(
        toNotify,
        input.expectedRecipients,
        tunables.confirmThreshold,
      )
    ) {
      return {
        kind: 'rejected',
        error: openingError('OPENING_AUDIENCE_CHANGED', {
          toNotify,
          expectedRecipients: input.expectedRecipients,
        }),
      };
    }

    // ── Écrire ──────────────────────────────────────────────────────────────
    const activationKey = `scholarship-open:${scholarshipId}:${input.academicYear}`;
    const cycle = await tx.scholarshipCycle.upsert({
      where: {
        scholarshipId_academicYear: {
          scholarshipId,
          academicYear: input.academicYear,
        },
      },
      create: {
        scholarshipId,
        academicYear: input.academicYear,
        status: 'open',
        dateConfidence: input.dateConfidence ?? 'confirmed',
        estimatedOpenAt: input.estimatedOpenAt
          ? new Date(input.estimatedOpenAt)
          : null,
        estimatedCloseAt: input.estimatedCloseAt
          ? new Date(input.estimatedCloseAt)
          : null,
        opensAt: ctx.opensAt,
        closesAt: ctx.closesAt,
        sourceUrl: input.sourceUrl,
        verifiedAt: now,
      },
      update: {
        status: 'open',
        dateConfidence: input.dateConfidence ?? 'confirmed',
        estimatedOpenAt: input.estimatedOpenAt
          ? new Date(input.estimatedOpenAt)
          : undefined,
        estimatedCloseAt: input.estimatedCloseAt
          ? new Date(input.estimatedCloseAt)
          : undefined,
        opensAt: ctx.opensAt,
        closesAt: ctx.closesAt,
        sourceUrl: input.sourceUrl,
        verifiedAt: now,
      },
      select: {
        id: true,
        status: true,
        openingNotifiedAt: true,
        openingFanoutDueAt: true,
        openingSkippedReason: true,
        openingAudience: true,
      },
    });

    // La première activation est celle qui pose `activatedAt` : sous verrou,
    // une seule requête peut la gagner.
    const firstActivation =
      (
        await tx.scholarshipCycle.updateMany({
          where: { id: cycle.id, activatedAt: null },
          data: { activatedAt: now, activationKey },
        })
      ).count === 1;

    await tx.scholarship.update({
      where: { id: scholarshipId },
      data: {
        deadlineAt: ctx.closesAt,
        sourceUrl: input.sourceUrl,
        lastVerifiedAt: now,
        isActive: true,
        moderationStatus: 'approved',
      },
    });

    let state: OpeningNotificationState;
    let reason: OpeningNotificationReason | null = null;
    let fanoutAt: Date | null = null;
    let reportedToNotify = 0;
    let legacyRecipients: LegacyRecipient[] = [];
    let legacySubscribers = 0;

    if (legacy && shouldNotify && firstActivation) {
      // Les destinataires sont ceux de l'aperçu et du compte ci-dessus (le
      // texte partagé `follow_rows`, `toNotify`) ; l'abonnement donne
      // `inAppEnabled`, que ce texte ne lit pas.
      const followers = new Map(
        (await this.audience.rows(audienceQuery, tx))
          .filter((row) => row.toNotify)
          .map((row) => [row.userId, row]),
      );
      const subscriptions = await tx.scholarshipAlertSubscription.findMany({
        where: { scholarshipId, mutedAt: null },
        select: {
          userId: true,
          pushEnabled: true,
          inAppEnabled: true,
          user: { select: { preferredLanguage: true } },
        },
      });
      legacySubscribers = subscriptions.length;
      legacyRecipients = subscriptions.flatMap((subscription) => {
        const follower = followers.get(subscription.userId);
        return follower
          ? [{ ...subscription, optedOut: follower.optedOut }]
          : [];
      });
      const inAppSubscribers = legacyRecipients.filter(
        (subscriber) => subscriber.inAppEnabled,
      );
      let inserted = 0;
      if (inAppSubscribers.length) {
        inserted = (
          await tx.userNotification.createMany({
            data: inAppSubscribers.map((subscriber) => ({
              userId: subscriber.userId,
              scholarshipId,
              // La colonne, pas seulement `data.cycleId` : le rapport, le
              // compte d'audience et la garde des 30 jours la lisent.
              cycleId: cycle.id,
              kind: SCHOLARSHIP_OPENED_KIND,
              dedupeKey: openingDedupeKey(cycle.id, subscriber.userId),
              titleFr: 'La bourse est ouverte',
              titleEn: 'Scholarship applications are open',
              bodyFr: `${scholarship.nameFr} accepte maintenant les candidatures jusqu'au ${ctx.closesAt.toLocaleDateString('fr-FR')}.`,
              bodyEn: `${scholarship.nameEn} is now accepting applications until ${ctx.closesAt.toLocaleDateString('en-GB')}.`,
              route: scholarshipRoute(scholarshipId),
              data: { scholarshipId, cycleId: cycle.id },
            })),
            skipDuplicates: true,
          })
        ).count;
      }
      await tx.scholarshipCycle.update({
        where: { id: cycle.id },
        data: {
          openingNotifiedAt: cycle.openingNotifiedAt ?? now,
          openingLastFanoutAt: now,
          openingAudience: (cycle.openingAudience ?? 0) + inserted,
          openingNotifiedById: actor.id,
        },
      });
      state = 'sent_legacy';
      reportedToNotify = legacyRecipients.length;
    } else if (shouldNotify && !legacy && cycle.openingFanoutDueAt == null) {
      if (toNotify === 0) {
        await tx.scholarshipCycle.update({
          where: { id: cycle.id },
          data: {
            openingNotifiedAt: cycle.openingNotifiedAt ?? now,
            openingAudience: cycle.openingAudience ?? 0,
          },
        });
        state = 'nothing_to_send';
        reason = cycle.openingNotifiedAt ? 'already_announced' : null;
      } else {
        fanoutAt = new Date(now.getTime() + tunables.holdSeconds * 1000);
        // `openingNotifiedById` n'est pas touché : sur une relance, il garde
        // l'auteur de la première annonce.
        await tx.scholarshipCycle.update({
          where: { id: cycle.id },
          data: {
            openingFanoutDueAt: fanoutAt,
            openingFanoutScope: scope,
            openingFanoutById: actor.id,
            openingSkippedAt: null,
            openingSkippedReason: null,
          },
        });
        state = 'scheduled';
        reportedToNotify = toNotify;
      }
    } else if (cycle.openingFanoutDueAt != null) {
      // Double clic, ou « dates seulement » pendant l'attente : l'annonce
      // programmée garde son heure et partira avec les dates corrigées (les
      // textes sont construits à l'envoi). Sans cette règle, le second de
      // deux clics de l'admin déjà déployé (sans `notify`) poserait
      // `dates_only` sur un cycle en cours d'annonce.
      state = 'already_scheduled';
      fanoutAt = cycle.openingFanoutDueAt;
      reportedToNotify = counts.toNotify;
    } else if (shouldNotify) {
      state = 'none';
      reason = 'legacy_first_activation_only';
    } else if (cycle.openingNotifiedAt == null) {
      const skipReason = cycle.openingSkippedReason ?? 'dates_only';
      await tx.scholarshipCycle.update({
        where: { id: cycle.id },
        data: { openingSkippedAt: now, openingSkippedReason: skipReason },
      });
      state = 'none';
      reason =
        skipReason === 'pre_existing_open' ? 'pre_existing_open' : 'dates_only';
    } else {
      state = 'none';
      reason = preExisting ? 'pre_existing_open' : 'already_announced';
    }

    const action: OpeningAuditAction =
      state === 'scheduled'
        ? 'scholarship_cycle.notify_scheduled'
        : state === 'sent_legacy'
          ? 'scholarship_cycle.notified_legacy'
          : firstActivation
            ? 'scholarship_cycle.opened'
            : 'scholarship_cycle.dates_updated';
    const changes = {
      academicYear: input.academicYear,
      opensAt: ctx.opensAt.toISOString(),
      closesAt: ctx.closesAt.toISOString(),
      notify: input.notify ?? null,
      mode,
      scope,
      toNotify: reportedToNotify,
      expectedRecipients: input.expectedRecipients ?? null,
      viaFavoriteOnly: counts.viaFavoriteOnly,
      viaAlertOnly: counts.viaAlertOnly,
      viaBoth: counts.viaBoth,
    } satisfies OpeningActivationAuditChanges;
    await tx.adminAuditEvent.create({
      data: {
        actorAdminId: actor.id,
        action,
        purposeCode: OPENING_AUDIT_PURPOSE,
        entityType: OPENING_AUDIT_ENTITY_TYPE,
        entityId: cycle.id,
        requestId: ctx.requestId,
        result: 'success',
        changes,
      },
    });

    return {
      kind: 'done',
      scholarship,
      cycle: { id: cycle.id, status: cycle.status },
      firstActivation,
      subscribers: state === 'sent_legacy' ? legacySubscribers : counts.audience,
      toNotify: reportedToNotify,
      state,
      reason,
      fanoutAt,
      legacyRecipients: state === 'sent_legacy' ? legacyRecipients : [],
    };
  }
}
