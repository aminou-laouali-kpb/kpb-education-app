import { NotFoundException } from '@nestjs/common';
import { PATH_METADATA, METHOD_METADATA } from '@nestjs/common/constants';
import { RequestMethod } from '@nestjs/common';

import type { PrismaService } from '../prisma/prisma.service';
import { SavedItemsService } from '../saved-items/saved-items.service';
import {
  SCHOLARSHIP_OPENING_MODE_ENV,
  type ScholarshipOpeningMode,
} from './opening/scholarship-opening.contract';
import { ScholarshipAlertsController } from './scholarship-alerts.controller';
import { ScholarshipAlertsService } from './scholarship-alerts.service';

/**
 * « Suivre » = favori + alerte d'ouverture + rappels (chantier C, §1.6).
 *
 * Les deux services qui écrivent un suivi — la cloche (`/me/scholarship-alerts`)
 * et le favori (`/saved-items`) — jouent ici contre UNE base en mémoire, mode
 * par mode : ce qui compte est l'état final des deux tables, pas la forme des
 * requêtes. Les réponses, elles, doivent rester celles d'avant à la clé près :
 * les builds 53/56 ne seront pas mises à jour avant des mois.
 */

type Where = Record<string, unknown>;

interface ScholarshipRow {
  id: string;
  moderationStatus: string;
  isActive: boolean;
}
interface SavedRow {
  id: string;
  userId: string;
  itemType: string;
  itemId: string;
  createdAt: Date;
}
interface AlertRow {
  id: string;
  userId: string;
  scholarshipId: string;
  pushEnabled: boolean;
  inAppEnabled: boolean;
  mutedAt: Date | null;
  impliedFollow: boolean;
  createdAt: Date;
}

/** `{ not: null }` et l'égalité stricte : ce que les services utilisent. */
function matches(row: object, where: Where): boolean {
  const record = row as Record<string, unknown>;
  return Object.entries(where).every(([key, expected]) => {
    if (
      expected !== null &&
      typeof expected === 'object' &&
      !(expected instanceof Date) &&
      'not' in expected
    ) {
      return record[key] !== (expected as { not: unknown }).not;
    }
    if (
      expected !== null &&
      typeof expected === 'object' &&
      !(expected instanceof Date) &&
      'in' in expected
    ) {
      return (expected as { in: unknown[] }).in.includes(record[key]);
    }
    return record[key] === expected;
  });
}

function pick<T extends object>(row: T, select?: Record<string, boolean>): Partial<T> {
  if (!select) return { ...row };
  const out: Partial<T> = {};
  for (const key of Object.keys(select) as (keyof T)[]) out[key] = row[key];
  return out;
}

class FollowStore {
  scholarships: ScholarshipRow[] = [];
  saved: SavedRow[] = [];
  alerts: AlertRow[] = [];
  private seq = 0;
  private clock = Date.parse('2026-10-15T10:00:00.000Z');

  private nextId(prefix: string): string {
    this.seq += 1;
    return `${prefix}-${this.seq}`;
  }
  private tick(): Date {
    this.clock += 1_000;
    return new Date(this.clock);
  }

  addScholarship(id: string, overrides: Partial<ScholarshipRow> = {}): void {
    this.scholarships.push({ id, moderationStatus: 'approved', isActive: true, ...overrides });
  }
  addFavorite(userId: string, itemId: string, itemType = 'scholarship'): SavedRow {
    const row = { id: this.nextId('saved'), userId, itemType, itemId, createdAt: this.tick() };
    this.saved.push(row);
    return row;
  }
  addAlert(userId: string, scholarshipId: string, overrides: Partial<AlertRow> = {}): AlertRow {
    const row: AlertRow = {
      id: this.nextId('alert'),
      userId,
      scholarshipId,
      pushEnabled: true,
      inAppEnabled: true,
      mutedAt: null,
      impliedFollow: false,
      createdAt: this.tick(),
      ...overrides,
    };
    this.alerts.push(row);
    return row;
  }
  favoriteOf(userId: string, scholarshipId: string): SavedRow | undefined {
    return this.saved.find(
      (row) => row.userId === userId && row.itemType === 'scholarship' && row.itemId === scholarshipId,
    );
  }
  alertOf(userId: string, scholarshipId: string): AlertRow | undefined {
    return this.alerts.find((row) => row.userId === userId && row.scholarshipId === scholarshipId);
  }

