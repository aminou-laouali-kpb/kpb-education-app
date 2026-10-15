import { randomUUID } from 'node:crypto';

import { AccountType, Prisma, PrismaClient } from '@prisma/client';

import {
  followedScholarshipIdsSql,
  followerAudienceCountsSql,
  followerCountsSql,
  followerRowsCte,
  followerRowsSql,
  followingPairsSql,
  newFollowerCountsSql,
  type FollowedScholarshipRow,
  type FollowerAudienceCounts,
  type FollowerCountRow,
  type FollowerRow,
  type FollowingPair,
  type NewFollowerCountRow,
} from './scholarship-follow.query';

/**
 * La définition « qui suit cette bourse » contre un vrai PostgreSQL.
 *
 * Les tests unitaires ne lisent que le TEXTE des requêtes. Ici chaque cas
 * d'audience est inséré puis lu : favori seul, alerte seule, les deux, sourdine
 * sur un favori, sourdine seule, désinscription globale, push coupé, déjà
 * prévenu, prévenu récemment pour un autre cycle (ligne héritée sans
 * `pushedAt`), ancien abonné sur une relance, favori orphelin.
 *
 * Tout se passe dans une transaction annulée : rien à nettoyer, et deux
 * exécutions concurrentes ne se voient pas.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

class Rollback extends Error {}

const DAY = 24 * 60 * 60 * 1000;

describePostgres('Requête de suivi des bourses — intégration PostgreSQL', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID().slice(0, 8);
  const now = new Date('2026-10-15T12:00:00.000Z');
  const announcedAt = new Date('2026-10-01T12:00:00.000Z');
  const renotifySince = new Date(now.getTime() - 30 * DAY);

  const sid = `follow-q-sch-${suffix}`;
  const otherSid = `follow-q-other-${suffix}`;
  const cycleId = `follow-q-cycle-${suffix}`;
  const oldCycleId = `follow-q-oldcycle-${suffix}`;
  const user = (key: string) => `follow-q-${key}-${suffix}`;
  const u = {
    fav: user('fav'),
    alert: user('alert'),
    both: user('both'),
    mutedFav: user('mutedfav'),
    mutedOnly: user('mutedonly'),
    optOut: user('optout'),
    pushOff: user('pushoff'),
    notified: user('notified'),
    recent: user('recent'),
    oldFollower: user('old'),
    device: user('device'),
    stranger: user('stranger'),
  };

  afterAll(async () => {
    await prisma.$disconnect();
  });

  /**
   * `body` dans une transaction toujours annulée. Toute autre erreur
   * (assertion ratée, requête refusée) est relancée telle quelle : son
   * message et son diff, pas « attendu Rollback ».
   */
  async function rolledBack(
    body: (tx: Prisma.TransactionClient) => Promise<void>,
  ): Promise<void> {
    try {
      await prisma.$transaction(
        async (tx) => {
          await seed(tx);
          await body(tx);
          throw new Rollback();
        },
        { maxWait: 5_000, timeout: 30_000 },
      );
    } catch (error) {
      if (error instanceof Rollback) return;
      throw error;
    }
    throw new Error('La transaction aurait dû être annulée.');
  }

  function scholarship(id: string) {
    return {
      id,
      nameFr: `Bourse ${id}`,
      nameEn: `Scholarship ${id}`,
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
      moderationStatus: 'approved' as const,
      lastVerifiedAt: now,
    };
  }

  async function seed(tx: Prisma.TransactionClient): Promise<void> {
    await tx.userProfile.createMany({
      data: Object.entries(u).map(([key, id]) => ({
        id,
        accountType: AccountType.student,
        preferredLanguage: key === 'alert' ? 'en' : 'fr',
        fullName: `Suivi ${key}`,
        email: `${id}@example.test`,
        phone: '',
        countryOfResidence: key === 'both' ? 'Cameroun' : 'Sénégal',
        disabledNotificationTypes:
          key === 'optOut' ? ['followed_scholarship_updates'] : [],
      })),
    });
    await tx.scholarship.createMany({
      data: [scholarship(sid), scholarship(otherSid)],
    });
    await tx.scholarshipCycle.createMany({
      data: [
        {
          id: oldCycleId,
          scholarshipId: sid,
          academicYear: '2025-2026',
          status: 'closed',
          dateConfidence: 'confirmed',
        },
        {
          id: cycleId,
          scholarshipId: sid,
          academicYear: '2026-2027',
          status: 'open',
          dateConfidence: 'confirmed',
        },
      ],
    });

    const recentFollow = new Date(announcedAt.getTime() + DAY);
    const favorite = (userId: string, createdAt = recentFollow) => ({
      userId,
      itemType: 'scholarship',
      itemId: sid,
      createdAt,
    });
    await tx.savedItem.createMany({
      data: [
        favorite(u.fav),
        favorite(u.both),
        favorite(u.mutedFav),
        favorite(u.optOut),
        favorite(u.recent),
        favorite(u.oldFollower, new Date(announcedAt.getTime() - 10 * DAY)),
        // Une autre bourse, et un favori orphelin (aucune FK sur itemId).
        { userId: u.fav, itemType: 'scholarship', itemId: otherSid },
        { userId: u.fav, itemType: 'scholarship', itemId: `missing-${suffix}` },
        // Pas une bourse.
        { userId: u.stranger, itemType: 'program', itemId: sid },
      ],
    });

    const alert = (
      userId: string,
      extra: { mutedAt?: Date; pushEnabled?: boolean } = {},
    ) => ({ userId, scholarshipId: sid, createdAt: recentFollow, ...extra });
    await tx.scholarshipAlertSubscription.createMany({
      data: [
        alert(u.alert),
        alert(u.both),
        alert(u.mutedFav, { mutedAt: now }),
        alert(u.mutedOnly, { mutedAt: now }),
        alert(u.pushOff, { pushEnabled: false }),
        alert(u.notified),
        alert(u.device),
      ],
    });
    await tx.deviceToken.create({
      data: { userProfileId: u.device, token: `tok-${suffix}`, platform: 'android' },
    });

    const opened = (userId: string, cycle: string, createdAt: Date) => ({
      userId,
      scholarshipId: sid,
      cycleId: cycle,
      kind: 'scholarship_opened',
      dedupeKey: `scholarship-opened:${cycle}:${userId}`,
      titleFr: 't',
      titleEn: 't',
      bodyFr: 'b',
      bodyEn: 'b',
      route: `/scholarships/${sid}`,
      createdAt,
    });
    await tx.userNotification.createMany({
      data: [
        // Déjà prévenu pour CE cycle.
        opened(u.notified, cycleId, new Date(now.getTime() - DAY)),
        // Prévenu il y a 5 jours pour un AUTRE cycle, par l'ancien chemin
        // (jamais de `pushedAt`) : la garde lit `createdAt`.
        opened(u.recent, oldCycleId, new Date(now.getTime() - 5 * DAY)),
      ],
    });
  }

  async function rows(
    tx: Prisma.TransactionClient,
    ...args: Parameters<typeof followerRowsSql>
  ): Promise<Map<string, FollowerRow>> {
    const result = await tx.$queryRaw<FollowerRow[]>(followerRowsSql(...args));
    return new Map(result.map((row) => [row.userId, row]));
  }

  function toNotify(map: Map<string, FollowerRow>): string[] {
    return [...map.values()]
      .filter((row) => row.toNotify)
      .map((row) => row.userId)
      .sort();
  }

  it('portée alertes : les alertes non mises en sourdine, déduplication comprise', async () => {
    await rolledBack(async (tx) => {
      const map = await rows(tx, sid, 'alerts', cycleId, renotifySince, null);

      expect(toNotify(map)).toEqual([u.alert, u.both, u.device, u.pushOff].sort());
      // Un favori seul n'est pas un candidat en portée alertes.
      expect(map.has(u.fav)).toBe(false);
      expect(map.get(u.mutedFav)).toMatchObject({ muted: true, toNotify: false });
      expect(map.get(u.mutedOnly)).toMatchObject({ muted: true, toNotify: false });
      expect(map.get(u.notified)).toMatchObject({
        alreadyNotified: true,
        toNotify: false,
      });
      expect(map.get(u.both)).toMatchObject({
        viaFavorite: true,
        viaAlert: true,
        countryOfResidence: 'Cameroun',
      });
      expect(map.get(u.alert)?.preferredLanguage).toBe('en');
    });
  });

  it('portée abonnés : favoris ∪ alertes, moins sourdines, déjà prévenus et prévenus récemment', async () => {
    await rolledBack(async (tx) => {
      const map = await rows(tx, sid, 'followers', cycleId, renotifySince, null);

      expect(toNotify(map)).toEqual(
        [u.fav, u.alert, u.both, u.optOut, u.pushOff, u.oldFollower, u.device].sort(),
      );
      // Inscrit une fois, quoi qu'il suive deux fois.
      expect([...map.keys()].filter((id) => id === u.both)).toHaveLength(1);
      expect(map.get(u.recent)).toMatchObject({
        recentlyNotified: true,
        toNotify: false,
      });
      // La désinscription et le push coupé laissent l'entrée d'inbox : ils
      // restent dans `toNotify`, l'envoi les marquera `skipped`.
      expect(map.get(u.optOut)).toMatchObject({ optedOut: true, toNotify: true });
      expect(map.get(u.pushOff)).toMatchObject({ pushEnabled: false, toNotify: true });
      expect(map.get(u.device)?.hasFcmDevice).toBe(true);
      expect(map.get(u.fav)?.hasFcmDevice).toBe(false);
      expect(map.has(u.stranger)).toBe(false);
    });
  });

  it('relance : seuls ceux qui suivent depuis la première annonce', async () => {
    await rolledBack(async (tx) => {
      const map = await rows(
        tx,
        sid,
        'followers',
        cycleId,
        renotifySince,
        announcedAt,
      );

      expect(map.get(u.oldFollower)).toMatchObject({
        followedBeforeAnnouncement: true,
        toNotify: false,
      });
      expect(map.get(u.fav)).toMatchObject({
        followedBeforeAnnouncement: false,
        toNotify: true,
      });
    });
  });

  it('nouveau cycle (pas encore créé) : personne n’est « déjà prévenu »', async () => {
    await rolledBack(async (tx) => {
      const map = await rows(tx, sid, 'alerts', null, renotifySince, null);

      // La ligne de `notified` porte sur `cycleId` : pour un cycle à venir,
      // c'est une annonce récente d'un AUTRE cycle de la bourse.
      expect(map.get(u.notified)).toMatchObject({
        alreadyNotified: false,
        recentlyNotified: true,
        toNotify: false,
      });
      expect(map.get(u.alert)?.toNotify).toBe(true);
    });
  });

  it('les comptes agrégés égalent les lignes (aperçu = activate = envoi)', async () => {
    await rolledBack(async (tx) => {
      for (const scope of ['alerts', 'followers'] as const) {
        for (const followSince of [null, announcedAt]) {
          const args = [sid, scope, cycleId, renotifySince, followSince] as const;
          const map = await rows(tx, ...args);
          const [counts] = await tx.$queryRaw<FollowerAudienceCounts[]>(
            followerAudienceCountsSql(...args),
          );
          const list = [...map.values()];
          const due = list.filter((row) => row.toNotify);
          expect(counts).toEqual({
            audience: list.filter((row) => !row.muted).length,
            muted: list.filter((row) => row.muted).length,
            toNotify: due.length,
            viaFavoriteOnly: due.filter((r) => r.viaFavorite && !r.viaAlert).length,
            viaAlertOnly: due.filter((r) => r.viaAlert && !r.viaFavorite).length,
            viaBoth: due.filter((r) => r.viaAlert && r.viaFavorite).length,
          });
        }
      }
    });
  });

  it('le même texte précède un INSERT … SELECT (le chemin de l’envoi)', async () => {
    await rolledBack(async (tx) => {
      await tx.$executeRawUnsafe(
        'CREATE TEMP TABLE follow_probe ("userId" TEXT PRIMARY KEY) ON COMMIT DROP',
      );
      const inserted = await tx.$executeRaw(Prisma.sql`${followerRowsCte(
        sid,
        'followers',
        cycleId,
        renotifySince,
        null,
      )}
        INSERT INTO follow_probe ("userId")
        SELECT "userId" FROM follow_rows WHERE "toNotify"
      `);
      const [counts] = await tx.$queryRaw<FollowerAudienceCounts[]>(
        followerAudienceCountsSql(sid, 'followers', cycleId, renotifySince, null),
      );
      expect(inserted).toBe(counts.toNotify);
      expect(inserted).toBe(7);
    });
  });

  it('couples suivis : la sourdine garde le couple, l’orphelin et la sourdine seule en sont exclus', async () => {
    await rolledBack(async (tx) => {
      const pairs = await tx.$queryRaw<FollowingPair[]>(
        followingPairsSql([sid, otherSid, `missing-${suffix}`]),
      );
      const keys = pairs.map((pair) => `${pair.scholarshipId}|${pair.userId}`);

      expect(keys).toContain(`${otherSid}|${u.fav}`);
      expect(keys).not.toContain(`missing-${suffix}|${u.fav}`);
      expect(keys).not.toContain(`${sid}|${u.mutedOnly}`);
      expect(pairs.find((p) => p.userId === u.mutedFav)).toMatchObject({
        viaFavorite: true,
        viaAlert: false,
        muted: true,
      });
      expect(pairs.filter((p) => p.scholarshipId === sid)).toHaveLength(10);

      expect(await tx.$queryRaw<FollowingPair[]>(followingPairsSql([]))).toEqual([]);
      const mine = await tx.$queryRaw<FollowingPair[]>(
        followingPairsSql([sid, otherSid], u.fav),
      );
      expect(mine.map((pair) => pair.scholarshipId).sort()).toEqual(
        [sid, otherSid].sort(),
      );
    });
  });

  it('bourses suivies d’un étudiant', async () => {
    await rolledBack(async (tx) => {
      const followed = await tx.$queryRaw<FollowedScholarshipRow[]>(
        followedScholarshipIdsSql(u.fav),
      );
      expect(followed).toEqual(
        [
          { scholarshipId: sid, viaFavorite: true, viaAlert: false, muted: false },
          { scholarshipId: otherSid, viaFavorite: true, viaAlert: false, muted: false },
        ].sort((a, b) => a.scholarshipId.localeCompare(b.scholarshipId)),
      );
      expect(
        await tx.$queryRaw<FollowedScholarshipRow[]>(
          followedScholarshipIdsSql(u.mutedOnly),
        ),
      ).toEqual([]);
    });
  });

  it('comptes par bourse, selon la portée', async () => {
    await rolledBack(async (tx) => {
      const alerts = await tx.$queryRaw<FollowerCountRow[]>(
        followerCountsSql('alerts', [sid]),
      );
      const followers = await tx.$queryRaw<FollowerCountRow[]>(
        followerCountsSql('followers', [sid]),
      );
      // Suivent : 6 favoris + 4 alertes seules (alert, pushOff, notified, device).
      expect(alerts).toEqual([{ scholarshipId: sid, followers: 10, notifiable: 5 }]);
      expect(followers).toEqual([{ scholarshipId: sid, followers: 10, notifiable: 9 }]);
    });
  });

  it('nouveaux abonnés d’un cycle annoncé : la relance, prévenus récents d’un autre cycle compris', async () => {
    await rolledBack(async (tx) => {
      const target = { scholarshipId: sid, cycleId, since: announcedAt };
      for (const scope of ['alerts', 'followers'] as const) {
        const [row] = await tx.$queryRaw<NewFollowerCountRow[]>(
          newFollowerCountsSql(scope, [target]),
        );
        const [relaunch] = await tx.$queryRaw<FollowerAudienceCounts[]>(
          followerAudienceCountsSql(sid, scope, cycleId, renotifySince, announcedAt),
        );
        // `recent` (prévenu il y a 5 jours pour l'ANCIEN cycle) n'a qu'un
        // favori : compté en portée abonnés, comme dans `notifiable`, mais
        // exclu du `toNotify` de l'aperçu par la garde des 30 jours.
        const recentOnly = scope === 'followers' ? 1 : 0;
        expect({ scope, row }).toEqual({
          scope,
          row: { scholarshipId: sid, newFollowers: relaunch.toNotify + recentOnly },
        });
      }
      // Abonnés : fav, both, optOut, pushOff, device, alert et recent ; ni
      // oldFollower (avant l'annonce), ni notified (déjà prévenu pour ce
      // cycle), ni les sourdines. Alertes : alert, both, pushOff, device.
      const [followers] = await tx.$queryRaw<NewFollowerCountRow[]>(
        newFollowerCountsSql('followers', [target]),
      );
      const [alerts] = await tx.$queryRaw<NewFollowerCountRow[]>(
        newFollowerCountsSql('alerts', [target]),
      );
      expect(followers.newFollowers).toBe(7);
      expect(alerts.newFollowers).toBe(4);

      // Une annonce postérieure à tous les suivis : personne de nouveau, pas
      // de ligne ; une autre bourse dans la même requête garde son compte (son
      // favori, daté par la base, est postérieur à l'origine des temps).
      const later = new Date(now.getTime() + DAY);
      expect(
        await tx.$queryRaw<NewFollowerCountRow[]>(
          newFollowerCountsSql('followers', [
            { scholarshipId: sid, cycleId, since: later },
            { scholarshipId: otherSid, cycleId: `follow-q-othercycle-${suffix}`, since: new Date(0) },
          ]),
        ),
      ).toEqual([{ scholarshipId: otherSid, newFollowers: 1 }]);
    });
  });
});
