import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';

import { SupabaseAuthService } from '../auth/supabase-auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { SalonController } from './salon.controller';
import { SalonService } from './salon.service';

/**
 * Faux client Prisma « en mémoire » qui APPLIQUE les clauses `where` (égalité,
 * `in`, `not`, relation `event`) et reproduit les deux garanties de Postgres
 * dont dépend l'inscription :
 *  - `SELECT … FOR UPDATE` : un verrou par session, tenu jusqu'à la fin de la
 *    transaction (les autres transactions attendent) ;
 *  - `@@unique([sessionId, userId])` : un second `create` lève P2002.
 * Chaque appel cède la main (`setImmediate`) : des requêtes lancées en
 * `Promise.all` s'entrelacent vraiment, comme sur un serveur.
 */
type Reg = {
  id: string;
  sessionId: string;
  userId: string;
  status: string;
  remindedAt: Date | null;
  reminded1hAt: Date | null;
};
type Sess = {
  id: string;
  eventId: string;
  status: string;
  capacity: number | null;
  startAt: Date;
  joinUrl: string | null;
  recordingUrl: string | null;
};
type Ev = { id: string; slug: string; status: string };

const tick = () => new Promise<void>((r) => setImmediate(r));

function matches(row: Record<string, unknown>, where: Record<string, any> = {}, rel: Record<string, (row: any) => Record<string, unknown>> = {}): boolean {
  return Object.entries(where).every(([key, cond]) => {
    if (rel[key]) return matches(rel[key](row), cond);
    const value = row[key];
    if (cond && typeof cond === 'object' && !(cond instanceof Date)) {
      if ('in' in cond) return (cond.in as unknown[]).includes(value);
      if ('not' in cond) return value !== cond.not;
    }
    return value === cond;
  });
}

function makeDb(seed: { events?: Ev[]; sessions?: Sess[]; regs?: Reg[] } = {}) {
  const events: Ev[] = seed.events ?? [{ id: 'e1', slug: 'salon-2027', status: 'scheduled' }];
  const sessions: Sess[] = seed.sessions ?? [];
  const regs: Reg[] = seed.regs ?? [];
  const locks = new Map<string, Promise<void>>();
  let seq = 0;
  let lockingEnabled = true;
  let beforeCreate: (() => void) | null = null;

  const eventOf = (s: Sess) => events.find((e) => e.id === s.eventId)!;
  const sessionRel = { event: (s: Sess) => eventOf(s) };

  const makeClient = (held: Array<() => void>) => ({
    $queryRaw: async (_strings: TemplateStringsArray, ...values: unknown[]) => {
      await tick();
      const id = values[0] as string;
      if (lockingEnabled) {
        const prev = locks.get(id) ?? Promise.resolve();
        let release!: () => void;
        const mine = new Promise<void>((r) => (release = r));
        locks.set(id, prev.then(() => mine));
        held.push(release);
        await prev;
      }
      return sessions.filter((s) => s.id === id).map((s) => ({ id: s.id }));
    },
    salonEvent: {
      findFirst: async ({ where, include }: any) => {
        await tick();
        const event = events.find((e) => matches(e, where));
        if (!event) return null;
        const list = sessions
          .filter((s) => s.eventId === event.id && matches(s, include?.sessions?.where))
          .map((s) => ({ ...s }));
        return { ...event, sessions: list };
      },
    },
    salonSession: {
      findFirst: async ({ where }: any) => {
        await tick();
        const s = sessions.find((x) => matches(x, where, sessionRel));
        return s ? { ...s, event: { ...eventOf(s) } } : null;
      },
      findUnique: async ({ where }: any) => {
        await tick();
        const s = sessions.find((x) => x.id === where.id);
        return s ? { ...s } : null;
      },
      update: async ({ where, data }: any) => {
        await tick();
        const s = sessions.find((x) => x.id === where.id)!;
        for (const [k, v] of Object.entries(data)) if (v !== undefined) (s as any)[k] = v;
        return { ...s };
      },
    },
    salonRegistration: {
      findUnique: async ({ where }: any) => {
        await tick();
        const key = where.sessionId_userId;
        const r = key
          ? regs.find((x) => x.sessionId === key.sessionId && x.userId === key.userId)
          : regs.find((x) => x.id === where.id);
        return r ? { ...r } : null;
      },
      findMany: async ({ where }: any) => {
        await tick();
        return regs.filter((r) => matches(r, where)).map((r) => ({ ...r }));
      },
      count: async ({ where }: any) => {
        await tick();
        return regs.filter((r) => matches(r, where)).length;
      },
      create: async ({ data }: any) => {
        await tick();
        beforeCreate?.();
        if (regs.some((r) => r.sessionId === data.sessionId && r.userId === data.userId)) {
          throw Object.assign(new Error('Unique constraint failed'), { code: 'P2002' });
        }
        const row: Reg = { id: `r${++seq}`, remindedAt: null, reminded1hAt: null, ...data };
        regs.push(row);
        return { ...row };
      },
      update: async ({ where, data }: any) => {
        await tick();
        const r = regs.find((x) => x.id === where.id)!;
        Object.assign(r, data);
        return { ...r };
      },
      updateMany: async ({ where, data }: any) => {
        await tick();
        const hit = regs.filter((r) => matches(r, where));
        hit.forEach((r) => Object.assign(r, data));
        return { count: hit.length };
      },
    },
  });

  const root = {
    ...makeClient([]),
    $transaction: async (fn: (tx: unknown) => Promise<unknown>) => {
      const held: Array<() => void> = [];
      try {
        return await fn(makeClient(held));
      } finally {
        held.forEach((release) => release());
      }
    },
  };
  const prisma = {
    isEnabled: true,
    execute: async (fn: (c: typeof root) => unknown) => fn(root),
  } as unknown as PrismaService;

  return {
    service: new SalonService(prisma),
    regs,
    sessions,
    events,
    disableLocking: () => (lockingEnabled = false),
    onBeforeCreate: (fn: () => void) => (beforeCreate = fn),
  };
}

