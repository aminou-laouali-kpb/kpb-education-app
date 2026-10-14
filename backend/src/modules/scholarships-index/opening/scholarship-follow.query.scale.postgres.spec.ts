import { randomUUID } from 'node:crypto';

import { AccountType, Prisma, PrismaClient } from '@prisma/client';

import {
  followerAudienceCountsSql,
  followerRowsSql,
  type FollowerAudienceCounts,
  type FollowerRow,
} from './scholarship-follow.query';
import {
  FOLLOWED_SCHOLARSHIP_OPT_OUT,
  openingDedupeKey,
  SCHOLARSHIP_OPENED_KIND,
  type OpeningAudienceScope,
} from './scholarship-opening.contract';

/**
 * « Qui suit cette bourse ? » à l'échelle, contre un vrai PostgreSQL.
 *
 * 1. Même résultat que l'ancien texte (gardé ci-dessous, à l'octet près, comme
 *    référence) sur des données tirées au hasard, dans les deux portées, avec
 *    ou sans cycle, première annonce ou relance.
 * 2. Un plan qui ne dépend pas des statistiques : 5 000 puis 20 000 abonnés
 *    insérés dans la transaction même — donc JAMAIS analysés — et la requête
 *    reste sous 2 s, avec le plan naturel ET avec les seules boucles
 *    imbriquées (`enable_hashjoin` / `enable_mergejoin` coupés : ce que choisit
 *    le planificateur quand des statistiques périmées estiment les favoris à
 *    une ligne). L'ancien texte prenait alors 2,8 s à 5 000 et ~25 s à 20 000
 *    (CTE des favoris, matérialisée donc sans index, en boucle interne : n × n).
 *
 * Tout se passe dans des transactions annulées : rien à nettoyer, et les
 * lignes insérées n'existent pour aucune statistique.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

class Rollback extends Error {}

const DAY = 24 * 60 * 60 * 1000;

// ── L'ancien texte (référence de sémantique) ────────────────────────────────
// Copie conforme de `followerRowsCte` avant sa réécriture : ne pas « corriger ».

function legacyFollowerRowsCte(
  scholarshipId: string,
  scope: OpeningAudienceScope,
  cycleId: string | null,
  renotifySince: Date,
  followSince: Date | null,
): Prisma.Sql {
  const favoritesInScope =
    scope === 'followers'
      ? Prisma.sql`UNION SELECT "userId" FROM follow_fav`
      : Prisma.empty;
  // En portée `alerts`, seule l'alerte date le suivi : un favori ancien ne doit
  // pas faire passer pour « ancien abonné » quelqu'un qui vient d'activer la
  // cloche.
  const followSinceExpr =
    scope === 'followers'
      ? Prisma.sql`LEAST(f."createdAt", CASE WHEN a."mutedAt" IS NULL THEN a."createdAt" END)`
      : Prisma.sql`CASE WHEN a."mutedAt" IS NULL THEN a."createdAt" END`;
  const alreadyNotifiedExpr =
    cycleId === null
      ? Prisma.sql`false`
      : Prisma.sql`EXISTS (
          SELECT 1 FROM "UserNotification" n
          WHERE n."dedupeKey" = ${openingDedupeKey(cycleId, '')} || c."userId"
        )`;
  const otherCycleClause =
    cycleId === null
      ? Prisma.empty
      : Prisma.sql`AND r."cycleId" IS DISTINCT FROM ${cycleId}`;
  // NOT (followSince > $followSince) : un début de suivi inconnu compte comme
  // ancien, jamais comme nouveau.
  const beforeAnnouncementExpr =
    followSince === null
      ? Prisma.sql`false`
      : Prisma.sql`(b."followSince" IS NULL OR b."followSince" <= ${followSince})`;

  return Prisma.sql`
    WITH follow_fav AS (
      SELECT si."userId", si."createdAt"
      FROM "SavedItem" si
      JOIN "Scholarship" s ON s."id" = si."itemId"
      WHERE si."itemType" = 'scholarship' AND si."itemId" = ${scholarshipId}
    ),
    follow_alert AS (
      SELECT a."userId", a."mutedAt", a."pushEnabled", a."createdAt"
      FROM "ScholarshipAlertSubscription" a
      WHERE a."scholarshipId" = ${scholarshipId}
    ),
    follow_candidates AS (
      SELECT "userId" FROM follow_alert
      ${favoritesInScope}
    ),
    follow_base AS (
      SELECT
        c."userId" AS "userId",
        (f."userId" IS NOT NULL) AS "viaFavorite",
        (a."userId" IS NOT NULL AND a."mutedAt" IS NULL) AS "viaAlert",
        (a."mutedAt" IS NOT NULL) AS "muted",
        COALESCE(a."pushEnabled", true) AS "pushEnabled",
        (${FOLLOWED_SCHOLARSHIP_OPT_OUT} = ANY(p."disabledNotificationTypes")) AS "optedOut",
        ${followSinceExpr} AS "followSince",
        ${alreadyNotifiedExpr} AS "alreadyNotified",
        EXISTS (
          SELECT 1 FROM "UserNotification" r
          WHERE r."userId" = c."userId"
            AND r."kind" = ${SCHOLARSHIP_OPENED_KIND}
            AND r."scholarshipId" = ${scholarshipId}
            ${otherCycleClause}
            AND r."createdAt" > ${renotifySince}
        ) AS "recentlyNotified",
        EXISTS (
          SELECT 1 FROM "DeviceToken" d WHERE d."userProfileId" = c."userId"
        ) AS "hasFcmDevice",
        p."preferredLanguage" AS "preferredLanguage",
        p."countryOfResidence" AS "countryOfResidence"
      FROM follow_candidates c
      JOIN "UserProfile" p ON p."id" = c."userId"
      LEFT JOIN follow_fav f ON f."userId" = c."userId"
      LEFT JOIN follow_alert a ON a."userId" = c."userId"
    ),
    follow_rows AS (
      SELECT
        b.*,
        ${beforeAnnouncementExpr} AS "followedBeforeAnnouncement",
        (
          NOT b."muted"
          AND NOT b."alreadyNotified"
          AND NOT b."recentlyNotified"
          AND NOT ${beforeAnnouncementExpr}
        ) AS "toNotify"
      FROM follow_base b
    )
  `;
}

function legacyFollowerRowsSql(...args: Parameters<typeof legacyFollowerRowsCte>): Prisma.Sql {
  return Prisma.sql`${legacyFollowerRowsCte(...args)}
    SELECT
      "userId", "viaFavorite", "viaAlert", "muted", "pushEnabled", "optedOut",
      "followSince", "alreadyNotified", "recentlyNotified",
      "followedBeforeAnnouncement", "toNotify", "hasFcmDevice",
      "preferredLanguage", "countryOfResidence"
    FROM follow_rows
    ORDER BY "userId"
  `;
}

/** Tirage reproductible : la graine est dans le message d'échec. */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

