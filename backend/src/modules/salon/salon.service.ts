import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

/**
 * Statuts « publiés » : seuls ceux-là sont visibles sur les routes publiques.
 * Un brouillon (`draft`) ou une édition annulée/terminée n'y apparaît pas.
 */
const PUBLISHED_STATUSES = ['scheduled', 'live'] as const;

type SessionLinks = { joinUrl: string | null; recordingUrl: string | null };

/**
 * Qui reçoit quel lien :
 *  - `recordingUrl` : seulement l'élève authentifié ET inscrit ;
 *  - `joinUrl` d'une session `scheduled` : seulement l'inscrit (sinon
 *    n'importe qui ayant l'id rejoignait la réunion et contournait `capacity`) ;
 *  - `joinUrl` d'une session `live` : tout élève AUTHENTIFIÉ, inscrit ou non.
 *    Compromis pour l'app installée, qui ne recharge pas le programme après
 *    une inscription : sans lui, un élève qui s'inscrit pendant le direct ne
 *    voyait plus « Rejoindre ». Un anonyme ne l'a jamais.
 * Les champs restent présents, à `null`, pour ne pas changer la forme de la
 * réponse lue par l'app.
 */
function withLinksFor<T extends SessionLinks & { status: string }>(
  session: T,
  viewer: { authenticated: boolean; registered: boolean },
): T {
  const joinAllowed =
    viewer.registered || (viewer.authenticated && session.status === 'live');
  return {
    ...session,
    joinUrl: joinAllowed ? session.joinUrl : null,
    recordingUrl: viewer.registered ? session.recordingUrl : null,
  };
}

/** Erreur Prisma de contrainte d'unicité (`@@unique([sessionId, userId])`). */
function isUniqueViolation(error: unknown): boolean {
  return (
    !!error &&
    typeof error === 'object' &&
    (error as { code?: unknown }).code === 'P2002'
  );
}

/**
 * Salon KPB Virtuel (Phase 3).
 *
 * Annual 2-day event inside the app. Canadian / French / Moroccan
 * universities answer questions live. Students RSVP so we can push
 * reminders (24h and 1h pre-session). We don't host video ourselves —
 * `SalonSession.joinUrl` points to Jitsi / Zoom / Meet.
 *
 * Fully ownable format: each edition compounds word-of-mouth.
 */
@Injectable()
export class SalonService {
  constructor(private readonly prismaService: PrismaService) {}

  // ── Public ────────────────────────────────────────────────────────────────

