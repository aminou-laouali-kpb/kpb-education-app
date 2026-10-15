import { randomUUID } from 'node:crypto';

import { AccountType, Prisma, PrismaClient } from '@prisma/client';

import { InternalRole } from '../../common/enums/internal-role.enum';
import type { PrismaService } from '../prisma/prisma.service';
import type {
  ScholarshipContentQualityService,
  ScholarshipReadinessReport,
} from '../scholarships-index/scholarship-content-quality.service';
import { ScholarshipLifecycleService } from '../scholarships-index/scholarship-lifecycle.service';
import { ScholarshipOpeningAdminService } from '../scholarships-index/opening/scholarship-opening-admin.service';
import { ScholarshipOpeningAudienceService } from '../scholarships-index/opening/scholarship-opening-audience.service';
import { ScholarshipOpeningFanoutService } from '../scholarships-index/opening/scholarship-opening-fanout.service';
import { readOpeningTunables } from '../scholarships-index/opening/scholarship-opening.contract';
import { NotificationDispatchService } from './notification-dispatch.service';
import type { OutboxSend } from './push-outbox-plan';
import { PushOutboxWorkerService } from './push-outbox-worker.service';
import type {
  PushDeliveryOutcome,
  PushSenderService,
} from './push-sender.service';

/**
 * La boîte d'envoi contre un vrai PostgreSQL : deux workers, un crash après
 * réservation, l'arrêt par l'équipe, le plafond du dispatcher après un
 * groupé, heures calmes et rythme sur de vraies lignes, et 5 000 abonnés.
 *
 * Une seule horloge : un midi UTC À VENIR (`anchor`). Les élèves (Sénégal,
 * UTC+0) n'y sont jamais en heures calmes, quelle que soit l'heure où la CI
 * tourne. TOUT instant du fichier en dérive (`at(minutes)`) — dates des
 * cycles, `activate`, échéance de l'envoi, passages du worker — et jamais de
 * `Date.now()` : mêler les deux horloges faisait échouer l'échelle 5 000
 * quand la suite démarrait entre 11 h 50 et 12 h UTC (l'ancre passait au
 * lendemain, l'échéance réelle tombait à plus de 24 h avant elle, et l'envoi
 * était abandonné comme « trop en retard »). Seules les DURÉES mesurées
 * lisent l'horloge réelle.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

const MIN = 60 * 1000;
const DAY = 24 * 60 * MIN;

function nextNoonUtc(after: number): Date {
  const noon = new Date(after);
  noon.setUTCHours(12, 0, 0, 0);
  if (noon.getTime() <= after) noon.setTime(noon.getTime() + DAY);
  return noon;
}

type SentPush = {
  userId: string;
  title: string;
  data: Record<string, string>;
  options: { collapseKey?: string; idempotencyKey?: string };
};

describePostgres('Boîte d’envoi push — intégration PostgreSQL', () => {
  jest.setTimeout(180_000);

  const prisma = new PrismaClient();
  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;

  const anchor = nextNoonUtc(Date.now() + 10 * MIN);
  const at = (minutes: number) => new Date(anchor.getTime() + minutes * MIN);
  /** Avant l'ancre de plus de 24 h 10 : toujours dans le passé réel aussi. */
  const longAgo = at(-3 * 24 * 60);

  let sent: SentPush[] = [];
  let outcome: PushDeliveryOutcome = { status: 'accepted', via: 'fcm', reason: null };
  let latency = () => 5 + Math.floor(Math.random() * 25);
  const push = {
    isConfigured: true,
    providers: { fcm: true, oneSignal: true },
    sendToUser: async () => true,
    sendWithStatus: async (
      userId: string,
      title: string,
      _body: string,
      data: Record<string, string>,
      options: { collapseKey?: string; idempotencyKey?: string } = {},
    ): Promise<PushDeliveryOutcome> => {
      const delay = latency();
      if (delay > 0) await new Promise((resolve) => setTimeout(resolve, delay));
      sent.push({ userId, title, data, options });
      return outcome;
    },
  } as unknown as PushSenderService;

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
  const audience = new ScholarshipOpeningAudienceService(prismaService);
  const fanout = new ScholarshipOpeningFanoutService(prismaService);
  const admin = new ScholarshipOpeningAdminService(prismaService, audience, quality, push);
  const lifecycle = new ScholarshipLifecycleService(prismaService, push, quality, audience);
  const worker = () => new PushOutboxWorkerService(prismaService, push, fanout);
  const actor = { id: 'adm-outbox-pg', role: InternalRole.Admin };

  const run = randomUUID().slice(0, 8);
  const prefix = `outbox-pg-${run}`;
  let seq = 0;
  const id = (kind: string) => `${prefix}-${kind}-${(seq += 1)}`;
  const savedEnv = { ...process.env };

  beforeEach(() => {
    sent = [];
    outcome = { status: 'accepted', via: 'fcm', reason: null };
    latency = () => 5 + Math.floor(Math.random() * 25);
  });

  afterEach(() => {
    if (savedEnv.KPB_SCHOLARSHIP_OPENING_MODE === undefined) {
      delete process.env.KPB_SCHOLARSHIP_OPENING_MODE;
    } else {
      process.env.KPB_SCHOLARSHIP_OPENING_MODE = savedEnv.KPB_SCHOLARSHIP_OPENING_MODE;
    }
  });

  afterAll(async () => {
    const like = `${prefix}-%`;
    await prisma.$executeRaw`
      DELETE FROM "AdminAuditEvent" WHERE "entityId" IN (
        SELECT c."id" FROM "ScholarshipCycle" c WHERE c."scholarshipId" LIKE ${like}
      )`;
    await prisma.$executeRaw`DELETE FROM "UserNotification" WHERE "userId" LIKE ${like}`;
    await prisma.$executeRaw`DELETE FROM "SavedItem" WHERE "userId" LIKE ${like}`;
    await prisma.$executeRaw`DELETE FROM "ScholarshipAlertSubscription" WHERE "userId" LIKE ${like}`;
    await prisma.$executeRaw`DELETE FROM "UserProfile" WHERE "id" LIKE ${like}`;
    await prisma.$executeRaw`DELETE FROM "Scholarship" WHERE "id" LIKE ${like}`;
    await prisma.$disconnect();
  });

  // ── Fabriques ─────────────────────────────────────────────────────────────

  async function student(country = 'Sénégal'): Promise<string> {
    const uid = id('usr');
    await prisma.userProfile.create({
      data: {
        id: uid,
        accountType: AccountType.student,
        preferredLanguage: 'fr',
        fullName: `Élève ${uid}`,
        email: `${uid}@example.test`,
        phone: '',
        countryOfResidence: country,
      },
    });
    return uid;
  }

  /** Une bourse publique et son cycle ouvert. */
  async function openCycle(): Promise<{ sid: string; cid: string }> {
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
        lastVerifiedAt: longAgo,
      },
    });
    const cycle = await prisma.scholarshipCycle.create({
      data: {
        scholarshipId: sid,
        academicYear: '2026-2027',
        status: 'open',
        dateConfidence: 'confirmed',
        opensAt: longAgo,
        closesAt: new Date(anchor.getTime() + 60 * DAY),
        activatedAt: longAgo,
        openingNotifiedAt: longAgo,
      },
    });
    return { sid, cid: cycle.id };
  }

  /** Une ligne `pending` comme l'envoi l'écrit, suivie par un favori. */
  async function pendingRow(
    userId: string,
    cycle: { sid: string; cid: string },
    notBefore: Date = at(-1),
    variant: 'favorite' | 'dates_confirmed' = 'favorite',
  ): Promise<string> {
    await prisma.savedItem.upsert({
      where: {
        userId_itemType_itemId: { userId, itemType: 'scholarship', itemId: cycle.sid },
      },
      create: { userId, itemType: 'scholarship', itemId: cycle.sid },
      update: {},
    });
    const row = await prisma.userNotification.create({
      data: {
        userId,
        scholarshipId: cycle.sid,
        cycleId: cycle.cid,
        kind: 'scholarship_opened',
        dedupeKey: `scholarship-opened:${cycle.cid}:${userId}`,
        titleFr: "C'est ouvert",
        titleEn: 'Applications are open',
        bodyFr: `${cycle.sid} : candidatures ouvertes.`,
        bodyEn: `${cycle.sid}: applications are open.`,
        route: `/scholarships/${cycle.sid}`,
        data: { scholarshipId: cycle.sid, cycleId: cycle.cid, variant },
        pushStatus: 'pending',
        pushNotBefore: notBefore,
      },
    });
    return row.id;
  }

  const rowState = (rowId: string) =>
    prisma.userNotification.findUniqueOrThrow({
      where: { id: rowId },
      select: {
        pushStatus: true,
        pushLastError: true,
        pushNotBefore: true,
        pushedAt: true,
        pushAttempts: true,
        pushBatchId: true,
        pushLockedBy: true,
      },
    });

  function sendOf(rowId: string, dedupeKey: string): OutboxSend {
    return {
      kind: 'single',
      rows: [{ id: rowId, pushAttempts: 0 }],
      leadRowId: rowId,
      title: 't',
      body: 'b',
      data: {},
      idempotencyKey: dedupeKey,
      collapseKey: 'kpb-x',
    };
  }

  /** Les lignes couvertes par les push envoyés (un groupé en couvre `count`). */
  const coveredKeys = () =>
    sent.flatMap((push) =>
      push.data.notificationKey
        ? [push.data.notificationKey]
        : push.data.refs.split(',').map((ref) => `${ref}:${push.userId}`),
    );

  // ── 7. Deux workers ───────────────────────────────────────────────────────

  it('deux workers en parallèle : chaque ligne part exactement une fois', async () => {
    const cycle = await openCycle();
    const keys: string[] = [];
    for (let i = 0; i < 40; i += 1) {
      const uid = await student();
      await pendingRow(uid, cycle);
      keys.push(`scholarship-opened:${cycle.cid}:${uid}`);
    }
    const [a, b] = await Promise.all([worker().runOnce(anchor), worker().runOnce(anchor)]);
    expect(a.accepted + b.accepted).toBe(40);
    expect(coveredKeys().sort()).toEqual(keys.sort());
    expect(
      await prisma.userNotification.count({
        where: { cycleId: cycle.cid, pushStatus: 'accepted', pushedAt: { not: null } },
      }),
    ).toBe(40);
  });

  it('même élève, deux lignes réservées par deux workers : jamais deux push en 30 min', async () => {
    const uid = await student();
    const row1 = await pendingRow(uid, await openCycle(), at(-2));
    const row2 = await pendingRow(uid, await openCycle(), at(-1));
    const a = worker();
    const b = worker();

    // A tient la ligne 1 ; B réserve la ligne 2 et voit A sur le même élève.
    expect((await a.claim(anchor, 1)).map((row) => row.id)).toEqual([row1]);
    const tallyB = await b.runOnce(anchor);
    expect(tallyB.deferredBusy).toBe(1);
    expect(sent).toHaveLength(0);
    expect(await rowState(row2)).toMatchObject({
      pushStatus: 'pending',
      pushLastError: 'deferred_busy',
      pushLockedBy: null,
      pushAttempts: 0,
    });

    // A reprend la main : la ligne 1 part seule.
    await a.release([row1]);
    await a.runOnce(anchor);
    expect(sent).toHaveLength(1);

    // La ligne 2 revient après son report : le rythme la repousse à +30 min.
    await b.runOnce(at(2));
    expect(sent).toHaveLength(1);
    const deferred = await rowState(row2);
    expect(deferred.pushLastError).toBe('deferred_pacing');
    const first = await rowState(row1);
    expect(deferred.pushNotBefore?.getTime()).toBeGreaterThanOrEqual(
      (first.pushedAt?.getTime() ?? 0) + 30 * MIN,
    );

    await b.runOnce(at(31));
    expect(sent).toHaveLength(2);
    const second = await rowState(row2);
    expect(
      (second.pushedAt?.getTime() ?? 0) - (first.pushedAt?.getTime() ?? 0),
    ).toBeGreaterThanOrEqual(30 * MIN);
  });

  /**
   * Un client dont la lecture de garde (rythme + contention, reconnue à
   * `"pushLockedBy" <>`) attend `gate` — après la fin de toutes les autres
   * lectures déjà lancées par le même worker. Force l'entrelacement : « le
   * rythme est lu AVANT la finalisation de l'autre worker, la contention
   * APRÈS ».
   */
  function guardGatedPrisma(gate: Promise<void>, onGuard: () => void): PrismaService {
    const inFlight: Promise<unknown>[] = [];
    const client = new Proxy(prisma, {
      get(target, prop) {
        if (prop === '$queryRaw') {
          return (query: TemplateStringsArray | Prisma.Sql, ...values: unknown[]) => {
            const text = Array.isArray(query)
              ? query.join('?')
              : (query as Prisma.Sql).strings.join('?');
            const runQuery = () =>
              Array.isArray(query)
                ? target.$queryRaw(query as TemplateStringsArray, ...values)
                : target.$queryRaw(query as Prisma.Sql);
            if (text.includes('"pushLockedBy" <>')) {
              const before = [...inFlight];
              return (async () => {
                await Promise.allSettled(before);
                onGuard();
                await gate;
                return runQuery();
              })();
            }
            const started = Promise.resolve(runQuery());
            inFlight.push(started.catch(() => undefined));
            return started;
          };
        }
        const value: unknown = Reflect.get(target, prop);
        return typeof value === 'function' ? value.bind(target) : value;
      },
    });
    return {
      isEnabled: true,
      execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
        operation(client),
    } as unknown as PrismaService;
  }

  it('même élève : une finalisation entre deux lectures de la garde ne fait jamais deux push', async () => {
    const uid = await student();
    const row1 = await pendingRow(uid, await openCycle(), at(-2));
    // Échue seulement après la réservation de A : B la prendra seul.
    const row2 = await pendingRow(uid, await openCycle(), at(1));

    let aSending: () => void = () => undefined;
    const aEntered = new Promise<void>((resolve) => {
      aSending = resolve;
    });
    let openA: () => void = () => undefined;
    const aGate = new Promise<void>((resolve) => {
      openA = resolve;
    });
    const pushA = {
      ...push,
      sendWithStatus: async (
        userId: string,
        title: string,
        body: string,
        data: Record<string, string>,
        options: { collapseKey?: string; idempotencyKey?: string } = {},
      ): Promise<PushDeliveryOutcome> => {
        if (userId === uid) {
          aSending();
          await aGate;
        }
        return push.sendWithStatus(userId, title, body, data, options);
      },
    } as unknown as PushSenderService;
    const a = new PushOutboxWorkerService(prismaService, pushA, fanout);

    let bAtGuard: () => void = () => undefined;
    const bReachedGuard = new Promise<void>((resolve) => {
      bAtGuard = resolve;
    });
    let openB: () => void = () => undefined;
    const bGate = new Promise<void>((resolve) => {
      openB = resolve;
    });
    const b = new PushOutboxWorkerService(guardGatedPrisma(bGate, bAtGuard), push, fanout);

    // A réserve la ligne 1, ne voit personne, et part chez le fournisseur.
    const aRun = a.runOnce(anchor);
    await aEntered;
    // B réserve la ligne 2 (la 1 est sous le bail de A) et lit tout sauf sa garde.
    const bRun = b.runOnce(at(2));
    await bReachedGuard;
    // A est accepté et finalise : bail levé, `pushedAt` posé.
    openA();
    await aRun;
    expect((await rowState(row1)).pushStatus).toBe('accepted');
    // B lit sa garde maintenant.
    openB();
    await bRun;

    expect(sent.filter((p) => p.userId === uid)).toHaveLength(1);
    const deferred = await rowState(row2);
    expect(deferred).toMatchObject({
      pushStatus: 'pending',
      pushLastError: 'deferred_pacing',
      pushLockedBy: null,
      pushAttempts: 0,
    });
    const first = await rowState(row1);
    expect(deferred.pushNotBefore?.getTime()).toBeGreaterThanOrEqual(
      (first.pushedAt?.getTime() ?? 0) + 30 * MIN,
    );
    // La ligne reportée ne doit pas partir dans les cas suivants.
    await prisma.userNotification.delete({ where: { id: row2 } });
  });

  it('même élève, deux workers en parallèle (×12) : au plus un push par élève et par passage', async () => {
    const students: string[] = [];
    for (let i = 0; i < 12; i += 1) {
      const uid = await student();
      students.push(uid);
      await pendingRow(uid, await openCycle(), at(-2));
      await pendingRow(uid, await openCycle(), at(-1));
    }
    await Promise.all([worker().runOnce(anchor), worker().runOnce(anchor)]);
    for (const uid of students) {
      expect(sent.filter((p) => p.userId === uid).length).toBeLessThanOrEqual(1);
    }
    // Ce qui n'est pas parti est reporté, jamais perdu.
    const rows = await prisma.userNotification.findMany({
      where: { userId: { in: students } },
      select: { pushStatus: true, pushLastError: true, pushLockedBy: true },
    });
    for (const row of rows) {
      expect(row.pushLockedBy).toBeNull();
      if (row.pushStatus === 'pending') {
        expect(['deferred_busy', 'deferred_pacing']).toContain(row.pushLastError);
      } else {
        expect(row.pushStatus).toBe('accepted');
      }
    }
    // Les lignes reportées ne doivent pas partir dans les cas suivants.
    await prisma.userNotification.deleteMany({
      where: { userId: { in: students }, pushStatus: 'pending' },
    });
  });

  // ── 8. Crash après réservation ────────────────────────────────────────────

  it('crash : un autre worker reprend après le bail, la finalisation tardive ne touche rien', async () => {
    const cycle = await openCycle();
    const rows: { id: string; key: string }[] = [];
    for (let i = 0; i < 3; i += 1) {
      const uid = await student();
      rows.push({
        id: await pendingRow(uid, cycle),
        key: `scholarship-opened:${cycle.cid}:${uid}`,
      });
    }
    const a = worker();
    const claimed = await a.claim(anchor);
    expect(claimed.map((row) => row.id).sort()).toEqual(rows.map((row) => row.id).sort());

    // Avant l'expiration du bail (5 min), personne d'autre n'y touche.
    await worker().runOnce(at(4));
    expect(sent).toHaveLength(0);

    await worker().runOnce(at(6));
    expect(coveredKeys().sort()).toEqual(rows.map((row) => row.key).sort());

    const late = await a.finalize(
      sendOf(rows[0].id, rows[0].key),
      { status: 'accepted', via: 'fcm', reason: null },
      at(7),
      { maxAttempts: 5 },
    );
    expect(late).toBe(0);
    for (const row of rows) {
      expect(await rowState(row.id)).toMatchObject({ pushStatus: 'accepted', pushAttempts: 1 });
    }
  });

  // ── 9. Arrêter les envois restants ────────────────────────────────────────

  it('arrêt : en attente → stopped_by_staff, une ligne en vol qui revient en nouvelle tentative est sautée', async () => {
    const cycle = await openCycle();
    const ids: string[] = [];
    for (let i = 0; i < 3; i += 1) {
      ids.push(await pendingRow(await student(), cycle, at(-3 + i)));
    }
    const a = worker();
    const [inFlight] = await a.claim(anchor, 1);
    expect(inFlight.id).toBe(ids[0]);

    const stop = await admin.stop(cycle.sid, cycle.cid, actor, `stop-${run}`);
    expect(stop).toEqual({ cycleId: cycle.cid, stopped: 2, inFlight: 1 });
    for (const rowId of ids.slice(1)) {
      expect(await rowState(rowId)).toMatchObject({
        pushStatus: 'skipped',
        pushLastError: 'stopped_by_staff',
      });
    }
    // Les entrées d'inbox restent.
    expect(await prisma.userNotification.count({ where: { cycleId: cycle.cid } })).toBe(3);

    // L'envoi en vol échoue passagèrement : il reste en attente…
    await a.finalize(
      sendOf(inFlight.id, inFlight.dedupeKey),
      { status: 'transient_error', via: 'fcm', reason: 'fcm_failed' },
      anchor,
      { maxAttempts: 5 },
    );
    expect(await rowState(inFlight.id)).toMatchObject({
      pushStatus: 'pending',
      pushLastError: 'retry_provider',
    });
    // … et n'est jamais renvoyé.
    await worker().runOnce(at(2));
    expect(sent).toHaveLength(0);
    expect(await rowState(inFlight.id)).toMatchObject({
      pushStatus: 'skipped',
      pushLastError: 'stopped_by_staff',
    });
    const report = await admin.report(cycle.sid, cycle.cid, at(3));
    expect(report.push.skipped).toMatchObject({ total: 3, stoppedByStaff: 3 });
    expect(report.fanout.stoppedAt).not.toBeNull();
  });

  // ── 9b. Plafond du dispatcher après un groupé ─────────────────────────────

  it('un groupé de 3 lignes ne consomme qu’une place du plafond du dispatcher', async () => {
    const uid = await student();
    for (let i = 0; i < 3; i += 1) await pendingRow(uid, await openCycle(), at(-3 + i));
    await worker().runOnce(anchor);
    expect(sent).toHaveLength(1);
    expect(sent[0].data).toMatchObject({
      route: '/deadlines',
      kind: 'scholarship_opened_bundle',
      count: '3',
    });
    expect(sent[0].data).not.toHaveProperty('scholarshipId');

    expect(
      await prisma.userNotification.count({
        where: { userId: uid, pushedAt: { gte: new Date(anchor.getTime() - DAY) } },
      }),
    ).toBe(1);
    const accepted = await prisma.userNotification.findMany({
      where: { userId: uid },
      select: { pushStatus: true, pushBatchId: true },
    });
    expect(new Set(accepted.map((row) => row.pushStatus))).toEqual(new Set(['accepted']));
    expect(new Set(accepted.map((row) => row.pushBatchId)).size).toBe(1);

    const dispatch = new NotificationDispatchService(prismaService, push);
    await expect(
      dispatch.dispatch({
        userId: uid,
        kind: 'deadline_reminder',
        dedupeKey: `deadline:test:${uid}`,
        title: { fr: 't', en: 't' },
        body: { fr: 'b', en: 'b' },
        route: '/deadlines',
        countryOfResidence: 'Sénégal',
        now: at(1),
      }),
    ).resolves.toBe('pushed');
  });

  it('un « Dates confirmées » groupé avec une ouverture : titre neutre, jamais « ouvertes »', async () => {
    const uid = await student();
    await pendingRow(uid, await openCycle(), at(-3), 'dates_confirmed');
    await pendingRow(uid, await openCycle(), at(-2));
    await worker().runOnce(anchor);
    expect(sent).toHaveLength(1);
    expect(sent[0].data).toMatchObject({ kind: 'scholarship_opened_bundle', count: '2' });
    expect(sent[0].title).toBe('2 bourses que tu suis ont du nouveau');

    const other = await student();
    await pendingRow(other, await openCycle(), at(-3));
    await pendingRow(other, await openCycle(), at(-2));
    await worker().runOnce(anchor);
    expect(sent[1].title).toBe('2 bourses que tu suis sont ouvertes');
  });

  // ── 10. Heures calmes et rythme sur de vraies lignes ──────────────────────

  it('Douala à 22 h 30 locales → 8 h locales + décalage stable', async () => {
    const uid = await student('Cameroun');
    const night = at(9 * 60 + 30); // 21 h 30 UTC = 22 h 30 à Douala
    const rowId = await pendingRow(uid, await openCycle(), new Date(night.getTime() - MIN));
    const tally = await worker().runOnce(night);
    expect(tally.deferredQuiet).toBe(1);
    expect(sent).toHaveLength(0);
    const state = await rowState(rowId);
    const eightLocal = new Date(night);
    eightLocal.setUTCDate(eightLocal.getUTCDate() + 1);
    eightLocal.setUTCHours(7, 0, 0, 0);
    expect(state.pushLastError).toBe('deferred_quiet_hours');
    expect(state.pushNotBefore?.getTime()).toBeGreaterThanOrEqual(eightLocal.getTime());
    expect(state.pushNotBefore?.getTime()).toBeLessThan(eightLocal.getTime() + 20 * MIN);
    expect(state.pushAttempts).toBe(0);
  });

  it('une 2e annonce 10 min après la 1re attend +30 min, puis part groupée avec une 3e', async () => {
    const uid = await student();
    const row1 = await pendingRow(uid, await openCycle(), at(-1));
    const row2 = await pendingRow(uid, await openCycle(), at(10));
    const row3 = await pendingRow(uid, await openCycle(), at(20));

    await worker().runOnce(anchor);
    expect(sent).toHaveLength(1);
    await worker().runOnce(at(10));
    await worker().runOnce(at(20));
    expect(sent).toHaveLength(1);
    expect((await rowState(row2)).pushLastError).toBe('deferred_pacing');
    expect((await rowState(row3)).pushLastError).toBe('deferred_pacing');

    await worker().runOnce(at(31));
    expect(sent).toHaveLength(2);
    expect(sent[1].data).toMatchObject({ kind: 'scholarship_opened_bundle', count: '2' });
    const [s2, s3] = [await rowState(row2), await rowState(row3)];
    expect(s2.pushBatchId).toBe(s3.pushBatchId);
    expect([s2.pushedAt, s3.pushedAt].filter(Boolean)).toHaveLength(1);
    expect((await rowState(row1)).pushStatus).toBe('accepted');
  });

  // ── 11. Échelle : 5 000 abonnés ───────────────────────────────────────────

  it('5 000 abonnés : activate, envoi et vidage dans les bornes', async () => {
    process.env.KPB_SCHOLARSHIP_OPENING_MODE = 'outbox_followers';
    const { sid } = await openCycle();
    const userPrefix = `${prefix}-bulk-`;
    await prisma.$executeRaw`
      INSERT INTO "UserProfile" (
        "id", "accountType", "preferredLanguage", "fullName", "email", "phone",
        "countryOfResidence", "updatedAt"
      )
      SELECT ${userPrefix} || g, 'student', 'fr', 'Élève ' || g,
             ${userPrefix} || g || '@example.test', '', 'Sénégal', now()
      FROM generate_series(1, 5000) AS g
    `;
    await prisma.$executeRaw`
      INSERT INTO "SavedItem" ("id", "userId", "itemType", "itemId")
      SELECT gen_random_uuid()::text, ${userPrefix} || g, 'scholarship', ${sid}
      FROM generate_series(1, 5000) AS g
    `;
    // Pas d'ANALYZE : la requête « qui suit » ne dépend pas des statistiques
    // (aucune jointure entre ensembles dérivés). Ces 5 000 favoris tout neufs
    // sont donc lus comme en production juste après une vague d'abonnements
    // (voir aussi `scholarship-follow.query.scale.postgres.spec.ts`).
    let started = Date.now();
    const result = await lifecycle.activate(
      sid,
      {
        academicYear: '2027-2028',
        opensAt: longAgo.toISOString(),
        closesAt: new Date(anchor.getTime() + 60 * DAY).toISOString(),
        sourceUrl: 'https://example.org/official',
        expectedRecipients: 5000,
      },
      actor,
      'scale',
      anchor,
    );
    const activateMs = Date.now() - started;
    expect(result.notification).toMatchObject({ state: 'scheduled', toNotify: 5000 });
    // Programmé sur la même horloge que l'envoi.
    expect(result.notification.fanoutAt).toBe(
      new Date(anchor.getTime() + readOpeningTunables().holdSeconds * 1000).toISOString(),
    );

    await prisma.scholarshipCycle.update({
      where: { id: result.cycleId },
      data: { openingFanoutDueAt: at(-1) },
    });
    started = Date.now();
    const fanned = await fanout.runDue(anchor);
    const fanoutMs = Date.now() - started;
    expect(fanned.inserted).toBe(5000);

    latency = () => 0;
    const outbox = worker();
    let passes = 0;
    started = Date.now();
    while (passes < 3) {
      passes += 1;
      await outbox.runOnce(anchor);
      const pending = await prisma.userNotification.count({
        where: { cycleId: result.cycleId, pushStatus: 'pending' },
      });
      if (pending === 0) break;
    }
    const drainMs = Date.now() - started;
    console.log(
      `Échelle 5 000 : activate ${activateMs} ms, envoi ${fanoutMs} ms, vidage ${drainMs} ms en ${passes} passage(s).`,
    );
    expect(activateMs).toBeLessThan(2_000);
    expect(fanoutMs).toBeLessThan(5_000);
    expect(
      await prisma.userNotification.count({
        where: { cycleId: result.cycleId, pushStatus: 'accepted' },
      }),
    ).toBe(5000);
    expect(sent).toHaveLength(5000);
  });
});