  readonly client = {
    $transaction: async (arg: unknown): Promise<unknown> =>
      typeof arg === 'function'
        ? (arg as (tx: unknown) => Promise<unknown>)(this.client)
        : Promise.all(arg as Promise<unknown>[]),
    scholarship: {
      findFirst: async (args: { where: Where; select?: Record<string, boolean> }) => {
        const row = this.scholarships.find((s) => matches(s, args.where));
        return row ? pick(row, args.select) : null;
      },
      findUnique: async (args: { where: { id: string }; select?: Record<string, boolean> }) => {
        const row = this.scholarships.find((s) => s.id === args.where.id);
        return row ? pick(row, args.select) : null;
      },
      findMany: async (args: { where: Where; select?: Record<string, boolean> }) =>
        this.scholarships.filter((s) => matches(s, args.where)).map((s) => pick(s, args.select)),
    },
    savedItem: {
      findUnique: async (args: {
        where: { userId_itemType_itemId: { userId: string; itemType: string; itemId: string } };
        select?: Record<string, boolean>;
      }) => {
        const row = this.saved.find((s) => matches(s, args.where.userId_itemType_itemId));
        return row ? pick(row, args.select) : null;
      },
      findFirst: async (args: { where: Where; select?: Record<string, boolean> }) => {
        const row = this.saved.find((s) => matches(s, args.where));
        return row ? pick(row, args.select) : null;
      },
      createMany: async (args: {
        data: { userId: string; itemType: string; itemId: string }[];
        skipDuplicates?: boolean;
      }) => {
        let count = 0;
        for (const data of args.data) {
          if (this.saved.some((s) => matches(s, data))) {
            if (!args.skipDuplicates) throw new Error('P2002');
            continue;
          }
          this.addFavorite(data.userId, data.itemId, data.itemType);
          count += 1;
        }
        return { count };
      },
      upsert: async (args: {
        where: { userId_itemType_itemId: { userId: string; itemType: string; itemId: string } };
        create: { userId: string; itemType: string; itemId: string };
      }) => {
        const existing = this.saved.find((s) => matches(s, args.where.userId_itemType_itemId));
        return existing ?? this.addFavorite(args.create.userId, args.create.itemId, args.create.itemType);
      },
      deleteMany: async (args: { where: Where }) => {
        const before = this.saved.length;
        this.saved = this.saved.filter((s) => !matches(s, args.where));
        return { count: before - this.saved.length };
      },
    },
    scholarshipAlertSubscription: {
      findMany: async (args: { where: Where; select?: Record<string, boolean> }) =>
        this.alerts
          .filter((a) => matches(a, args.where))
          .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
          .map((a) => pick(a, args.select)),
      findUnique: async (args: {
        where: { userId_scholarshipId: { userId: string; scholarshipId: string } };
        select?: Record<string, boolean>;
      }) => {
        const row = this.alerts.find((a) => matches(a, args.where.userId_scholarshipId));
        return row ? pick(row, args.select) : null;
      },
      upsert: async (args: {
        where: { userId_scholarshipId: { userId: string; scholarshipId: string } };
        create: Partial<AlertRow> & { userId: string; scholarshipId: string };
        update: Partial<AlertRow>;
      }) => {
        const existing = this.alerts.find((a) => matches(a, args.where.userId_scholarshipId));
        if (existing) {
          Object.assign(existing, args.update);
          return existing;
        }
        return this.addAlert(args.create.userId, args.create.scholarshipId, args.create);
      },
      createMany: async (args: {
        data: (Partial<AlertRow> & { userId: string; scholarshipId: string })[];
        skipDuplicates?: boolean;
      }) => {
        let count = 0;
        for (const data of args.data) {
          if (!this.scholarships.some((s) => s.id === data.scholarshipId)) {
            throw new Error('P2003 foreign key');
          }
          if (this.alertOf(data.userId, data.scholarshipId)) {
            if (!args.skipDuplicates) throw new Error('P2002');
            continue;
          }
          this.addAlert(data.userId, data.scholarshipId, data);
          count += 1;
        }
        return { count };
      },
      updateMany: async (args: { where: Where; data: Partial<AlertRow> }) => {
        const rows = this.alerts.filter((a) => matches(a, args.where));
        for (const row of rows) Object.assign(row, args.data);
        return { count: rows.length };
      },
      deleteMany: async (args: { where: Where }) => {
        const before = this.alerts.length;
        this.alerts = this.alerts.filter((a) => !matches(a, args.where));
        return { count: before - this.alerts.length };
      },
    },
  };