  /** Upcoming + currently-live events. Drafts and ended editions are hidden. */
  async listEvents() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.salonEvent.findMany({
        where: { status: { in: ['scheduled', 'live'] } },
        orderBy: { startAt: 'asc' },
      }),
    );
    return { items: items ?? [] };
  }

  /**
   * Une édition publiée et ses sessions publiées. `viewerId` : l'élève
   * authentifié s'il y en a un — il reçoit le lien de visio des seules
   * sessions auxquelles il est inscrit.
   */
  async getEventBySlug(slug: string, viewerId?: string) {
    const event = await this.prismaService.execute((prisma) =>
      prisma.salonEvent.findFirst({
        // Un brouillon ou une édition annulée n'est pas publique, même à qui
        // connaît ou devine le slug.
        where: { slug, status: { in: [...PUBLISHED_STATUSES] } },
        include: {
          sessions: {
            where: { status: { in: [...PUBLISHED_STATUSES] } },
            orderBy: { startAt: 'asc' },
          },
        },
      }),
    );
    if (!event) {
      throw new NotFoundException(`Salon event ${slug} not found.`);
    }
    const registered = await this.activeRegistrationSessionIds(
      viewerId,
      event.sessions.map((s) => s.id),
    );
    return {
      ...event,
      sessions: event.sessions.map((s) =>
        withLinksFor(s, {
          authenticated: !!viewerId,
          registered: registered.has(s.id),
        }),
      ),
    };
  }

  async getSession(sessionId: string, viewerId?: string) {
    const session = await this.prismaService.execute((prisma) =>
      prisma.salonSession.findFirst({
        // La session ET son édition doivent être publiées.
        where: {
          id: sessionId,
          status: { in: [...PUBLISHED_STATUSES] },
          event: { status: { in: [...PUBLISHED_STATUSES] } },
        },
        include: { event: true },
      }),
    );
    if (!session) {
      throw new NotFoundException(`Session ${sessionId} not found.`);
    }
    const registered = await this.activeRegistrationSessionIds(viewerId, [
      session.id,
    ]);
    return withLinksFor(session, {
      authenticated: !!viewerId,
      registered: registered.has(session.id),
    });
  }

  /** Les sessions (parmi `sessionIds`) où `viewerId` a une inscription active. */
  private async activeRegistrationSessionIds(
    viewerId: string | undefined,
    sessionIds: string[],
  ): Promise<Set<string>> {
    if (!viewerId || sessionIds.length === 0) return new Set();
    const rows = await this.prismaService.execute((prisma) =>
      prisma.salonRegistration.findMany({
        where: {
          userId: viewerId,
          sessionId: { in: sessionIds },
          status: { not: 'cancelled' },
        },
        select: { sessionId: true },
      }),
    );
    return new Set((rows ?? []).map((r) => r.sessionId));
  }

  // ── Registrations ────────────────────────────────────────────────────────

  /**
   * Student → RSVP to a session. Honors capacity if set. Idempotent: if
   * the user already has a registration row, we just return it.
   *
   * Comptage et insertion se font dans UNE transaction, la ligne de la session
   * verrouillée (`FOR UPDATE`) : avant, dix élèves arrivant dans la même
   * seconde lisaient tous « 49 places prises » et la session finissait à 59
   * pour 50. Le verrou sérialise les inscriptions d'une même session ; chacune
   * relit ensuite l'état validé par la précédente.
   */
  async register(userId: string, sessionId: string) {
    let outcome;
    try {
      outcome = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const locked = await tx.$queryRaw<Array<{ id: string }>>`
            SELECT "id" FROM "SalonSession" WHERE "id" = ${sessionId} FOR UPDATE
          `;
          if (locked.length === 0) return { kind: 'not_found' as const };

          const session = await tx.salonSession.findUnique({
            where: { id: sessionId },
            select: { status: true, capacity: true },
          });
          if (!session) return { kind: 'not_found' as const };
          if (session.status !== 'scheduled' && session.status !== 'live') {
            return { kind: 'closed' as const, status: session.status };
          }

          const existing = await tx.salonRegistration.findUnique({
            where: { sessionId_userId: { sessionId, userId } },
          });
          if (existing && existing.status !== 'cancelled') {
            return { kind: 'ok' as const, registration: existing };
          }

          // Seules les inscriptions actives occupent une place : une annulation
          // libère la sienne.
          const active = await tx.salonRegistration.count({
            where: { sessionId, status: { not: 'cancelled' } },
          });
          if (session.capacity && active >= session.capacity) {
            return { kind: 'full' as const };
          }

          if (existing) {
            // Réinscription après annulation : on réactive la ligne existante.
            // Les marqueurs de rappel repartent de zéro, sinon un élève qui
            // avait déjà reçu le rappel J-1 ou « 1 h avant » ne recevait plus
            // jamais aucun rappel pour cette session.
            const registration = await tx.salonRegistration.update({
              where: { id: existing.id },
              data: {
                status: 'registered',
                remindedAt: null,
                reminded1hAt: null,
              },
            });
            return { kind: 'ok' as const, registration };
          }

          const registration = await tx.salonRegistration.create({
            data: { userId, sessionId, status: 'registered' },
          });
          return { kind: 'ok' as const, registration };
        }),
      );
    } catch (error) {
      // Double clic : la seconde requête bute sur `@@unique([sessionId,
      // userId])`. On rend l'inscription existante (route idempotente) au
      // lieu d'une 500.
      if (!isUniqueViolation(error)) throw error;
      const existing = await this.prismaService.execute((prisma) =>
        prisma.salonRegistration.findUnique({
          where: { sessionId_userId: { sessionId, userId } },
        }),
      );
      if (existing && existing.status !== 'cancelled') return existing;
      throw error;
    }

    if (!outcome || outcome.kind === 'not_found') {
      throw new NotFoundException(`Session ${sessionId} not found.`);
    }
    if (outcome.kind === 'closed') {
      throw new BadRequestException(
        `Session is ${outcome.status} — registrations closed.`,
      );
    }
    if (outcome.kind === 'full') {
      throw new ConflictException('Session is full.');
    }
    return outcome.registration;
  }

  async cancelRegistration(userId: string, sessionId: string) {
    return this.prismaService.execute((prisma) =>
      prisma.salonRegistration.updateMany({
        where: { userId, sessionId, status: { not: 'cancelled' } },
        data: { status: 'cancelled' },
      }),
    );
  }

  async listMyRegistrations(userId: string) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.salonRegistration.findMany({
        where: { userId, status: { not: 'cancelled' } },
        orderBy: { createdAt: 'desc' },
        include: { session: { include: { event: true } } },
      }),
    );
    return { items: items ?? [] };
  }

  // ── Admin ────────────────────────────────────────────────────────────────

  async listAdminEvents() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.salonEvent.findMany({
        orderBy: [{ year: 'desc' }, { startAt: 'desc' }],
        include: { _count: { select: { sessions: true } } },
      }),
    );
    return { items: items ?? [] };
  }

  async createEvent(data: {
    slug: string;
    nameFr: string;
    nameEn: string;
    year: number;
    startAt: Date | string;
    endAt: Date | string;
    heroImageUrl?: string;
    descriptionFr?: string;
    descriptionEn?: string;
    status?: 'draft' | 'scheduled' | 'live' | 'ended' | 'cancelled';
  }) {
    return this.prismaService.execute((prisma) =>
      prisma.salonEvent.create({
        data: {
          ...data,
          startAt: new Date(data.startAt),
          endAt: new Date(data.endAt),
          status: (data.status ?? 'draft') as never,
        },
      }),
    );
  }

  async updateEvent(
    id: string,
    data: Partial<{
      nameFr: string;
      nameEn: string;
      year: number;
      startAt: Date | string;
      endAt: Date | string;
      heroImageUrl: string;
      descriptionFr: string;
      descriptionEn: string;
      status: 'draft' | 'scheduled' | 'live' | 'ended' | 'cancelled';
    }>,
  ) {
    return this.prismaService.execute((prisma) =>
      prisma.salonEvent.update({
        where: { id },
        data: {
          ...data,
          startAt: data.startAt ? new Date(data.startAt) : undefined,
          endAt: data.endAt ? new Date(data.endAt) : undefined,
          status: data.status ? (data.status as never) : undefined,
        },
      }),
    );
  }

  async createSession(data: {
    eventId: string;
    partnerId?: string;
    titleFr: string;
    titleEn: string;
    descriptionFr?: string;
    descriptionEn?: string;
    hostName?: string;
    startAt: Date | string;
    durationMinutes?: number;
    joinUrl?: string;
    capacity?: number;
    displayOrder?: number;
  }) {
    return this.prismaService.execute((prisma) =>
      prisma.salonSession.create({
        data: {
          ...data,
          startAt: new Date(data.startAt),
        },
      }),
    );
  }

  async updateSession(
    id: string,
    data: Partial<{
      partnerId: string;
      titleFr: string;
      titleEn: string;
      descriptionFr: string;
      descriptionEn: string;
      hostName: string;
      startAt: Date | string;
      durationMinutes: number;
      joinUrl: string;
      recordingUrl: string;
      capacity: number;
      status: 'scheduled' | 'live' | 'ended' | 'cancelled';
      displayOrder: number;
    }>,
  ) {
    const nextStartAt = data.startAt ? new Date(data.startAt) : undefined;
    return this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const before = nextStartAt
          ? await tx.salonSession.findUnique({
              where: { id },
              select: { startAt: true },
            })
          : null;
        const updated = await tx.salonSession.update({
          where: { id },
          data: {
            ...data,
            startAt: nextStartAt,
            status: data.status ? (data.status as never) : undefined,
          },
        });
        // Session déplacée : les rappels déjà envoyés visaient l'ancienne date.
        // On remet les marqueurs à zéro pour que les inscrits reçoivent le
        // rappel J-1 et « 1 h avant » de la NOUVELLE date. Un PATCH qui renvoie
        // la même date ne touche à rien (pas de rappel en double).
        if (
          nextStartAt &&
          before &&
          before.startAt.getTime() !== nextStartAt.getTime()
        ) {
          await tx.salonRegistration.updateMany({
            where: { sessionId: id },
            data: { remindedAt: null, reminded1hAt: null },
          });
        }
        return updated;
      }),
    );
  }

  async listSessionRegistrations(sessionId: string) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.salonRegistration.findMany({
        where: { sessionId },
        orderBy: { createdAt: 'asc' },
        include: {
          user: { select: { id: true, fullName: true, email: true } },
        },
      }),
    );
    return { items: items ?? [] };
  }
}
