import type { Scholarship, ScholarshipCycle } from '@prisma/client';

import {
  PUBLIC_SCHOLARSHIP_BASE_MATCH_CEILING,
  mapScholarship,
} from './catalog.mapper';

// `baseMatch` tel que `/catalog/scholarships` le sert aux applications. Les
// builds installées en tirent un palier (« Très bon match » dès 70) ou un
// badge « 78 % », y compris quand l'étudiant n'a rempli aucun profil.

const scholarship = (baseMatch: number) =>
  ({
    id: 'mastercard-test',
    nameFr: 'Bourse test',
    nameEn: 'Test scholarship',
    countryId: 'can',
    relatedFieldIds: ['computer_science'],
    keyRequirementsFr: [],
    keyRequirementsEn: [],
    eligibilityFr: [],
    eligibilityEn: [],
    baseMatch,
    deadlineAt: null,
  }) as unknown as Scholarship & { cycles?: ScholarshipCycle[] };

/// Reproduction du calcul des builds installées, qui ne changera pas avant
/// leur prochaine version : `_matchScholarship` (lib/app/core/services/
/// app_search_service.dart) et les seuils de `ProfileFit.fromScore`
/// (lib/app/core/models/profile_fit.dart).
type InstalledProfile = {
  countryMatches: boolean;
  fieldMatches: boolean;
  gradeBonus: 0 | 10 | 25;
  wantsScholarshipSupport: boolean;
};

function installedScore(baseMatch: number, profile: InstalledProfile | null) {
  if (profile === null) return baseMatch;
  let score = baseMatch;
  if (profile.countryMatches) score += 20;
  if (profile.fieldMatches) score += 15;
  score += profile.gradeBonus;
  if (profile.wantsScholarshipSupport) score += 10;
  return Math.min(score, 98);
}

function installedTier(score: number): 'strong' | 'good' | 'explore' {
  if (score >= 70) return 'strong';
  if (score >= 50) return 'good';
  return 'explore';
}

describe('mapScholarship — baseMatch servi aux applications', () => {
  it.each([70, 76, 78, 79, 80, 100])(
    'ramène une fiche publiée à %s sous les paliers « bon » et « très bon »',
    (stored) => {
      const served = mapScholarship(scholarship(stored)).baseMatch;

      expect(served).toBe(PUBLIC_SCHOLARSHIP_BASE_MATCH_CEILING);
      expect(served).toBeLessThan(50);
    },
  );

  it('ne relève jamais une valeur plus basse saisie en admin', () => {
    expect(mapScholarship(scholarship(30)).baseMatch).toBe(30);
    expect(mapScholarship(scholarship(0)).baseMatch).toBe(0);
  });

  it('ne sert jamais une valeur négative', () => {
    expect(mapScholarship(scholarship(-5)).baseMatch).toBe(0);
  });

  it('garde le champ présent et entier (lu en `int` par l’app)', () => {
    const dto = mapScholarship(scholarship(78));

    expect(dto).toHaveProperty('baseMatch');
    expect(Number.isInteger(dto.baseMatch)).toBe(true);
  });

  it('ne change aucune autre clé de la réponse', () => {
    expect(Object.keys(mapScholarship(scholarship(78))).sort()).toEqual(
      [
        'baseMatch',
        'countryId',
        'cycleStatus',
        'dateConfidence',
        'deadlineAt',
        'deadlineLabel',
        'eligibility',
        'id',
        'keyRequirements',
        'lastVerifiedAt',
        'levelEligible',
        'name',
        'relatedFieldIds',
        'sourceUrl',
        'typeOfFunding',
        'verifiedById',
        'verifiedByName',
      ].sort(),
    );
  });

  describe('ce que les builds installées en affichent', () => {
    const served = mapScholarship(scholarship(78)).baseMatch;

    it('sans profil : plus de « Très bon match » ni de « Bon match »', () => {
      expect(installedTier(installedScore(78, null))).toBe('strong');
      expect(installedTier(installedScore(served, null))).toBe('explore');
    });

    it('avec un profil : le palier dépend enfin de ce que l’étudiant a déclaré', () => {
      const nothingInCommon: InstalledProfile = {
        countryMatches: false,
        fieldMatches: false,
        gradeBonus: 0,
        wantsScholarshipSupport: false,
      };
      const countryAndField: InstalledProfile = {
        ...nothingInCommon,
        countryMatches: true,
        fieldMatches: true,
      };

      // Avant : « très bon » pour tout le monde.
      expect(installedTier(installedScore(78, nothingInCommon))).toBe('strong');
      // Après : rien en commun n'est plus « très bon »…
      expect(installedTier(installedScore(served, nothingInCommon))).toBe(
        'explore',
      );
      // … et un pays et un domaine visés le restent.
      expect(installedTier(installedScore(served, countryAndField))).toBe(
        'strong',
      );
    });
  });
});
