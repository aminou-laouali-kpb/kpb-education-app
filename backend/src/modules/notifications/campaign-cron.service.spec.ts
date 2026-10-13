import { CampaignCronService } from './campaign-cron.service';
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
  type Row = { id: string; name: string; status: string; scheduledFor: Date };
  type Where = { id?: string; status?: string };

  /** Base partagée entre répliques : c'est elle qui arbitre la prise. */
  function makeDb(initial: Row[]) {
    const rows = [...initial];
    const findManyCalls: string[][] = [];
    const hooks: { afterRead?: () => void; failRead?: boolean } = {};
    const client = {
      notificationCampaign: {
        // Instantané au moment de la lecture, comme une vraie requête : deux
        // workers qui lisent avant toute prise voient la même campagne.
        findMany: async ({ where }: { where: Where }) => {
          if (hooks.failRead) throw new Error('db down');
          const hit = rows
            .filter((r) => r.status === where.status)
            .map((r) => ({ ...r }));
          findManyCalls.push(hit.map((r) => r.id));
          hooks.afterRead?.();
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
          const hit = rows.filter(
            (r) =>
              (!where.id || r.id === where.id) &&
              (!where.status || r.status === where.status),
          );
          hit.forEach((r) => (r.status = data.status));
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
});
