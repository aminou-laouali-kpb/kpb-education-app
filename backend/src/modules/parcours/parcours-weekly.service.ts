// ─────────────────────────────────────────────────────────────────────────────
// "Récit de la semaine" — the weekly inspiration push (KPB-169).
//
// 86 stories sit in the library with no rhythm; a student who watched three of
// them has no reason to come back. One editorially-chosen story per week, sent
// Sunday 18:00 local — the hour someone is thinking about the week ahead — is
// the rendez-vous that turns the library into an appointment.
//
// Deliberately spaced from the other recurring sends so the frequency cap never
// has to arbitrate between them: Sunday 18h here, Monday 08h digest (KPB-163),
// Wednesday 09h matches (KPB-168), daily 19h scholarship (KPB-162).
//
// Honest by construction: no featured story ⇒ nothing is sent. There is no
// "fall back to any story" path — an empty editorial slot is empty.
//
// OFF by default (KPB_PARCOURS_WEEKLY_ENABLED). Push goes through
// NotificationDispatchService (KPB-155): quiet hours, the rolling-24h cap, the
// durable feed and per-week dedup are inherited.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import {
  localHourFor,
  localWeekdayFor,
  utcOffsetHoursForCountry,
} from '../../common/country-timezone';
import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import { PrismaService } from '../prisma/prisma.service';
import { ParcoursService } from './parcours.service';

const SEND_HOUR_LOCAL = 18;
const SEND_WEEKDAY_LOCAL = 0; // Sunday (Date.getUTCDay() numbering).

@Injectable()
export class ParcoursWeeklyService {
  private readonly logger = new Logger(ParcoursWeeklyService.name);

  private readonly enabled = process.env.KPB_PARCOURS_WEEKLY_ENABLED === 'true';

  constructor(
    private readonly prisma: PrismaService,
    private readonly parcours: ParcoursService,
    private readonly dispatch: NotificationDispatchService,
  ) {}

  /**
   * Hourly tick: push the week's story to every student whose LOCAL time is
   * Sunday 18:00 right now. Recipients are filtered on local time BEFORE any
   * other work, so a run outside the window costs one indexed query.
   */
  @Cron('0 * * * *')
  async sendWeeklyPush(now = new Date()): Promise<void> {
    if (!this.enabled || !this.prisma.isEnabled) return;

    const candidates =
      (await this.prisma.execute((db) =>
        db.userProfile.findMany({
          where: {
            accountType: 'student',
            NOT: { disabledNotificationTypes: { has: 'parcours_weekly' } },
          },
          select: {
            id: true,
            preferredLanguage: true,
            countryOfResidence: true,
          },
        }),
      )) ?? [];

    const recipients = candidates.filter((r) => {
      const offset = utcOffsetHoursForCountry(r.countryOfResidence);
      return (
        localWeekdayFor(now, offset) === SEND_WEEKDAY_LOCAL &&
        localHourFor(now, offset) === SEND_HOUR_LOCAL
      );
    });
    if (recipients.length === 0) return;

    // Only look up the story once we know somebody is listening.
    // Le push part le DIMANCHE soir : il annonce le récit de la semaine qui
    // COMMENCE le lendemain. Choisi sur `now`, il annonçait celui de la
    // semaine qui se termine, remplacé sur l'accueil quelques heures après.
    const weekStart = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const story = await this.parcours.pickStoryOfWeek(weekStart);
    if (!story) {
      this.logger.warn(
        'Récit de la semaine: no featured story published — nothing sent.',
      );
      return;
    }

    const weekKey = this.parcours.weekKey(weekStart);
    let pushed = 0;
    for (const r of recipients) {
      const outcome = await this.dispatch.dispatch({
        userId: r.id,
        kind: 'parcours_weekly',
        dedupeKey: `parcours-weekly:${weekKey}:${r.id}`,
        title: {
          fr: '✨ Le récit de la semaine',
          en: '✨ This week’s story',
        },
        body: {
          fr: this.line(story.personName, story.hook.fr, story.title.fr),
          en: this.line(story.personName, story.hook.en, story.title.en),
        },
        route: `/parcours/${story.slug}`,
        data: { type: 'parcours_weekly', storySlug: story.slug },
        preferredLanguage: r.preferredLanguage,
        countryOfResidence: r.countryOfResidence,
        now,
      });
      if (outcome === 'pushed') pushed += 1;
    }

    this.logger.log(
      `Récit de la semaine "${story.slug}" (${weekKey}): ` +
        `${recipients.length} in window, ${pushed} push(es) sent.`,
    );
  }

  /** "Awa Diallo — <hook>", falling back to the title when there is no hook,
   *  and to the hook alone when the story has no person attached. */
  private line(personName: string, hook: string, title: string): string {
    const tail = hook.trim() || title.trim();
    const name = personName.trim();
    if (!name) return tail;
    return tail ? `${name} — ${tail}` : name;
  }
}
