import { Logger } from '@nestjs/common';

import type { PrismaService } from '../prisma/prisma.service';
import type { ScholarshipOpeningFanoutService } from '../scholarships-index/opening/scholarship-opening-fanout.service';
import type { OutboxSend } from './push-outbox-plan';
import {
  emptyPushOutboxTally,
  PushOutboxWorkerService,
  runPool,
  type ClaimedOutboxRow,
} from './push-outbox-worker.service';
import type {
  PushDeliveryOutcome,
  PushSenderService,
} from './push-sender.service';

type UpdateCall = {
  where: { id: { in: string[] }; pushLockedBy: string; pushStatus: string };
  data: Record<string, unknown>;
};

const NOON = new Date('2026-10-15T12:00:00.000Z');

function claimed(id: string, userId = 'u1', over: Partial<ClaimedOutboxRow> = {}): ClaimedOutboxRow {
  return {
    id,
    userId,
    scholarshipId: `s-${id}`,
    cycleId: `c-${id}`,
    kind: 'scholarship_opened',
    dedupeKey: `scholarship-opened:c-${id}:${userId}`,
    titleFr: "C'est ouvert",
    titleEn: 'Applications are open',
    bodyFr: 'corps',
    bodyEn: 'body',
    route: `/scholarships/s-${id}`,
    pushAttempts: 0,
    createdAt: new Date('2026-10-15T11:00:00.000Z'),
    variant: 'favorite',
    ...over,
  };
}

function detail(id: string, country = 'Sénégal') {
  return {
    id,
    preferredLanguage: 'fr',
    countryOfResidence: country,
    optedOut: false,
    favorite: true,
    muted: false,
    alertActive: false,
    pushEnabled: true,
    scholarshipPublic: true,
    nameFr: `Bourse ${id}`,
    nameEn: `Scholarship ${id}`,
    cycleExists: true,
    closeAt: new Date('2026-12-01T00:00:00.000Z'),
    stoppedAt: null,
  };
}

function makeWorker(
  opts: {
    claims?: ClaimedOutboxRow[][];
    details?: ReturnType<typeof detail>[];
    outcome?: PushDeliveryOutcome;
    /** Nombre de lignes que chaque `updateMany` touche (bail perdu : 0). */
    updateCount?: (call: UpdateCall) => number;
    onEnrich?: () => void;
  } = {},
) {
  const updates: UpdateCall[] = [];
  const executes: Array<{ text: string; values: unknown[] }> = [];
  const queries: string[] = [];
  const claims = [...(opts.claims ?? [])];
  const client = {
    $queryRaw: async (query: TemplateStringsArray | { strings: readonly string[] }) => {
      const text = (Array.isArray(query) ? query : (query as { strings: readonly string[] }).strings).join('?');
      queries.push(text);
      if (text.includes('FOR UPDATE SKIP LOCKED')) return claims.shift() ?? [];
      if (text.includes('JOIN "UserProfile" pr')) {
        opts.onEnrich?.();
        return opts.details ?? [];
      }
      // La garde (rythme + contention) : personne, aucun push récent.
      if (text.includes('"pushLockedBy" <>')) return [];
      throw new Error(`unexpected query: ${text.slice(0, 80)}`);
    },
    $executeRaw: async (strings: TemplateStringsArray, ...values: unknown[]) => {
      executes.push({ text: strings.join('?'), values });
      return Array.isArray(values[0]) ? values[0].length : 0;
    },
    userNotification: {
      updateMany: async (call: UpdateCall) => {
        updates.push(call);
        return { count: opts.updateCount ? opts.updateCount(call) : call.where.id.in.length };
      },
    },
  };
  const prisma = {
    isEnabled: true,
    execute: async <T>(fn: (db: unknown) => Promise<T>) => fn(client),
  } as unknown as PrismaService;
  const sendWithStatus = jest.fn(
    async (): Promise<PushDeliveryOutcome> =>
      opts.outcome ?? { status: 'accepted', via: 'fcm', reason: null },
  );
  const push = {
    isConfigured: true,
    sendWithStatus,
  } as unknown as PushSenderService;
  const runDue = jest.fn(async () => ({
    cycles: 0,
    inserted: 0,
    pending: 0,
    skipped: 0,
    dropped: 0,
  }));
  const fanout = { runDue } as unknown as ScholarshipOpeningFanoutService;
  const worker = new PushOutboxWorkerService(prisma, push, fanout);
  return { worker, updates, executes, queries, sendWithStatus, runDue };
}

