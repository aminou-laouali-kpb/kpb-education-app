import { CommunityNotificationsService } from '../community/community-notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { DailyScholarshipService } from '../scholarships-index/daily-scholarship.service';
import { ScholarshipsIndexService } from '../scholarships-index/scholarships-index.service';
import { CampaignMailService } from './campaign-mail.service';
import { NotificationDispatchService } from './notification-dispatch.service';
import { ProfileNudgeCronService } from './profile-nudge-cron.service';
import { PushSenderService } from './push-sender.service';
import { WeeklyDigestService } from './weekly-digest.service';

/**
 * Audit 57, F06 — la politique validée dit : « Cloud Messaging ne reçoit que
 * le jeton de notifications de l'appareil, aucun identifiant de compte ni
 * donnée de profil ». Tout ce que `PushSenderService` reçoit (titre, corps,
 * charge `data`) part chez Google (FCM) ou OneSignal.
 *
 * Ici, chaque expéditeur passe par le VRAI `NotificationDispatchService` (qui
 * ajoute `route`, `type` et `notificationKey`) jusqu'à un expéditeur push qui
 * capture ce qui partirait : ni l'id du compte, ni son e-mail, ni son nom, ni
 * son téléphone. Les autres chemins sont figés à côté :
 * `campaign-executor.service.spec.ts` (campagnes), `push-outbox-plan.spec.ts`
 * et `push-outbox-worker.postgres.spec.ts` (annonces d'ouverture),
 * `milestone-reminder.service.spec.ts` (dates limites : `data` exacte).
 */
describe('Charges push : aucun identifiant de compte (audit 57, F06)', () => {
  const ACCOUNT = {
    id: 'acct-7f3k9qz',
    email: 'aicha.secret@example.com',
    fullName: 'Aïcha Secretname',
    phone: '+22790000099',
  };
  const FORBIDDEN = [ACCOUNT.id, ACCOUNT.email, 'Secretname', ACCOUNT.phone];
  const recipient = {
    ...ACCOUNT,
    preferredLanguage: 'fr',
    countryOfResidence: 'SN', // UTC+0
    targetCountryIds: [] as string[],
  };

  const env = {
    daily: process.env.KPB_DAILY_SCHOLARSHIP_ENABLED,
    weekly: process.env.KPB_WEEKLY_DIGEST_ENABLED,
  };
  afterEach(() => {
    for (const [k, v] of [
      ['KPB_DAILY_SCHOLARSHIP_ENABLED', env.daily],
      ['KPB_WEEKLY_DIGEST_ENABLED', env.weekly],
    ] as const) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  });

  /** Base factice : le fil `UserNotification` du dispatcher + les lectures d'un expéditeur. */
  function harness(models: Record<string, Record<string, unknown>>) {
    const feed = new Map<string, { id: string; dedupeKey: string }>();
    const client: Record<string, unknown> = {
      ...models,
      userNotification: {
        createMany: async ({ data }: { data: Array<{ dedupeKey: string }> }) => {
          let count = 0;
          for (const row of data) {
            if (feed.has(row.dedupeKey)) continue;
            feed.set(row.dedupeKey, { id: `cmrow${feed.size + 1}`, dedupeKey: row.dedupeKey });
            count += 1;
          }
          return { count };
        },
        findUnique: async ({ where }: { where: { dedupeKey: string } }) =>
          feed.get(where.dedupeKey) ?? null,
        findFirst: async () => null,
        count: async () => 0,
        update: async () => ({}),
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: unknown) => unknown) => fn(client),
      tryExecute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;
    const sent: Array<{ title: string; body: string; data: Record<string, string> | undefined }> = [];
    const push = {
      isConfigured: true,
      sendToUser: async (_userId: string, title: string, body: string, data?: Record<string, string>) => {
        sent.push({ title, body, data });
        return true;
      },
    } as unknown as PushSenderService;
    const dispatcher = new NotificationDispatchService(prisma, push);
    return { prisma, dispatcher, sent, feed };
  }

  function expectClean(sent: Array<{ title: string; body: string; data?: Record<string, string> }>) {
    expect(sent.length).toBeGreaterThan(0);
    for (const payload of sent) {
      const text = JSON.stringify(payload);
      for (const forbidden of FORBIDDEN) expect(text).not.toContain(forbidden);
      // La clé de tap est l'id opaque de la ligne du fil.
      expect(payload.data?.notificationKey).toMatch(/^cmrow\d+$/);
    }
  }

  it('bourse du jour', async () => {
    process.env.KPB_DAILY_SCHOLARSHIP_ENABLED = 'true';
    const h = harness({
      scholarship: {
        findMany: async () => [
          {
            id: 'sch-1',
            nameFr: 'Bourse X',
            nameEn: 'Scholarship X',
            countryNameFr: 'France',
            countryNameEn: 'France',
            deadlineAt: new Date('2026-09-01T00:00:00Z'),
          },
        ],
      },
      userProfile: { findMany: async () => [recipient] },
    });
    const service = new DailyScholarshipService(
      h.prisma,
      {} as unknown as ScholarshipsIndexService,
      h.dispatcher,
    );
    await service.sendDailyPush(new Date('2026-07-24T19:00:00Z'));
    expectClean(h.sent);
  });

  it('récap de la semaine', async () => {
    process.env.KPB_WEEKLY_DIGEST_ENABLED = 'true';
    const h = harness({
      userProfile: { findMany: async () => [recipient] },
      scholarship: {
        findMany: async () => [
          {
            id: 's1',
            nameFr: 'Bourse Nouvelle',
            nameEn: 'New Scholarship',
            countryId: 'fra',
            countryNameFr: 'France',
            deadlineAt: new Date(Date.now() + 40 * 86_400_000),
            cycles: [],
          },
        ],
      },
      savedItem: { findMany: async () => [] },
      case: { findMany: async () => [] },
    });
    const mail = { send: async () => true } as unknown as CampaignMailService;
    await new WeeklyDigestService(h.prisma, h.dispatcher, mail).sendWeeklyDigests(
      new Date('2026-07-27T08:00:00Z'),
    );
    expectClean(h.sent);
  });

  it('relance « complète ton profil »', async () => {
    const h = harness({
      userProfile: { findMany: async () => [recipient], update: async () => ({}) },
    });
    await new ProfileNudgeCronService(h.prisma, h.dispatcher).run(new Date('2026-07-25T12:00:00Z'));
    expectClean(h.sent);
  });

  it('communauté : réponse, réponse vérifiée, modération', async () => {
    const member = {
      id: 'mem-author',
      userId: ACCOUNT.id,
      user: { preferredLanguage: 'fr', countryOfResidence: 'SN', disabledNotificationTypes: [] },
    };
    const h = harness({
      communityFollow: { findMany: async () => [] },
      communityBlock: { findMany: async () => [] },
      communityMember: { findMany: async () => [member] },
    });
    const community = new CommunityNotificationsService(h.prisma, h.dispatcher);
    const now = new Date('2026-07-24T12:00:00Z');
    const post = { id: 'post-1', title: 'Visa étudiant', type: 'question', authorMemberId: 'mem-author' };
    await community.replyPosted({ post, reply: { id: 'rep-1', authorMemberId: 'mem-other' }, now });
    await community.verifiedAnswer({ post, reply: { id: 'rep-2', authorMemberId: null }, now });
    await community.moderation({
      memberId: 'mem-author',
      event: 'warning',
      reason: 'Respecte la charte',
      referenceId: 'ref-1',
      now,
    });
    expect(h.sent).toHaveLength(3);
    expectClean(h.sent);
  });
});
