import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

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

  async getEventBySlug(slug: string) {
    const event = await this.prismaService.execute((prisma) =>
      prisma.salonEvent.findUnique({
        where: { slug },
        include: {
          sessions: {
            where: { status: { in: ['scheduled', 'live'] } },
            orderBy: { startAt: 'asc' },
          },
        },
      }),
    );
    if (!event) {
      throw new NotFoundException(`Salon event ${slug} not found.`);
    }
    return event;
  }

  async getSession(sessionId: string) {
    const session = await this.prismaService.execute((prisma) =>
      prisma.salonSession.findUnique({
        where: { id: sessionId },
        include: { event: true },
      }),
    );
    if (!session) {
      throw new NotFoundException(`Session ${sessionId} not found.`);
    }
    return session;
  }

  // ── Registrations ────────────────────────────────────────────────────────

  /**
   * Student → RSVP to a session. Honors capacity if set. Idempotent: if
   * the user already has a registration row, we just return it.
   */
  async register(userId: string, sessionId: string) {
    const session = await this.prismaService.execute((prisma) =>
      prisma.salonSession.findUnique({
        where: { id: sessionId },
        include: { registrations: true },
      }),
    );
    if (!session) {
      throw new NotFoundException(`Session ${sessionId} not found.`);
    }
    if (session.status !== 'scheduled' && session.status !== 'live') {
      throw new BadRequestException(
        `Session is ${session.status} — registrations closed.`,
      );
    }

    const existing = session.registrations.find((r) => r.userId === userId);
    if (existing && existing.status !== 'cancelled') {
      return existing;
    }

    // Seules les inscriptions actives occupent une place : une annulation
    // libère la sienne (avant, une session pouvait s'afficher « pleine » à
    // cause d'inscriptions annulées).
    const active = session.registrations.filter(
      (r) => r.status !== 'cancelled',
    ).length;
    if (session.capacity && active >= session.capacity) {
      throw new ConflictException('Session is full.');
    }

    if (existing) {
      // Réinscription après annulation : on réactive la ligne existante au
      // lieu de renvoyer l'inscription annulée avec un 200.
      return this.prismaService.execute((prisma) =>
        prisma.salonRegistration.update({
          where: { id: existing.id },
          data: { status: 'registered' },
        }),
      );
    }

    const registration = await this.prismaService.execute((prisma) =>
      prisma.salonRegistration.create({
        data: { userId, sessionId, status: 'registered' },
      }),
    );
    return registration;
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
    return this.prismaService.execute((prisma) =>
      prisma.salonSession.update({
        where: { id },
        data: {
          ...data,
          startAt: data.startAt ? new Date(data.startAt) : undefined,
          status: data.status ? (data.status as never) : undefined,
        },
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