  readonly prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: unknown) => Promise<T>) => operation(this.client),
  } as unknown as PrismaService;
}

const STUDENT = 'stu-1';
const SID = 'chevening';

function setup() {
  const store = new FollowStore();
  store.addScholarship(SID);
  store.addScholarship('pending-one', { moderationStatus: 'pending' });
  store.addScholarship('inactive-one', { isActive: false });
  return {
    store,
    alerts: new ScholarshipAlertsService(store.prismaService),
    savedItems: new SavedItemsService(store.prismaService),
  };
}

const MODES: ScholarshipOpeningMode[] = ['legacy', 'outbox_alerts', 'outbox_followers'];
const previousMode = process.env[SCHOLARSHIP_OPENING_MODE_ENV];

function useMode(mode: ScholarshipOpeningMode): void {
  beforeEach(() => {
    process.env[SCHOLARSHIP_OPENING_MODE_ENV] = mode;
  });
}

afterAll(() => {
  if (previousMode === undefined) delete process.env[SCHOLARSHIP_OPENING_MODE_ENV];
  else process.env[SCHOLARSHIP_OPENING_MODE_ENV] = previousMode;
});

describe.each(MODES)('Suivre une bourse — mode %s (règles communes)', (mode) => {
  useMode(mode);

  describe('GET /me/scholarship-alerts', () => {
    it('masque les alertes en sourdine, même forme de réponse', async () => {
      const { store, alerts } = setup();
      store.addAlert(STUDENT, SID);
      store.addScholarship('eiffel');
      store.addAlert(STUDENT, 'eiffel', { mutedAt: new Date() });

      const result = await alerts.list(STUDENT);

      expect(result.items.map((item) => item.scholarshipId)).toEqual([SID]);
      expect(Object.keys(result.items[0]).sort()).toEqual([
        'createdAt',
        'id',
        'inAppEnabled',
        'pushEnabled',
        'scholarshipId',
      ]);
      expect(typeof result.items[0].createdAt).toBe('string');
    });
  });

  describe('POST /me/scholarship-alerts/:id (cloche allumée)', () => {
    it('lève la sourdine, réponse inchangée', async () => {
      const { store, alerts } = setup();
      store.addFavorite(STUDENT, SID);
      store.addAlert(STUDENT, SID, { mutedAt: new Date(), pushEnabled: false });

      await expect(alerts.subscribe(STUDENT, SID)).resolves.toEqual({
        scholarshipId: SID,
        subscribed: true,
      });
      expect(store.alertOf(STUDENT, SID)).toMatchObject({
        mutedAt: null,
        pushEnabled: true,
        inAppEnabled: true,
        impliedFollow: false,
      });
    });

    it.each(['pending-one', 'inactive-one', 'missing'])(
      '404 sur une bourse non suivable (%s), rien n’est écrit',
      async (scholarshipId) => {
        const { store, alerts } = setup();
        await expect(alerts.subscribe(STUDENT, scholarshipId)).rejects.toBeInstanceOf(
          NotFoundException,
        );
        expect(store.alerts).toEqual([]);
        expect(store.saved).toEqual([]);
      },
    );
  });

  describe('POST /me/scholarship-alerts (« Suivre les N compatibles »)', () => {
    it('allume la cloche sur les bourses suivables, ignore les autres sans erreur', async () => {
      const { store, alerts } = setup();
      store.addScholarship('eiffel');

      await expect(
        alerts.subscribeMany(STUDENT, [SID, 'pending-one', 'eiffel', 'inactive-one', 'missing']),
      ).resolves.toEqual({
        subscribedIds: [SID, 'eiffel'],
        skippedIds: ['pending-one', 'inactive-one', 'missing'],
      });
      expect(store.alertOf(STUDENT, SID)).toMatchObject({ mutedAt: null });
      expect(store.alertOf(STUDENT, 'eiffel')).toMatchObject({ mutedAt: null });
      expect(store.alertOf(STUDENT, 'pending-one')).toBeUndefined();
      expect(store.alertOf(STUDENT, 'inactive-one')).toBeUndefined();
    });

    it('est idempotent : un favori déjà posé reste, une sourdine est levée, rien n’est doublé', async () => {
      const { store, alerts } = setup();
      store.addFavorite(STUDENT, SID);
      store.addAlert(STUDENT, SID, { mutedAt: new Date() });

      await alerts.subscribeMany(STUDENT, [SID, SID]);
      await alerts.subscribeMany(STUDENT, [SID]);

      expect(store.alerts.filter((row) => row.scholarshipId === SID)).toHaveLength(1);
      expect(store.alertOf(STUDENT, SID)).toMatchObject({ mutedAt: null, impliedFollow: false });
      expect(store.favoriteOf(STUDENT, SID)).toBeDefined();
      expect(store.saved.filter((row) => row.itemId === SID)).toHaveLength(1);
    });

    it('une liste vide ne lit ni n’écrit rien', async () => {
      const { store, alerts } = setup();
      await expect(alerts.subscribeMany(STUDENT, [])).resolves.toEqual({
        subscribedIds: [],
        skippedIds: [],
      });
      expect(store.alerts).toEqual([]);
    });
  });

  describe('DELETE /me/scholarship-alerts/:id (cloche éteinte)', () => {
    it('sur un favori de l’étudiant : sourdine, le favori reste', async () => {
      const { store, alerts } = setup();
      store.addFavorite(STUDENT, SID);
      store.addAlert(STUDENT, SID);

      await expect(alerts.unsubscribe(STUDENT, SID)).resolves.toEqual({
        scholarshipId: SID,
        subscribed: false,
      });
      expect(store.favoriteOf(STUDENT, SID)).toBeDefined();
      expect(store.alertOf(STUDENT, SID)?.mutedAt).toBeInstanceOf(Date);
      expect((await alerts.list(STUDENT)).items).toEqual([]);
    });

    it('sur un favori sans alerte : pose une sourdine', async () => {
      const { store, alerts } = setup();
      store.addFavorite(STUDENT, SID);

      await alerts.unsubscribe(STUDENT, SID);

      expect(store.alertOf(STUDENT, SID)).toMatchObject({ impliedFollow: false });
      expect(store.alertOf(STUDENT, SID)?.mutedAt).toBeInstanceOf(Date);
    });

    it('une sourdine déjà posée garde sa date', async () => {
      const { store, alerts } = setup();
      const mutedAt = new Date('2026-09-01T00:00:00.000Z');
      store.addFavorite(STUDENT, SID);
      store.addAlert(STUDENT, SID, { mutedAt });

      await alerts.unsubscribe(STUDENT, SID);

      expect(store.alertOf(STUDENT, SID)?.mutedAt).toBe(mutedAt);
    });

    it('favori posé par la cloche : alerte et favori retirés', async () => {
      const { store, alerts } = setup();
      store.addFavorite(STUDENT, SID);
      store.addAlert(STUDENT, SID, { impliedFollow: true });

      await alerts.unsubscribe(STUDENT, SID);

      expect(store.alertOf(STUDENT, SID)).toBeUndefined();
      expect(store.favoriteOf(STUDENT, SID)).toBeUndefined();
    });

    it('alerte seule : supprimée, comme avant', async () => {
      const { store, alerts } = setup();
      store.addAlert(STUDENT, SID);

      await alerts.unsubscribe(STUDENT, SID);

      expect(store.alerts).toEqual([]);
      expect(store.saved).toEqual([]);
    });

    it('favori orphelin (bourse supprimée) : rien à couper, pas d’erreur', async () => {
      const { store, alerts } = setup();
      store.addFavorite(STUDENT, 'deleted-scholarship');

      await expect(alerts.unsubscribe(STUDENT, 'deleted-scholarship')).resolves.toEqual({
        scholarshipId: 'deleted-scholarship',
        subscribed: false,
      });
      expect(store.alerts).toEqual([]);
      expect(store.saved).toHaveLength(1);
    });

    it('ne touche pas au suivi d’un autre étudiant', async () => {
      const { store, alerts } = setup();
      store.addFavorite('stu-2', SID);
      store.addAlert('stu-2', SID, { impliedFollow: true });

      await alerts.unsubscribe(STUDENT, SID);

      expect(store.alertOf('stu-2', SID)).toMatchObject({ mutedAt: null });
      expect(store.favoriteOf('stu-2', SID)).toBeDefined();
    });
  });

  describe('PATCH /me/scholarship-alerts/:id', () => {
    it('notifyOpening:false sur un favori : sourdine, toujours suivie', async () => {
      const { store, alerts } = setup();
      store.addFavorite(STUDENT, SID);
      store.addAlert(STUDENT, SID);

      await expect(alerts.updatePreference(STUDENT, SID, false)).resolves.toEqual({
        scholarshipId: SID,
        following: true,
        notifyOpening: false,
      });
      expect(store.favoriteOf(STUDENT, SID)).toBeDefined();
      expect(store.alertOf(STUDENT, SID)?.mutedAt).toBeInstanceOf(Date);
    });

    it('notifyOpening:false sur une bourse non suivie : following relu à false', async () => {
      const { store, alerts } = setup();

      await expect(alerts.updatePreference(STUDENT, SID, false)).resolves.toEqual({
        scholarshipId: SID,
        following: false,
        notifyOpening: false,
      });
      expect(store.alertOf(STUDENT, SID)?.mutedAt).toBeInstanceOf(Date);
    });

    it('notifyOpening:false sur une alerte seule : plus suivie', async () => {
      const { store, alerts } = setup();
      store.addAlert(STUDENT, SID);

      await expect(alerts.updatePreference(STUDENT, SID, false)).resolves.toEqual({
        scholarshipId: SID,
        following: false,
        notifyOpening: false,
      });
    });

    it('notifyOpening:true lève la sourdine', async () => {
      const { store, alerts } = setup();
      store.addFavorite(STUDENT, SID);
      store.addAlert(STUDENT, SID, { mutedAt: new Date() });

      await expect(alerts.updatePreference(STUDENT, SID, true)).resolves.toEqual({
        scholarshipId: SID,
        following: true,
        notifyOpening: true,
      });
      expect(store.alertOf(STUDENT, SID)?.mutedAt).toBeNull();
      expect((await alerts.list(STUDENT)).items).toHaveLength(1);
    });

    it.each([true, false])('404 sur une bourse non approuvée (notifyOpening=%s)', async (notify) => {
      const { store, alerts } = setup();
      await expect(
        alerts.updatePreference(STUDENT, 'pending-one', notify),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(store.alerts).toEqual([]);
    });
  });

  describe('DELETE /saved-items/:id', () => {
    it('emporte l’alerte en sourdine de ce favori, réponse inchangée', async () => {
      const { store, savedItems } = setup();
      const favorite = store.addFavorite(STUDENT, SID);
      store.addAlert(STUDENT, SID, { mutedAt: new Date() });

      await expect(savedItems.remove(favorite.id, STUDENT)).resolves.toEqual({
        id: favorite.id,
      });
      expect(store.saved).toEqual([]);
      expect(store.alerts).toEqual([]);
    });

    it('le favori d’un autre étudiant : 404, rien ne bouge', async () => {
      const { store, savedItems } = setup();
      const favorite = store.addFavorite('stu-2', SID);
      store.addAlert('stu-2', SID, { mutedAt: new Date() });

      await expect(savedItems.remove(favorite.id, STUDENT)).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(store.saved).toHaveLength(1);
      expect(store.alerts).toHaveLength(1);
    });

    it('un favori qui n’est pas une bourse ne touche à aucune alerte', async () => {
      const { store, savedItems } = setup();
      const program = store.addFavorite(STUDENT, SID, 'program');
      store.addAlert(STUDENT, SID, { mutedAt: new Date() });

      await savedItems.remove(program.id, STUDENT);

      expect(store.alerts).toHaveLength(1);
    });
  });

  describe('POST /saved-items', () => {
    it('le favori devient celui de l’étudiant : la cloche éteinte ne le retire plus', async () => {
      const { store, alerts, savedItems } = setup();
      store.addFavorite(STUDENT, SID);
      store.addAlert(STUDENT, SID, { impliedFollow: true });

      const response = await savedItems.create({ type: 'scholarship', itemId: SID }, STUDENT);
      expect(Object.keys(response).sort()).toEqual(['createdAt', 'id', 'itemId', 'type', 'userId']);
      expect(store.alertOf(STUDENT, SID)?.impliedFollow).toBe(false);

      await alerts.unsubscribe(STUDENT, SID);
      expect(store.favoriteOf(STUDENT, SID)).toBeDefined();
      expect(store.alertOf(STUDENT, SID)?.mutedAt).toBeInstanceOf(Date);
    });
  });
});

describe.each(['legacy', 'outbox_alerts'] as const)(
  'Suivre une bourse — mode %s : cloche et favori restent distincts',
  (mode) => {
    useMode(mode);

    it('la cloche ne pose pas de favori', async () => {
      const { store, alerts } = setup();

      await alerts.subscribe(STUDENT, SID);

      expect(store.saved).toEqual([]);
      expect(store.alertOf(STUDENT, SID)).toMatchObject({ mutedAt: null, impliedFollow: false });
    });

    it('PATCH notifyOpening:true ne pose pas de favori', async () => {
      const { store, alerts } = setup();

      await expect(alerts.updatePreference(STUDENT, SID, true)).resolves.toEqual({
        scholarshipId: SID,
        following: true,
        notifyOpening: true,
      });
      expect(store.saved).toEqual([]);
    });

    it('retirer le favori garde une alerte active', async () => {
      const { store, savedItems } = setup();
      const favorite = store.addFavorite(STUDENT, SID);
      store.addAlert(STUDENT, SID);

      await savedItems.remove(favorite.id, STUDENT);

      expect(store.alertOf(STUDENT, SID)).toMatchObject({ mutedAt: null });
    });
  },
);

describe('Suivre une bourse — mode outbox_followers : « Suivre » est un seul geste', () => {
  useMode('outbox_followers');

  it('la cloche pose le favori, marqué « posé par la cloche »', async () => {
    const { store, alerts } = setup();

    await alerts.subscribe(STUDENT, SID);

    expect(store.favoriteOf(STUDENT, SID)).toBeDefined();
    expect(store.alertOf(STUDENT, SID)).toMatchObject({ mutedAt: null, impliedFollow: true });
  });

  it('un favori déjà là reste celui de l’étudiant', async () => {
    const { store, alerts } = setup();
    store.addFavorite(STUDENT, SID);

    await alerts.subscribe(STUDENT, SID);

    expect(store.saved).toHaveLength(1);
    expect(store.alertOf(STUDENT, SID)).toMatchObject({ impliedFollow: false });
  });

  it('une alerte seule d’avant la bascule devient « posée par la cloche » si la cloche crée le favori', async () => {
    const { store, alerts } = setup();
    store.addAlert(STUDENT, SID);

    await alerts.subscribe(STUDENT, SID);

    expect(store.alertOf(STUDENT, SID)).toMatchObject({ impliedFollow: true });
  });

  it('cloche allumée puis éteinte : rien ne reste', async () => {
    const { store, alerts } = setup();

    await alerts.subscribe(STUDENT, SID);
    await alerts.unsubscribe(STUDENT, SID);

    expect(store.saved).toEqual([]);
    expect(store.alerts).toEqual([]);
  });

  it('cloche allumée deux fois : le favori reste marqué « posé par la cloche »', async () => {
    const { store, alerts } = setup();

    await alerts.subscribe(STUDENT, SID);
    await alerts.subscribe(STUDENT, SID);
    await alerts.unsubscribe(STUDENT, SID);

    expect(store.saved).toEqual([]);
    expect(store.alerts).toEqual([]);
  });

  it('PATCH notifyOpening:true pose le favori ; false le garde', async () => {
    const { store, alerts } = setup();

    await alerts.updatePreference(STUDENT, SID, true);
    expect(store.favoriteOf(STUDENT, SID)).toBeDefined();

    await expect(alerts.updatePreference(STUDENT, SID, false)).resolves.toEqual({
      scholarshipId: SID,
      following: true,
      notifyOpening: false,
    });
    expect(store.favoriteOf(STUDENT, SID)).toBeDefined();
  });

  it('retirer le favori retire toute alerte, active comprise', async () => {
    const { store, savedItems } = setup();
    const favorite = store.addFavorite(STUDENT, SID);
    store.addAlert(STUDENT, SID);

    await savedItems.remove(favorite.id, STUDENT);

    expect(store.saved).toEqual([]);
    expect(store.alerts).toEqual([]);
  });

  it('une sourdine posée avant la bascule est encore respectée après', async () => {
    const { store, alerts } = setup();
    store.addFavorite(STUDENT, SID);
    store.addAlert(STUDENT, SID);
    process.env[SCHOLARSHIP_OPENING_MODE_ENV] = 'legacy';
    await alerts.unsubscribe(STUDENT, SID);

    process.env[SCHOLARSHIP_OPENING_MODE_ENV] = 'outbox_followers';

    expect(store.alertOf(STUDENT, SID)?.mutedAt).toBeInstanceOf(Date);
    expect((await alerts.list(STUDENT)).items).toEqual([]);
    await expect(alerts.updatePreference(STUDENT, SID, false)).resolves.toMatchObject({
      following: true,
      notifyOpening: false,
    });
  });
});

describe('ScholarshipAlertsController', () => {
  it('PATCH :scholarshipId passe notifyOpening à l’étudiant connecté', async () => {
    const service = {
      updatePreference: jest.fn(async () => ({
        scholarshipId: SID,
        following: true,
        notifyOpening: false,
      })),
    } as unknown as ScholarshipAlertsService;
    const controller = new ScholarshipAlertsController(service);

    await controller.updatePreference(SID, { notifyOpening: false }, { studentUser: { id: STUDENT } });

    expect(service.updatePreference).toHaveBeenCalledWith(STUDENT, SID, false);
    const handler = Object.getOwnPropertyDescriptor(
      ScholarshipAlertsController.prototype,
      'updatePreference',
    )?.value as object;
    expect(Reflect.getMetadata(PATH_METADATA, handler)).toBe(':scholarshipId');
    expect(Reflect.getMetadata(METHOD_METADATA, handler)).toBe(RequestMethod.PATCH);
  });

  it('POST / (groupé) a sa propre route, sans paramètre : aucun conflit avec POST :scholarshipId', async () => {
    const service = {
      subscribeMany: jest.fn(async () => ({ subscribedIds: [SID], skippedIds: [] })),
    } as unknown as ScholarshipAlertsService;
    const controller = new ScholarshipAlertsController(service);

    await expect(
      controller.subscribeMany({ scholarshipIds: [SID] }, { studentUser: { id: STUDENT } }),
    ).resolves.toEqual({ subscribedIds: [SID], skippedIds: [] });
    expect(service.subscribeMany).toHaveBeenCalledWith(STUDENT, [SID]);

    const route = (name: string) => {
      const handler = Object.getOwnPropertyDescriptor(
        ScholarshipAlertsController.prototype,
        name,
      )?.value as object;
      return [
        Reflect.getMetadata(METHOD_METADATA, handler),
        Reflect.getMetadata(PATH_METADATA, handler),
      ];
    };
    expect(route('subscribeMany')).toEqual([RequestMethod.POST, '/']);
    expect(route('subscribe')).toEqual([RequestMethod.POST, ':scholarshipId']);
  });
});
