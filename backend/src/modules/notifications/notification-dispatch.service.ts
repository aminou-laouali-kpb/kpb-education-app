// ─────────────────────────────────────────────────────────────────────────────
// NotificationDispatchService — the single, guarded path for user-directed
// reminders (KPB-155).
//
// Every reminder is FIRST recorded in the durable in-app feed (`UserNotification`,
// deduped on `dedupeKey`); the push is then gated by:
//   • quiet hours  — no push in the local 21:00–08:00 window (per residence);
//   • frequency cap — at most N pushes per user per rolling 24h.
//
// A gated reminder still lives in the feed (`pushedAt` stays NULL) — the student
// sees it next time they open the app; we just don't ping their phone at 3am or
// spam them. This is the anti-opt-out foundation the evening "Bourse du jour"
// (KPB-162) and weekly digest (KPB-163) build on: they call dispatch() too.
//
// Dedup is global: if the daily cron and a manual admin trigger both produce the
// same (reminder, user, threshold), the second createMany is a no-op and no
// second push goes out.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import {
  isWithinQuietHours,
  utcOffsetHoursForCountry,
} from '../../common/country-timezone';
import { PrismaService } from '../prisma/prisma.service';
import { PushSenderService } from './push-sender.service';

export type DispatchOutcome =
  | 'pushed' // feed written + push delivered
  | 'deduped' // already recorded for this dedupeKey — nothing sent
  | 'quiet_hours' // feed written; push held back (local quiet window)
  | 'capped' // feed written; push held back (daily cap reached)
  | 'push_unconfigured' // feed written; no push provider configured
  | 'push_failed' // feed written; provider rejected the push
  | 'skipped'; // DB disabled or transient error — nothing recorded

export interface DispatchInput {
  userId: string;
  /** Feed `kind` (e.g. 'deadline_reminder'). */
  kind: string;
  /** Idempotency key — one push per unique key, ever. */
  dedupeKey: string;
  title: { fr: string; en: string };
  body: { fr: string; en: string };
  route: string;
  data?: Record<string, string>;
  scholarshipId?: string | null;
  preferredLanguage?: string | null;
  countryOfResidence?: string | null;
  /** Injectable clock for tests; defaults to now. */
  now?: Date;
}

const DAY_MS = 24 * 60 * 60 * 1000;
const DEFAULT_MAX_PUSHES_PER_DAY = 3;
const DEFAULT_QUIET_START_HOUR = 21;
const DEFAULT_QUIET_END_HOUR = 8;

@Injectable()
export class NotificationDispatchService {
  private readonly logger = new Logger(NotificationDispatchService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushSenderService,
  ) {}

  private get maxPushesPerDay(): number {
    return readEnvInt('KPB_PUSH_MAX_PER_DAY', DEFAULT_MAX_PUSHES_PER_DAY, 1, 50);
  }

  private get quietStartHour(): number {
    return readEnvInt('KPB_PUSH_QUIET_START', DEFAULT_QUIET_START_HOUR, 0, 23);
  }

  private get quietEndHour(): number {
    return readEnvInt('KPB_PUSH_QUIET_END', DEFAULT_QUIET_END_HOUR, 0, 23);
  }

  async dispatch(input: DispatchInput): Promise<DispatchOutcome> {
    if (!this.prisma.isEnabled) return 'skipped';
    const now = input.now ?? new Date();

    try {
      // 1. Durable feed write, idempotent on dedupeKey. count === 0 ⇒ this
      //    reminder was already recorded, so neither re-record nor re-push.
      const recorded = await this.prisma.execute((p) =>
        p.userNotification.createMany({
          data: [
            {
              userId: input.userId,
              scholarshipId: input.scholarshipId ?? null,
              kind: input.kind,
              dedupeKey: input.dedupeKey,
              titleFr: input.title.fr,
              titleEn: input.title.en,
              bodyFr: input.body.fr,
              bodyEn: input.body.en,
              route: input.route,
              data: (input.data ?? {}) as Prisma.InputJsonValue,
            },
          ],
          skipDuplicates: true,
        }),
      );
      if (!recorded || recorded.count === 0) return 'deduped';

      // 2. Push gating (feed entry already persisted regardless of outcome).
      if (!this.push.isConfigured) return 'push_unconfigured';

      const offset = utcOffsetHoursForCountry(input.countryOfResidence);
      if (
        isWithinQuietHours(now, offset, this.quietStartHour, this.quietEndHour)
      ) {
        return 'quiet_hours';
      }

      const since = new Date(now.getTime() - DAY_MS);
      const pushesInWindow =
        (await this.prisma.execute((p) =>
          p.userNotification.count({
            where: { userId: input.userId, pushedAt: { gte: since } },
          }),
        )) ?? 0;
      if (pushesInWindow >= this.maxPushesPerDay) return 'capped';

      // 3. Deliver in the user's language, then stamp pushedAt.
      const isEnglish = (input.preferredLanguage ?? '')
        .toLowerCase()
        .startsWith('en');
      // `notificationKey` : rendu par l'application au tap (`POST
      // /me/push-opens`) pour passer le rappel en lu. C'est l'identifiant
      // OPAQUE de la ligne du fil, pas la `dedupeKey` : celle-ci porte presque
      // toujours l'id du compte (`weekly-digest:<semaine>:<userId>`…), et la
      // charge `data` part chez Google (FCM) et OneSignal — la politique promet
      // qu'aucun identifiant de compte n'y figure (audit 57, F06).
      const feedRow = await this.prisma.execute((p) =>
        p.userNotification.findUnique({
          where: { dedupeKey: input.dedupeKey },
          select: { id: true },
        }),
      );
      const ok = await this.push.sendToUser(
        input.userId,
        isEnglish ? input.title.en : input.title.fr,
        isEnglish ? input.body.en : input.body.fr,
        {
          ...(input.data ?? {}),
          route: input.route,
          type: input.kind,
          ...(feedRow ? { notificationKey: feedRow.id } : {}),
        },
      );
      if (!ok) return 'push_failed';

      await this.prisma.execute((p) =>
        p.userNotification.update({
          where: { dedupeKey: input.dedupeKey },
          data: { pushedAt: now },
        }),
      );
      return 'pushed';
    } catch (error) {
      // One bad reminder must never abort a batch of them.
      this.logger.error(
        `Dispatch failed for user ${input.userId} (${input.kind}).`,
      );
      void error;
      return 'skipped';
    }
  }
}

/** Parse a bounded integer env var, clamped to [min, max], else fallback. */
function readEnvInt(
  name: string,
  fallback: number,
  min: number,
  max: number,
): number {
  const raw = process.env[name]?.trim();
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}
