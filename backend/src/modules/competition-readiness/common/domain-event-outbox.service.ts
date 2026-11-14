import { randomUUID } from 'node:crypto';

import { Injectable } from '@nestjs/common';
import { Prisma, type DomainEventOutbox } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { utcTimestamp } from '../../../common/sql-time';
import { COMPETITION_READINESS_SCHEMA_VERSION } from './competition-readiness.contract';
import { hashCanonicalPayload } from './idempotency.service';

export type DomainEventOutboxPrismaClient = Pick<
  Prisma.TransactionClient,
  '$queryRaw' | 'domainEventOutbox'
>;

export interface ClaimDomainEventsInput {
  workerId: string;
  batchSize?: number;
  leaseMs?: number;
  now?: Date;
}

export interface ClaimedDomainEventInput {
  eventId: string;
  workerId: string;
}

export interface EnqueueDomainEventInput {
  eventId?: string;
  eventName: string;
  schemaVersion?: number;
  aggregateType: string;
  aggregateId: string;
  payload: Prisma.InputJsonValue;
  occurredAt?: Date;
}

export interface EnqueueDomainEventResult {
  created: boolean;
  event: DomainEventOutbox;
}

/** @internal Boundary adapters must map this to a frozen public API code. */
export class DomainEventConflictError extends Error {
  readonly code = 'OUTBOX_EVENT_CONFLICT' as const;

  constructor() {
    super('Event ID was reused with different event data.');
    this.name = DomainEventConflictError.name;
  }
}

/** @internal This storage failure is intentionally not an HTTP exception. */
export class DomainEventOutboxUnavailableError extends Error {
  readonly code = 'OUTBOX_STORAGE_UNAVAILABLE' as const;

  constructor() {
    super('Domain event outbox is unavailable.');
    this.name = DomainEventOutboxUnavailableError.name;
  }
}

@Injectable()
export class DomainEventOutboxService {
  constructor(private readonly prisma: PrismaService) {}

  async enqueue(
    input: EnqueueDomainEventInput,
    client?: DomainEventOutboxPrismaClient,
  ): Promise<EnqueueDomainEventResult> {
    const candidateId = randomUUID();
    const eventId = input.eventId ?? randomUUID();
    const occurredAt = input.occurredAt ?? new Date();
    const schemaVersion =
      input.schemaVersion ?? COMPETITION_READINESS_SCHEMA_VERSION;

    const event = await this.runRequired(client, (db) =>
      db.domainEventOutbox.upsert({
        where: { eventId },
        create: {
          id: candidateId,
          eventId,
          eventName: input.eventName,
          schemaVersion,
          aggregateType: input.aggregateType,
          aggregateId: input.aggregateId,
          payload: input.payload,
          occurredAt,
        },
        update: {},
      }),
    );

    if (
      event.eventName !== input.eventName ||
      event.schemaVersion !== schemaVersion ||
      event.aggregateType !== input.aggregateType ||
      event.aggregateId !== input.aggregateId ||
      hashCanonicalPayload(event.payload) !==
        hashCanonicalPayload(input.payload) ||
      (input.occurredAt !== undefined &&
        event.occurredAt.getTime() !== input.occurredAt.getTime())
    ) {
      throw new DomainEventConflictError();
    }

    return { created: event.id === candidateId, event };
  }

  async markProcessed(
    eventId: string,
    processedAt = new Date(),
    client?: DomainEventOutboxPrismaClient,
  ): Promise<DomainEventOutbox> {
    return this.runRequired(client, (db) =>
      db.domainEventOutbox.update({
        where: { eventId },
        data: {
          status: 'processed',
          processedAt,
          lockedAt: null,
          lockedBy: null,
          leaseExpiresAt: null,
          lastErrorCode: null,
        },
      }),
    );
  }

  async scheduleRetry(
    input: { eventId: string; nextAttemptAt: Date; errorCode: string },
    client?: DomainEventOutboxPrismaClient,
  ): Promise<DomainEventOutbox> {
    return this.runRequired(client, (db) =>
      db.domainEventOutbox.update({
        where: { eventId: input.eventId },
        data: {
          status: 'pending',
          attemptCount: { increment: 1 },
          nextAttemptAt: input.nextAttemptAt,
          lockedAt: null,
          lockedBy: null,
          leaseExpiresAt: null,
          lastErrorCode: input.errorCode,
        },
      }),
    );
  }

  async markDeadLetter(
    input: { eventId: string; errorCode: string; deadLetteredAt?: Date },
    client?: DomainEventOutboxPrismaClient,
  ): Promise<DomainEventOutbox> {
    return this.runRequired(client, (db) =>
      db.domainEventOutbox.update({
        where: { eventId: input.eventId },
        data: {
          status: 'dead_lettered',
          attemptCount: { increment: 1 },
          deadLetteredAt: input.deadLetteredAt ?? new Date(),
          lockedAt: null,
          lockedBy: null,
          leaseExpiresAt: null,
          lastErrorCode: input.errorCode,
        },
      }),
    );
  }

