import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { ActivateScholarshipDto } from './dto/activate-scholarship.dto';
import { ForecastScholarshipDto } from './dto/forecast-scholarship.dto';
import { ScholarshipContentQualityService } from './scholarship-content-quality.service';

@Injectable()
export class ScholarshipLifecycleService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly pushSender: PushSenderService,
    private readonly contentQuality: ScholarshipContentQualityService,
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

  async activate(scholarshipId: string, input: ActivateScholarshipDto) {
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

    const activationKey = `scholarship-open:${scholarshipId}:${input.academicYear}`;
    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const scholarship = await tx.scholarship.findUnique({
          where: { id: scholarshipId },
          select: { id: true, nameFr: true, nameEn: true },
        });
        if (!scholarship) return null;

        const existing = await tx.scholarshipCycle.findUnique({
          where: {
            scholarshipId_academicYear: {
              scholarshipId,
              academicYear: input.academicYear,
            },
          },
          select: { id: true, activatedAt: true },
        });
        const firstActivation = existing?.activatedAt == null;

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
            opensAt,
            closesAt,
            sourceUrl: input.sourceUrl,
            verifiedAt: now,
            activatedAt: now,
            activationKey,
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
            opensAt,
            closesAt,
            sourceUrl: input.sourceUrl,
            verifiedAt: now,
            activatedAt: existing?.activatedAt ?? now,
            activationKey,
          },
        });

        await tx.scholarship.update({
          where: { id: scholarshipId },
          data: {
            deadlineAt: closesAt,
            sourceUrl: input.sourceUrl,
            lastVerifiedAt: now,
            isActive: true,
            moderationStatus: 'approved',
          },
        });

        const subscribers = await tx.scholarshipAlertSubscription.findMany({
          where: { scholarshipId },
          select: {
            userId: true,
            pushEnabled: true,
            inAppEnabled: true,
            user: { select: { preferredLanguage: true } },
          },
        });

        if (firstActivation) {
          const inAppSubscribers = subscribers.filter((s) => s.inAppEnabled);
          if (inAppSubscribers.length) {
            await tx.userNotification.createMany({
              data: inAppSubscribers.map((subscriber) => ({
                userId: subscriber.userId,
                scholarshipId,
                kind: 'scholarship_opened',
                dedupeKey: `scholarship-opened:${cycle.id}:${subscriber.userId}`,
                titleFr: 'La bourse est ouverte',
                titleEn: 'Scholarship applications are open',
                bodyFr: `${scholarship.nameFr} accepte maintenant les candidatures jusqu'au ${closesAt.toLocaleDateString('fr-FR')}.`,
                bodyEn: `${scholarship.nameEn} is now accepting applications until ${closesAt.toLocaleDateString('en-GB')}.`,
                route: `/scholarships/${scholarshipId}`,
                data: { scholarshipId, cycleId: cycle.id },
              })),
              skipDuplicates: true,
            });
          }
        }

        return { scholarship, cycle, subscribers, firstActivation };
      }),
    );

    if (!result) {
      throw new NotFoundException(`Scholarship ${scholarshipId} not found.`);
    }

    // KPB-173: solicited and event-driven — these users explicitly subscribed
    // to THIS scholarship's opening, and the cycle opens once. Kept on the
    // direct sender rather than the reminder path.
    let pushesSent = 0;
    if (result.firstActivation) {
      for (const subscriber of result.subscribers) {
        if (!subscriber.pushEnabled) continue;
        const isEnglish = subscriber.user.preferredLanguage === 'en';
        const delivered = await this.pushSender.sendToUser(
          subscriber.userId,
          isEnglish ? 'Scholarship applications are open' : 'La bourse est ouverte',
          isEnglish
            ? `${result.scholarship.nameEn} is now accepting applications.`
            : `${result.scholarship.nameFr} accepte maintenant les candidatures.`,
          {
            route: `/scholarships/${scholarshipId}`,
            scholarshipId,
            cycleId: result.cycle.id,
          },
        );
        if (delivered) pushesSent += 1;
      }
    }

    return {
      scholarshipId,
      cycleId: result.cycle.id,
      status: result.cycle.status,
      firstActivation: result.firstActivation,
      subscribers: result.subscribers.length,
      pushesSent,
    };
  }
}
