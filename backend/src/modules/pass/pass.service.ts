import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { PassGrant, Prisma, PrismaClient } from '@prisma/client';

import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import { PrismaService } from '../prisma/prisma.service';

const DAY_MS = 24 * 60 * 60 * 1000;

export type PassGrantSource = 'webhook' | 'admin';

export interface PassGrantInput {
  email: string;
  durationDays: number;
  paymentReference: string;
  amountXof?: number;
  note?: string;
  source: PassGrantSource;
  /** Commercial (webhook) ou e-mail de l'administrateur (console). */
  grantedBy: string;
  /** Administrateur connecté, pour le journal d'audit ; null pour n8n. */
  actorAdminId: string | null;
  requestId: string;
}

export interface PassStatus {
  active: boolean;
  /** Fin de la période couverte, Pass en cours et prolongations comprises. */
  activeUntil: string | null;
}

export interface PassGrantResult {
  status: 'granted' | 'already_granted';
  grantId: string;
  account: { id: string; fullName: string; email: string };
  startsAt: string;
  endsAt: string;
  activeUntil: string;
}

/**
 * Une référence se compare sur ses seuls lettres et chiffres, sans casse :
 * « OM-2611-4455 », « om 2611 4455 » et « OM.2611.4455 » sont le même
 * paiement. Deux commerciaux qui recopient un reçu chacun à sa façon ne
 * doivent jamais ouvrir deux accès.
 */
export function normalizePaymentReference(raw: string): string {
  return raw.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
}

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === 'P2002'
  );
}

/** Statut affiché d'une ligne, à un instant donné. */
export function grantState(
  grant: Pick<PassGrant, 'startsAt' | 'endsAt' | 'revokedAt'>,
  now: Date,
): 'revoked' | 'upcoming' | 'active' | 'expired' {
  if (grant.revokedAt) return 'revoked';
  if (grant.startsAt > now) return 'upcoming';
  if (grant.endsAt > now) return 'active';
  return 'expired';
}

/**
 * Le Pass Karatou : des périodes d'accès accordées APRÈS un paiement hors de
 * l'app (mobile money vérifié par un commercial). L'app ne vend rien ; elle
 * lit seulement si une période couvre l'instant présent.
 *
 * - Un même paiement (référence) n'ouvre qu'un accès : rejouer le webhook rend
 *   l'accès existant, une référence déjà prise par un AUTRE compte est refusée.
 * - Un nouvel accès prolonge le Pass en cours : il commence à sa fin.
 * - Chaque accès et chaque révocation laisse une ligne d'audit.
 */
@Injectable()
export class PassService {
  private readonly logger = new Logger(PassService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly dispatch: NotificationDispatchService,
  ) {}

