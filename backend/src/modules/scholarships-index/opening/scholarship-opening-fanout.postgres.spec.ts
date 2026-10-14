import { randomUUID } from 'node:crypto';

import { HttpException } from '@nestjs/common';
import { AccountType, PrismaClient } from '@prisma/client';

import { runMirror } from '../../../cli/scholarship-follow-mirror.cli';
import { InternalRole } from '../../../common/enums/internal-role.enum';
import type { PushSenderService } from '../../notifications/push-sender.service';
import type { PrismaService } from '../../prisma/prisma.service';
import type { ActivateScholarshipDto } from '../dto/activate-scholarship.dto';
import type {
  ScholarshipContentQualityService,
  ScholarshipReadinessReport,
} from '../scholarship-content-quality.service';
import {
  ScholarshipLifecycleService,
  type OpeningActor,
} from '../scholarship-lifecycle.service';
import { ScholarshipOpeningAdminService } from './scholarship-opening-admin.service';
import { ScholarshipOpeningAudienceService } from './scholarship-opening-audience.service';
import { ScholarshipOpeningFanoutService } from './scholarship-opening-fanout.service';

/**
 * L'annonce d'ouverture contre un vrai PostgreSQL : audience écrite, aperçu =
 * activate = envoi, activations concurrentes, annulation contre envoi, année
 * suivante et corrections, gardes du worker, pas d'annonce rétroactive,
 * activate qui attend un envoi en cours.
 *
 * Chaque cas crée ses bourses et ses élèves (suffixe aléatoire) et les
 * supprime ensuite. Les annonces sont rendues échues en reculant
 * `openingFanoutDueAt`, puis envoyées avec l'horloge réelle : les dates de
 * début de suivi comparées à `openingNotifiedAt` restent cohérentes.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

const DAY = 24 * 60 * 60 * 1000;

describePostgres('Annonce d’ouverture — intégration PostgreSQL', () => {
  jest.setTimeout(120_000);

  const prisma = new PrismaClient();
  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;

  const READY: ScholarshipReadinessReport = {
    scholarshipId: 'x',
    ready: true,
    score: 100,
    verificationMaxAgeDays: 30,
    checks: [],
    blockingIssues: [],
  };
  const quality = {
    assertReady: async () => READY,
    getReadiness: async () => READY,
  } as unknown as ScholarshipContentQualityService;
  const pushes: string[] = [];
  const push = {
    isConfigured: true,
    providers: { fcm: false, oneSignal: true },
    sendToUser: async (userId: string) => {
      pushes.push(userId);
      return true;
    },
  } as unknown as PushSenderService;

  const audience = new ScholarshipOpeningAudienceService(prismaService);
  const lifecycle = new ScholarshipLifecycleService(prismaService, push, quality, audience);
  const fanout = new ScholarshipOpeningFanoutService(prismaService);
  const admin = new ScholarshipOpeningAdminService(prismaService, audience, quality, push);

  const run = randomUUID().slice(0, 8);
  const created = {
    users: new Set<string>(),
    scholarships: new Set<string>(),
    admins: new Set<string>(),
  };
  let seq = 0;
  const id = (kind: string) => `open-pg-${kind}-${run}-${(seq += 1)}`;

  let actor: OpeningActor;
  const savedEnv = { ...process.env };

  beforeAll(async () => {
    const adminId = id('adm');
    await prisma.adminUser.create({
      data: {
        id: adminId,
        fullName: 'Aminata D.',
        email: `${adminId}@example.test`,
        role: InternalRole.Admin,
        languageScope: [],
      },
    });
    created.admins.add(adminId);
    actor = { id: adminId, role: InternalRole.Admin };
  });

  afterEach(() => {
    for (const key of [
      'KPB_SCHOLARSHIP_OPENING_MODE',
      'KPB_OPENING_CONFIRM_THRESHOLD',
      'KPB_OPENING_RENOTIFY_DAYS',
    ]) {
      if (savedEnv[key] === undefined) delete process.env[key];
      else process.env[key] = savedEnv[key];
    }
  });

  afterAll(async () => {
    const users = [...created.users];
    const scholarships = [...created.scholarships];
    const cycles = await prisma.scholarshipCycle.findMany({
      where: { scholarshipId: { in: scholarships } },
      select: { id: true },
    });
    await prisma.adminAuditEvent.deleteMany({
      // Les refus sur une année sans cycle portent sur la bourse.
      where: { entityId: { in: [...cycles.map((cycle) => cycle.id), ...scholarships] } },
    });
    await prisma.userNotification.deleteMany({ where: { userId: { in: users } } });
    await prisma.savedItem.deleteMany({ where: { userId: { in: users } } });
    await prisma.deviceToken.deleteMany({ where: { userProfileId: { in: users } } });
    await prisma.scholarshipAlertSubscription.deleteMany({
      where: { userId: { in: users } },
    });
    await prisma.userProfile.deleteMany({ where: { id: { in: users } } });
    await prisma.scholarship.deleteMany({ where: { id: { in: scholarships } } });
    await prisma.adminUser.deleteMany({ where: { id: { in: [...created.admins] } } });
    await prisma.$disconnect();
  });

  // ── Fabriques ─────────────────────────────────────────────────────────────

  async function scholarship(): Promise<string> {
    const sid = id('sch');
    await prisma.scholarship.create({
      data: {
        id: sid,
        nameFr: `Bourse ${sid}`,
        nameEn: `Scholarship ${sid}`,
        countryId: 'gbr',
        levelEligibleFr: 'Master',
        levelEligibleEn: "Master's",
        typeOfFundingFr: 'Complète',
        typeOfFundingEn: 'Full',
        deadlineLabelFr: '—',
        deadlineLabelEn: '—',
        keyRequirementsFr: [],
        keyRequirementsEn: [],
        relatedFieldIds: [],
        isActive: true,
        moderationStatus: 'approved',
        lastVerifiedAt: new Date(),
      },
    });
    created.scholarships.add(sid);
    return sid;
  }

  async function student(
    over: { lang?: string; country?: string; optOut?: boolean; fcm?: boolean } = {},
  ): Promise<string> {
    const uid = id('usr');
    await prisma.userProfile.create({
      data: {
        id: uid,
        accountType: AccountType.student,
        preferredLanguage: over.lang ?? 'fr',
        fullName: `Élève ${uid}`,
        email: `${uid}@example.test`,
        phone: '',
        countryOfResidence: over.country ?? 'Sénégal',
        disabledNotificationTypes: over.optOut ? ['followed_scholarship_updates'] : [],
      },
    });
    if (over.fcm) {
      await prisma.deviceToken.create({
        data: { userProfileId: uid, token: `tok-${uid}`, platform: 'android' },
      });
    }
    created.users.add(uid);
    return uid;
  }

  const favorite = (userId: string, itemId: string, createdAt?: Date) =>
    prisma.savedItem.create({
      data: { userId, itemType: 'scholarship', itemId, ...(createdAt ? { createdAt } : {}) },
    });

  const alert = (
    userId: string,
    scholarshipId: string,
    over: { mutedAt?: Date; pushEnabled?: boolean } = {},
  ) =>
    prisma.scholarshipAlertSubscription.create({
      data: { userId, scholarshipId, ...over },
    });

  function activation(over: Partial<ActivateScholarshipDto> = {}): ActivateScholarshipDto {
    const now = Date.now();
    return {
      academicYear: '2026-2027',
      opensAt: new Date(now - DAY).toISOString(),
      closesAt: new Date(now + 60 * DAY).toISOString(),
      sourceUrl: 'https://example.org/official',
      ...over,
    };
  }

  /** L'annonce programmée devient échue maintenant. */
  async function makeDue(cycleId: string): Promise<void> {
    await prisma.scholarshipCycle.update({
      where: { id: cycleId },
      data: { openingFanoutDueAt: new Date(Date.now() - 1_000) },
    });
  }

  async function announce(sid: string, over: Partial<ActivateScholarshipDto> = {}) {
    const result = await lifecycle.activate(sid, activation(over), actor, `req-${run}`);
    if (result.notification.state === 'scheduled') {
      await makeDue(result.cycleId);
      await fanout.runDue(new Date());
    }
    return result;
  }

  const rowsOf = (cycleId: string) =>
    prisma.userNotification.findMany({
      where: { cycleId, kind: 'scholarship_opened' },
      select: {
        userId: true,
        pushStatus: true,
        pushLastError: true,
        titleFr: true,
        data: true,
        dedupeKey: true,
      },
      orderBy: { userId: 'asc' },
    });

  async function httpError(promise: Promise<unknown>): Promise<HttpException> {
    try {
      await promise;
    } catch (error) {
      if (error instanceof HttpException) return error;
      throw error;
    }
    throw new Error('expected an HttpException');
  }

  // ── 1. Audience ───────────────────────────────────────────────────────────

  it.each([
    ['outbox_alerts', 'alerts'],
    ['outbox_followers', 'followers'],
  ] as const)('audience écrite en portée %s', async (mode, scope) => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = mode;
    const sid = await scholarship();
    const otherCycleSid = sid;
    const u = {
      fav: await student(),
      alert: await student({ lang: 'en' }),
      both: await student(),
      mutedFav: await student(),
      pushOff: await student(),
      optOut: await student({ optOut: true }),
      recent: await student(),
      orphan: await student(),
    };
    await favorite(u.fav, sid);
    await alert(u.alert, sid);
    await favorite(u.both, sid);
    await alert(u.both, sid);
    await favorite(u.mutedFav, sid);
    await alert(u.mutedFav, sid, { mutedAt: new Date() });
    await alert(u.pushOff, sid, { pushEnabled: false });
    await alert(u.optOut, sid);
    await favorite(u.optOut, sid);
    await alert(u.recent, sid);
    await favorite(u.recent, sid);
    await favorite(u.orphan, `missing-${run}`);
    // Prévenu il y a 3 jours pour un AUTRE cycle de la même bourse, par une
    // ligne héritée sans `pushedAt` : exclu par la garde des 30 jours.
    const oldCycle = await prisma.scholarshipCycle.create({
      data: {
        scholarshipId: otherCycleSid,
        academicYear: '2025-2026',
        status: 'closed',
        dateConfidence: 'confirmed',
      },
    });
    await prisma.userNotification.create({
      data: {
        userId: u.recent,
        scholarshipId: sid,
        cycleId: oldCycle.id,
        kind: 'scholarship_opened',
        dedupeKey: `scholarship-opened:${oldCycle.id}:${u.recent}`,
        titleFr: 't',
        titleEn: 't',
        bodyFr: 'b',
        bodyEn: 'b',
        route: `/scholarships/${sid}`,
        createdAt: new Date(Date.now() - 3 * DAY),
      },
    });

    const result = await announce(sid);
    expect(result.notification.state).toBe('scheduled');

    const rows = await rowsOf(result.cycleId);
    const byUser = new Map(rows.map((row) => [row.userId, row]));
    const expected = new Map<string, [string, string | null, string]>([
      [u.alert, ['pending', null, 'alert']],
      [u.both, ['pending', null, 'alert']],
      [u.pushOff, ['skipped', 'push_disabled', 'alert']],
      [u.optOut, ['skipped', 'opt_out', 'alert']],
    ]);
    if (scope === 'followers') expected.set(u.fav, ['pending', null, 'favorite']);
    expect(new Set(byUser.keys())).toEqual(new Set(expected.keys()));
    for (const [userId, [status, reason, variant]] of expected) {
      const row = byUser.get(userId);
      expect(row).toMatchObject({
        pushStatus: status,
        pushLastError: reason,
        dedupeKey: `scholarship-opened:${result.cycleId}:${userId}`,
      });
      expect(row?.data).toMatchObject({ scholarshipId: sid, cycleId: result.cycleId, variant });
    }
    expect(byUser.get(u.alert)?.titleFr).toBe("C'est ouvert");
    if (scope === 'followers') {
      expect(byUser.get(u.fav)?.titleFr).toBe('Une bourse que tu suis est ouverte');
    }
    const cycle = await prisma.scholarshipCycle.findUniqueOrThrow({
      where: { id: result.cycleId },
    });
    expect(cycle).toMatchObject({
      openingFanoutDueAt: null,
      openingAudience: expected.size,
      openingNotifiedById: actor.id,
    });
    expect(cycle.openingNotifiedAt).toBeInstanceOf(Date);
  });

  // ── 2. Aperçu = activate = envoi ──────────────────────────────────────────

  it('aperçu, activate et envoi comptent la même audience', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_followers';
    const sid = await scholarship();
    for (let i = 0; i < 6; i += 1) {
      const uid = await student({ fcm: i === 0, lang: i === 2 ? 'en' : 'fr' });
      if (i % 2 === 0) await favorite(uid, sid);
      if (i % 3 === 0) await alert(uid, sid);
      if (i === 5) await alert(uid, sid, { mutedAt: new Date() });
    }
    const preview = await admin.preview(sid, { academicYear: '2026-2027' }, actor);
    expect(preview.target).toMatchObject({ exists: false, firstActivation: true, defaultNotify: true });
    const result = await lifecycle.activate(sid, activation(), actor, 'req');
    expect(result.notification.toNotify).toBe(preview.audience.toNotify);
    await makeDue(result.cycleId);
    const tally = await fanout.runDue(new Date());
    const rows = await rowsOf(result.cycleId);
    expect(rows).toHaveLength(preview.audience.toNotify);
    expect(tally.inserted).toBeGreaterThanOrEqual(rows.length);
    expect(preview.audience.devices.fcm).toBe(1);
    expect(preview.audience.byLanguage.en).toBe(1);

    const report = await admin.report(sid, result.cycleId);
    expect(report.inbox.total).toBe(rows.length);
    expect(report.push.pending).toBe(rows.length);
    expect(report.fanout).toMatchObject({
      scope: 'followers',
      notifiedBy: { id: actor.id, name: 'Aminata D.' },
    });
    const after = await admin.preview(sid, {}, actor);
    expect(after.target).toMatchObject({
      academicYear: '2026-2027',
      alreadyAnnounced: true,
      defaultNotify: false,
    });
    expect(after.audience.toNotify).toBe(0);
    expect(after.recentEvents.map((event) => event.action)).toEqual([
      'scholarship_cycle.fanout_completed',
      'scholarship_cycle.notify_scheduled',
    ]);
    expect(after.recentEvents[1]).toMatchObject({ actorName: 'Aminata D.', academicYear: '2026-2027' });
  });

  it('legacy : aperçu = activate = envoi, y compris après une mauvaise année', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'legacy';
    const sid = await scholarship();
    const u = {
      first: await student(),
      optOut: await student({ optOut: true }),
      muted: await student(),
      fav: await student(),
    };
    await alert(u.first, sid);
    await alert(u.optOut, sid);
    await alert(u.muted, sid, { mutedAt: new Date() });
    await favorite(u.fav, sid);

    // 1. L'équipe ouvre 2026-2027 par erreur : prévenus = l'aperçu ; le
    //    désinscrit a son entrée d'inbox, pas de push.
    const wrongPreview = await admin.preview(sid, { academicYear: '2026-2027' }, actor);
    expect(wrongPreview.mode).toBe('legacy');
    expect(wrongPreview.audience).toMatchObject({
      toNotify: 2,
      optedOut: 1,
      pushEligible: 1,
      muted: 1,
      // Envoi immédiat : ni heures calmes ni rythme, quelle que soit l'heure.
      deferredQuietHours: 0,
      deferredPacing: 0,
    });
    pushes.length = 0;
    const wrong = await lifecycle.activate(
      sid,
      activation({ notify: true, expectedRecipients: wrongPreview.audience.toNotify }),
      actor,
      'legacy-wrong',
    );
    expect(wrong.notification).toMatchObject({ state: 'sent_legacy', toNotify: 2 });
    expect(wrong.pushesSent).toBe(1);
    expect(pushes).toEqual([u.first]);
    expect((await rowsOf(wrong.cycleId)).map((row) => row.userId).sort()).toEqual(
      [u.first, u.optOut].sort(),
    );

    // 2. Puis la bonne année : la garde des 30 jours vaut aussi en legacy,
    //    seul l'abonné arrivé depuis est prévenu, et le nombre confirmé passe.
    const late = await student();
    await alert(late, sid);
    const preview = await admin.preview(sid, { academicYear: '2027-2028' }, actor);
    expect(preview.audience).toMatchObject({ toNotify: 1, recentlyNotified: 2 });
    pushes.length = 0;
    const right = await lifecycle.activate(
      sid,
      activation({
        academicYear: '2027-2028',
        notify: true,
        expectedRecipients: preview.audience.toNotify,
      }),
      actor,
      'legacy-right',
    );
    expect(right).toMatchObject({
      subscribers: 3,
      pushesSent: 1,
      notification: { state: 'sent_legacy', toNotify: 1 },
    });
    expect(pushes).toEqual([late]);
    expect((await rowsOf(right.cycleId)).map((row) => row.userId)).toEqual([late]);
  });

  // ── 3. Activations concurrentes ───────────────────────────────────────────

  it('deux premiers clics simultanés : une première activation, une programmation, pas de 500', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
    const sid = await scholarship();
    await alert(await student(), sid);
    const [a, b] = await Promise.all([
      lifecycle.activate(sid, activation(), actor, 'r1'),
      lifecycle.activate(sid, activation(), actor, 'r2'),
    ]);
    expect([a.firstActivation, b.firstActivation].sort()).toEqual([false, true]);
    expect([a.notification.state, b.notification.state].sort()).toEqual([
      'already_scheduled',
      'scheduled',
    ]);
    expect(a.cycleId).toBe(b.cycleId);
    expect(a.notification.fanoutAt).toBe(b.notification.fanoutAt);
  });

  // ── 4. Annulation contre envoi ────────────────────────────────────────────

  it('annulation contre envoi (×30) : exactement un gagnant', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
    const followers = [await student(), await student()];
    let cancelWins = 0;
    let fanoutWins = 0;
    for (let i = 0; i < 30; i += 1) {
      const sid = await scholarship();
      for (const uid of followers) await alert(uid, sid);
      const result = await lifecycle.activate(sid, activation(), actor, `race-${i}`);
      await makeDue(result.cycleId);
      const [cancelled] = await Promise.all([
        admin.cancel(sid, result.cycleId, actor, `cancel-${i}`).then(
          () => true,
          (error: unknown) => {
            expect(error).toBeInstanceOf(HttpException);
            const body = (error as HttpException).getResponse() as {
              code: string;
              details: { lastFanoutAt: string | null };
            };
            expect(body.code).toBe('OPENING_NOT_SCHEDULED');
            expect(body.details.lastFanoutAt).not.toBeNull();
            return false;
          },
        ),
        fanout.runDue(new Date()),
      ]);
      const rows = await rowsOf(result.cycleId);
      const cycle = await prisma.scholarshipCycle.findUniqueOrThrow({
        where: { id: result.cycleId },
      });
      expect(cycle.openingFanoutDueAt).toBeNull();
      if (cancelled) {
        cancelWins += 1;
        expect(rows).toHaveLength(0);
        expect(cycle.openingLastFanoutAt).toBeNull();
        // Plus tard, l'équipe annonce pour de bon.
        const again = await announce(sid, { notify: true });
        expect(again.notification.state).toBe('scheduled');
        expect(await rowsOf(result.cycleId)).toHaveLength(2);
      } else {
        fanoutWins += 1;
        expect(rows).toHaveLength(2);
      }
    }
    expect(cancelWins + fanoutWins).toBe(30);
  });

  it('annulation hors programmation : 409 sans « trop tard », 404 hors bourse', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
    const sid = await scholarship();
    await alert(await student(), sid);
    const result = await lifecycle.activate(sid, activation({ notify: false }), actor, 'r');
    const conflict = await httpError(admin.cancel(sid, result.cycleId, actor, 'c'));
    expect(conflict.getStatus()).toBe(409);
    expect(conflict.getResponse()).toMatchObject({
      code: 'OPENING_NOT_SCHEDULED',
      details: { lastFanoutAt: null },
    });
    const other = await scholarship();
    expect((await httpError(admin.cancel(other, result.cycleId, actor, 'c'))).getStatus()).toBe(404);
  });

  // ── 5. Année suivante et corrections ──────────────────────────────────────

  it('nouvelle année, correction de dates, relance aux seuls nouveaux abonnés', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_followers';
    const sid = await scholarship();
    const early = await student();
    await favorite(early, sid);

    const first = await announce(sid);
    expect(await rowsOf(first.cycleId)).toHaveLength(1);

    // Correction des dates, même année, sans `notify` : rien de nouveau.
    const fix = await lifecycle.activate(
      sid,
      activation({ closesAt: new Date(Date.now() + 90 * DAY).toISOString() }),
      actor,
      'fix',
    );
    expect(fix.notification).toMatchObject({ state: 'none', reason: 'already_announced' });

    // Un nouvel abonné après l'annonce : la relance ne vise que lui.
    await new Promise((resolve) => setTimeout(resolve, 20));
    const late = await student();
    await favorite(late, sid);
    const preview = await admin.preview(sid, { academicYear: '2026-2027' }, actor);
    expect(preview.audience.toNotify).toBe(1);
    const again = await announce(sid, { notify: true });
    expect(again.notification).toMatchObject({ state: 'scheduled', toNotify: 1 });
    expect((await rowsOf(first.cycleId)).map((row) => row.userId).sort()).toEqual(
      [early, late].sort(),
    );
    const cycle = await prisma.scholarshipCycle.findUniqueOrThrow({ where: { id: first.cycleId } });
    expect(cycle.openingAudience).toBe(2);

    // L'année suivante est une nouvelle annonce (au-delà des 30 jours).
    await prisma.userNotification.updateMany({
      where: { cycleId: first.cycleId },
      data: { createdAt: new Date(Date.now() - 40 * DAY) },
    });
    const next = await announce(sid, { academicYear: '2027-2028' });
    expect(next.firstActivation).toBe(true);
    expect(await rowsOf(next.cycleId)).toHaveLength(2);
  });

  // ── 6. Gardes du worker ───────────────────────────────────────────────────

  it('bourse retirée pendant l’attente → not_public_at_fanout, aucune ligne', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
    const sid = await scholarship();
    await alert(await student(), sid);
    const result = await lifecycle.activate(sid, activation(), actor, 'r');
    await prisma.scholarship.update({ where: { id: sid }, data: { isActive: false } });
    await makeDue(result.cycleId);
    await fanout.runDue(new Date());
    expect(await rowsOf(result.cycleId)).toHaveLength(0);
    expect(
      await prisma.scholarshipCycle.findUniqueOrThrow({ where: { id: result.cycleId } }),
    ).toMatchObject({ openingFanoutDueAt: null, openingSkippedReason: 'not_public_at_fanout' });
    // Le fil de l'équipe dit « abandonné », jamais « envoyé ».
    const preview = await admin.preview(sid, { academicYear: '2026-2027' }, actor);
    expect(preview.recentEvents[0]).toMatchObject({
      action: 'scholarship_cycle.fanout_completed',
      outcome: 'skipped',
      reasonCode: 'not_public_at_fanout',
      toNotify: 0,
    });
    expect(preview.recentEvents[1]).toMatchObject({
      action: 'scholarship_cycle.notify_scheduled',
      outcome: 'sent',
    });
    expect(preview.recentEvents[1]).not.toHaveProperty('reasonCode');
  });

  it('clôture passée pendant l’attente → cycle_closed_at_fanout, aucune ligne', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
    const sid = await scholarship();
    await alert(await student(), sid);
    const result = await lifecycle.activate(sid, activation(), actor, 'r');
    await prisma.scholarshipCycle.update({
      where: { id: result.cycleId },
      data: { closesAt: new Date(Date.now() - 60_000) },
    });
    await makeDue(result.cycleId);
    await fanout.runDue(new Date());
    expect(await rowsOf(result.cycleId)).toHaveLength(0);
    expect(
      await prisma.scholarshipCycle.findUniqueOrThrow({ where: { id: result.cycleId } }),
    ).toMatchObject({ openingSkippedReason: 'cycle_closed_at_fanout' });
    const preview = await admin.preview(sid, { academicYear: '2026-2027' }, actor);
    expect(preview.recentEvents[0]).toMatchObject({
      outcome: 'skipped',
      reasonCode: 'cycle_closed_at_fanout',
    });
  });

  it('échue depuis 25 h → fanout_expired, aucune ligne, le cycle revient dans « À faire »', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
    const sid = await scholarship();
    await alert(await student(), sid);
    const result = await lifecycle.activate(sid, activation(), actor, 'r');
    await prisma.scholarshipCycle.update({
      where: { id: result.cycleId },
      data: { openingFanoutDueAt: new Date(Date.now() - 25 * 60 * 60 * 1000) },
    });
    const tally = await fanout.runDue(new Date());
    expect(tally.dropped).toBeGreaterThanOrEqual(1);
    expect(await rowsOf(result.cycleId)).toHaveLength(0);
    const events = await prisma.adminAuditEvent.findMany({
      where: { entityId: result.cycleId },
      select: { action: true },
    });
    expect(events.map((event) => event.action)).toContain('scholarship_cycle.fanout_expired');
    const preview = await admin.preview(sid, { academicYear: '2026-2027' }, actor);
    expect(preview.recentEvents[0]).toMatchObject({
      action: 'scholarship_cycle.fanout_expired',
      outcome: 'skipped',
      reasonCode: 'fanout_too_late',
    });
    const todo = await admin.todo();
    expect(todo.items.map((item) => item.cycleId)).toContain(result.cycleId);
    expect(todo.items.find((item) => item.cycleId === result.cycleId)).toMatchObject({
      source: 'admin',
      followers: 1,
      notifiable: 1,
    });
  });

  it('« À faire » : un seul nombre, abonnés à prévenir = colonne « Abonnés » = aperçu', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
    const sid = await scholarship();
    // Deux favoris seuls, une alerte, une alerte en sourdine sur un favori.
    await favorite(await student(), sid);
    await favorite(await student(), sid);
    await alert(await student(), sid);
    const muted = await student();
    await favorite(muted, sid);
    await alert(muted, sid, { mutedAt: new Date() });
    // Ouvert par le catalogue après la mise en service : dans « À faire ».
    const cycle = await prisma.scholarshipCycle.create({
      data: {
        scholarshipId: sid,
        academicYear: '2026-2027',
        status: 'open',
        dateConfidence: 'confirmed',
        opensAt: new Date(Date.now() - DAY),
        closesAt: new Date(Date.now() + 60 * DAY),
      },
    });

    const todo = await admin.todo();
    const item = todo.items.find((row) => row.cycleId === cycle.id);
    // Le favori en sourdine suit toujours (rappels) : 4 suivent, 1 à prévenir
    // en portée « alertes ».
    expect(item).toMatchObject({ source: 'catalogue', followers: 4, notifiable: 1 });
    const overview = await admin.overview();
    expect(overview.items.find((row) => row.scholarshipId === sid)?.notifiable).toBe(
      item?.notifiable,
    );
    const preview = await admin.preview(sid, { academicYear: '2026-2027' }, actor);
    expect(preview.audience.toNotify).toBe(item?.notifiable);
  });

  // ── 6b. Pas d'annonce rétroactive ─────────────────────────────────────────

  it('après la bascule et la CLI, une relance ne touche que les abonnés postérieurs', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
    const sid = await scholarship();
    const alertOld = await student();
    const favOld = await student();
    const alertWithFav = await student();
    await alert(alertOld, sid);
    await favorite(favOld, sid);
    await alert(alertWithFav, sid);
    await favorite(alertWithFav, sid);
    const first = await announce(sid);
    expect((await rowsOf(first.cycleId)).map((row) => row.userId).sort()).toEqual(
      [alertOld, alertWithFav].sort(),
    );

    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_followers';
    const mirrored = await runMirror(prisma, { apply: true });
    expect(mirrored.refused).toBeNull();
    expect(mirrored.inserted).toBeGreaterThanOrEqual(1);
    expect(
      await prisma.scholarshipAlertSubscription.findMany({
        where: { scholarshipId: sid },
        select: { userId: true, impliedFollow: true },
        orderBy: { userId: 'asc' },
      }),
    ).toEqual(
      [
        { userId: alertOld, impliedFollow: true },
        { userId: alertWithFav, impliedFollow: false },
      ].sort((a, b) => a.userId.localeCompare(b.userId)),
    );
    // Idempotent.
    expect((await runMirror(prisma, { apply: true })).inserted).toBe(0);

    await new Promise((resolve) => setTimeout(resolve, 20));
    const favNew = await student();
    await favorite(favNew, sid);
    const again = await announce(sid, { notify: true });
    expect(again.notification.toNotify).toBe(1);
    expect((await rowsOf(first.cycleId)).map((row) => row.userId).sort()).toEqual(
      [alertOld, alertWithFav, favNew].sort(),
    );
  });

  it('cycle pré-existant (reprise) : notify:true → 409, seul le refus à l’audit', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_followers';
    const sid = await scholarship();
    await favorite(await student(), sid);
    const cycle = await prisma.scholarshipCycle.create({
      data: {
        scholarshipId: sid,
        academicYear: '2026-2027',
        status: 'open',
        dateConfidence: 'confirmed',
        activatedAt: new Date(Date.now() - 10 * DAY),
        openingNotifiedAt: new Date(Date.now() - 10 * DAY),
        openingPreExisting: true,
      },
    });
    const error = await httpError(
      lifecycle.activate(sid, activation({ notify: true }), actor, 'r'),
    );
    expect(error.getStatus()).toBe(409);
    expect(error.getResponse()).toMatchObject({ code: 'OPENING_NOT_RETROACTIVE' });
    expect(
      await prisma.adminAuditEvent.findMany({
        where: { entityId: cycle.id },
        select: { result: true, reasonCode: true, actorAdminId: true },
      }),
    ).toEqual([{ result: 'refused', reasonCode: 'OPENING_NOT_RETROACTIVE', actorAdminId: actor.id }]);
    expect(await rowsOf(cycle.id)).toHaveLength(0);
    expect(
      await prisma.scholarshipCycle.findUniqueOrThrow({ where: { id: cycle.id } }),
    ).toMatchObject({ openingFanoutDueAt: null, openingSkippedAt: null });
    const preview = await admin.preview(sid, { academicYear: '2026-2027' }, actor);
    expect(preview.recentEvents[0]).toMatchObject({
      outcome: 'refused',
      reasonCode: 'OPENING_NOT_RETROACTIVE',
      actorName: 'Aminata D.',
      academicYear: '2026-2027',
    });
  });

  // ── 6c. activate attend un envoi en cours ─────────────────────────────────

  it('cycle tenu par un envoi au-delà de 5 s → 409 OPENING_BUSY, rien d’écrit', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
    const sid = await scholarship();
    await alert(await student(), sid);
    const result = await lifecycle.activate(sid, activation({ notify: false }), actor, 'r');
    const auditsBefore = await prisma.adminAuditEvent.count({
      where: { entityId: result.cycleId },
    });

    let locked: () => void = () => undefined;
    const lockTaken = new Promise<void>((resolve) => {
      locked = resolve;
    });
    const holder = prisma.$transaction(
      async (tx) => {
        await tx.$queryRaw`SELECT "id" FROM "ScholarshipCycle" WHERE "id" = ${result.cycleId} FOR UPDATE`;
        locked();
        await new Promise((resolve) => setTimeout(resolve, 7_000));
      },
      { timeout: 20_000 },
    );
    await lockTaken;
    const started = Date.now();
    const error = await httpError(
      lifecycle.activate(sid, activation({ notify: true }), actor, 'busy'),
    );
    const waited = Date.now() - started;
    await holder;

    expect(error.getStatus()).toBe(409);
    expect(error.getResponse()).toMatchObject({ code: 'OPENING_BUSY' });
    expect(waited).toBeGreaterThanOrEqual(4_500);
    expect(waited).toBeLessThan(7_000);
    expect(
      await prisma.adminAuditEvent.count({ where: { entityId: result.cycleId } }),
    ).toBe(auditsBefore);
    expect(
      await prisma.scholarshipCycle.findUniqueOrThrow({ where: { id: result.cycleId } }),
    ).toMatchObject({ openingFanoutDueAt: null });
  });

  it.each(['stop', 'cancel'] as const)(
    '%s sur un cycle tenu par un envoi au-delà de 5 s → 409 OPENING_BUSY, rien d’écrit',
    async (op) => {
      process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_alerts';
      const sid = await scholarship();
      await alert(await student(), sid);
      const result = await lifecycle.activate(sid, activation(), actor, 'r');
      expect(result.notification.state).toBe('scheduled');
      const auditsBefore = await prisma.adminAuditEvent.count({
        where: { entityId: result.cycleId },
      });

      let locked: () => void = () => undefined;
      const lockTaken = new Promise<void>((resolve) => {
        locked = resolve;
      });
      const holder = prisma.$transaction(
        async (tx) => {
          await tx.$queryRaw`SELECT "id" FROM "ScholarshipCycle" WHERE "id" = ${result.cycleId} FOR UPDATE`;
          locked();
          await new Promise((resolve) => setTimeout(resolve, 7_000));
        },
        { timeout: 20_000 },
      );
      await lockTaken;
      const started = Date.now();
      const error = await httpError(
        op === 'stop'
          ? admin.stop(sid, result.cycleId, actor, 'busy')
          : admin.cancel(sid, result.cycleId, actor, 'busy'),
      );
      const waited = Date.now() - started;
      await holder;

      expect(error.getStatus()).toBe(409);
      expect(error.getResponse()).toMatchObject({
        code: 'OPENING_BUSY',
        message:
          'Un envoi est en cours de préparation pour ce cycle. Réessayez dans quelques secondes.',
      });
      expect(waited).toBeGreaterThanOrEqual(4_500);
      expect(waited).toBeLessThan(7_000);
      expect(
        await prisma.adminAuditEvent.count({ where: { entityId: result.cycleId } }),
      ).toBe(auditsBefore);
      expect(
        await prisma.scholarshipCycle.findUniqueOrThrow({ where: { id: result.cycleId } }),
      ).toMatchObject({ openingStoppedAt: null, openingFanoutDueAt: expect.any(Date) });
    },
  );

  // ── Seuil (vrai compte) et vue d'ensemble ─────────────────────────────────

  it('au-delà du seuil : 400 sans confirmation, 403 pour un ContentManager', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_followers';
    process.env.KPB_OPENING_CONFIRM_THRESHOLD = '2';
    const sid = await scholarship();
    for (let i = 0; i < 3; i += 1) await favorite(await student(), sid);
    const missing = await httpError(lifecycle.activate(sid, activation(), actor, 'r'));
    expect(missing.getResponse()).toMatchObject({
      code: 'OPENING_CONFIRMATION_REQUIRED',
      details: { toNotify: 3, threshold: 2 },
    });
    const cm = await httpError(
      lifecycle.activate(
        sid,
        activation({ expectedRecipients: 3 }),
        { id: actor.id, role: InternalRole.ContentManager },
        'r',
      ),
    );
    expect(cm.getStatus()).toBe(403);
    // Rien d'écrit pour les étudiants : le cycle n'existe toujours pas. Le
    // refus est à l'audit, sur la bourse, et dans le fil de l'aperçu.
    expect(await prisma.scholarshipCycle.count({ where: { scholarshipId: sid } })).toBe(0);
    expect(
      await prisma.adminAuditEvent.findMany({
        where: { entityType: 'Scholarship', entityId: sid },
        select: { result: true, reasonCode: true },
      }),
    ).toEqual([{ result: 'refused', reasonCode: 'OPENING_REQUIRES_ADMIN' }]);
    const refused = await admin.preview(sid, { academicYear: '2026-2027' }, actor);
    expect(refused.recentEvents).toEqual([
      expect.objectContaining({
        outcome: 'refused',
        reasonCode: 'OPENING_REQUIRES_ADMIN',
        academicYear: '2026-2027',
        toNotify: 3,
      }),
    ]);
    const ok = await lifecycle.activate(sid, activation({ expectedRecipients: 3 }), actor, 'r');
    expect(ok.notification).toMatchObject({ state: 'scheduled', toNotify: 3 });

    const overview = await admin.overview();
    expect(overview.items.find((item) => item.scholarshipId === sid)).toMatchObject({
      followers: 3,
      notifiable: 3,
      lastAnnounced: null,
      scheduledAt: ok.notification.fanoutAt,
    });
  });
});
