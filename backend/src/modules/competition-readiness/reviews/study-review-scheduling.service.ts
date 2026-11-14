import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { InternalRole } from '../../../common/enums/internal-role.enum';
import { PrismaService } from '../../prisma/prisma.service';
import { utcTimestamp } from '../../../common/sql-time';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  featureDisabled,
  idempotencyInProgress,
  idempotencyPayloadMismatch,
  outboxEventConflict,
  versionConflict,
  workspaceNotFound,
} from '../common/competition-readiness.errors';
import {
  DomainEventConflictError,
  DomainEventOutboxService,
  DomainEventOutboxUnavailableError,
} from '../common/domain-event-outbox.service';
import { FeatureAccessService } from '../common/feature-access.service';
import {
  IdempotencyPayloadMismatchError,
  IdempotencyService,
  IdempotencyStorageUnavailableError,
} from '../common/idempotency.service';
import {
  AdminReviewAccessService,
  type AdminReviewActor,
} from '../admin/admin-review-access.service';
import { AdminReviewOperationsService } from '../admin/admin-review-operations.service';
import type { OfferReviewSlotsDto } from '../admin/dto/offer-review-slots.dto';
import type { BookStudyReviewAppointmentDto } from './dto/book-study-review-appointment.dto';
import type { CancelStudyReviewAppointmentDto } from './dto/cancel-study-review-appointment.dto';
import type { RescheduleStudyReviewAppointmentDto } from './dto/reschedule-study-review-appointment.dto';

const MAX_OFFER_LIFETIME_MS = 30 * 24 * 60 * 60 * 1000;
const MIN_RESCHEDULE_NOTICE_MS = 60 * 60 * 1000;
const MUTABLE_APPOINTMENT_STATUSES = ['scheduled', 'confirmed'] as const;

const scopedReviewSelect = {
  id: true,
  version: true,
  status: true,
  assignedCounsellorId: true,
  preferredContact: true,
  timezone: true,
  workspace: {
    select: {
      id: true,
      userId: true,
      scholarshipId: true,
      scholarship: { select: { id: true, countryId: true } },
    },
  },
} satisfies Prisma.StudyReviewRequestSelect;

type ScopedReview = Prisma.StudyReviewRequestGetPayload<{
  select: typeof scopedReviewSelect;
}>;