const START = new Date('2027-03-10T15:00:00Z');
const session = (over: Partial<Sess> = {}): Sess => ({
  id: 's1',
  eventId: 'e1',
  status: 'scheduled',
  capacity: 1,
  startAt: START,
  joinUrl: 'https://meet.example/abc',
  recordingUrl: 'https://rec.example/abc',
  ...over,
});
const reg = (over: Partial<Reg>): Reg => ({
  id: 'r0',
  sessionId: 's1',
  userId: 'u0',
  status: 'registered',
  remindedAt: null,
  reminded1hAt: null,
  ...over,
});

describe('SalonService.register', () => {
  it('reactivates a cancelled registration instead of returning it', async () => {
    const db = makeDb({ sessions: [session()], regs: [reg({ id: 'r1', userId: 'u1', status: 'cancelled' })] });
    const result = await db.service.register('u1', 's1');
    expect(result).toMatchObject({ id: 'r1', status: 'registered' });
    expect(db.regs).toHaveLength(1);
  });

  it('does not count cancelled registrations against capacity', async () => {
    const db = makeDb({ sessions: [session()], regs: [reg({ id: 'r1', userId: 'other', status: 'cancelled' })] });
    await expect(db.service.register('u1', 's1')).resolves.toMatchObject({ status: 'registered' });
  });

  it('still refuses when active registrations fill the session', async () => {
    const db = makeDb({ sessions: [session()], regs: [reg({ id: 'r1', userId: 'other' })] });
    await expect(db.service.register('u1', 's1')).rejects.toBeInstanceOf(ConflictException);
  });

  it('404 for an unknown session, 400 for a closed one', async () => {
    const db = makeDb({ sessions: [session({ status: 'ended' })] });
    await expect(db.service.register('u1', 'nope')).rejects.toBeInstanceOf(NotFoundException);
    await expect(db.service.register('u1', 's1')).rejects.toBeInstanceOf(BadRequestException);
  });

  // ── Audit §29 — capacité et concurrence ───────────────────────────────────
  it('10 inscriptions simultanées pour la dernière place : une seule passe', async () => {
    const full = Array.from({ length: 49 }, (_, i) => reg({ id: `old${i}`, userId: `old${i}` }));
    const db = makeDb({ sessions: [session({ capacity: 50 })], regs: full });

    const results = await Promise.allSettled(
      Array.from({ length: 10 }, (_, i) => db.service.register(`new${i}`, 's1')),
    );

    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    const rejected = results.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
    expect(rejected).toHaveLength(9);
    rejected.forEach((r) => expect(r.reason).toBeInstanceOf(ConflictException));
    expect(db.regs.filter((r) => r.status !== 'cancelled')).toHaveLength(50);
  });

  it('le faux client détecte bien la course : sans verrou, la capacité saute', async () => {
    // Garde-fou du test ci-dessus : si le verrou ne servait à rien, ce test-ci
    // échouerait — la simulation reproduit donc bien la course.
    const full = Array.from({ length: 49 }, (_, i) => reg({ id: `old${i}`, userId: `old${i}` }));
    const db = makeDb({ sessions: [session({ capacity: 50 })], regs: full });
    db.disableLocking();
    await Promise.allSettled(
      Array.from({ length: 10 }, (_, i) => db.service.register(`new${i}`, 's1')),
    );
    expect(db.regs.length).toBeGreaterThan(50);
  });

  it('double clic du même élève : une seule ligne, la même inscription rendue', async () => {
    const db = makeDb({ sessions: [session({ capacity: 5 })] });
    const [a, b] = await Promise.all([db.service.register('u1', 's1'), db.service.register('u1', 's1')]);
    expect(a!.id).toBe(b!.id);
    expect(db.regs).toHaveLength(1);
  });

  it('P2002 (ligne insérée entre-temps) : rend l’inscription existante, pas une 500', async () => {
    const db = makeDb({ sessions: [session({ capacity: 5 })] });
    db.onBeforeCreate(() => {
      if (!db.regs.some((r) => r.userId === 'u1')) {
        db.regs.push(reg({ id: 'concurrent', userId: 'u1' }));
      }
    });
    await expect(db.service.register('u1', 's1')).resolves.toMatchObject({ id: 'concurrent', status: 'registered' });
    expect(db.regs).toHaveLength(1);
  });

  // ── Audit §28 — marqueurs de rappel ───────────────────────────────────────
  it('une réinscription remet les marqueurs de rappel à zéro', async () => {
    const sent = new Date('2027-03-09T15:00:00Z');
    const db = makeDb({
      sessions: [session()],
      regs: [reg({ id: 'r1', userId: 'u1', status: 'cancelled', remindedAt: sent, reminded1hAt: sent })],
    });
    await db.service.register('u1', 's1');
    expect(db.regs[0]).toMatchObject({ status: 'registered', remindedAt: null, reminded1hAt: null });
  });
});

