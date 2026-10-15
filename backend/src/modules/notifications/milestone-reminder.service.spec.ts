import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { MilestoneReminderService } from './milestone-reminder.service';
import {
  DispatchInput,
  DispatchOutcome,
  NotificationDispatchService,
} from './notification-dispatch.service';

const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;
// Midi UTC : `daysUntil` compte en jours LOCAUX, et midi tombe le même jour
// civil dans tous les fuseaux de −11 h à +11 h. Le test ne dépend donc pas du
// fuseau de la machine qui le lance.
const NOW = new Date('2026-10-20T12:00:00.000Z');
const MODE_ENV = 'KPB_SCHOLARSHIP_OPENING_MODE';

/** Seule `Date` est figée : les promesses et les minuteries restent réelles. */
const EVERYTHING_BUT_DATE = [
  'hrtime',
  'nextTick',
  'performance',
  'queueMicrotask',
  'requestAnimationFrame',
  'cancelAnimationFrame',
  'requestIdleCallback',
  'cancelIdleCallback',
  'setImmediate',
  'clearImmediate',
  'setInterval',
  'clearInterval',
  'setTimeout',
  'clearTimeout',
] as const;

interface Recipient {
  id: string;
  fullName: string;
  preferredLanguage: string;
  countryOfResidence: string;
}

interface Saved {
  itemId: string;
  user: Recipient;
}

/** Ce que rend la requête des abonnés en mode `outbox_followers`. */
interface FollowerRow {
  scholarshipId: string;
  userId: string;
  fullName: string;
  preferredLanguage: string;
  countryOfResidence: string;
}

type Cycle = {
  status: 'open' | 'forecast' | 'closed';
  dateConfidence: 'confirmed' | 'estimated';
};

/**
 * Guards KPB-64/KPB-155: the unified reminder cron fires only at the fixed
 * thresholds (incl. the new J-3), only for approved+active followed
 * scholarships, deep-links to /deadlines, and routes every reminder through the
 * dispatcher (durable feed + dedup + quiet-hours/cap) carrying both languages.
 *
 * Chantier C (§5) : la clé porte la date d'échéance (les seuils se réarment
 * chaque année et après une prolongation), les bourses sont lues AVANT leurs
 * abonnés, l'audience devient « qui suit » en mode `outbox_followers`, et les
 * cycles sont triés par année.
 */