function send(rows: Array<{ id: string; pushAttempts?: number }>): OutboxSend {
  return {
    kind: rows.length > 1 ? 'bundle' : 'single',
    rows: rows.map((row) => ({ id: row.id, pushAttempts: row.pushAttempts ?? 0 })),
    leadRowId: rows[0].id,
    title: 't',
    body: 'b',
    data: {},
    idempotencyKey: 'k',
    collapseKey: 'kpb-k',
  };
}

describe('PushOutboxWorkerService', () => {
  let warns: string[] = [];
  let logs: string[] = [];
  const savedEnv = { ...process.env };

  beforeEach(() => {
    warns = [];
    logs = [];
    jest.spyOn(Logger.prototype, 'warn').mockImplementation((m: unknown) => void warns.push(String(m)));
    jest.spyOn(Logger.prototype, 'log').mockImplementation((m: unknown) => void logs.push(String(m)));
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    for (const key of ['KPB_PUSH_OUTBOX_ENABLED', 'KPB_PUSH_OUTBOX_TICK_BUDGET_MS']) {
      if (savedEnv[key] === undefined) delete process.env[key];
      else process.env[key] = savedEnv[key];
    }
  });

  describe('finalize : issue → mise à jour, toujours sous bail', () => {
    it('accepted : pushedAt sur la seule ligne de tête, même lot pour toutes', async () => {
      const { worker, updates } = makeWorker();
      const tally = emptyPushOutboxTally();
      await worker.finalize(
        send([{ id: 'lead' }, { id: 'r2' }, { id: 'r3' }]),
        { status: 'accepted', via: 'onesignal', reason: null },
        NOON,
        { maxAttempts: 5 },
        tally,
      );
      expect(updates).toHaveLength(2);
      expect(updates[0].where).toEqual({
        id: { in: ['lead'] },
        pushLockedBy: worker.workerId,
        pushStatus: 'pending',
      });
      expect(updates[0].data).toMatchObject({
        pushStatus: 'accepted',
        pushProvider: 'onesignal',
        pushedAt: NOON,
        pushAttempts: { increment: 1 },
        pushLastError: null,
        pushLockedUntil: null,
        pushLockedBy: null,
      });
      expect(updates[1].where.id.in).toEqual(['r2', 'r3']);
      expect(updates[1].data).not.toHaveProperty('pushedAt');
      expect(updates[1].data.pushBatchId).toBe(updates[0].data.pushBatchId);
      expect(tally).toMatchObject({ accepted: 3, acceptedPushes: 1, leaseLost: 0 });
    });

    it('no_device : fournisseur noté, tentative comptée', async () => {
      const { worker, updates } = makeWorker();
      await worker.finalize(
        send([{ id: 'a' }]),
        { status: 'no_device', via: 'onesignal', reason: 'invalid_aliases' },
        NOON,
        { maxAttempts: 5 },
      );
      expect(updates[0].data).toMatchObject({
        pushStatus: 'no_device',
        pushProvider: 'onesignal',
        pushAttempts: { increment: 1 },
      });
      expect(updates[0].data).not.toHaveProperty('pushedAt');
    });

    it.each([
      [0, 60_000],
      [1, 300_000],
      [2, 1_200_000],
      [3, 3_600_000],
    ])('transient_error après %i appel(s) → nouvelle tentative dans %i ms', async (attempts, delay) => {
      const { worker, updates } = makeWorker();
      await worker.finalize(
        send([{ id: 'a', pushAttempts: attempts }]),
        { status: 'transient_error', via: 'fcm', reason: 'fcm_failed' },
        NOON,
        { maxAttempts: 5 },
      );
      expect(updates[0].data).toEqual({
        pushAttempts: { increment: 1 },
        pushNotBefore: new Date(NOON.getTime() + delay),
        pushLastError: 'retry_provider',
        pushLockedUntil: null,
        pushLockedBy: null,
      });
    });

    it('transient_error au 5e appel → failed/max_attempts ; un groupé suit le passé de chaque ligne', async () => {
      const { worker, updates } = makeWorker();
      await worker.finalize(
        send([{ id: 'old', pushAttempts: 4 }, { id: 'new', pushAttempts: 0 }]),
        { status: 'transient_error', via: 'onesignal', reason: 'http_5xx' },
        NOON,
        { maxAttempts: 5 },
      );
      const byId = new Map(updates.map((u) => [u.where.id.in[0], u.data]));
      expect(byId.get('old')).toMatchObject({ pushStatus: 'failed', pushLastError: 'max_attempts' });
      expect(byId.get('new')).toMatchObject({ pushLastError: 'retry_provider' });
      expect(byId.get('new')).not.toHaveProperty('pushStatus');
    });

    it('permanent_error → failed/provider_permanent ; unconfigured → skipped sans tentative', async () => {
      const { worker, updates } = makeWorker();
      await worker.finalize(
        send([{ id: 'a' }]),
        { status: 'permanent_error', via: 'onesignal', reason: 'http_4xx' },
        NOON,
        { maxAttempts: 5 },
      );
      await worker.finalize(
        send([{ id: 'b' }]),
        { status: 'unconfigured', via: null, reason: null },
        NOON,
        { maxAttempts: 5 },
      );
      expect(updates[0].data).toMatchObject({
        pushStatus: 'failed',
        pushLastError: 'provider_permanent',
        pushAttempts: { increment: 1 },
      });
      expect(updates[1].data).toEqual({
        pushStatus: 'skipped',
        pushLastError: 'push_unconfigured',
        pushLockedUntil: null,
        pushLockedBy: null,
      });
    });

    it('bail perdu : 0 ligne mise à jour, journalisé sans identifiant', async () => {
      const { worker } = makeWorker({ updateCount: () => 0 });
      const updated = await worker.finalize(
        send([{ id: 'a' }, { id: 'b' }]),
        { status: 'accepted', via: 'fcm', reason: null },
        NOON,
        { maxAttempts: 5 },
      );
      expect(updated).toBe(0);
      expect(warns).toEqual(['Push outbox: lease lost on 2 row(s) before finalizing.']);
    });
  });

  describe('runOnce', () => {
    it('envoie, finalise, et journalise une ligne de bilan sans identifiant', async () => {
      const rows = [claimed('a', 'u1'), claimed('b', 'u2')];
      const { worker, sendWithStatus, runDue } = makeWorker({
        claims: [rows, []],
        details: rows.map((row) => detail(row.id)),
      });
      const tally = await worker.runOnce(NOON, () => NOON.getTime());
      expect(runDue).toHaveBeenCalled();
      expect(sendWithStatus).toHaveBeenCalledTimes(2);
      expect(sendWithStatus.mock.calls[0]).toEqual([
        'u1',
        "C'est ouvert",
        'corps',
        expect.objectContaining({ notificationKey: 'scholarship-opened:c-a:u1' }),
        { collapseKey: expect.stringMatching(/^kpb-/), idempotencyKey: 'scholarship-opened:c-a:u1' },
      ]);
      expect(tally).toMatchObject({ accepted: 2, acceptedPushes: 2 });
      expect(logs).toHaveLength(1);
      expect(logs[0]).toMatch(/^Push outbox: fanout cycles=0 rows=0 \| accepted=2 pushes=2 /);
      expect(logs[0]).not.toContain('u1');
    });

    it('la variante de chaque ligne (data.variant) décide du titre du groupé', async () => {
      const rows = [
        claimed('a', 'u1', {
          variant: 'dates_confirmed',
          createdAt: new Date('2026-10-15T11:00:00.000Z'),
        }),
        claimed('b', 'u1', {
          variant: 'alert',
          createdAt: new Date('2026-10-15T11:10:00.000Z'),
        }),
      ];
      const { worker, queries, sendWithStatus } = makeWorker({
        claims: [rows, []],
        details: rows.map((row) => detail(row.id)),
      });
      await worker.runOnce(NOON, () => NOON.getTime());
      const claim = queries.find((text) => text.includes('FOR UPDATE SKIP LOCKED'));
      expect(claim).toContain(`n."data"->>'variant' AS "variant"`);
      expect(sendWithStatus).toHaveBeenCalledTimes(1);
      expect(sendWithStatus.mock.calls[0].slice(1, 3)).toEqual([
        '2 bourses que tu suis ont du nouveau',
        'Bourse b et Bourse a. Regarde les dates.',
      ]);
    });

    it('un report (heures calmes) ne compte pas comme tentative', async () => {
      const night = new Date('2026-10-15T22:00:00.000Z');
      const rows = [claimed('a', 'u1')];
      const { worker, executes, sendWithStatus } = makeWorker({
        claims: [rows, []],
        details: [detail('a')],
      });
      const tally = await worker.runOnce(night, () => night.getTime());
      expect(sendWithStatus).not.toHaveBeenCalled();
      expect(tally.deferredQuiet).toBe(1);
      expect(executes).toHaveLength(1);
      expect(executes[0].text).not.toContain('pushAttempts');
      expect(executes[0].text).toContain('"pushLockedBy" =');
      expect(executes[0].values[2]).toEqual(['deferred_quiet_hours']);
    });

    it('budget épuisé : plus aucun envoi, les réservations sont rendues', async () => {
      let t = NOON.getTime();
      const rows = [claimed('a', 'u1'), claimed('b', 'u2')];
      const { worker, sendWithStatus, updates } = makeWorker({
        claims: [rows, []],
        details: rows.map((row) => detail(row.id)),
        // Un enrichissement lent consomme tout le budget.
        onEnrich: () => {
          t += 61_000;
        },
      });
      const tally = await worker.runOnce(NOON, () => t);
      expect(sendWithStatus).not.toHaveBeenCalled();
      const releases = updates.filter(
        (u) => Object.keys(u.data).sort().join() === 'pushLockedBy,pushLockedUntil',
      );
      expect(releases.length).toBeGreaterThanOrEqual(2);
      expect(tally.released).toBeGreaterThanOrEqual(2);
    });

    it('une finalisation qui échoue laisse les lignes sous bail (pas de renvoi immédiat)', async () => {
      const rows = [claimed('a', 'u1')];
      const { worker, updates } = makeWorker({
        claims: [rows, []],
        details: [detail('a')],
        updateCount: (call) => {
          if ('pushStatus' in call.data) throw Object.assign(new Error('db'), { code: 'P1001' });
          return call.where.id.in.length;
        },
      });
      const tally = await worker.runOnce(NOON, () => NOON.getTime());
      expect(tally.released).toBe(0);
      expect(
        updates.filter((u) => Object.keys(u.data).sort().join() === 'pushLockedBy,pushLockedUntil'),
      ).toHaveLength(0);
    });

    it('une voie qui échoue (libération hors budget) ne rend pas les lignes en vol des autres voies', async () => {
      let t = NOON.getTime();
      const rows = [claimed('a', 'u1'), claimed('b', 'u2')];
      let openGate: () => void = () => undefined;
      const gate = new Promise<void>((resolve) => {
        openGate = resolve;
      });
      const isRelease = (call: UpdateCall) =>
        Object.keys(call.data).sort().join() === 'pushLockedBy,pushLockedUntil';
      const { worker, updates, sendWithStatus } = makeWorker({
        claims: [rows, []],
        details: rows.map((row) => detail(row.id)),
        updateCount: (call) => {
          // La base tombe au moment où la voie 2, hors budget, rend la ligne
          // de u2 ; l'envoi de u1 est encore chez le fournisseur.
          if (isRelease(call) && call.where.id.in.includes('b')) {
            setTimeout(openGate, 20);
            throw Object.assign(new Error('db down'), { code: 'P1001' });
          }
          return call.where.id.in.length;
        },
      });
      sendWithStatus.mockImplementation(async (): Promise<PushDeliveryOutcome> => {
        // L'appel au fournisseur de u1 consomme le budget du passage.
        t += 61_000;
        await gate;
        return { status: 'accepted', via: 'fcm', reason: null };
      });

      const result = await worker.runOnce(NOON, () => t).catch((error: unknown) => error);
      // Laisser l'envoi de u1 se terminer s'il tournait encore.
      await gate;
      await new Promise((resolve) => setTimeout(resolve, 20));

      expect(sendWithStatus).toHaveBeenCalledTimes(1);
      // La ligne en vol n'est jamais rendue par ce passage : sa finalisation
      // (fencée par le bail) l'aurait sinon ratée, et elle repartirait.
      const releasedIds = updates.filter(isRelease).flatMap((call) => call.where.id.in);
      expect(releasedIds).not.toContain('a');
      const accepted = updates.find(
        (call) => call.data.pushStatus === 'accepted' && call.where.id.in.includes('a'),
      );
      expect(accepted).toBeDefined();
      // Le passage se termine normalement, sans rejeter.
      expect(result).toMatchObject({ accepted: 1 });
    });

    it('rien à faire : aucune ligne de journal', async () => {
      const { worker } = makeWorker({ claims: [[]] });
      await worker.runOnce(NOON, () => NOON.getTime());
      expect(logs).toEqual([]);
    });
  });

  describe('runPool', () => {
    it('une erreur passe à onError, la voie continue et le pool ne rejette pas', async () => {
      const done: number[] = [];
      const errors: unknown[] = [];
      await expect(
        runPool(
          [1, 2, 3, 4, 5],
          2,
          async (n) => {
            await new Promise((resolve) => setTimeout(resolve, n));
            if (n === 2) throw new Error('boom');
            done.push(n);
          },
          (error) => errors.push(error),
        ),
      ).resolves.toBeUndefined();
      expect(done.sort()).toEqual([1, 3, 4, 5]);
      expect(errors).toHaveLength(1);
    });
  });

  describe('poll', () => {
    it('interrupteur d’urgence : KPB_PUSH_OUTBOX_ENABLED=false arrête les deux phases', async () => {
      process.env.KPB_PUSH_OUTBOX_ENABLED = 'false';
      const { worker, runDue } = makeWorker({ claims: [[]] });
      const runOnce = jest.spyOn(worker, 'runOnce');
      await worker.poll();
      expect(runOnce).not.toHaveBeenCalled();
      expect(runDue).not.toHaveBeenCalled();

      process.env.KPB_PUSH_OUTBOX_ENABLED = 'true';
      await worker.poll();
      expect(runOnce).toHaveBeenCalledTimes(1);
      expect(runDue).toHaveBeenCalled();
    });

    it('un passage à la fois', async () => {
      const { worker } = makeWorker({ claims: [[], []] });
      let release: () => void = () => undefined;
      const gate = new Promise<void>((resolve) => {
        release = resolve;
      });
      const runOnce = jest
        .spyOn(worker, 'runOnce')
        .mockImplementation(async () => {
          await gate;
          return {} as Awaited<ReturnType<PushOutboxWorkerService['runOnce']>>;
        });
      const first = worker.poll();
      await worker.poll();
      release();
      await first;
      expect(runOnce).toHaveBeenCalledTimes(1);
    });
  });
});