describe('SalonService.updateSession — rappels (audit §28)', () => {
  const sent = new Date('2027-03-09T15:00:00Z');
  const seed = () =>
    makeDb({
      sessions: [session({ capacity: null }), session({ id: 's2', capacity: null })],
      regs: [
        reg({ id: 'r1', userId: 'u1', remindedAt: sent, reminded1hAt: sent }),
        reg({ id: 'r2', userId: 'u2', status: 'cancelled', remindedAt: sent }),
        reg({ id: 'r3', sessionId: 's2', userId: 'u1', remindedAt: sent }),
      ],
    });

  it('déplacer la session remet à zéro les marqueurs de SES inscriptions', async () => {
    const db = seed();
    await db.service.updateSession('s1', { startAt: '2027-03-17T15:00:00Z' });
    expect(db.sessions[0].startAt.toISOString()).toBe('2027-03-17T15:00:00.000Z');
    expect(db.regs.find((r) => r.id === 'r1')).toMatchObject({ remindedAt: null, reminded1hAt: null });
    expect(db.regs.find((r) => r.id === 'r2')!.remindedAt).toBeNull();
    // L'autre session n'est pas touchée.
    expect(db.regs.find((r) => r.id === 'r3')!.remindedAt).toEqual(sent);
  });

  it('renvoyer la même date ne réarme rien (pas de rappel en double)', async () => {
    const db = seed();
    await db.service.updateSession('s1', { startAt: START.toISOString(), titleFr: 'Nouveau titre' });
    expect(db.regs.find((r) => r.id === 'r1')!.remindedAt).toEqual(sent);
  });

  it('un PATCH sans startAt ne réarme rien', async () => {
    const db = seed();
    await db.service.updateSession('s1', { capacity: 30 });
    expect(db.regs.find((r) => r.id === 'r1')!.reminded1hAt).toEqual(sent);
  });
});