@Injectable()
export class StudyReviewSchedulingService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly featureAccess: FeatureAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
    private readonly adminAccess: AdminReviewAccessService,
    private readonly adminReviews: AdminReviewOperationsService,
  ) {}

  async offerSlots(
    actor: AdminReviewActor,
    reviewRequestId: string,
    input: OfferReviewSlotsDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    this.adminAccess.assertReviewFeatureEnabled();
    const preflight = await this.loadScopedReview(reviewRequestId);
    if (!preflight) throw new NotFoundException('Review request not found.');
    await this.adminAccess.assertCanReadDetail(actor, preflight);
    await this.adminAccess.assertCanOfferSlots(actor, preflight);
    const actorCounsellorId =
      actor.role === InternalRole.Counselor
        ? (await this.adminAccess.resolveCounsellor(actor)).id
        : null;
    const expiresAt = this.parseExplicitDate(input.expiresAt, 'Offer expiry');

    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'admin',
              actorId: actor.id,
              operation: `study-review.slot-offers:${reviewRequestId}`,
              idempotencyKey,
              payload: input,
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return this.deserializeOfferReplay(
              reservation.responseSnapshot,
              reservation.responseCode,
            );
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();

          await tx.$queryRaw(
            Prisma.sql`SELECT "id" FROM "StudyReviewRequest" WHERE "id" = ${reviewRequestId} FOR UPDATE`,
          );
          const current = await tx.studyReviewRequest.findUnique({
            where: { id: reviewRequestId },
            select: scopedReviewSelect,
          });
          if (!current) throw new NotFoundException('Review request not found.');
          if (
            actorCounsellorId &&
            current.assignedCounsellorId !== actorCounsellorId
          ) {
            throw this.forbiddenScope();
          }
          if (current.version !== input.expectedVersion) {
            throw versionConflict(current.version);
          }
          if (
            !['triaged', 'call_offered', 'scheduled'].includes(current.status) ||
            !current.assignedCounsellorId
          ) {
            throw this.reviewNotTriaged();
          }

          const now = new Date();
          if (
            expiresAt <= now ||
            expiresAt.getTime() - now.getTime() > MAX_OFFER_LIFETIME_MS
          ) {
            throw new BadRequestException(
              'Offer expiry must be future and within 30 days.',
            );
          }
          const slots = await tx.counsellorAvailabilitySlot.findMany({
            where: { id: { in: input.slotIds } },
            include: { counsellor: { select: { fullName: true } } },
          });
          const slotsById = new Map(slots.map((slot) => [slot.id, slot]));
          const orderedSlots = input.slotIds.map((slotId) => slotsById.get(slotId));
          if (
            orderedSlots.some(
              (slot) =>
                !slot ||
                slot.counsellorId !== current.assignedCounsellorId ||
                slot.status !== 'available' ||
                slot.startsAt <= now ||
                slot.bookedCount >= slot.capacity,
            )
          ) {
            throw this.slotTaken('One or more slots are no longer available.');
          }
          const validSlots = orderedSlots.filter(
            (slot): slot is NonNullable<typeof slot> => Boolean(slot),
          );
          const consumedOfferCount = await tx.appointment.count({
            where: {
              reviewRequestId,
              slotId: { in: input.slotIds },
              slotOfferId: { not: null },
            },
          });
          if (consumedOfferCount > 0) {
            throw this.slotTaken(
              'A previously booked slot cannot be offered again for this review.',
            );
          }
          if (validSlots.some((slot) => expiresAt >= slot.startsAt)) {
            throw new BadRequestException(
              'Offer expiry must be before every offered slot.',
            );
          }

          if (['call_offered', 'scheduled'].includes(current.status)) {
            const activeOfferCount = await tx.studyReviewSlotOffer.count({
              where: {
                reviewRequestId,
                status: 'offered',
                expiresAt: { gt: now },
              },
            });
            if (activeOfferCount > 0) {
              throw new CompetitionReadinessHttpException(
                'FORBIDDEN_SCOPE',
                409,
                'Active slot offers must expire before replacement.',
              );
            }
            await tx.studyReviewSlotOffer.updateMany({
              where: {
                reviewRequestId,
                status: 'offered',
                expiresAt: { lte: now },
              },
              data: { status: 'expired', selectedAt: null },
            });
          }

          const offers = [];
          for (const slot of validSlots) {
            const offer = await tx.studyReviewSlotOffer.upsert({
              where: {
                reviewRequestId_slotId: {
                  reviewRequestId,
                  slotId: slot.id,
                },
              },
              create: {
                reviewRequestId,
                slotId: slot.id,
                offeredAt: now,
                expiresAt,
              },
              update: {
                offeredAt: now,
                expiresAt,
                status: 'offered',
                selectedAt: null,
              },
            });
            offers.push({
              id: offer.id,
              slotId: slot.id,
              startsAt: slot.startsAt.toISOString(),
              endsAt: slot.endsAt.toISOString(),
              timezone: slot.timezone,
              expiresAt: offer.expiresAt.toISOString(),
              counsellorName: slot.counsellor.fullName,
            });
          }

          const nextStatus =
            current.status === 'scheduled' ? 'scheduled' : 'call_offered';
          const transitioned = await tx.studyReviewRequest.updateMany({
            where: {
              id: reviewRequestId,
              version: input.expectedVersion,
              status: current.status,
              assignedCounsellorId: current.assignedCounsellorId,
            },
            data: { status: nextStatus, version: { increment: 1 } },
          });
          if (transitioned.count !== 1) {
            const latest = await tx.studyReviewRequest.findUnique({
              where: { id: reviewRequestId },
              select: { version: true },
            });
            throw versionConflict(latest?.version ?? current.version);
          }
          const nextVersion = current.version + 1;
          await tx.adminAuditEvent.create({
            data: {
              actorAdminId: actor.id,
              action: 'study_review.slot_offers_created',
              purposeCode: 'review_scheduling',
              entityType: 'StudyReviewRequest',
              entityId: reviewRequestId,
              requestId,
              reasonCode: input.reasonCode,
              result: 'success',
              changes: {
                previousVersion: current.version,
                nextVersion,
                slotIds: input.slotIds,
                expiresAt: expiresAt.toISOString(),
              },
            },
          });
          await this.outbox.enqueue(
            {
              eventId: `study_review.slot_offered:${reviewRequestId}:${nextVersion}`,
              eventName: 'study_review.slot_offered',
              aggregateType: 'StudyReviewRequest',
              aggregateId: reviewRequestId,
              occurredAt: now,
              payload: {
                reviewRequestId,
                workspaceId: current.workspace.id,
                userId: current.workspace.userId,
                version: nextVersion,
                slotOfferIds: offers.map((offer) => offer.id),
                expiresAt: expiresAt.toISOString(),
              },
            },
            tx,
          );
          const snapshot = {
            reviewRequestId,
            version: nextVersion,
            status: nextStatus,
            offers,
          };
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: snapshot,
              resourceType: 'StudyReviewRequest',
              resourceId: reviewRequestId,
              resultingVersion: nextVersion,
            },
            tx,
          );
          return { statusCode: 201, snapshot };
        }),
      );
      if (!result) throw databaseUnavailable();
      // The admin client already consumes a direct ReviewRequestDetail. Keeping
      // that response shape avoids a breaking wrapper while the idempotency
      // record protects the scheduling effect itself.
      return {
        statusCode: result.statusCode,
        body: await this.adminReviews.getDetail(actor, reviewRequestId),
      };
    } catch (error) {
      this.translateInfrastructureError(error);
    }
  }

  async listOfferedSlots(userId: string, reviewRequestId: string) {
    this.assertDb();
    await this.assertStudentAccess(userId);
    const now = new Date();
    const review = await this.prismaService.execute((prisma) =>
      prisma.studyReviewRequest.findFirst({
        where: { id: reviewRequestId, workspace: { userId } },
        select: {
          id: true,
          version: true,
          status: true,
          timezone: true,
          assignedCounsellorId: true,
          slotOffers: {
            where: { status: 'offered', expiresAt: { gt: now } },
            orderBy: [{ slot: { startsAt: 'asc' } }, { id: 'asc' }],
            include: {
              slot: {
                include: { counsellor: { select: { fullName: true } } },
              },
            },
          },
        },
      }),
    );
    if (!review) throw workspaceNotFound();
    const offers =
      ['call_offered', 'scheduled'].includes(review.status)
        ? review.slotOffers
            .filter(
              (offer) =>
                offer.slot.counsellorId === review.assignedCounsellorId &&
                offer.slot.status === 'available' &&
                offer.slot.startsAt > now &&
                offer.slot.bookedCount < offer.slot.capacity,
            )
            .map((offer) => ({
              slotOfferId: offer.id,
              slotId: offer.slotId,
              startsAt: offer.slot.startsAt.toISOString(),
              endsAt: offer.slot.endsAt.toISOString(),
              timezone: offer.slot.timezone,
              expiresAt: offer.expiresAt.toISOString(),
              counsellorName: offer.slot.counsellor.fullName,
            }))
        : [];
    return {
      reviewRequestId: review.id,
      reviewRequestVersion: review.version,
      timezone: review.timezone,
      offers,
    };
  }

  async book(
    userId: string,
    reviewRequestId: string,
    input: BookStudyReviewAppointmentDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    await this.assertStudentAccess(userId);
    this.assertTimezone(input.timezone);
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'student',
              actorId: userId,
              operation: `study-review.appointment:${reviewRequestId}`,
              idempotencyKey,
              payload: input,
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return this.deserializeBookingReplay(
              reservation.responseSnapshot,
              reservation.responseCode,
            );
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();

          await tx.$queryRaw(
            Prisma.sql`SELECT "id" FROM "StudyReviewRequest" WHERE "id" = ${reviewRequestId} FOR UPDATE`,
          );
          const review = await tx.studyReviewRequest.findUnique({
            where: { id: reviewRequestId },
            select: scopedReviewSelect,
          });
          if (!review || review.workspace.userId !== userId) {
            throw workspaceNotFound();
          }

          const byBookingKey = await tx.appointment.findUnique({
            where: { bookingKey: input.bookingKey },
          });
          if (byBookingKey) {
            if (
              byBookingKey.userId !== userId ||
              byBookingKey.reviewRequestId !== reviewRequestId ||
              byBookingKey.slotOfferId !== input.slotOfferId ||
              byBookingKey.timezone !== input.timezone
            ) {
              throw idempotencyPayloadMismatch();
            }
            const response = this.bookingResponse(byBookingKey, review);
            await this.idempotency.complete(
              {
                recordId: reservation.recordId,
                responseCode: 200,
                responseSnapshot: response,
                resourceType: 'Appointment',
                resourceId: byBookingKey.id,
                resultingVersion: review.version,
              },
              tx,
            );
            return { statusCode: 200, body: response };
          }

          if (review.version !== input.expectedVersion) {
            throw versionConflict(review.version);
          }
          if (
            review.status !== 'call_offered' ||
            !review.assignedCounsellorId
          ) {
            throw this.reviewNotTriaged();
          }
          const offer = await tx.studyReviewSlotOffer.findUnique({
            where: { id: input.slotOfferId },
            include: { slot: true },
          });
          if (!offer || offer.reviewRequestId !== reviewRequestId) {
            throw this.noSlotOffered();
          }
          const now = new Date();
          if (offer.expiresAt <= now) throw this.slotOfferExpired();
          if (offer.status !== 'offered') {
            throw this.slotTaken('This slot offer is no longer selectable.');
          }
          if (input.timezone !== offer.slot.timezone) {
            throw new BadRequestException(
              'Appointment timezone must match the offered slot timezone.',
            );
          }
          if (
            offer.slot.counsellorId !== review.assignedCounsellorId ||
            offer.slot.status !== 'available' ||
            offer.slot.startsAt <= now ||
            offer.slot.bookedCount >= offer.slot.capacity
          ) {
            throw this.slotTaken('This slot is no longer available.');
          }

          const transitioned = await tx.studyReviewRequest.updateMany({
            where: {
              id: reviewRequestId,
              version: input.expectedVersion,
              status: 'call_offered',
              assignedCounsellorId: review.assignedCounsellorId,
            },
            data: { status: 'scheduled', version: { increment: 1 } },
          });
          if (transitioned.count !== 1) {
            const latest = await tx.studyReviewRequest.findUnique({
              where: { id: reviewRequestId },
              select: { version: true },
            });
            throw versionConflict(latest?.version ?? review.version);
          }

          const claimed = await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`
              UPDATE "CounsellorAvailabilitySlot"
              SET
                "bookedCount" = "bookedCount" + 1,
                "status" = CASE
                  WHEN "bookedCount" + 1 >= "capacity"
                  THEN 'exhausted'::"AvailabilitySlotStatus"
                  ELSE "status"
                END,
                "version" = "version" + 1,
                "updatedAt" = ${utcTimestamp(now)}
              WHERE "id" = ${offer.slotId}
                AND "status" = 'available'::"AvailabilitySlotStatus"
                AND "bookedCount" < "capacity"
                AND "startsAt" > ${utcTimestamp(now)}
              RETURNING "id"
            `,
          );
          if (claimed.length !== 1) {
            throw this.slotTaken('This slot is no longer available.');
          }

          const selected = await tx.studyReviewSlotOffer.updateMany({
            where: { id: offer.id, status: 'offered', expiresAt: { gt: now } },
            data: { status: 'selected', selectedAt: now },
          });
          if (selected.count !== 1) {
            throw this.slotTaken('This slot offer is no longer selectable.');
          }
          await tx.studyReviewSlotOffer.updateMany({
            where: {
              reviewRequestId,
              id: { not: offer.id },
              status: 'offered',
            },
            data: { status: 'withdrawn', selectedAt: null },
          });

          const appointment = await tx.appointment.create({
            data: {
              userId,
              title: 'Study review call',
              goal: 'Review scholarship application',
              startsAt: offer.slot.startsAt,
              endsAt: offer.slot.endsAt,
              timezone: offer.slot.timezone,
              status: 'scheduled',
              contactMethod: review.preferredContact ?? 'in_app',
              counsellorId: review.assignedCounsellorId,
              reviewRequestId,
              slotId: offer.slotId,
              slotOfferId: offer.id,
              bookingKey: input.bookingKey,
            },
          });
          await tx.scholarshipWorkspace.update({
            where: { id: review.workspace.id },
            data: { lastActivityAt: now, version: { increment: 1 } },
          });
          const nextReview = { ...review, version: review.version + 1, status: 'scheduled' };
          const response = this.bookingResponse(appointment, nextReview);
          await tx.adminAuditEvent.create({
            data: {
              actorAdminId: null,
              action: 'study_review.appointment_booked',
              purposeCode: 'review_scheduling',
              entityType: 'StudyReviewRequest',
              entityId: reviewRequestId,
              requestId,
              result: 'success',
              changes: {
                appointmentId: appointment.id,
                slotId: offer.slotId,
                slotOfferId: offer.id,
                previousVersion: review.version,
                nextVersion: review.version + 1,
              },
            },
          });
          await this.outbox.enqueue(
            {
              eventId: `study_review.appointment_booked:${appointment.id}`,
              eventName: 'study_review.appointment_booked',
              aggregateType: 'StudyReviewRequest',
              aggregateId: reviewRequestId,
              occurredAt: now,
              payload: {
                reviewRequestId,
                workspaceId: review.workspace.id,
                userId,
                appointmentId: appointment.id,
                slotId: offer.slotId,
                slotOfferId: offer.id,
                counsellorId: review.assignedCounsellorId,
                version: review.version + 1,
              },
            },
            tx,
          );
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: response,
              resourceType: 'Appointment',
              resourceId: appointment.id,
              resultingVersion: review.version + 1,
            },
            tx,
          );
          return { statusCode: 201, body: response };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      if (this.isBookingConstraintConflict(error)) {
        throw this.slotTaken('This slot is no longer available.');
      }
      this.translateInfrastructureError(error);
    }
  }

  async cancel(
    userId: string,
    appointmentId: string,
    input: CancelStudyReviewAppointmentDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    await this.assertStudentAccess(userId);
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'student',
              actorId: userId,
              operation: `study-review.appointment.cancel:${appointmentId}`,
              idempotencyKey,
              payload: input,
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return this.deserializeBookingReplay(
              reservation.responseSnapshot,
              reservation.responseCode,
            );
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();

          const owned = await tx.$queryRaw<
            Array<{ id: string; reviewRequestId: string }>
          >(
            Prisma.sql`
              SELECT "id", "reviewRequestId"
              FROM "Appointment"
              WHERE "id" = ${appointmentId}
                AND "userId" = ${userId}
                AND "reviewRequestId" IS NOT NULL
              FOR UPDATE
            `,
          );
          if (owned.length !== 1) throw workspaceNotFound();
          const reviewRequestId = owned[0].reviewRequestId;
          await tx.$queryRaw(
            Prisma.sql`SELECT "id" FROM "StudyReviewRequest" WHERE "id" = ${reviewRequestId} FOR UPDATE`,
          );
          const [review, appointment] = await Promise.all([
            tx.studyReviewRequest.findUnique({
              where: { id: reviewRequestId },
              select: scopedReviewSelect,
            }),
            tx.appointment.findUnique({ where: { id: appointmentId } }),
          ]);
          if (
            !review ||
            review.workspace.userId !== userId ||
            !appointment ||
            appointment.userId !== userId ||
            appointment.reviewRequestId !== reviewRequestId
          ) {
            throw workspaceNotFound();
          }
          if (review.version !== input.expectedVersion) {
            throw versionConflict(review.version);
          }
          const now = new Date();
          this.assertMutableAppointment(appointment, review.status, now, false);

          const transitioned = await tx.studyReviewRequest.updateMany({
            where: {
              id: reviewRequestId,
              version: input.expectedVersion,
              status: 'scheduled',
            },
            data: { status: 'triaged', version: { increment: 1 } },
          });
          if (transitioned.count !== 1) {
            const latest = await tx.studyReviewRequest.findUnique({
              where: { id: reviewRequestId },
              select: { version: true },
            });
            throw versionConflict(latest?.version ?? review.version);
          }
          const cancelled = await tx.appointment.updateMany({
            where: {
              id: appointmentId,
              userId,
              reviewRequestId,
              status: { in: [...MUTABLE_APPOINTMENT_STATUSES] },
            },
            data: { status: 'cancelled' },
          });
          if (cancelled.count !== 1) throw this.appointmentNotChangeable();
          await this.releaseSlotCapacity(tx, appointment.slotId!, now);
          await tx.studyReviewSlotOffer.updateMany({
            where: { reviewRequestId, status: 'offered' },
            data: { status: 'withdrawn', selectedAt: null },
          });
          await tx.scholarshipWorkspace.update({
            where: { id: review.workspace.id },
            data: { lastActivityAt: now, version: { increment: 1 } },
          });
          const cancelledAppointment = await tx.appointment.findUnique({
            where: { id: appointmentId },
          });
          if (!cancelledAppointment) throw databaseUnavailable();
          const nextReview = {
            ...review,
            version: review.version + 1,
            status: 'triaged',
          };
          const response = this.bookingResponse(
            cancelledAppointment,
            nextReview,
          );
          await tx.adminAuditEvent.create({
            data: {
              actorAdminId: null,
              action: 'study_review.appointment_cancelled',
              purposeCode: 'review_scheduling',
              entityType: 'Appointment',
              entityId: appointmentId,
              requestId,
              reasonCode: input.reasonCode,
              result: 'success',
              changes: {
                reviewRequestId,
                slotId: appointment.slotId,
                previousReviewVersion: review.version,
                nextReviewVersion: review.version + 1,
              },
            },
          });
          await this.outbox.enqueue(
            {
              eventId: `study_review.appointment_cancelled:${appointmentId}:${review.version + 1}`,
              eventName: 'study_review.appointment_cancelled',
              aggregateType: 'StudyReviewRequest',
              aggregateId: reviewRequestId,
              occurredAt: now,
              payload: {
                reviewRequestId,
                workspaceId: review.workspace.id,
                userId,
                appointmentId,
                slotId: appointment.slotId,
                version: review.version + 1,
              },
            },
            tx,
          );
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 200,
              responseSnapshot: response,
              resourceType: 'Appointment',
              resourceId: appointmentId,
              resultingVersion: review.version + 1,
            },
            tx,
          );
          return { statusCode: 200, body: response };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      this.translateInfrastructureError(error);
    }
  }

  async reschedule(
    userId: string,
    appointmentId: string,
    input: RescheduleStudyReviewAppointmentDto,
    idempotencyKey: string,
    requestId: string,
  ) {
    this.assertDb();
    await this.assertStudentAccess(userId);
    this.assertTimezone(input.timezone);
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'student',
              actorId: userId,
              operation: `study-review.appointment.reschedule:${appointmentId}`,
              idempotencyKey,
              payload: input,
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return this.deserializeBookingReplay(
              reservation.responseSnapshot,
              reservation.responseCode,
            );
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();

          const owned = await tx.$queryRaw<
            Array<{ id: string; reviewRequestId: string }>
          >(
            Prisma.sql`
              SELECT "id", "reviewRequestId"
              FROM "Appointment"
              WHERE "id" = ${appointmentId}
                AND "userId" = ${userId}
                AND "reviewRequestId" IS NOT NULL
              FOR UPDATE
            `,
          );
          if (owned.length !== 1) throw workspaceNotFound();
          const reviewRequestId = owned[0].reviewRequestId;
          await tx.$queryRaw(
            Prisma.sql`SELECT "id" FROM "StudyReviewRequest" WHERE "id" = ${reviewRequestId} FOR UPDATE`,
          );
          const [review, appointment, byBookingKey] = await Promise.all([
            tx.studyReviewRequest.findUnique({
              where: { id: reviewRequestId },
              select: scopedReviewSelect,
            }),
            tx.appointment.findUnique({ where: { id: appointmentId } }),
            tx.appointment.findUnique({
              where: { bookingKey: input.bookingKey },
            }),
          ]);
          if (
            !review ||
            review.workspace.userId !== userId ||
            !appointment ||
            appointment.userId !== userId ||
            appointment.reviewRequestId !== reviewRequestId
          ) {
            throw workspaceNotFound();
          }
          if (byBookingKey) {
            if (
              byBookingKey.id === appointmentId ||
              byBookingKey.userId !== userId ||
              byBookingKey.reviewRequestId !== reviewRequestId ||
              byBookingKey.slotOfferId !== input.slotOfferId ||
              byBookingKey.timezone !== input.timezone
            ) {
              throw idempotencyPayloadMismatch();
            }
            const response = {
              ...this.bookingResponse(byBookingKey, review),
              previousAppointmentId: appointmentId,
            };
            await this.idempotency.complete(
              {
                recordId: reservation.recordId,
                responseCode: 200,
                responseSnapshot: response,
                resourceType: 'Appointment',
                resourceId: byBookingKey.id,
                resultingVersion: review.version,
              },
              tx,
            );
            return { statusCode: 200, body: response };
          }
          if (review.version !== input.expectedVersion) {
            throw versionConflict(review.version);
          }
          const now = new Date();
          this.assertMutableAppointment(appointment, review.status, now, true);
          const offer = await tx.studyReviewSlotOffer.findUnique({
            where: { id: input.slotOfferId },
            include: { slot: true, appointment: { select: { id: true } } },
          });
          if (!offer || offer.reviewRequestId !== reviewRequestId) {
            throw this.noSlotOffered();
          }
          if (offer.appointment) {
            throw this.slotTaken('This slot offer was already consumed.');
          }
          if (offer.expiresAt <= now) throw this.slotOfferExpired();
          if (offer.status !== 'offered') {
            throw this.slotTaken('This slot offer is no longer selectable.');
          }
          if (input.timezone !== offer.slot.timezone) {
            throw new BadRequestException(
              'Appointment timezone must match the offered slot timezone.',
            );
          }
          if (
            !review.assignedCounsellorId ||
            offer.slot.counsellorId !== review.assignedCounsellorId ||
            offer.slot.status !== 'available' ||
            offer.slot.startsAt.getTime() - now.getTime() <
              MIN_RESCHEDULE_NOTICE_MS ||
            offer.slot.bookedCount >= offer.slot.capacity ||
            offer.slotId === appointment.slotId
          ) {
            throw this.slotTaken('The replacement slot is not available.');
          }

          const transitioned = await tx.studyReviewRequest.updateMany({
            where: {
              id: reviewRequestId,
              version: input.expectedVersion,
              status: 'scheduled',
              assignedCounsellorId: review.assignedCounsellorId,
            },
            data: { status: 'scheduled', version: { increment: 1 } },
          });
          if (transitioned.count !== 1) {
            const latest = await tx.studyReviewRequest.findUnique({
              where: { id: reviewRequestId },
              select: { version: true },
            });
            throw versionConflict(latest?.version ?? review.version);
          }
          const cancelled = await tx.appointment.updateMany({
            where: {
              id: appointmentId,
              userId,
              reviewRequestId,
              status: { in: [...MUTABLE_APPOINTMENT_STATUSES] },
            },
            data: { status: 'cancelled' },
          });
          if (cancelled.count !== 1) throw this.appointmentNotChangeable();
          await this.releaseSlotCapacity(tx, appointment.slotId!, now);
          const claimed = await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`
              UPDATE "CounsellorAvailabilitySlot"
              SET
                "bookedCount" = "bookedCount" + 1,
                "status" = CASE
                  WHEN "bookedCount" + 1 >= "capacity"
                  THEN 'exhausted'::"AvailabilitySlotStatus"
                  ELSE "status"
                END,
                "version" = "version" + 1,
                "updatedAt" = ${utcTimestamp(now)}
              WHERE "id" = ${offer.slotId}
                AND "status" = 'available'::"AvailabilitySlotStatus"
                AND "bookedCount" < "capacity"
                AND "startsAt" > ${utcTimestamp(now)}
              RETURNING "id"
            `,
          );
          if (claimed.length !== 1) {
            throw this.slotTaken('The replacement slot is no longer available.');
          }
          const selected = await tx.studyReviewSlotOffer.updateMany({
            where: { id: offer.id, status: 'offered', expiresAt: { gt: now } },
            data: { status: 'selected', selectedAt: now },
          });
          if (selected.count !== 1) {
            throw this.slotTaken('This slot offer is no longer selectable.');
          }
          await tx.studyReviewSlotOffer.updateMany({
            where: {
              reviewRequestId,
              id: { not: offer.id },
              status: 'offered',
            },
            data: { status: 'withdrawn', selectedAt: null },
          });
          const replacement = await tx.appointment.create({
            data: {
              userId,
              caseId: appointment.caseId,
              title: appointment.title,
              goal: appointment.goal,
              startsAt: offer.slot.startsAt,
              endsAt: offer.slot.endsAt,
              timezone: offer.slot.timezone,
              status: 'scheduled',
              contactMethod: appointment.contactMethod,
              notes: appointment.notes,
              counsellorId: review.assignedCounsellorId,
              reviewRequestId,
              slotId: offer.slotId,
              slotOfferId: offer.id,
              bookingKey: input.bookingKey,
            },
          });
          await tx.scholarshipWorkspace.update({
            where: { id: review.workspace.id },
            data: { lastActivityAt: now, version: { increment: 1 } },
          });
          const nextReview = {
            ...review,
            version: review.version + 1,
            status: 'scheduled',
          };
          const response = {
            ...this.bookingResponse(replacement, nextReview),
            previousAppointmentId: appointmentId,
          };
          await tx.adminAuditEvent.create({
            data: {
              actorAdminId: null,
              action: 'study_review.appointment_rescheduled',
              purposeCode: 'review_scheduling',
              entityType: 'Appointment',
              entityId: replacement.id,
              requestId,
              reasonCode: input.reasonCode,
              result: 'success',
              changes: {
                previousAppointmentId: appointmentId,
                previousSlotId: appointment.slotId,
                replacementSlotId: offer.slotId,
                slotOfferId: offer.id,
                previousReviewVersion: review.version,
                nextReviewVersion: review.version + 1,
              },
            },
          });
          await this.outbox.enqueue(
            {
              eventId: `study_review.appointment_rescheduled:${appointmentId}:${replacement.id}`,
              eventName: 'study_review.appointment_rescheduled',
              aggregateType: 'StudyReviewRequest',
              aggregateId: reviewRequestId,
              occurredAt: now,
              payload: {
                reviewRequestId,
                workspaceId: review.workspace.id,
                userId,
                previousAppointmentId: appointmentId,
                appointmentId: replacement.id,
                previousSlotId: appointment.slotId,
                slotId: offer.slotId,
                slotOfferId: offer.id,
                counsellorId: review.assignedCounsellorId,
                version: review.version + 1,
              },
            },
            tx,
          );
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 200,
              responseSnapshot: response,
              resourceType: 'Appointment',
              resourceId: replacement.id,
              resultingVersion: review.version + 1,
            },
            tx,
          );
          return { statusCode: 200, body: response };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      if (this.isBookingConstraintConflict(error)) {
        throw this.slotTaken('The replacement slot is no longer available.');
      }
      this.translateInfrastructureError(error);
    }
  }

  private assertMutableAppointment(
    appointment: { status: string; startsAt: Date; slotId: string | null },
    reviewStatus: string,
    now: Date,
    requireRescheduleNotice: boolean,
  ) {
    if (
      reviewStatus !== 'scheduled' ||
      !MUTABLE_APPOINTMENT_STATUSES.includes(
        appointment.status as (typeof MUTABLE_APPOINTMENT_STATUSES)[number],
      ) ||
      !appointment.slotId
    ) {
      throw this.appointmentNotChangeable();
    }
    if (appointment.startsAt <= now) {
      throw new BadRequestException(
        'Past or started appointments can no longer be changed.',
      );
    }
    if (
      requireRescheduleNotice &&
      appointment.startsAt.getTime() - now.getTime() <
        MIN_RESCHEDULE_NOTICE_MS
    ) {
      throw new BadRequestException(
        'Appointments can only be rescheduled at least 60 minutes before start.',
      );
    }
  }

  private async releaseSlotCapacity(
    tx: Prisma.TransactionClient,
    slotId: string,
    now: Date,
  ) {
    const released = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        UPDATE "CounsellorAvailabilitySlot"
        SET
          "bookedCount" = "bookedCount" - 1,
          "status" = CASE
            WHEN "status" = 'exhausted'::"AvailabilitySlotStatus"
            THEN 'available'::"AvailabilitySlotStatus"
            ELSE "status"
          END,
          "version" = "version" + 1,
          "updatedAt" = ${utcTimestamp(now)}
        WHERE "id" = ${slotId}
          AND "bookedCount" > 0
        RETURNING "id"
      `,
    );
    if (released.length !== 1) {
      throw this.slotTaken('Appointment capacity could not be released.');
    }
  }

  private async loadScopedReview(id: string): Promise<ScopedReview | null> {
    const result = await this.prismaService.execute((prisma) =>
      prisma.studyReviewRequest.findUnique({
        where: { id },
        select: scopedReviewSelect,
      }),
    );
    return result ?? null;
  }

  private bookingResponse(
    appointment: {
      id: string;
      reviewRequestId: string | null;
      slotOfferId: string | null;
      slotId: string | null;
      counsellorId: string | null;
      startsAt: Date;
      endsAt: Date | null;
      timezone: string | null;
      status: string;
      contactMethod: string;
      createdAt: Date;
    },
    review: { id: string; version: number; status: string },
  ) {
    return {
      appointment: {
        id: appointment.id,
        reviewRequestId: appointment.reviewRequestId,
        slotOfferId: appointment.slotOfferId,
        slotId: appointment.slotId,
        counsellorId: appointment.counsellorId,
        startsAt: appointment.startsAt.toISOString(),
        endsAt: appointment.endsAt?.toISOString() ?? null,
        timezone: appointment.timezone,
        status: appointment.status,
        contactMethod: appointment.contactMethod,
        createdAt: appointment.createdAt.toISOString(),
      },
      reviewRequest: {
        id: review.id,
        version: review.version,
        status: review.status,
      },
    };
  }

  private deserializeOfferReplay(
    snapshot: Prisma.JsonValue | null,
    statusCode: number | null,
  ) {
    if (
      !snapshot ||
      Array.isArray(snapshot) ||
      typeof snapshot !== 'object' ||
      typeof snapshot.reviewRequestId !== 'string' ||
      ![200, 201].includes(statusCode ?? 0)
    ) {
      throw databaseUnavailable();
    }
    return { statusCode: statusCode as 200 | 201, snapshot };
  }

  private deserializeBookingReplay(
    snapshot: Prisma.JsonValue | null,
    statusCode: number | null,
  ) {
    if (
      !snapshot ||
      Array.isArray(snapshot) ||
      typeof snapshot !== 'object' ||
      !snapshot.appointment ||
      !snapshot.reviewRequest ||
      ![200, 201].includes(statusCode ?? 0)
    ) {
      throw databaseUnavailable();
    }
    return { statusCode: statusCode as 200 | 201, body: snapshot };
  }

  private parseExplicitDate(value: string, label: string): Date {
    if (!/(?:Z|[+-]\d{2}:\d{2})$/.test(value)) {
      throw new BadRequestException(`${label} requires an explicit UTC offset.`);
    }
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException(`${label} is invalid.`);
    }
    return date;
  }

  private assertTimezone(timezone: string) {
    try {
      new Intl.DateTimeFormat('en-US', { timeZone: timezone }).format();
    } catch {
      throw new BadRequestException('Invalid IANA timezone.');
    }
  }

  private async assertStudentAccess(userId: string) {
    if (process.env.KPB_STUDY_REVIEW_ENABLED?.trim().toLowerCase() !== 'true') {
      throw featureDisabled('study_review');
    }
    const decision = await this.featureAccess.evaluate({
      feature: 'success_lab',
      userId,
    });
    if (!decision.allowed) throw featureDisabled('success_lab');
  }

  private noSlotOffered() {
    return new CompetitionReadinessHttpException(
      'NO_SLOT_OFFERED',
      404,
      'No selectable slot offer was found.',
    );
  }

  private slotOfferExpired() {
    return new CompetitionReadinessHttpException(
      'SLOT_OFFER_EXPIRED',
      409,
      'The selected slot offer has expired.',
    );
  }

  private slotTaken(message: string) {
    return new CompetitionReadinessHttpException('SLOT_TAKEN', 409, message);
  }

  private reviewNotTriaged() {
    return new CompetitionReadinessHttpException(
      'REVIEW_REQUEST_NOT_TRIAGED',
      409,
      'The review request is not ready for scheduling.',
    );
  }

  private appointmentNotChangeable() {
    return new CompetitionReadinessHttpException(
      'REVIEW_REQUEST_NOT_TRIAGED',
      409,
      'This appointment can no longer be changed.',
    );
  }

  private forbiddenScope() {
    return new CompetitionReadinessHttpException(
      'FORBIDDEN_SCOPE',
      403,
      'This operator cannot offer slots for this review request.',
    );
  }

  private isBookingConstraintConflict(error: unknown): boolean {
    if (!(error instanceof Prisma.PrismaClientKnownRequestError)) return false;
    if (error.code !== 'P2002') return false;
    const detail = JSON.stringify(error.meta ?? {});
    return [
      'Appointment_bookingKey_key',
      'Appointment_slotOfferId_key',
      'one_active_appointment_per_review_request',
      'bookingKey',
      'slotOfferId',
      'reviewRequestId',
    ].some((marker) => detail.includes(marker));
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }

  private translateInfrastructureError(error: unknown): never {
    if (error instanceof IdempotencyPayloadMismatchError) {
      throw idempotencyPayloadMismatch();
    }
    if (error instanceof IdempotencyStorageUnavailableError) {
      throw databaseUnavailable();
    }
    if (error instanceof DomainEventConflictError) throw outboxEventConflict();
    if (error instanceof DomainEventOutboxUnavailableError) {
      throw databaseUnavailable();
    }
    throw error;
  }
}