  private async run<T>(operation: (prisma: PrismaClient) => Promise<T>): Promise<T> {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException('Database is not configured. Set DATABASE_URL.');
    }
    return (await this.prismaService.execute(operation)) as T;
  }

  /** Statut du Pass d'un élève. Sans base : pas de Pass (jamais un faux accès). */
  async status(userId: string, now: Date = new Date()): Promise<PassStatus> {
    const grants = await this.prismaService.tryExecute((prisma) =>
      prisma.passGrant.findMany({
        where: { userId, revokedAt: null, endsAt: { gt: now } },
        select: { startsAt: true, endsAt: true },
        orderBy: { endsAt: 'desc' },
      }),
    );
    if (!grants?.length) return { active: false, activeUntil: null };
    const active = grants.some((grant) => grant.startsAt <= now);
    return {
      active,
      activeUntil: active ? grants[0].endsAt.toISOString() : null,
    };
  }

  async hasActivePass(userId: string, now: Date = new Date()): Promise<boolean> {
    return (await this.status(userId, now)).active;
  }

  async grant(input: PassGrantInput, now: Date = new Date()): Promise<PassGrantResult> {
    const email = input.email.trim();
    const paymentReference = normalizePaymentReference(input.paymentReference);
    if (paymentReference.length < 3) {
      throw new BadRequestException({
        code: 'PAYMENT_REFERENCE_INVALID',
        message: 'La référence de paiement doit contenir au moins 3 lettres ou chiffres.',
      });
    }
    const note = input.note?.trim() || null;

    let result;
    try {
      result = await this.run((prisma) =>
        prisma.$transaction(async (tx) => {
          const user = await tx.userProfile.findFirst({
            where: { email: { equals: email, mode: 'insensitive' } },
            select: {
              id: true,
              fullName: true,
              email: true,
              preferredLanguage: true,
              countryOfResidence: true,
            },
          });
          if (!user) return { kind: 'account_not_found' as const };

          const existing = await tx.passGrant.findUnique({
            where: { paymentReference },
          });
          if (existing) {
            if (existing.userId !== user.id) {
              return { kind: 'reference_taken' as const };
            }
            return { kind: 'already' as const, user, grant: existing };
          }

          // Prolonge le Pass en cours (ou déjà programmé) au lieu de le chevaucher.
          const latest = await tx.passGrant.findFirst({
            where: { userId: user.id, revokedAt: null, endsAt: { gt: now } },
            orderBy: { endsAt: 'desc' },
            select: { endsAt: true },
          });
          const startsAt = latest ? latest.endsAt : now;
          const endsAt = new Date(startsAt.getTime() + input.durationDays * DAY_MS);

          const grant = await tx.passGrant.create({
            data: {
              userId: user.id,
              startsAt,
              endsAt,
              durationDays: input.durationDays,
              paymentReference,
              amountXof: input.amountXof ?? null,
              source: input.source,
              grantedBy: input.grantedBy.trim(),
              note,
            },
          });
          await tx.adminAuditEvent.create({
            data: {
              actorAdminId: input.actorAdminId,
              action: 'pass.granted',
              purposeCode: 'pass_karatou',
              entityType: 'PassGrant',
              entityId: grant.id,
              requestId: input.requestId,
              result: 'success',
              changes: {
                userId: user.id,
                source: input.source,
                grantedBy: grant.grantedBy,
                durationDays: grant.durationDays,
                startsAt: grant.startsAt.toISOString(),
                endsAt: grant.endsAt.toISOString(),
              } satisfies Prisma.InputJsonValue,
            },
          });
          return { kind: 'created' as const, user, grant };
        }),
      );
    } catch (error) {
      // Deux envois simultanés de la même référence : le second perd la course.
      if (isUniqueViolation(error)) {
        throw new ConflictException({
          code: 'PAYMENT_REFERENCE_TAKEN',
          message: 'Cette référence de paiement a déjà ouvert un accès.',
        });
      }
      throw error;
    }

    if (result.kind === 'account_not_found') {
      throw new NotFoundException({
        code: 'ACCOUNT_NOT_FOUND',
        message:
          "Aucun compte KPB avec cet e-mail. Vérifiez l'adresse utilisée dans l'app.",
      });
    }
    if (result.kind === 'reference_taken') {
      throw new HttpException(
        {
          code: 'PAYMENT_REFERENCE_TAKEN',
          message: 'Cette référence de paiement a déjà ouvert un accès pour un autre compte.',
        },
        HttpStatus.CONFLICT,
      );
    }

    const { user, grant } = result;
    if (result.kind === 'created') {
      await this.notifyActivated(user, grant);
    }
    const status = await this.status(user.id, now);
    return {
      status: result.kind === 'created' ? 'granted' : 'already_granted',
      grantId: grant.id,
      account: { id: user.id, fullName: user.fullName, email: user.email },
      startsAt: grant.startsAt.toISOString(),
      endsAt: grant.endsAt.toISOString(),
      activeUntil: status.activeUntil ?? grant.endsAt.toISOString(),
    };
  }

  async revoke(
    grantId: string,
    input: { reason: string; revokedBy: string; actorAdminId: string | null; requestId: string },
    now: Date = new Date(),
  ) {
    const reason = input.reason.trim();
    const grant = await this.run((prisma) =>
      prisma.$transaction(async (tx) => {
        const current = await tx.passGrant.findUnique({ where: { id: grantId } });
        if (!current) return null;
        if (current.revokedAt) return current;
        const updated = await tx.passGrant.update({
          where: { id: grantId },
          data: { revokedAt: now, revokedBy: input.revokedBy, revokedReason: reason },
        });
        await tx.adminAuditEvent.create({
          data: {
            actorAdminId: input.actorAdminId,
            action: 'pass.revoked',
            purposeCode: 'pass_karatou',
            entityType: 'PassGrant',
            entityId: grantId,
            requestId: input.requestId,
            reasonCode: reason.slice(0, 200),
            result: 'success',
            changes: { userId: current.userId } satisfies Prisma.InputJsonValue,
          },
        });
        return updated;
      }),
    );
    if (!grant) throw new NotFoundException(`Pass grant ${grantId} not found.`);
    return { id: grant.id, revokedAt: grant.revokedAt?.toISOString() ?? null };
  }

  /** Console : derniers accès, filtrables par e-mail ou nom. */
  async list(query: { q?: string } = {}, now: Date = new Date()) {
    const q = query.q?.trim();
    const grants = await this.run((prisma) =>
      prisma.passGrant.findMany({
        where: q
          ? {
              OR: [
                { user: { email: { contains: q, mode: 'insensitive' } } },
                { user: { fullName: { contains: q, mode: 'insensitive' } } },
                { paymentReference: { contains: normalizePaymentReference(q) } },
              ],
            }
          : {},
        orderBy: { createdAt: 'desc' },
        take: 200,
        include: { user: { select: { id: true, fullName: true, email: true } } },
      }),
    );
    return {
      items: grants.map((grant) => ({
        id: grant.id,
        account: grant.user,
        startsAt: grant.startsAt.toISOString(),
        endsAt: grant.endsAt.toISOString(),
        durationDays: grant.durationDays,
        paymentReference: grant.paymentReference,
        amountXof: grant.amountXof,
        source: grant.source,
        grantedBy: grant.grantedBy,
        note: grant.note,
        createdAt: grant.createdAt.toISOString(),
        revokedAt: grant.revokedAt?.toISOString() ?? null,
        revokedBy: grant.revokedBy,
        revokedReason: grant.revokedReason,
        state: grantState(grant, now),
      })),
    };
  }

  /** Meilleur effort : un échec de notification n'annule jamais l'accès. */
  private async notifyActivated(
    user: { id: string; preferredLanguage: string; countryOfResidence: string },
    grant: PassGrant,
  ) {
    const date = (locale: string) =>
      new Intl.DateTimeFormat(locale, {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
        timeZone: 'UTC',
      }).format(grant.endsAt);
    try {
      await this.dispatch.dispatch({
        userId: user.id,
        kind: 'pass_activated',
        dedupeKey: `pass-activated:${grant.id}`,
        title: { fr: '🎉 Ton Pass Karatou est actif', en: '🎉 Your Karatou Pass is active' },
        body: {
          fr: `Tous les cours et l'accompagnement KPB sont ouverts jusqu'au ${date('fr-FR')}.`,
          en: `All courses and KPB guidance are open until ${date('en-GB')}.`,
        },
        route: '/profile',
        data: { type: 'pass_activated' },
        preferredLanguage: user.preferredLanguage,
        countryOfResidence: user.countryOfResidence,
      });
    } catch (error) {
      this.logger.warn(
        `Pass activation notice not sent (${error instanceof Error ? error.name : 'unknown'}).`,
      );
    }
  }
}
