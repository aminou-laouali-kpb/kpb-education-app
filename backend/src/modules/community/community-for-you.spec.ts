import { Prisma } from '@prisma/client';

import {
  FOR_YOU_WEIGHTS,
  forYouReasons,
  forYouScore,
  forYouSql,
  type ForYouSignals,
} from './community-for-you';

const base: ForYouSignals = {
  ageHours: 10,
  followedScholarship: false,
  targetCountry: false,
  targetLevel: false,
  followedDiscussion: false,
  replyCount: 0,
  helpfulCount: 0,
  hasVerifiedAnswer: false,
};

describe('score « Pour toi » (§10)', () => {
  it('applique exactement la formule publiée', () => {
    const s = { ...base, ageHours: 22, followedScholarship: true, targetCountry: true, replyCount: 3, helpfulCount: 1, hasVerifiedAnswer: true };
    const expected = (1 + 4 + 2 + Math.log(1 + 3 + 2) + 2) / Math.pow(22 + 2, 1.2);
    expect(forYouScore(s)).toBeCloseTo(expected, 12);
  });

  it('est déterministe à horloge fixée', () => {
    const s = { ...base, ageHours: 5, targetCountry: true, replyCount: 2 };
    expect(forYouScore(s)).toBe(forYouScore({ ...s }));
  });

  it('la récence décroît le score, l’affinité le relève', () => {
    expect(forYouScore({ ...base, ageHours: 1 })).toBeGreaterThan(forYouScore({ ...base, ageHours: 30 }));
    expect(forYouScore({ ...base, followedScholarship: true })).toBeGreaterThan(forYouScore({ ...base, targetCountry: true }));
    expect(forYouScore({ ...base, targetCountry: true })).toBeGreaterThan(forYouScore({ ...base, targetLevel: true }));
    expect(forYouScore({ ...base, hasVerifiedAnswer: true })).toBeGreaterThan(forYouScore(base));
  });

  it('une bourse suivie d’hier passe devant une publication neutre de la journée', () => {
    const followedYesterday = forYouScore({ ...base, ageHours: 24, followedScholarship: true, targetCountry: true });
    const neutralSixHours = forYouScore({ ...base, ageHours: 6 });
    expect(followedYesterday).toBeGreaterThan(neutralSixHours);
  });

  it('un âge négatif (horloge décalée) est ramené à zéro', () => {
    expect(forYouScore({ ...base, ageHours: -5 })).toBe(forYouScore({ ...base, ageHours: 0 }));
  });

  it('raisons dans l’ordre du contrat, « popular » à partir de 5 interactions pondérées', () => {
    expect(
      forYouReasons({ ...base, followedScholarship: true, targetLevel: true, hasVerifiedAnswer: true, replyCount: 3, helpfulCount: 1 }),
    ).toEqual(['followed_scholarship', 'target_level', 'verified_answer', 'popular']);
    expect(forYouReasons({ ...base, replyCount: 4 })).toEqual([]);
    expect(forYouReasons({ ...base, replyCount: 5 })).toEqual(['popular']);
    expect(FOR_YOU_WEIGHTS.popularEngagement).toBeCloseTo(Math.log(6), 12);
  });
});

describe('requête SQL du fil', () => {
  const asOf = new Date('2026-10-17T12:00:00.000Z');
  const input = {
    asOf,
    windowStart: new Date('2026-08-18T12:00:00.000Z'),
    viewerMemberId: 'me',
    followedScholarshipIds: ['s1'],
    targetCountryIds: [],
    targetLevel: null,
    blockedMemberIds: [],
    type: null,
    hashtag: null,
    cursor: null,
    limit: 21,
  };

  it('porte les mêmes poids que le miroir et exclut épinglées, fenêtre et lecteur', () => {
    const sql: Prisma.Sql = forYouSql(input);
    expect(sql.sql).toContain('POWER("ageHours" +');
    expect(sql.sql).toContain('p."pinnedAt" IS NULL');
    expect(sql.sql).toContain(`p."status" = 'visible'`);
    expect(sql.values).toEqual(expect.arrayContaining([4, 2, 1, 2, 1.2, 'me', asOf]));
  });

  it('n’envoie jamais un tableau vide (`ANY(\'{}\')` serait vrai pour personne, mais lisible)', () => {
    const sql = forYouSql(input);
    expect(sql.values.filter((v) => Array.isArray(v) && v.length === 0)).toEqual([]);
  });

  it('ajoute le curseur (score, id) et les filtres seulement quand ils sont demandés', () => {
    const plain = forYouSql(input).sql;
    expect(plain).not.toContain('s."rank" <');
    const paged = forYouSql({ ...input, cursor: { rank: '0.500000000000', id: 'p9' }, type: 'question', hashtag: 'cv' });
    expect(paged.sql).toContain('s."rank" <');
    expect(paged.sql).toContain('"CommunityPostType"');
    expect(paged.sql).toContain('h."tag" =');
  });
});