describe('Routes publiques du salon (audit §31)', () => {
  const seed = () =>
    makeDb({
      events: [
        { id: 'e1', slug: 'salon-2027', status: 'live' },
        { id: 'e2', slug: 'salon-2028', status: 'draft' },
      ],
      sessions: [
        session({ status: 'live' }),
        session({ id: 's2', joinUrl: 'https://meet.example/s2' }),
        session({ id: 's3', status: 'cancelled' }),
        session({ id: 's4', eventId: 'e2' }),
      ],
      regs: [
        reg({ id: 'r1', userId: 'u1', sessionId: 's1' }),
        reg({ id: 'r2', userId: 'u1', sessionId: 's2', status: 'cancelled' }),
      ],
    });

  it('une édition en brouillon est introuvable par son slug', async () => {
    await expect(seed().service.getEventBySlug('salon-2028')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('anonyme : programme visible, aucun lien de visio ni d’enregistrement', async () => {
    const event = await seed().service.getEventBySlug('salon-2027');
    expect(event.sessions.map((s) => s.id)).toEqual(['s1', 's2']);
    event.sessions.forEach((s) => {
      expect(s.joinUrl).toBeNull();
      expect(s.recordingUrl).toBeNull();
    });
  });

  it('élève inscrit : liens de SES sessions (pas d’une inscription annulée)', async () => {
    const event = await seed().service.getEventBySlug('salon-2027', 'u1');
    const byId = Object.fromEntries(event.sessions.map((s) => [s.id, s]));
    expect(byId.s1.joinUrl).toBe('https://meet.example/abc');
    expect(byId.s1.recordingUrl).toBe('https://rec.example/abc');
    // s2 est `scheduled` et son inscription est annulée : rien.
    expect(byId.s2.joinUrl).toBeNull();
    expect(byId.s2.recordingUrl).toBeNull();
  });

  it('session `live` : joinUrl servi à tout élève authentifié, même non inscrit', async () => {
    // Compromis pour l'app installée, qui ne recharge pas après inscription.
    const event = await seed().service.getEventBySlug('salon-2027', 'u2');
    const byId = Object.fromEntries(event.sessions.map((s) => [s.id, s]));
    expect(byId.s1.joinUrl).toBe('https://meet.example/abc');
    // L'enregistrement reste réservé aux inscrits.
    expect(byId.s1.recordingUrl).toBeNull();
    // Session `scheduled` : toujours réservée aux inscrits.
    expect(byId.s2.joinUrl).toBeNull();
  });

  it('getSession : 404 pour une session annulée ou d’une édition en brouillon', async () => {
    const db = seed();
    await expect(db.service.getSession('s3')).rejects.toBeInstanceOf(NotFoundException);
    await expect(db.service.getSession('s4')).rejects.toBeInstanceOf(NotFoundException);
  });

  it('getSession : anonyme sans lien ; `live` ouvert aux authentifiés ; `scheduled` aux seuls inscrits', async () => {
    const db = seed();
    expect((await db.service.getSession('s1')).joinUrl).toBeNull();
    const live = await db.service.getSession('s1', 'u2');
    expect(live.joinUrl).toBe('https://meet.example/abc');
    expect(live.recordingUrl).toBeNull();
    expect((await db.service.getSession('s1', 'u1')).recordingUrl).toBe('https://rec.example/abc');
    expect((await db.service.getSession('s2', 'u2')).joinUrl).toBeNull();
    expect((await db.service.getSession('s2', 'u1')).joinUrl).toBeNull();
  });

  describe('contrôleur : authentification facultative', () => {
    const make = () => {
      const db = seed();
      const auth = {
        verifyAndResolve: jest.fn(async (token: string) => {
          if (token !== 'good') throw new UnauthorizedException('Invalid or expired access token.');
          return { id: 'u2' };
        }),
      };
      const controller = new SalonController(db.service, auth as unknown as SupabaseAuthService);
      return { controller, auth };
    };
    const req = (authorization?: string) => ({ headers: { authorization } }) as unknown as Request;

    it('sans en-tête : visiteur sans compte, programme servi sans lien, jamais de 401', async () => {
      const { controller, auth } = make();
      const event = await controller.getEvent('salon-2027', req());
      expect(event.sessions.map((s) => s.id)).toEqual(['s1', 's2']);
      event.sessions.forEach((s) => expect(s.joinUrl).toBeNull());
      expect((await controller.getSession('s1', req())).joinUrl).toBeNull();
      expect(auth.verifyAndResolve).not.toHaveBeenCalled();
    });

    it('jeton valide : élève reconnu (lien de la session live)', async () => {
      const { controller } = make();
      expect((await controller.getSession('s1', req('Bearer good'))).joinUrl).toBe('https://meet.example/abc');
      const event = await controller.getEvent('salon-2027', req('Bearer good'));
      expect(event.sessions[0].joinUrl).toBe('https://meet.example/abc');
    });

    it('jeton invalide ou expiré : 401, pour que l’app rafraîchisse son jeton', async () => {
      const { controller } = make();
      await expect(controller.getSession('s1', req('Bearer expired'))).rejects.toBeInstanceOf(UnauthorizedException);
      await expect(controller.getEvent('salon-2027', req('Bearer expired'))).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('en-tête Authorization qui n’est pas un Bearer : 401', async () => {
      const { controller } = make();
      await expect(controller.getSession('s1', req('Basic abc'))).rejects.toBeInstanceOf(UnauthorizedException);
    });
  });
});
