import { SCHOLARSHIP_OPENING_MODE_ENV } from './opening/scholarship-opening.contract';
import {
  alertFacts,
  followFlags,
  hasFollowedScholarshipOptOut,
  isFollowUnified,
} from './scholarship-follow-state';

/**
 * La définition de « suivre » côté API étudiant doit être celle du SQL
 * partagé (`scholarship-follow.query.ts`) : favori OU alerte non en sourdine ;
 * prévenu = suivi ET pas de sourdine.
 */
describe('followFlags', () => {
  it.each([
    // favori, alerte active, alerte en sourdine → suivi, via favori, via alerte, annonce
    [false, false, false, [false, false, false, false]],
    [true, false, false, [true, true, false, true]],
    [false, true, false, [true, false, true, true]],
    [true, true, false, [true, true, true, true]],
    // La sourdine prime sur le favori, mais la bourse reste suivie.
    [true, false, true, [true, true, false, false]],
    // Une sourdine seule ne suit rien.
    [false, false, true, [false, false, false, false]],
  ] as const)(
    'favori=%s alerte=%s sourdine=%s',
    (favorite, activeAlert, mutedAlert, [following, viaFavorite, viaAlert, notifyOpening]) => {
      expect(followFlags({ favorite, activeAlert, mutedAlert })).toEqual({
        following,
        viaFavorite,
        viaAlert,
        notifyOpening,
      });
    },
  );
});

describe('alertFacts', () => {
  it('lit une ligne absente, active ou en sourdine', () => {
    expect(alertFacts(null)).toEqual({ activeAlert: false, mutedAlert: false });
    expect(alertFacts({ mutedAt: null })).toEqual({ activeAlert: true, mutedAlert: false });
    expect(alertFacts({ mutedAt: new Date() })).toEqual({
      activeAlert: false,
      mutedAlert: true,
    });
  });
});

describe('hasFollowedScholarshipOptOut', () => {
  it('reconnaît la clé globale, et elle seule', () => {
    expect(hasFollowedScholarshipOptOut(['followed_scholarship_updates'])).toBe(true);
    expect(hasFollowedScholarshipOptOut(['weekly_digest', 'daily_scholarship'])).toBe(false);
    expect(hasFollowedScholarshipOptOut([])).toBe(false);
    expect(hasFollowedScholarshipOptOut(null)).toBe(false);
    expect(hasFollowedScholarshipOptOut(undefined)).toBe(false);
  });
});

describe('isFollowUnified', () => {
  it.each([
    [undefined, false],
    ['legacy', false],
    ['outbox_alerts', false],
    ['outbox_followers', true],
    [' OUTBOX_FOLLOWERS ', true],
    ['nimporte', false],
  ])('%s → %s', (mode, expected) => {
    expect(isFollowUnified({ [SCHOLARSHIP_OPENING_MODE_ENV]: mode })).toBe(expected);
  });
});
