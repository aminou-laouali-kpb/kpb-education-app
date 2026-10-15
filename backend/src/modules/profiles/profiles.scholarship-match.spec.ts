import type { PrismaService } from '../prisma/prisma.service';
import type { StorageService } from '../storage/storage.service';
import { ProfilesService } from './profiles.service';

/**
 * `GET /profiles/me` expose les réponses de « Mes 10 bourses » EN LECTURE
 * (chantier D) : l'écran profil les affiche. Elles ne s'écrivent que par
 * `POST /scholarships/match/runs` — le PATCH du profil complet ne les connaît
 * pas, et une build plus ancienne ignore ces clés (profile_api_codec.dart lit
 * des clés explicites).
 */
describe('ProfilesService — réponses « Mes 10 bourses » en lecture', () => {
  const NOW = new Date('2026-10-15T10:00:00.000Z');
  const row = {
    id: 'user-1',
    accountType: 'student',
    preferredLanguage: 'fr',
    fullName: 'Awa',
    email: 'awa@example.org',
    phone: '+227',
    whatsApp: null,
    countryOfResidence: 'Niger',
    currentLevel: 'Terminale',
    targetLevel: 'Bachelor',
    languageLevel: 'Intermediate',
    gradeRange: '12 - 14/20',
    bacSeries: null,
    annualTuitionBudgetEur: null,
    monthlyBudgetEur: null,
    preferredCurrency: 'XOF',
    wantsScholarship: true,
    newsletterOptIn: false,
    disabledNotificationTypes: [],
    fieldIds: ['d01'],
    targetCountryIds: [],
    availableDocuments: [],
    avatarStorageKey: null,
    aiConsentedAt: null,
    birthDate: new Date('2007-03-01T00:00:00.000Z'),
    guardianName: null,
    guardianContact: null,
    guardianConsentedAt: null,
    nationalityCode: 'ner',
    secondNationalityCode: null,
    highestDiploma: 'bac',
    scholarshipTargetLevel: 'bachelor',
    gradeBandOn20: '12_14',
    englishLevel: 'b1',
    frenchLevel: null,
    languageTests: [{ type: 'ielts', score: 6.5 }, { type: 'nope', score: 1 }],
    workExperienceBand: null,
    scholarshipProfileConfirmedAt: NOW,
    scholarshipMatchAlertsOptInAt: null,
    updatedAt: NOW,
  };

  function service() {
    const prisma = {
      isEnabled: true,
      execute: async (fn: (client: unknown) => Promise<unknown>) =>
        fn({ userProfile: { findUnique: async () => row } }),
    } as unknown as PrismaService;
    return new ProfilesService(prisma, {} as StorageService);
  }

  it('sert les nouvelles clés, `languageTests` relu par la garde', async () => {
    const profile = (await service().getMe('user-1')) as Record<string, unknown>;

    expect(profile).toMatchObject({
      nationalityCode: 'ner',
      secondNationalityCode: null,
      highestDiploma: 'bac',
      scholarshipTargetLevel: 'bachelor',
      gradeBandOn20: '12_14',
      englishLevel: 'b1',
      frenchLevel: null,
      languageTests: [{ type: 'ielts', score: 6.5 }],
      workExperienceBand: null,
      scholarshipProfileConfirmedAt: NOW.toISOString(),
      scholarshipMatchAlertsOptIn: false,
    });
    // L'ancien `targetLevel` reste ce qu'il était : jamais un nouveau jeton.
    expect(profile.targetLevel).toBe('Bachelor');
  });
});