describe('MilestoneReminderService', () => {
  const savedMode = process.env[MODE_ENV];

  beforeAll(() => {
    jest.useFakeTimers({ now: NOW, doNotFake: [...EVERYTHING_BUT_DATE] });
  });
  afterAll(() => {
    jest.useRealTimers();
  });
  afterEach(() => {
    if (savedMode === undefined) delete process.env[MODE_ENV];
    else process.env[MODE_ENV] = savedMode;
  });

  function makeService(
    opts: {
      saved?: Saved[];
      followerRows?: FollowerRow[];
      scholarships?: unknown[];
      /** Clés présentes en base ET écrites il y a moins de 36 h. */
      recentKeys?: string[];
      /** Partagé entre deux services : la table `UserNotification` qui reste. */
      feed?: Set<string>;
    } = {},
  ) {
    const dispatched: DispatchInput[] = [];
    const calls = {
      scholarshipWhere: [] as Record<string, unknown>[],
      scholarshipSelect: [] as Record<string, unknown>[],
      savedWhere: [] as Record<string, unknown>[],
      rawSql: [] as Prisma.Sql[],
      guardWhere: [] as Array<{
        dedupeKey: { in: string[] };
        createdAt: { gte: Date };
      }>,
    };
    const client = {
      savedItem: {
        findMany: async ({
          where,
        }: {
          where: { itemType: string; itemId: { in: string[] } };
        }) => {
          calls.savedWhere.push(where);
          return (opts.saved ?? []).filter((item) =>
            where.itemId.in.includes(item.itemId),
          );
        },
      },
      $queryRaw: async (sql: Prisma.Sql) => {
        calls.rawSql.push(sql);
        return opts.followerRows ?? [];
      },
      scholarship: {
        findMany: async ({
          where,
          select,
        }: {
          where: Record<string, unknown>;
          select: Record<string, unknown>;
        }) => {
          calls.scholarshipWhere.push(where);
          calls.scholarshipSelect.push(select);
          return opts.scholarships ?? [];
        },
      },
      userNotification: {
        findMany: async ({
          where,
        }: {
          where: { dedupeKey: { in: string[] }; createdAt: { gte: Date } };
        }) => {
          calls.guardWhere.push(where);
          return (opts.recentKeys ?? [])
            .filter((key) => where.dedupeKey.in.includes(key))
            .map((dedupeKey) => ({ dedupeKey }));
        },
      },
      case: { findMany: async () => [] },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    // Le vrai dispatcher déduplique sur `dedupeKey` (contrainte unique) : la
    // doublure aussi, sinon « la clé se réarme » ne prouverait rien.
    const feed = opts.feed ?? new Set<string>();
    const dispatch = {
      dispatch: async (input: DispatchInput): Promise<DispatchOutcome> => {
        dispatched.push(input);
        if (feed.has(input.dedupeKey)) return 'deduped';
        feed.add(input.dedupeKey);
        return 'pushed';
      },
    } as unknown as NotificationDispatchService;
    return {
      service: new MilestoneReminderService(prisma, dispatch),
      dispatched,
      calls,
    };
  }

  const recipient = (id: string, lang = 'fr'): Recipient => ({
    id,
    fullName: 'A',
    preferredLanguage: lang,
    countryOfResidence: 'SN',
  });
  const savedFor = (lang: string, userId = 'u1', itemId = 'sch-1'): Saved => ({
    itemId,
    user: recipient(userId, lang),
  });
  const followerRow = (userId: string, scholarshipId = 'sch-1'): FollowerRow => ({
    scholarshipId,
    userId,
    fullName: 'A',
    preferredLanguage: 'fr',
    countryOfResidence: 'SN',
  });
  // `cycles` fait partie de la SÉLECTION Prisma depuis que le rappel refuse
  // les dates estimées. Prisma rend toujours un tableau (vide s'il n'y a pas de
  // cycle) : la doublure doit donc en rendre un aussi, sinon elle ne décrit
  // plus la requête qu'elle prétend simuler — et le service se protégerait d'un
  // `undefined` qui n'existe jamais en production.
  const scholarshipDueInDays = (
    days: number,
    cycles: Cycle[] = [],
    id = 'sch-1',
  ) => ({
    id,
    nameFr: 'Bourse X',
    nameEn: 'Scholarship X',
    deadlineAt: new Date(NOW.getTime() + days * DAY),
    countryNameFr: 'France',
    countryNameEn: 'France',
    cycles,
  });

  it('produces a J-7 reminder deep-linking to /deadlines', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7)],
    });
    const reminders = await service.collectDueReminders(new Date());
    expect(reminders).toHaveLength(1);
    expect(reminders[0].titleFr).toBe('Bourse à J-7');
    expect(reminders[0].route).toBe('/deadlines');
  });

  // Chantier C, §5.1 : la route NE change PAS. La fiche `/scholarships/:id`
  // applique `publicScholarshipWhere` (vérifiée, échéance non passée), que la
  // requête des rappels n'applique pas : un J-0 ou une bourse approuvée sans
  // `lastVerifiedAt` ouvrirait une 404 sur les builds 53/56 en magasin.
  it('garde la route /deadlines dans tous les modes, et l’identifiant dans les données', async () => {
    for (const mode of ['legacy', 'outbox_alerts', 'outbox_followers']) {
      process.env[MODE_ENV] = mode;
      const { service } = makeService({
        saved: [savedFor('fr')],
        followerRows: [followerRow('u1')],
        scholarships: [scholarshipDueInDays(0)],
      });
      const [reminder] = await service.collectDueReminders(new Date());
      expect(reminder.route).toBe('/deadlines');
      expect(reminder.data).toEqual({
        type: 'milestone_reminder',
        reminderType: 'saved_scholarship',
        scholarshipId: 'sch-1',
        daysUntil: '0',
      });
    }
  });

  // ── Revue du build 49, point 9 : les bourses « à venir » ────────────────
  //
  // L'importeur remplit `deadlineAt` depuis `estimatedCloseAt` quand le cycle
  // n'est pas confirmé. Sans le refus, l'app poussait « plus que 3 jours pour
  // candidater » sur une campagne dont AUCUNE date n'a été publiée. Deux
  // surfaces se taisaient déjà correctement (pastille de liste, calendrier) ;
  // la notification, seule des trois à réveiller le téléphone, ne consultait
  // pas le champ.
  it('ne rappelle JAMAIS sur une date estimée', async () => {
    const { service, calls } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7, [
        { status: 'forecast', dateConfidence: 'estimated' },
      ])],
    });
    const reminders = await service.collectDueReminders(new Date());
    expect(reminders).toHaveLength(0);
    // Aucune bourse à rappeler : aucun abonné n'est lu.
    expect(calls.savedWhere).toHaveLength(0);
  });

  it('rappelle bien sur une date confirmée', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7, [
        { status: 'open', dateConfidence: 'confirmed' },
      ])],
    });
    // Contre-garde du test précédent : sans elle, une erreur qui supprimerait
    // TOUS les rappels passerait pour un correctif.
    expect(await service.collectDueReminders(new Date())).toHaveLength(1);
  });

  it('une fiche héritée SANS cycle reste rappelée (le silence n\'est pas un refus)', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7, [])],
    });
    expect(await service.collectDueReminders(new Date())).toHaveLength(1);
  });

  // LA régression que la revue automatique a trouvée sur la PR #252.
  //
  // Une bourse dont la campagne EN COURS est ouverte et confirmée, et pour
  // laquelle l'exploitation a déjà saisi la prévision de l'année suivante.
  // `deadlineAt` appartient au cycle OUVERT. La première version sélectionnait
  // « l'année lexicographiquement la plus récente » — donc la prévision, donc
  // « estimée » — et supprimait des rappels parfaitement légitimes, sur les
  // bourses les plus suivies précisément parce qu'elles sont les mieux tenues.
  it('rappelle quand un cycle OUVERT confirmé coexiste avec une prévision plus récente',
      async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [
        scholarshipDueInDays(7, [
          { status: 'forecast', dateConfidence: 'estimated' },
          { status: 'open', dateConfidence: 'confirmed' },
        ]),
      ],
    });
    const reminders = await service.collectDueReminders(new Date());
    expect(reminders).toHaveLength(1);
    expect(reminders[0].titleFr).toBe('Bourse à J-7');
  });

  // Chantier C, §5.5 : sans `orderBy`, deux cycles `open` (l'ancien jamais
  // refermé, le nouveau prolongé à l'estimée) étaient départagés par l'ordre
  // physique des lignes. Triés par année décroissante, `selectCurrentCycle`
  // prend le plus récent, comme la fiche — et tous les cycles restent lus
  // (aucun `take`), sinon la régression de la PR #252 revient.
  it('lit TOUS les cycles, triés par année décroissante', async () => {
    const { service, calls } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7)],
    });
    await service.collectDueReminders(new Date());
    expect(calls.scholarshipSelect[0].cycles).toEqual({
      select: { status: true, dateConfidence: true },
      orderBy: { academicYear: 'desc' },
    });
  });

  it('suit le cycle ouvert le plus récent quand la base en rend deux, triés par année', async () => {
    // 2027-2028 ouvert sur une date estimée, 2026-2027 ouvert et confirmé :
    // l'ordre `academicYear desc` met le plus récent en tête, et c'est lui
    // que la fiche affiche. Pas de rappel « J-7 » affirmé sur une estimée.
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [
        scholarshipDueInDays(7, [
          { status: 'open', dateConfidence: 'estimated' },
          { status: 'open', dateConfidence: 'confirmed' },
        ]),
      ],
    });
    expect(await service.collectDueReminders(new Date())).toHaveLength(0);
  });

  it('reminds at the new J-3 threshold', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(3)],
    });
    const reminders = await service.collectDueReminders(new Date());
    expect(reminders).toHaveLength(1);
    expect(reminders[0].titleFr).toBe('Bourse à J-3');
  });

  it('does not remind off-threshold (J-8)', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(8)],
    });
    const reminders = await service.collectDueReminders(new Date());
    expect(reminders).toHaveLength(0);
  });

  it('queries only approved + active scholarships', async () => {
    const { service, calls } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7)],
    });
    await service.collectDueReminders(new Date());
    const where = calls.scholarshipWhere[0];
    expect(where?.isActive).toBe(true);
    expect(where?.moderationStatus).toBe('approved');
  });

  // §5.4 : l'ancien ordre chargeait TOUS les favoris de bourse de la base,
  // chaque matin, pour en garder une poignée.
  it('lit les bourses d’abord, puis les seuls abonnés des bourses à un seuil', async () => {
    const { service, calls } = makeService({
      saved: [savedFor('fr'), savedFor('fr', 'u2', 'sch-2')],
      scholarships: [
        scholarshipDueInDays(7),
        scholarshipDueInDays(8, [], 'sch-2'),
      ],
    });
    await service.collectDueReminders(new Date());
    expect(calls.scholarshipWhere[0]).not.toHaveProperty('id');
    expect(calls.savedWhere).toEqual([
      { itemType: 'scholarship', itemId: { in: ['sch-1'] } },
    ]);
  });

  it('dispatches with both languages, a dated dedupeKey, and residence', async () => {
    const { service, dispatched } = makeService({
      saved: [savedFor('en')],
      scholarships: [scholarshipDueInDays(7)],
    });
    await service.handleDailyMilestoneReminders();
    expect(dispatched).toHaveLength(1);
    const input = dispatched[0];
    expect(input.dedupeKey).toBe('deadline:scholarship:sch-1:2026-10-27:u1:d7');
    expect(input.title.fr).toBe('Bourse à J-7');
    expect(input.title.en).toBe('Scholarship deadline in 7 days');
    expect(input.preferredLanguage).toBe('en');
    expect(input.countryOfResidence).toBe('SN');
    expect(input.scholarshipId).toBe('sch-1');
    expect(input.route).toBe('/deadlines');
  });

  it('la date de la clé est la date UTC de l’échéance enregistrée par l’admin', async () => {
    const { service } = makeService({
      saved: [savedFor('fr')],
      scholarships: [
        {
          ...scholarshipDueInDays(7),
          // L'admin enregistre la fin de journée UTC.
          deadlineAt: new Date('2026-10-27T23:59:59.999Z'),
        },
      ],
    });
    // « Maintenant » à moins d'une heure de l'échéance dans la journée :
    // `daysUntil` (jours locaux) vaut 7 dans tout fuseau à l'heure ronde, alors
    // que la date LOCALE de l'échéance est le 28 à l'est de Greenwich. La clé,
    // elle, prend la date UTC — la même sur chaque serveur.
    const reminders = await service.collectDueReminders(
      new Date('2026-10-20T23:00:00.000Z'),
    );
    expect(reminders.map((r) => r.dedupeKey)).toEqual([
      'deadline:scholarship:sch-1:2026-10-27:u1:d7',
    ]);
  });

  // ── Réarmement (§5.2) ──────────────────────────────────────────────────

  it('réarme les seuils l’année suivante : même bourse, même étudiant, même seuil', async () => {
    const feed = new Set<string>();
    const thisYear = makeService({
      feed,
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7)],
    });
    await thisYear.service.handleDailyMilestoneReminders();

    jest.setSystemTime(new Date(NOW.getTime() + 365 * DAY));
    try {
      const nextYear = makeService({
        feed,
        saved: [savedFor('fr')],
        scholarships: [scholarshipDueInDays(365 + 7)],
      });
      const result = await nextYear.service.handleDailyMilestoneReminders();
      expect(result.outcomes).toEqual({ pushed: 1 });
      expect(nextYear.dispatched[0].dedupeKey).toBe(
        'deadline:scholarship:sch-1:2027-10-27:u1:d7',
      );
    } finally {
      jest.setSystemTime(NOW);
    }
  });

  it('réarme les seuils après une prolongation de l’échéance', async () => {
    const feed = new Set<string>();
    // Échéance au 27/10 : le J-7 part le 20/10.
    await makeService({
      feed,
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7)],
    }).service.handleDailyMilestoneReminders();

    // Le 21/10, l'échéance est repoussée au 28/10 : nouveau J-7.
    jest.setSystemTime(new Date(NOW.getTime() + DAY));
    try {
      const extended = makeService({
        feed,
        saved: [savedFor('fr')],
        scholarships: [scholarshipDueInDays(8)],
      });
      const result = await extended.service.handleDailyMilestoneReminders();
      expect(result.outcomes).toEqual({ pushed: 1 });
      expect(extended.dispatched[0].dedupeKey).toBe(
        'deadline:scholarship:sch-1:2026-10-28:u1:d7',
      );
    } finally {
      jest.setSystemTime(NOW);
    }
  });

  it('une relance le même jour reste dédupliquée', async () => {
    const feed = new Set<string>();
    const options = {
      feed,
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(7)],
    };
    await makeService(options).service.handleDailyMilestoneReminders();
    const rerun = await makeService(options).service.handleDailyMilestoneReminders();
    expect(rerun).toEqual({ due: 1, outcomes: { deduped: 1 } });
  });

  // ── Garde de transition (à retirer après le 2026-11-15) ────────────────

  it('ne renvoie pas un rappel déjà parti ce matin sous la clé sans date', async () => {
    const { service, dispatched, calls } = makeService({
      saved: [savedFor('fr', 'u1'), savedFor('fr', 'u2')],
      scholarships: [scholarshipDueInDays(7)],
      recentKeys: ['deadline:scholarship:sch-1:u1:d7'],
    });
    const result = await service.handleDailyMilestoneReminders();

    expect(dispatched.map((input) => input.userId)).toEqual(['u2']);
    // Pour l'admin, c'est une relance du même jour : `deduped`.
    expect(result).toEqual({ due: 2, outcomes: { deduped: 1, pushed: 1 } });
    // Seules les clés anciennes de CE passage, écrites depuis moins de 36 h :
    // la clé du J-7 de l'an dernier ne doit jamais bloquer celui de cette année.
    expect(calls.guardWhere).toEqual([
      {
        dedupeKey: {
          in: [
            'deadline:scholarship:sch-1:u1:d7',
            'deadline:scholarship:sch-1:u2:d7',
          ],
        },
        createdAt: { gte: new Date(NOW.getTime() - 36 * HOUR) },
      },
    ]);
  });

  it('découpe la garde en lots bornés (paramètres liés de PostgreSQL)', async () => {
    const saved = Array.from({ length: 2_500 }, (_, i) =>
      savedFor('fr', `u${i}`),
    );
    const { service, calls } = makeService({
      saved,
      scholarships: [scholarshipDueInDays(7)],
    });
    const reminders = await service.collectDueReminders(new Date());
    expect(reminders).toHaveLength(2_500);
    expect(calls.guardWhere.map((where) => where.dedupeKey.in.length)).toEqual([
      1_000, 1_000, 500,
    ]);
  });

  it('ne lit pas la garde quand aucun rappel de bourse n’est dû', async () => {
    const { service, calls } = makeService({
      saved: [savedFor('fr')],
      scholarships: [scholarshipDueInDays(8)],
    });
    await service.collectDueReminders(new Date());
    expect(calls.guardWhere).toHaveLength(0);
  });

  // ── Audience (§5.3) ─────────────────────────────────────────────────────

  it.each(['legacy', 'outbox_alerts', '', 'nimporte'])(
    'mode « %s » : les favoris seulement, comme avant le chantier C',
    async (mode) => {
      process.env[MODE_ENV] = mode;
      const { service, calls } = makeService({
        saved: [savedFor('fr', 'fav')],
        // Un étudiant « alerte seule » : invisible hors `outbox_followers`.
        followerRows: [followerRow('fav'), followerRow('alert-only')],
        scholarships: [scholarshipDueInDays(7)],
      });
      const reminders = await service.collectDueReminders(new Date());
      expect(reminders.map((r) => r.user.id)).toEqual(['fav']);
      expect(calls.rawSql).toHaveLength(0);
    },
  );

  it('mode outbox_followers : ceux qui suivent, par la définition partagée', async () => {
    process.env[MODE_ENV] = 'outbox_followers';
    const { service, calls } = makeService({
      saved: [savedFor('fr', 'fav')],
      followerRows: [followerRow('alert-only'), followerRow('fav')],
      scholarships: [
        scholarshipDueInDays(7),
        scholarshipDueInDays(8, [], 'sch-2'),
      ],
    });
    const reminders = await service.collectDueReminders(new Date());

    expect(reminders.map((r) => r.user.id)).toEqual(['alert-only', 'fav']);
    expect(reminders[0]).toMatchObject({
      user: {
        id: 'alert-only',
        fullName: 'A',
        preferredLanguage: 'fr',
        countryOfResidence: 'SN',
      },
      dedupeKey: 'deadline:scholarship:sch-1:2026-10-27:alert-only:d7',
    });
    // Les favoris ne sont plus lus à part : la requête partagée les inclut.
    expect(calls.savedWhere).toHaveLength(0);
    expect(calls.rawSql).toHaveLength(1);
    const sql = calls.rawSql[0];
    // `followingPairsSql`, restreint aux bourses à un seuil aujourd'hui.
    expect(sql.sql).toContain('FULL OUTER JOIN');
    expect(sql.sql).toContain('si."itemId" = ANY(');
    expect(sql.sql).toContain('JOIN "UserProfile" p');
    expect(sql.values).toContainEqual(['sch-1']);
  });

  // Une sourdine ne coupe que l'annonce d'ouverture ; la désinscription
  // globale `followed_scholarship_updates` aussi. Un rappel d'échéance est
  // transactionnel (`common/notification-types.ts`).
  it('mode outbox_followers : ni la sourdine ni la désinscription globale ne coupent les rappels', async () => {
    process.env[MODE_ENV] = 'outbox_followers';
    const { service, calls } = makeService({
      followerRows: [followerRow('muted-fav')],
      scholarships: [scholarshipDueInDays(7)],
    });
    expect(await service.collectDueReminders(new Date())).toHaveLength(1);
    const text = calls.rawSql[0].sql;
    expect(text).not.toContain('disabledNotificationTypes');
    // Le seul filtre sur la sourdine est celui de la définition « suit » :
    // une alerte en sourdine SANS favori ne suit plus.
    expect(text).toContain('WHERE f."userId" IS NOT NULL OR a."mutedAt" IS NULL');
    expect(text).not.toMatch(/NOT\s+pairs\."muted"/);
  });

  it('un même étudiant abonné à deux bourses dues reçoit deux rappels distincts', async () => {
    process.env[MODE_ENV] = 'outbox_followers';
    const { service } = makeService({
      followerRows: [followerRow('u1', 'sch-1'), followerRow('u1', 'sch-2')],
      scholarships: [
        scholarshipDueInDays(7),
        scholarshipDueInDays(14, [], 'sch-2'),
      ],
    });
    const keys = (await service.collectDueReminders(new Date())).map(
      (r) => r.dedupeKey,
    );
    expect(keys).toEqual([
      'deadline:scholarship:sch-1:2026-10-27:u1:d7',
      'deadline:scholarship:sch-2:2026-11-03:u1:d14',
    ]);
  });
});