  /**
   * Atomically reserves a bounded batch for one worker. The CTE and update are
   * one PostgreSQL statement, while SKIP LOCKED allows several app replicas to
   * poll without ever processing the same live lease concurrently.
   */
  async claimBatch(
    input: ClaimDomainEventsInput,
  ): Promise<DomainEventOutbox[]> {
    const workerId = input.workerId.trim();
    if (!workerId) throw new Error('OUTBOX_WORKER_ID_REQUIRED');

    const batchSize = clampInteger(input.batchSize ?? 20, 1, 100);
    const leaseMs = clampInteger(input.leaseMs ?? 60_000, 5_000, 15 * 60_000);
    const now = input.now ?? new Date();
    const leaseExpiresAt = new Date(now.getTime() + leaseMs);

    return this.runRequired(undefined, (db) =>
      db.$queryRaw<DomainEventOutbox[]>(Prisma.sql`
        WITH candidates AS (
          SELECT "id"
          FROM "DomainEventOutbox"
          WHERE "deadLetteredAt" IS NULL
            AND (
              (
                "status" = 'pending'
                AND "nextAttemptAt" <= ${utcTimestamp(now)}
              )
              OR (
                "status" = 'processing'
                AND "leaseExpiresAt" <= ${utcTimestamp(now)}
              )
            )
          ORDER BY "nextAttemptAt" ASC, "occurredAt" ASC, "id" ASC
          FOR UPDATE SKIP LOCKED
          LIMIT ${batchSize}
        )
        UPDATE "DomainEventOutbox" AS event
        SET
          "status" = 'processing',
          "lockedAt" = ${utcTimestamp(now)},
          "lockedBy" = ${workerId},
          "leaseExpiresAt" = ${utcTimestamp(leaseExpiresAt)}
        FROM candidates
        WHERE event."id" = candidates."id"
        RETURNING event.*
      `),
    );
  }

  async markClaimProcessed(
    input: ClaimedDomainEventInput & { processedAt?: Date },
    client?: DomainEventOutboxPrismaClient,
  ): Promise<boolean> {
    const result = await this.runRequired(client, (db) =>
      db.domainEventOutbox.updateMany({
        where: {
          eventId: input.eventId,
          status: 'processing',
          lockedBy: input.workerId,
        },
        data: {
          status: 'processed',
          processedAt: input.processedAt ?? new Date(),
          lockedAt: null,
          lockedBy: null,
          leaseExpiresAt: null,
          lastErrorCode: null,
        },
      }),
    );
    return result.count === 1;
  }

  async scheduleClaimRetry(
    input: ClaimedDomainEventInput & {
      nextAttemptAt: Date;
      errorCode: string;
    },
    client?: DomainEventOutboxPrismaClient,
  ): Promise<boolean> {
    const result = await this.runRequired(client, (db) =>
      db.domainEventOutbox.updateMany({
        where: {
          eventId: input.eventId,
          status: 'processing',
          lockedBy: input.workerId,
        },
        data: {
          status: 'pending',
          attemptCount: { increment: 1 },
          nextAttemptAt: input.nextAttemptAt,
          lockedAt: null,
          lockedBy: null,
          leaseExpiresAt: null,
          lastErrorCode: input.errorCode,
        },
      }),
    );
    return result.count === 1;
  }

  async deadLetterClaim(
    input: ClaimedDomainEventInput & {
      errorCode: string;
      deadLetteredAt?: Date;
    },
    client?: DomainEventOutboxPrismaClient,
  ): Promise<boolean> {
    const result = await this.runRequired(client, (db) =>
      db.domainEventOutbox.updateMany({
        where: {
          eventId: input.eventId,
          status: 'processing',
          lockedBy: input.workerId,
        },
        data: {
          status: 'dead_lettered',
          attemptCount: { increment: 1 },
          deadLetteredAt: input.deadLetteredAt ?? new Date(),
          lockedAt: null,
          lockedBy: null,
          leaseExpiresAt: null,
          lastErrorCode: input.errorCode,
        },
      }),
    );
    return result.count === 1;
  }

  private async runRequired<T extends object>(
    client: DomainEventOutboxPrismaClient | undefined,
    operation: (db: DomainEventOutboxPrismaClient) => Promise<T>,
  ): Promise<T> {
    if (client) return operation(client);
    if (!this.prisma.isEnabled) throw this.databaseUnavailable();

    const result = await this.prisma.execute((db) => operation(db));
    if (result === null) throw this.databaseUnavailable();
    return result;
  }

  private databaseUnavailable(): DomainEventOutboxUnavailableError {
    return new DomainEventOutboxUnavailableError();
  }
}

function clampInteger(value: number, minimum: number, maximum: number): number {
  if (!Number.isFinite(value)) return minimum;
  return Math.min(maximum, Math.max(minimum, Math.floor(value)));
}
