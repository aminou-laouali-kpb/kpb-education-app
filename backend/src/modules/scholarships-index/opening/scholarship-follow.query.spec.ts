import type { Prisma } from '@prisma/client';

import {
  followedScholarshipIdsSql,
  followerAudienceCountsSql,
  followerCountsSql,
  followerRowsCte,
  followerRowsSql,
  followingPairsSql,
} from './scholarship-follow.query';

/**
 * Le TEXTE des requêtes de suivi. Leur comportement est prouvé contre un vrai
 * PostgreSQL (`scholarship-follow.query.postgres.spec.ts`) ; ici, ce qui doit
 * tenir sans base : un seul texte commun, aucun paramètre NULL, et les favoris
 * toujours joints à la bourse.
 */
const SINCE = new Date('2026-09-15T12:00:00.000Z');
const ANNOUNCED = new Date('2026-10-01T12:00:00.000Z');

function flat(sql: Prisma.Sql): string {
  return sql.text.replace(/\s+/g, ' ').trim();
}

describe('scholarship-follow.query', () => {
  const builders = [
    ['followerRowsSql', followerRowsSql],
    ['followerAudienceCountsSql', followerAudienceCountsSql],
  ] as const;

  it.each(builders)(
    '%s commence par le texte commun, à l’octet près (aperçu = activate = envoi)',
    (_name, build) => {
      for (const scope of ['alerts', 'followers'] as const) {
        for (const cycleId of ['c1', null]) {
          for (const followSince of [null, ANNOUNCED]) {
            const cte = followerRowsCte('s1', scope, cycleId, SINCE, followSince);
            const full = build('s1', scope, cycleId, SINCE, followSince);
            expect(full.text.startsWith(cte.text)).toBe(true);
            expect(full.values.slice(0, cte.values.length)).toEqual(cte.values);
          }
        }
      }
    },
  );

  it('ne passe jamais de paramètre NULL (PostgreSQL ne sait pas typer `$1 IS NULL`)', () => {
    const all = [
      followerRowsSql('s1', 'alerts', null, SINCE, null),
      followerRowsSql('s1', 'followers', 'c1', SINCE, ANNOUNCED),
      followerAudienceCountsSql('s1', 'followers', null, SINCE, null),
      followingPairsSql([]),
      followingPairsSql(['s1'], 'u1'),
      followedScholarshipIdsSql('u1'),
      followerCountsSql('alerts'),
      followerCountsSql('followers', ['s1']),
    ];
    for (const sql of all) {
      expect(sql.values).not.toContain(null);
      expect(sql.values).not.toContain(undefined);
    }
  });

  it('portée alertes : les favoris ne sont pas des candidats', () => {
    expect(flat(followerRowsCte('s1', 'alerts', 'c1', SINCE, null))).not.toContain(
      'UNION SELECT "userId" FROM follow_fav',
    );
    expect(flat(followerRowsCte('s1', 'followers', 'c1', SINCE, null))).toContain(
      'UNION SELECT "userId" FROM follow_fav',
    );
  });

  it('sans cycle : personne n’est déjà prévenu, toute annonce de la bourse est « récente »', () => {
    const text = flat(followerRowsCte('s1', 'alerts', null, SINCE, null));
    expect(text).toContain('false AS "alreadyNotified"');
    expect(text).not.toContain('IS DISTINCT FROM');

    const withCycle = followerRowsCte('s1', 'alerts', 'c1', SINCE, null);
    expect(flat(withCycle)).toContain('r."cycleId" IS DISTINCT FROM');
    // Le préfixe de la clé de déduplication, au format d'avant le chantier.
    expect(withCycle.values).toContain('scholarship-opened:c1:');
  });

  it('première annonce : personne n’est « ancien abonné » ; relance : la date est passée', () => {
    expect(flat(followerRowsCte('s1', 'followers', 'c1', SINCE, null))).toContain(
      'false AS "followedBeforeAnnouncement"',
    );
    const relaunch = followerRowsCte('s1', 'followers', 'c1', SINCE, ANNOUNCED);
    expect(relaunch.values).toContain(ANNOUNCED);
    expect(relaunch.values).toContain(SINCE);
  });

  it('lit la désinscription globale par sa clé', () => {
    expect(followerRowsCte('s1', 'followers', 'c1', SINCE, null).values).toContain(
      'followed_scholarship_updates',
    );
  });

  it('joint chaque favori à la bourse (favoris orphelins ignorés)', () => {
    for (const sql of [
      followerRowsCte('s1', 'followers', 'c1', SINCE, null),
      followingPairsSql(['s1']),
      followedScholarshipIdsSql('u1'),
      followerCountsSql('followers'),
    ]) {
      expect(flat(sql)).toContain('JOIN "Scholarship" s ON s."id" = si."itemId"');
      expect(flat(sql)).toContain('si."itemType" = \'scholarship\'');
    }
  });

  it('couples : filtre par bourses (tableau, vide compris) et, au besoin, par étudiant', () => {
    const none = followingPairsSql([]);
    expect(flat(none)).toContain('si."itemId" = ANY(');
    expect(none.values).toContainEqual([]);

    const mine = followingPairsSql(['s1', 's2'], 'u1');
    expect(mine.values).toContainEqual(['s1', 's2']);
    expect(mine.values).toContain('u1');
    expect(flat(followingPairsSql(['s1']))).not.toContain('si."userId" =');
  });

  it('comptes par bourse : l’audience suit la portée', () => {
    expect(flat(followerCountsSql('alerts'))).toContain(
      'count(*) FILTER (WHERE "viaAlert")::int AS "notifiable"',
    );
    expect(flat(followerCountsSql('followers'))).toContain(
      'count(*) FILTER (WHERE NOT "muted")::int AS "notifiable"',
    );
    expect(flat(followerCountsSql('followers'))).not.toContain('ANY(');
  });
});
