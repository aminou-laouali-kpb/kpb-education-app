// ─────────────────────────────────────────────────────────────────────────────
// "Bourse du jour" (KPB-162) — the daily variable-reward anchor.
//
// One scholarship is featured per day (deterministic global rotation over the
// eligible set — no storage), surfaced on Home via GET /scholarships/daily and
// pushed at 19:00 in each user's local time.
//
// The push reuses NotificationDispatchService (KPB-155): quiet hours, the daily
// frequency cap, the durable in-app feed and per-key dedup all come for free.
// It is OFF by default (KPB_DAILY_SCHOLARSHIP_ENABLED) so nothing fires until
// the Home card + opt-out toggle ship and ops enable it; the endpoint works
// regardless.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import {
  localHourFor,
  utcOffsetHoursForCountry,
} from '../../common/country-timezone';
import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import { PrismaService } from '../prisma/prisma.service';
import { ScholarshipsIndexService } from './scholarships-index.service';
import { publicScholarshipWhere } from '../../common/public-scholarship-where';

const DAY_MS = 24 * 60 * 60 * 1000;
const SEND_HOUR_LOCAL = 19; // 19:00 in the recipient's local time.

interface DailyPick {
  id: string;
  nameFr: string;
  nameEn: string;
  countryNameFr: string | null;
  countryNameEn: string | null;
  deadlineAt: Date | null;
}

@Injectable()
export class DailyScholarshipService {
  private readonly logger = new Logger(DailyScholarshipService.name);

  private readonly pushEnabled =
    process.env.KPB_DAILY_SCHOLARSHIP_ENABLED === 'true';

  constructor(
    private readonly prisma: PrismaService,
    private readonly scholarships: ScholarshipsIndexService,
    private readonly dispatch: NotificationDispatchService,
  ) {}

  /** UTC day index — stable across a calendar day; drives the rotation. */
  private dayNumber(date: Date): number {
    return Math.floor(date.getTime() / DAY_MS);
  }

  private dateKey(date: Date): string {
    return date.toISOString().slice(0, 10);
  }

  /**
   * Deterministic global "scholarship of the day": eligible = active + approved
   * + upcoming deadline, ordered by soonest deadline, rotated by day index so a
   * given scholarship does not recur within `eligible.length` days (best-effort
   * as the eligible set shifts). Returns null when nothing is eligible.
   */
  async pickForDate(date: Date): Promise<DailyPick | null> {
    const eligible = await this.prisma.execute((db) =>
      db.scholarship.findMany({
        // Même règle que la vue publique (fiche vérifiée par un humain) : sinon
        // la bourse poussée répondait 404 au tap. On garde l'exigence d'une
        // échéance à venir propre à la « bourse du jour ».
        where: {
          ...publicScholarshipWhere(date),
          AND: [{ deadlineAt: { gt: date } }],
        },
        orderBy: [{ deadlineAt: 'asc' }, { id: 'asc' }],
        select: {
          id: true,
          nameFr: true,
          nameEn: true,
          countryNameFr: true,
          countryNameEn: true,
          deadlineAt: true,
        },
      }),
    );
    if (!eligible || eligible.length === 0) return null;
    return eligible[this.dayNumber(date) % eligible.length];
  }

  /** Today's pick, fully serialized for the app (reuses getForProfile). */
  async getDailyForProfile(userId: string, lang: 'fr' | 'en') {
    const now = new Date();
    const pick = await this.pickForDate(now);
    if (!pick) return { date: this.dateKey(now), scholarship: null };
    try {
      const scholarship = await this.scholarships.getForProfile(pick.id, {
        lang,
        userId,
      });
      return { date: this.dateKey(now), scholarship };
    } catch {
      // Picked row became unavailable between query and read — degrade to empty.
      return { date: this.dateKey(now), scholarship: null };
    }
  }

  /**
   * Hourly tick: push the day's pick to every student whose LOCAL time is 19:00
   * right now (residence → UTC offset), skipping opt-outs. The per-day dedupeKey
   * guarantees at most one daily-scholarship push per user; dispatch enforces
   * quiet hours + the daily cap and writes the durable feed entry.
   */
  @Cron('0 * * * *')
  async sendDailyPush(now = new Date()): Promise<void> {
    if (!this.pushEnabled || !this.prisma.isEnabled) return;
    const pick = await this.pickForDate(now);
    if (!pick) return;

    const recipients =
      (await this.prisma.execute((db) =>
        db.userProfile.findMany({
          where: {
            accountType: 'student',
            NOT: { disabledNotificationTypes: { has: 'daily_scholarship' } },
          },
          select: {
            id: true,
            preferredLanguage: true,
            countryOfResidence: true,
          },
        }),
      )) ?? [];

    const dateKey = this.dateKey(now);
    let pushed = 0;
    for (const r of recipients) {
      const offset = utcOffsetHoursForCountry(r.countryOfResidence);
      if (localHourFor(now, offset) !== SEND_HOUR_LOCAL) continue;
      const outcome = await this.dispatch.dispatch({
        userId: r.id,
        kind: 'daily_scholarship',
        dedupeKey: `daily-scholarship:${dateKey}:${r.id}`,
        title: { fr: '🎓 Bourse du jour', en: '🎓 Scholarship of the day' },
        body: {
          fr: `${pick.nameFr}${pick.countryNameFr ? ` — ${pick.countryNameFr}` : ''}. À découvrir avant la deadline.`,
          en: `${pick.nameEn}${pick.countryNameEn ? ` — ${pick.countryNameEn}` : ''}. Worth a look before the deadline.`,
        },
        route: `/scholarships/${pick.id}`,
        data: { type: 'daily_scholarship', scholarshipId: pick.id },
        scholarshipId: pick.id,
        preferredLanguage: r.preferredLanguage,
        countryOfResidence: r.countryOfResidence,
        now,
      });
      if (outcome === 'pushed') pushed += 1;
    }

    if (pushed > 0) {
      this.logger.log(
        `Bourse du jour "${pick.nameFr}": ${pushed} push(es) sent at local ${SEND_HOUR_LOCAL}h.`,
      );
    }
  }
}