describePostgres('Requête de suivi — même sémantique, plan sans statistiques', () => {
  jest.setTimeout(180_000);

  const prisma = new PrismaClient();
  const now = new Date('2026-10-15T12:00:00.000Z');
  const announcedAt = new Date('2026-10-01T12:00:00.000Z');
  const renotifySince = new Date(now.getTime() - 30 * DAY);

  afterAll(async () => {
    await prisma.$disconnect();
  });

  async function rolledBack(body: (tx: Prisma.TransactionClient) => Promise<void>) {
    await expect(
      prisma.$transaction(
        async (tx) => {
          await body(tx);
          throw new Rollback();
        },
        { maxWait: 5_000, timeout: 170_000 },
      ),
    ).rejects.toBeInstanceOf(Rollback);
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

  it('nouveau texte = ancien texte sur des données tirées au hasard', async () => {
    const seed = Number(process.env.KPB_FOLLOW_QUERY_SEED ?? Date.now() % 2 ** 31);
    const random = mulberry32(seed);
    const pick = (p: number) => random() < p;
    const around = (center: Date, spreadDays: number) =>
      new Date(center.getTime() + Math.round((random() * 2 - 1) * spreadDays * DAY));

    const sfx = randomUUID().slice(0, 8);
    const sid = `fq-eq-sch-${sfx}`;
    const otherSid = `fq-eq-other-${sfx}`;
    const missingSid = `fq-eq-missing-${sfx}`;
    const cycleId = `fq-eq-cycle-${sfx}`;
    const oldCycleId = `fq-eq-old-${sfx}`;

    await rolledBack(async (tx) => {
      await tx.scholarship.createMany({ data: [scholarship(sid), scholarship(otherSid)] });
      await tx.scholarshipCycle.createMany({
        data: [
          { id: oldCycleId, scholarshipId: sid, academicYear: '2025-2026', status: 'closed', dateConfidence: 'confirmed' },
          { id: cycleId, scholarshipId: sid, academicYear: '2026-2027', status: 'open', dateConfidence: 'confirmed' },
        ],
      });

      const users = Array.from({ length: 400 }, (_, i) => `fq-eq-u${i}-${sfx}`);
      await tx.userProfile.createMany({
        data: users.map((id) => ({
          id,
          accountType: AccountType.student,
          preferredLanguage: pick(0.2) ? 'en' : 'fr',
          fullName: id,
          email: `${id}@example.test`,
          phone: '',
          countryOfResidence: pick(0.3) ? 'Cameroun' : 'Sénégal',
          disabledNotificationTypes: pick(0.2) ? [FOLLOWED_SCHOLARSHIP_OPT_OUT] : [],
        })),
      });

      const favorites: Prisma.SavedItemCreateManyInput[] = [];
      const alerts: Prisma.ScholarshipAlertSubscriptionCreateManyInput[] = [];
      const tokens: Prisma.DeviceTokenCreateManyInput[] = [];
      const notifications: Prisma.UserNotificationCreateManyInput[] = [];
      const opened = (userId: string, scholarshipId: string, cycle: string | null, createdAt: Date, key: string) => ({
        userId,
        scholarshipId,
        cycleId: cycle,
        kind: SCHOLARSHIP_OPENED_KIND,
        dedupeKey: key,
        titleFr: 't',
        titleEn: 't',
        bodyFr: 'b',
        bodyEn: 'b',
        route: `/scholarships/${scholarshipId}`,
        createdAt,
      });
      for (const userId of users) {
        if (pick(0.6)) {
          favorites.push({ userId, itemType: 'scholarship', itemId: sid, createdAt: around(announcedAt, 20) });
        }
        if (pick(0.1)) favorites.push({ userId, itemType: 'scholarship', itemId: otherSid });
        // Favori orphelin : `itemId` d'une bourse qui n'existe pas.
        if (pick(0.1)) favorites.push({ userId, itemType: 'scholarship', itemId: missingSid });
        if (pick(0.05)) favorites.push({ userId, itemType: 'program', itemId: sid });
        if (pick(0.5)) {
          alerts.push({
            userId,
            scholarshipId: sid,
            createdAt: around(announcedAt, 20),
            mutedAt: pick(0.3) ? around(now, 5) : null,
            pushEnabled: !pick(0.15),
          });
        }
        if (pick(0.1)) alerts.push({ userId, scholarshipId: otherSid });
        if (pick(0.3)) tokens.push({ userProfileId: userId, token: `tok-${userId}`, platform: 'android' });
        if (pick(0.15)) {
          notifications.push(opened(userId, sid, cycleId, around(now, 3), openingDedupeKey(cycleId, userId)));
        }
        if (pick(0.25)) {
          notifications.push(
            opened(userId, sid, oldCycleId, around(renotifySince, 10), openingDedupeKey(oldCycleId, userId)),
          );
        }
        // Ligne héritée sans colonne `cycleId` (avant la reprise).
        if (pick(0.05)) {
          notifications.push(opened(userId, sid, null, around(now, 40), `legacy:${sfx}:${userId}`));
        }
        if (pick(0.1)) {
          notifications.push(opened(userId, otherSid, null, around(now, 5), `other:${sfx}:${userId}`));
        }
      }
      await tx.savedItem.createMany({ data: favorites });
      await tx.scholarshipAlertSubscription.createMany({ data: alerts });
      await tx.deviceToken.createMany({ data: tokens });
      await tx.userNotification.createMany({ data: notifications });

      let compared = 0;
      for (const scholarshipId of [sid, missingSid]) {
        for (const scope of ['alerts', 'followers'] as const) {
          for (const cycle of [cycleId, null]) {
            for (const followSince of [null, announcedAt]) {
              const args = [scholarshipId, scope, cycle, renotifySince, followSince] as const;
              const [fresh, legacy] = await Promise.all([
                tx.$queryRaw<FollowerRow[]>(followerRowsSql(...args)),
                tx.$queryRaw<FollowerRow[]>(legacyFollowerRowsSql(...args)),
              ]);
              expect({ seed, args, rows: fresh }).toEqual({ seed, args, rows: legacy });
              if (scholarshipId === sid) expect(fresh.length).toBeGreaterThan(0);
              compared += fresh.length;
            }
          }
        }
      }
      expect(compared).toBeGreaterThan(1_000);
    });
  });

  // ── Échelle sans statistiques ──────────────────────────────────────────────

  async function bulkFollowers(
    tx: Prisma.TransactionClient,
    prefix: string,
    sid: string,
    from: number,
    to: number,
  ): Promise<void> {
    await tx.$executeRaw`
      INSERT INTO "UserProfile" (
        "id", "accountType", "preferredLanguage", "fullName", "email", "phone",
        "countryOfResidence", "updatedAt"
      )
      SELECT ${prefix} || g, 'student', 'fr', 'Élève ' || g,
             ${prefix} || g || '@example.test', '', 'Sénégal', now()
      FROM generate_series(${from}::int, ${to}::int) AS g
    `;
    await tx.$executeRaw`
      INSERT INTO "SavedItem" ("id", "userId", "itemType", "itemId", "createdAt")
      SELECT gen_random_uuid()::text, ${prefix} || g, 'scholarship', ${sid}, now()
      FROM generate_series(${from}::int, ${to}::int) AS g
    `;
    // Un tiers a aussi l'alerte « M'avertir », un sur dix-sept l'a en sourdine.
    await tx.$executeRaw`
      INSERT INTO "ScholarshipAlertSubscription" ("id", "userId", "scholarshipId", "mutedAt", "updatedAt")
      SELECT gen_random_uuid()::text, ${prefix} || g, ${sid},
             CASE WHEN g % 17 = 0 THEN now() END, now()
      FROM generate_series(${from}::int, ${to}::int) AS g
      WHERE g % 3 = 0
    `;
    // Un sur sept a déjà reçu l'annonce d'un autre cycle de la bourse.
    await tx.$executeRaw`
      INSERT INTO "UserNotification" (
        "id", "userId", "scholarshipId", "cycleId", "kind", "dedupeKey",
        "titleFr", "titleEn", "bodyFr", "bodyEn", "route", "createdAt"
      )
      SELECT gen_random_uuid()::text, ${prefix} || g, ${sid}, ${`${prefix}old`},
             ${SCHOLARSHIP_OPENED_KIND}, ${`scholarship-opened:${prefix}old:`} || ${prefix} || g,
             't', 't', 'b', 'b', '/x', now()
      FROM generate_series(${from}::int, ${to}::int) AS g
      WHERE g % 7 = 0
    `;
  }

  async function timed<T>(work: () => Promise<T>): Promise<[T, number]> {
    const started = Date.now();
    const result = await work();
    return [result, Date.now() - started];
  }

  it.each(['followers', 'alerts'] as const)(
    'portée %s : 5 000 puis 20 000 abonnés jamais analysés, sous 2 s',
    async (scope: OpeningAudienceScope) => {
      const sfx = randomUUID().slice(0, 8);
      const sid = `fq-scale-sch-${sfx}`;
      const prefix = `fq-scale-${sfx}-`;
      const cycleId = `${prefix}cycle`;
      const timings: string[] = [];

      await rolledBack(async (tx) => {
        await tx.scholarship.create({ data: scholarship(sid) });
        const expected = (n: number) => {
          // Candidats : tous (abonnés) ou les porteurs d'alerte ; exclus : la
          // sourdine (g % 51, alerte ET sourdine) puis les prévenus récents.
          let audience = 0;
          let toNotify = 0;
          for (let g = 1; g <= n; g += 1) {
            const alert = g % 3 === 0;
            const muted = alert && g % 17 === 0;
            if (scope === 'alerts' && !alert) continue;
            if (!muted) audience += 1;
            if (!muted && g % 7 !== 0) toNotify += 1;
          }
          return { audience, toNotify };
        };

        for (const [from, to] of [
          [1, 5_000],
          [5_001, 20_000],
        ] as const) {
          await bulkFollowers(tx, prefix, sid, from, to);
          const args = [sid, scope, cycleId, renotifySince, null] as const;
          for (const plan of ['naturel', 'boucles imbriquées'] as const) {
            const nestedOnly = plan === 'boucles imbriquées' ? 'off' : 'on';
            await tx.$executeRawUnsafe(`SET LOCAL enable_hashjoin = ${nestedOnly}`);
            await tx.$executeRawUnsafe(`SET LOCAL enable_mergejoin = ${nestedOnly}`);
            const [[counts], countMs] = await timed(() =>
              tx.$queryRaw<FollowerAudienceCounts[]>(followerAudienceCountsSql(...args)),
            );
            const [rows, rowsMs] = await timed(() =>
              tx.$queryRaw<FollowerRow[]>(followerRowsSql(...args)),
            );
            timings.push(`${to} abonnés, plan ${plan} : comptes ${countMs} ms, lignes ${rowsMs} ms`);
            expect(counts).toMatchObject(expected(to));
            expect(rows.filter((row) => row.toNotify)).toHaveLength(expected(to).toNotify);
            // Borne large pour une machine de CI (mesuré : ~0,1 à 0,3 s à
            // 20 000) ; l'ancien texte : ~25 s à 20 000.
            expect(countMs).toBeLessThan(2_000);
            expect(rowsMs).toBeLessThan(2_000);
          }
        }
      });
      console.log(`Requête de suivi (${scope}, sans ANALYZE) — ${timings.join(' ; ')}.`);
    },
  );
});
