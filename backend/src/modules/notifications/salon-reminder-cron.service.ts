import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { PrismaService } from '../prisma/prisma.service';
import { PushSenderService } from './push-sender.service';

/**
 * KPB-78 — salon RSVP reminders. Runs hourly so it can catch both the
 * 24h-before and 1h-before windows. Each
 * reminder is stamped (remindedAt for 24h, reminded1hAt for 1h) so it fires
 * exactly once. The push deep-links to `/salon` (route added in KPB-63).
 *
 * KPB-173: kept on the direct sender on purpose. These reminders are SOLICITED
 * (the student registered for this session) and time-critical to the minute —
 * a "starts in 1h" push suppressed by quiet hours, or dropped by the daily cap,
 * is worse than useless. See KPB-175 for giving dispatch a way to express
 * "solicited, time-critical" so this can move without losing that property.
 */
@Injectable()
export class SalonReminderCronService {
  private readonly logger = new Logger(SalonReminderCronService.name);
  private static readonly MIN_MS = 60 * 1000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushSenderService,
  ) {}

  /// Hourly, on the hour.
  @Cron('0 * * * *')
  async scheduledRun(): Promise<void> {
    if (!this.prisma.isEnabled) return;
    await this.run();
  }

  /// Core logic, also callable from an admin endpoint for testing.
  async run(): Promise<{ reminders24h: number; reminders1h: number }> {
    const now = new Date();
    const horizon = new Date(
      now.getTime() + 25 * 60 * SalonReminderCronService.MIN_MS,
    );

    const regs = await this.prisma.execute((p) =>
      p.salonRegistration.findMany({
        where: {
          status: 'registered',
          session: { startAt: { gt: now, lte: horizon } },
        },
        select: {
          id: true,
          remindedAt: true,
          reminded1hAt: true,
          session: { select: { startAt: true, titleFr: true, titleEn: true } },
          user: { select: { id: true, preferredLanguage: true } },
        },
      }),
    );

    let reminders24h = 0;
    let reminders1h = 0;

    for (const r of regs ?? []) {
      const minutes =
        (r.session.startAt.getTime() - now.getTime()) /
        SalonReminderCronService.MIN_MS;
      const en = (r.user.preferredLanguage ?? '').toLowerCase().startsWith('en');
      const title = en ? r.session.titleEn : r.session.titleFr;

      // 24h-before reminder.
      if (r.remindedAt == null && minutes > 23 * 60 && minutes <= 25 * 60) {
        const ok = await this.push.sendToUser(
          r.user.id,
          en ? '📅 Salon tomorrow' : '📅 Salon demain',
          en
            ? `Your KPB salon session "${title}" is tomorrow. See you there!`
            : `Ta session salon KPB « ${title} » a lieu demain. À très vite !`,
          { type: 'salon_reminder', route: '/salon' },
        );
        if (ok) reminders24h++;
        await this.prisma.execute((p) =>
          p.salonRegistration.update({
            where: { id: r.id },
            data: { remindedAt: new Date() },
          }),
        );
        continue;
      }

      // 1h-before reminder.
      if (r.reminded1hAt == null && minutes > 0 && minutes <= 90) {
        const ok = await this.push.sendToUser(
          r.user.id,
          en ? '⏰ Salon starting soon' : '⏰ Salon bientôt',
          en
            ? `Your KPB salon session "${title}" starts soon. Get ready!`
            : `Ta session salon KPB « ${title} » commence bientôt. Prépare-toi !`,
          { type: 'salon_reminder', route: '/salon' },
        );
        if (ok) reminders1h++;
        await this.prisma.execute((p) =>
          p.salonRegistration.update({
            where: { id: r.id },
            data: { reminded1hAt: new Date() },
          }),
        );
      }
    }

    this.logger.log(
      `Salon reminders: ${reminders24h} (24h) + ${reminders1h} (1h) sent.`,
    );
    return { reminders24h, reminders1h };
  }
}
