import {
  CampaignCronService,
  ORPHAN_DRAFT_GRACE_MS,
  ORPHAN_DRAFT_MAX_AGE_MS,
  STALE_SENDING_MS,
} from './campaign-cron.service';
import { CampaignExecutorService } from './campaign-executor.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Une campagne programmée ne doit partir qu'UNE fois.
 *
 * Le cron lisait les campagnes `scheduled` puis les passait à `sending` par un
 * `update` inconditionnel : deux ticks qui se chevauchent, ou deux répliques de
 * l'API, lisaient la même ligne et l'envoyaient chacun — chaque élève recevait
 * la notification en double. La prise est désormais conditionnelle
 * (`updateMany` sur `status: scheduled`) et seul le worker qui la gagne exécute.
 */
describe('CampaignCronService', () => {
  type Row = {
    id: string;
    name: string;
    status: string;
    scheduledFor: Date | null;
    createdAt?: Date;
    updatedAt?: Date;
  };
  type Range = { lt?: Date; lte?: Date; gte?: Date };
  type Where = Record<string, unknown>;

  /** Évalue un `where` Prisma simple (égalité, null, lt / lte / gte). */
  function matches(row: Row, where: Where) {
    return Object.entries(where).every(([key, cond]) => {
      const value = row[key as keyof Row];
      if (cond === null) return value === null || value === undefined;
      if (cond && typeof cond === 'object' && !(cond instanceof Date)) {
        const r = cond as Range;
        if (!(value instanceof Date)) return false;
        if (r.lt && !(value < r.lt)) return false;
        if (r.lte && !(value <= r.lte)) return false;
        if (r.gte && !(value >= r.gte)) return false;
        return true;
      }
      return value === cond;
    });
  }

  /** Base partagée entre répliques : c'est elle qui arbitre la prise. */
  function makeDb(initial: Row[]) {
    const rows = [...initial];
    /** Lectures des campagnes PROGRAMMÉES (ids vus), dans l'ordre. */
    const findManyCalls: string[][] = [];
    const failedDeliveriesOf: string[] = [];
    const hooks: { afterRead?: () => void; failRead?: boolean } = {};
    const client = {
      notificationCampaign: {
        // Instantané au moment de la lecture, comme une vraie requête : deux
        // workers qui lisent avant toute prise voient la même campagne.
        findMany: async ({ where }: { where: Where }) => {
          if (hooks.failRead) throw new Error('db down');
          const hit = rows.filter((r) => matches(r, where)).map((r) => ({ ...r }));
          if (where.status === 'scheduled') {
            findManyCalls.push(hit.map((r) => r.id));
            hooks.afterRead?.();
          }
          return hit;
        },
        // Vérification et écriture dans le même pas synchrone : c'est la
        // garantie qu'offre un UPDATE … WHERE status = 'scheduled' en base.
        updateMany: async ({
          where,
          data,
        }: {
          where: Where;
          data: { status: string };
        }) => {
          const hit = rows.filter((r) => matches(r, where));
          hit.forEach((r) => {
            r.status = data.status;
            r.updatedAt = new Date();
          });
          return { count: hit.length };
        },
        update: async ({
          where,
          data,
        }: {
          where: { id: string };
          data: { status: string };
        }) => {
          const row = rows.find((r) => r.id === where.id);
          if (row) row.status = data.status;
          return row;
        },
      },
      notificationDelivery: {
        updateMany: async ({ where }: { where: { campaignId: string } }) => {
          failedDeliveriesOf.push(where.campaignId);
          return { count: 3 };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
      tryExecute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return {
      prisma,
      rows,
      hooks,
      findManyCalls,
      failedDeliveriesOf,
      status: (id: string) => rows.find((r) => r.id === id)?.status,
      /** Ce que ferait un autre worker : prendre la ligne avant nous. */
      claimElsewhere: (id: string) => {
        const row = rows.find((r) => r.id === id);
        if (row) row.status = 'sending';
      },
    };
  }

  /** Exécuteur factice : note chaque envoi, et peut rester « en cours ». */
  function makeExecutor(options: { hold?: Promise<void>; fail?: boolean } = {}) {
    const executed: string[] = [];
    const executor = {
      execute: async (id: string) => {
        executed.push(id);
        if (options.hold) await options.hold;
        if (options.fail) throw new Error('boom');
        return { enqueued: 1 };
      },
    } as unknown as CampaignExecutorService;
    return { executor, executed };
  }

  function due(id: string): Row {
    return {
      id,
      name: `Campagne ${id}`,
      status: 'scheduled',
      scheduledFor: new Date(Date.now() - 60_000),
    };
  }

  /** Laisse les promesses en attente avancer jusqu'à leur prochain blocage. */
  const flush = () => new Promise((resolve) => setImmediate(resolve));

  it('réclame une campagne échue (sending) puis l’exécute', async () => {
    const db = makeDb([due('c1')]);
    const { executor, executed } = makeExecutor();
    await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();
    expect(executed).toEqual(['c1']);
    expect(db.status('c1')).toBe('sending');
  });

  // Le défaut : deux répliques lisent la même campagne avant que l'une ou
  // l'autre ne l'ait prise. L'ancien `update` par id laissait passer les deux.
  it('deux ticks concurrents (deux répliques) n’envoient la campagne qu’une fois', async () => {
    const db = makeDb([due('c1')]);
    const { executor, executed } = makeExecutor();
    const replicaA = new CampaignCronService(db.prisma, executor);
    const replicaB = new CampaignCronService(db.prisma, executor);

    await Promise.all([
      replicaA.handleScheduledCampaigns(),
      replicaB.handleScheduledCampaigns(),
    ]);

    // Les deux ont bien vu la campagne : seule la prise les a départagées.
    expect(db.findManyCalls).toEqual([['c1'], ['c1']]);
    expect(executed).toEqual(['c1']);
  });

  it('saute une campagne déjà réclamée par un autre worker (count 0)', async () => {
    const db = makeDb([due('c1')]);
    const { executor, executed } = makeExecutor();
    // L'autre worker prend la ligne entre notre lecture et notre prise.
    db.hooks.afterRead = () => db.claimElsewhere('c1');

    await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();

    expect(executed).toEqual([]);
    // Et surtout : on ne touche pas au statut d'une campagne qu'on n'a pas
    // prise — pas de `failed` posé par erreur sur l'envoi de l'autre worker.
    expect(db.status('c1')).toBe('sending');
  });

  it('une prise perdue ne bloque pas les autres campagnes du lot', async () => {
    const db = makeDb([due('c1'), due('c2')]);
    const { executor, executed } = makeExecutor();
    db.hooks.afterRead = () => db.claimElsewhere('c1');

    await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();

    expect(executed).toEqual(['c2']);
  });

  // Une grosse campagne envoie un push à la fois et peut dépasser la minute.
  it('un tick ne démarre pas tant que le précédent tourne encore', async () => {
    let release!: () => void;
    const hold = new Promise<void>((resolve) => (release = resolve));
    const db = makeDb([due('c1')]);
    const { executor, executed } = makeExecutor({ hold });
    const service = new CampaignCronService(db.prisma, executor);

    const first = service.handleScheduledCampaigns();
    await flush();
    expect(executed).toEqual(['c1']);

    // Une autre campagne arrive à échéance pendant que c1 est en cours : le
    // tick suivant ne la lit même pas, il cède la place.
    db.rows.push(due('c2'));
    await service.handleScheduledCampaigns();
    expect(db.findManyCalls).toHaveLength(1);
    expect(executed).toEqual(['c1']);

    release();
    await first;

    // Le verrou est relâché : rien n'est perdu, c2 part au tick d'après.
    await service.handleScheduledCampaigns();
    expect(executed).toEqual(['c1', 'c2']);
  });

  it('relâche le verrou même quand le tick échoue', async () => {
    const db = makeDb([due('c1')]);
    const { executor, executed } = makeExecutor();
    const service = new CampaignCronService(db.prisma, executor);

    db.hooks.failRead = true;
    await service.handleScheduledCampaigns();
    expect(executed).toEqual([]);

    db.hooks.failRead = false;
    await service.handleScheduledCampaigns();
    expect(executed).toEqual(['c1']);
  });

  it('filet de sécurité : marque « failed » quand l’exécuteur lève', async () => {
    const db = makeDb([due('c1')]);
    const { executor } = makeExecutor({ fail: true });
    await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();
    expect(db.status('c1')).toBe('failed');
  });

  it('ne fait rien sans base configurée', async () => {
    const db = makeDb([due('c1')]);
    (db.prisma as unknown as { isEnabled: boolean }).isEnabled = false;
    const { executor, executed } = makeExecutor();
    await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();
    expect(executed).toEqual([]);
    expect(db.findManyCalls).toEqual([]);
  });

  /**
   * Reprise des campagnes orphelines : processus mort entre la création et la
   * réservation (reste `draft`), ou en plein envoi (reste `sending`).
   */
  describe('reprise des campagnes orphelines', () => {
    const MIN = 60 * 1000;
    const ago = (ms: number) => new Date(Date.now() - ms);

    function draft(id: string, createdMsAgo: number): Row {
      return {
        id,
        name: `Immédiate ${id}`,
        status: 'draft',
        scheduledFor: null,
        createdAt: ago(createdMsAgo),
        updatedAt: ago(createdMsAgo),
      };
    }
    function sending(id: string, heartbeatMsAgo: number): Row {
      return {
        id,
        name: `En cours ${id}`,
        status: 'sending',
        scheduledFor: null,
        createdAt: ago(heartbeatMsAgo + MIN),
        updatedAt: ago(heartbeatMsAgo),
      };
    }

    it('reprend un draft immédiat orphelin (> 5 min) via la réservation', async () => {
      const db = makeDb([draft('d1', ORPHAN_DRAFT_GRACE_MS + MIN)]);
      const { executor, executed } = makeExecutor();
      await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();
      expect(executed).toEqual(['d1']);
      expect(db.status('d1')).toBe('sending');
    });

    it('ne touche pas un draft tout juste créé (la requête va le réserver)', async () => {
      const db = makeDb([draft('d1', 30 * 1000)]);
      const { executor, executed } = makeExecutor();
      await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();
      expect(executed).toEqual([]);
      expect(db.status('d1')).toBe('draft');
    });

    it('ne renvoie pas un draft trop ancien (> 24 h)', async () => {
      const db = makeDb([draft('d1', ORPHAN_DRAFT_MAX_AGE_MS + MIN)]);
      const { executor, executed } = makeExecutor();
      await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();
      expect(executed).toEqual([]);
    });

    it('ne reprend pas un draft programmé (scheduledFor renseigné)', async () => {
      const row = draft('d1', ORPHAN_DRAFT_GRACE_MS + MIN);
      row.scheduledFor = ago(MIN);
      const db = makeDb([row]);
      const { executor, executed } = makeExecutor();
      await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();
      expect(executed).toEqual([]);
    });

    it('deux répliques reprennent le même draft : un seul envoi', async () => {
      const db = makeDb([draft('d1', ORPHAN_DRAFT_GRACE_MS + MIN)]);
      const { executor, executed } = makeExecutor();
      await Promise.all([
        new CampaignCronService(db.prisma, executor).handleScheduledCampaigns(),
        new CampaignCronService(db.prisma, executor).handleScheduledCampaigns(),
      ]);
      expect(executed).toEqual(['d1']);
    });

    it('sending sans battement depuis > 15 min → failed, livraisons queued abandonnées', async () => {
      const db = makeDb([sending('s1', STALE_SENDING_MS + MIN)]);
      const { executor, executed } = makeExecutor();
      await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();
      expect(db.status('s1')).toBe('failed');
      expect(db.failedDeliveriesOf).toEqual(['s1']);
      // Pas de relance automatique : une partie a pu être livrée.
      expect(executed).toEqual([]);
    });

    it('ne coupe jamais un envoi vivant (battement récent)', async () => {
      const db = makeDb([sending('s1', 2 * MIN)]);
      const { executor } = makeExecutor();
      await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();
      expect(db.status('s1')).toBe('sending');
      expect(db.failedDeliveriesOf).toEqual([]);
    });

    it('un battement arrivé entre la lecture et l’écriture annule la mise en échec', async () => {
      const db = makeDb([sending('s1', STALE_SENDING_MS + MIN)]);
      const { executor } = makeExecutor();
      // La lecture voit la campagne « muette » ; le battement tombe juste
      // après, avant l'UPDATE conditionnel.
      const client = (db.prisma as unknown as {
        execute: (fn: (c: unknown) => unknown) => Promise<unknown>;
      });
      const original = client.execute;
      let first = true;
      client.execute = async (fn) => {
        const result = await original(fn);
        if (first) {
          first = false;
          db.rows[0].updatedAt = new Date();
        }
        return result;
      };
      await new CampaignCronService(db.prisma, executor).handleScheduledCampaigns();
      expect(db.status('s1')).toBe('sending');
    });
  });

  it('à l’arrêt, attend le tick en cours', async () => {
    let release!: () => void;
    const hold = new Promise<void>((resolve) => (release = resolve));
    const db = makeDb([due('c1')]);
    const { executor } = makeExecutor({ hold });
    const service = new CampaignCronService(db.prisma, executor);

    const tick = service.handleScheduledCampaigns();
    await flush();
    let shutDown = false;
    const shutdown = service.onModuleDestroy().then(() => {
      shutDown = true;
    });
    await flush();
    expect(shutDown).toBe(false);

    release();
    await Promise.all([tick, shutdown]);
    expect(shutDown).toBe(true);
  });
});

