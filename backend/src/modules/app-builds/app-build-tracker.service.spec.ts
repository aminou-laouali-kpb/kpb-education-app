import { Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import {
  AppBuildTrackerService,
  buildSeenUpdate,
} from './app-build-tracker.service';

const T0 = new Date(Date.UTC(2026, 9, 13, 12, 0, 0));
const HOUR = 60 * 60 * 1000;
const at = (ms: number) => new Date(T0.getTime() + ms);

const flush = () => new Promise((resolve) => setImmediate(resolve));

function makeTracker(options: {
  enabled?: boolean;
  executeRaw?: jest.Mock;
  execute?: jest.Mock;
} = {}) {
  const executeRaw = options.executeRaw ?? jest.fn().mockResolvedValue(1);
  const client = { $executeRaw: executeRaw };
  const execute =
    options.execute ??
    jest.fn((operation: (c: typeof client) => Promise<unknown>) =>
      operation(client),
    );
  const prisma = {
    isEnabled: options.enabled ?? true,
    execute,
  } as unknown as PrismaService;
  return { tracker: new AppBuildTrackerService(prisma), execute, executeRaw };
}

describe('AppBuildTrackerService', () => {
  let debug: jest.SpyInstance;
  let error: jest.SpyInstance;

  beforeEach(() => {
    debug = jest.spyOn(Logger.prototype, 'debug').mockImplementation(() => {});
    error = jest.spyOn(Logger.prototype, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    debug.mockRestore();
    error.mockRestore();
  });

  it('ne fait rien sans base (Prisma désactivé)', () => {
    const { tracker, execute } = makeTracker({ enabled: false });
    expect(tracker.record('p1', { version: '2.3.0', build: 54 }, T0)).toBe(
      false,
    );
    expect(execute).not.toHaveBeenCalled();
  });

  it('écrit la première requête, puis au plus une fois par 6 h', async () => {
    const { tracker, executeRaw } = makeTracker();
    const reading = { version: '2.3.0', build: 54 };

    expect(tracker.record('p1', reading, T0)).toBe(true);
    expect(tracker.record('p1', reading, at(1000))).toBe(false);
    expect(tracker.record('p1', reading, at(5 * HOUR))).toBe(false);
    expect(tracker.record('p1', reading, at(6 * HOUR))).toBe(true);
    await flush();

    expect(executeRaw).toHaveBeenCalledTimes(2);
    const [first] = executeRaw.mock.calls[0] as [Prisma.Sql];
    expect(first.values).toEqual(['2.3.0', 54, T0, 'p1']);
  });

  it('écrit la mise à jour d’un compte sans attendre la fin des 6 h', async () => {
    const { tracker, executeRaw } = makeTracker();
    tracker.record('p1', { version: '2.3.0', build: 54 }, T0);
    expect(
      tracker.record('p1', { version: '2.4.0', build: 56 }, at(HOUR)),
    ).toBe(true);
    await flush();

    const [second] = executeRaw.mock.calls[1] as [Prisma.Sql];
    expect(second.values).toEqual(['2.4.0', 56, at(HOUR), 'p1']);
  });

  it('note le passage d’une build sans en-tête, sans effacer une valeur connue', async () => {
    const { tracker, executeRaw } = makeTracker();
    expect(tracker.record('p53', { version: null, build: null }, T0)).toBe(
      true,
    );
    await flush();

    const [sql] = executeRaw.mock.calls[0] as [Prisma.Sql];
    expect(sql.values).toEqual([null, null, T0, 'p53']);
    // NULL ne remplace pas : `COALESCE(NULL, colonne)` garde la colonne.
    expect(sql.sql).toMatch(
      /"lastAppVersion" = COALESCE\(\?::text, "lastAppVersion"\)/,
    );
    expect(sql.sql).toMatch(
      /"lastAppBuild" = COALESCE\(\?::integer, "lastAppBuild"\)/,
    );
  });

  it('ne fait jamais attendre la requête sur l’écriture', () => {
    // Une base qui ne répond pas : `record` rend la main quand même.
    const never = jest.fn(() => new Promise<never>(() => {}));
    const { tracker } = makeTracker({ execute: never });
    expect(tracker.record('p1', { version: '2.3.0', build: 54 }, T0)).toBe(
      true,
    );
    expect(never).toHaveBeenCalledTimes(1);
  });

  it('avale un échec d’écriture : journal debug, code borné, pas de message', async () => {
    const failure = Object.assign(
      new Error('column "lastAppBuild" ... jean.dupont@example.com'),
      { code: 'P2010' },
    );
    const { tracker } = makeTracker({
      executeRaw: jest.fn().mockRejectedValue(failure),
    });
    const unhandled = jest.fn();
    process.on('unhandledRejection', unhandled);
    try {
      expect(tracker.record('p1', { version: '2.3.0', build: 54 }, T0)).toBe(
        true,
      );
      await flush();
      await flush();
    } finally {
      process.off('unhandledRejection', unhandled);
    }

    expect(unhandled).not.toHaveBeenCalled();
    expect(debug).toHaveBeenCalledTimes(1);
    const [message] = debug.mock.calls[0] as [string];
    expect(message).toContain('P2010');
    expect(message).not.toContain('example.com');
  });

  it('un échec ne relance pas une écriture à chaque requête', async () => {
    const executeRaw = jest.fn().mockRejectedValue(new Error('down'));
    const { tracker } = makeTracker({ executeRaw });
    tracker.record('p1', { version: '2.3.0', build: 54 }, T0);
    await flush();
    expect(tracker.record('p1', { version: '2.3.0', build: 54 }, at(1000))).toBe(
      false,
    );
    expect(executeRaw).toHaveBeenCalledTimes(1);
  });

  it.each([
    ['rejette', (failure: Error) => jest.fn().mockRejectedValue(failure)],
    [
      'jette de façon synchrone',
      (failure: Error) =>
        jest.fn(() => {
          throw failure;
        }),
    ],
  ])(
    'un échec d’écriture qui %s ne passe jamais par le journal d’erreurs de PrismaService',
    async (_label, makeExecuteRaw) => {
      // Le vrai `execute` journalise en erreur tout ce que l'opération lui
      // laisse remonter : l'échec doit être avalé avant, sinon une simple
      // mesure perdue ressemblerait à une panne du chemin de données.
      const previousDatabaseUrl = process.env.DATABASE_URL;
      delete process.env.DATABASE_URL;
      const prismaService = new PrismaService();
      if (previousDatabaseUrl !== undefined) {
        process.env.DATABASE_URL = previousDatabaseUrl;
      }
      const executeRaw = makeExecuteRaw(
        Object.assign(new Error('relation ... jean.dupont@example.com'), {
          code: 'P2010',
        }),
      );
      Object.defineProperty(prismaService, 'client', {
        value: { $executeRaw: executeRaw },
      });
      const unhandled = jest.fn();
      process.on('unhandledRejection', unhandled);
      try {
        const tracker = new AppBuildTrackerService(prismaService);
        expect(tracker.record('p1', { version: '2.3.0', build: 54 }, T0)).toBe(
          true,
        );
        await flush();
        await flush();
      } finally {
        process.off('unhandledRejection', unhandled);
      }

      expect(executeRaw).toHaveBeenCalledTimes(1);
      expect(error).not.toHaveBeenCalled();
      expect(unhandled).not.toHaveBeenCalled();
      expect(debug).toHaveBeenCalledTimes(1);
      expect(debug).toHaveBeenCalledWith(expect.stringContaining('P2010'));
    },
  );

  it('garde un filet si `execute` rejette lui-même', async () => {
    const { tracker } = makeTracker({
      execute: jest.fn().mockRejectedValue(new TypeError('boom')),
    });
    const unhandled = jest.fn();
    process.on('unhandledRejection', unhandled);
    try {
      expect(tracker.record('p1', { version: '2.3.0', build: 54 }, T0)).toBe(
        true,
      );
      await flush();
      await flush();
    } finally {
      process.off('unhandledRejection', unhandled);
    }

    expect(unhandled).not.toHaveBeenCalled();
    expect(debug).toHaveBeenCalledWith(expect.stringContaining('TypeError'));
  });

  it('ne jette pas même si l’accès à la base jette de façon synchrone', () => {
    const { tracker } = makeTracker({
      execute: jest.fn(() => {
        throw new TypeError('boom');
      }),
    });
    expect(() =>
      tracker.record('p1', { version: '2.3.0', build: 54 }, T0),
    ).not.toThrow();
    expect(debug).toHaveBeenCalledWith(expect.stringContaining('TypeError'));
  });
});

describe('buildSeenUpdate', () => {
  const sql = buildSeenUpdate('p1', { version: '2.3.0', build: 54 }, T0);

  it('cible une seule ligne, par identifiant, en paramètres liés', () => {
    expect(sql.sql).toMatch(/UPDATE "UserProfile"/);
    expect(sql.sql).toMatch(/WHERE "id" = \?\s*$/);
    expect(sql.values).toEqual(['2.3.0', 54, T0, 'p1']);
  });

  it('ne touche pas à `updatedAt` : voir passer une requête n’est pas modifier le profil', () => {
    expect(sql.sql).not.toContain('updatedAt');
    expect(sql.sql).toMatch(
      /"lastAppSeenAt" = \(\?::timestamptz AT TIME ZONE 'UTC'\)/,
    );
  });
});
