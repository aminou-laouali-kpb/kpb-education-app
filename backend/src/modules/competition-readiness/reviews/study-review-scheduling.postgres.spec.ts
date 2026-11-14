import { randomUUID } from "node:crypto";

import { PrismaClient } from "@prisma/client";

import {
  allowAllFeatures,
  cleanupFixtures,
  createAdultStudent,
  createWorkspace,
  describePostgres,
  realPrismaService,
  withEnv,
} from "../common/advisory-lock.postgres-fixtures";
import { DomainEventOutboxService } from "../common/domain-event-outbox.service";
import { IdempotencyService } from "../common/idempotency.service";
import type { AdminReviewAccessService } from "../admin/admin-review-access.service";
import type { AdminReviewOperationsService } from "../admin/admin-review-operations.service";
import { StudyReviewSchedulingService } from "./study-review-scheduling.service";

const HOUR = 60 * 60_000;

/**
 * Prise et annulation de rendez-vous sur un vrai Postgres. Le créneau est
 * réservé par du SQL brut qui compare `startsAt` (colonne sans fuseau, en UTC)
 * à « maintenant » et écrit `updatedAt`. Lancée avec KPB_POSTGRES_TEST_TIMEZONE
 * décalé (la CI : UTC+14), cette spec prouve que ni la comparaison ni l'écriture
 * ne dépendent du fuseau de la base : sans `AT TIME ZONE 'UTC'`, en UTC+14, un
 * créneau qui commence dans deux heures passait pour déjà commencé.
 *
 *   DATABASE_URL=… npm run test:integration:advisory-locks
 */
describePostgres("rendez-vous de relecture — créneaux, PostgreSQL", () => {
  const prisma = new PrismaClient();
  const s = randomUUID();
  const ids = {
    userId: `tz-review-user-${s}`,
    scholarship: `tz-review-sch-${s}`,
    cycle: `tz-review-cyc-${s}`,
    workspace: `tz-review-ws-${s}`,
    counsellor: `tz-review-csl-${s}`,
    review: `tz-review-req-${s}`,
    slot: `tz-review-slot-${s}`,
    offer: `tz-review-offer-${s}`,
  };
  const prismaService = realPrismaService(prisma);
  // La prise et l'annulation par l'élève ne passent pas par les services admin.
  const service = new StudyReviewSchedulingService(
    prismaService,
    allowAllFeatures,
    new IdempotencyService(prismaService),
    new DomainEventOutboxService(prismaService),
    {} as AdminReviewAccessService,
    {} as AdminReviewOperationsService,
  );
  const startsAt = new Date(Date.now() + 2 * HOUR);
  let restoreEnv: () => void;

  beforeAll(async () => {
    restoreEnv = withEnv({ KPB_STUDY_REVIEW_ENABLED: "true" });
    await createAdultStudent(prisma, ids.userId);
    await createWorkspace(prisma, ids);
    await prisma.counsellor.create({
      data: {
        id: ids.counsellor,
        fullName: "Conseiller Test",
        email: `${ids.counsellor}@example.test`,
        phone: "+2250700000001",
        countryOfResidence: "CI",
        bioFr: "Test",
        bioEn: "Test",
        isActive: true,
      },
    });
    await prisma.studyReviewRequest.create({
      data: {
        id: ids.review,
        workspaceId: ids.workspace,
        requestNumber: 1,
        status: "call_offered",
        assignedCounsellorId: ids.counsellor,
      },
    });
    await prisma.counsellorAvailabilitySlot.create({
      data: {
        id: ids.slot,
        counsellorId: ids.counsellor,
        startsAt,
        endsAt: new Date(startsAt.getTime() + HOUR),
        timezone: "Africa/Abidjan",
      },
    });
    await prisma.studyReviewSlotOffer.create({
      data: {
        id: ids.offer,
        reviewRequestId: ids.review,
        slotId: ids.slot,
        expiresAt: new Date(Date.now() + HOUR),
      },
    });
  });

  afterAll(async () => {
    restoreEnv();
    await prisma.idempotencyRecord.deleteMany({
      where: { actorId: ids.userId },
    });
    await prisma.domainEventOutbox.deleteMany({
      where: { aggregateId: ids.review },
    });
    await prisma.adminAuditEvent.deleteMany({
      where: { entityId: ids.review },
    });
    await prisma.appointment.deleteMany({ where: { userId: ids.userId } });
    await prisma.studyReviewSlotOffer.deleteMany({
      where: { reviewRequestId: ids.review },
    });
    await prisma.counsellorAvailabilitySlot.deleteMany({
      where: { id: ids.slot },
    });
    await prisma.studyReviewRequest.deleteMany({ where: { id: ids.review } });
    await prisma.counsellor.deleteMany({ where: { id: ids.counsellor } });
    await prisma.scholarshipWorkspace.deleteMany({
      where: { id: ids.workspace },
    });
    await cleanupFixtures(prisma, ids);
    await prisma.$disconnect();
  });

  const expectNow = (date: Date, before: number) => {
    expect(date.getTime()).toBeGreaterThanOrEqual(before - 1);
    expect(date.getTime()).toBeLessThanOrEqual(Date.now() + 1);
  };

  it("réserve un créneau qui commence dans deux heures et écrit updatedAt en UTC", async () => {
    const before = Date.now();
    const booked = await service.book(
      ids.userId,
      ids.review,
      {
        expectedVersion: 1,
        slotOfferId: ids.offer,
        bookingKey: `tz-review-booking-${s}`,
        timezone: "Africa/Abidjan",
      },
      `tz-review-book-${s}`,
      `tz-review-req-book-${s}`,
    );

    expect(booked.statusCode).toBe(201);
    const slot = await prisma.counsellorAvailabilitySlot.findUniqueOrThrow({
      where: { id: ids.slot },
    });
    expect(slot.bookedCount).toBe(1);
    expect(slot.status).toBe("exhausted");
    expectNow(slot.updatedAt, before);
  });

  it("annuler rend la place et écrit updatedAt en UTC", async () => {
    const appointment = await prisma.appointment.findFirstOrThrow({
      where: { userId: ids.userId, slotId: ids.slot },
    });
    const before = Date.now();
    await service.cancel(
      ids.userId,
      appointment.id,
      { expectedVersion: 2, reasonCode: "student_unavailable" },
      `tz-review-cancel-${s}`,
      `tz-review-req-cancel-${s}`,
    );

    const slot = await prisma.counsellorAvailabilitySlot.findUniqueOrThrow({
      where: { id: ids.slot },
    });
    expect(slot.bookedCount).toBe(0);
    expect(slot.status).toBe("available");
    expectNow(slot.updatedAt, before);
  });
});
