import type {
  Country,
  Field,
  Institution,
  Program,
  Scholarship,
  ScholarshipCycle,
} from '@prisma/client';

import { commonsRasterDisplayUrl } from '../etudes-en-france/catalog/eef-catalog.admission';
import { ORIENTATION_FIELDS } from '../orientation/orientation-fields.data';

// AI-resilience metadata lives in the orientation field referential (not the
// Field table). Enrich the field DTO from it by id so the app can show the
// "métier d'avenir" framing without a schema migration.
const IA_RESILIENCE_BY_FIELD = new Map<string, string>(
  ORIENTATION_FIELDS.map((f) => [f.id, f.iaResilience]),
);

type Localized = { fr: string; en: string };

function localized(fr?: string | null, en?: string | null): Localized {
  return { fr: fr ?? '', en: en ?? fr ?? '' };
}

function localizedList(fr?: string[] | null, en?: string[] | null): Localized[] {
  const frList = fr ?? [];
  const enList = en ?? [];
  const len = Math.max(frList.length, enList.length);
  return Array.from({ length: len }, (_, i) => ({
    fr: frList[i] ?? '',
    en: enList[i] ?? '',
  }));
}

export function mapField(row: Field) {
  return {
    id: row.id,
    name: localized(row.nameFr, row.nameEn),
    description: localized(row.descriptionFr, row.descriptionEn),
    subjects: localizedList(row.subjectsFr, row.subjectsEn),
    careers: localizedList(row.careersFr, row.careersEn),
    dailyLife: localizedList(row.dailyLifeFr, row.dailyLifeEn),
    skills: localizedList(row.skillsFr, row.skillsEn),
    personalityTraits: localizedList(
      row.personalityTraitsFr,
      row.personalityTraitsEn,
    ),
    relatedCountryIds: row.relatedCountryIds,
    relatedScholarshipIds: row.relatedScholarshipIds,
    iaResilience: IA_RESILIENCE_BY_FIELD.get(row.id) ?? '',
  };
}

export function mapCountry(row: Country) {
  return {
    id: row.id,
    code: row.code,
    flagEmoji: row.flagEmoji,
    name: localized(row.nameFr, row.nameEn),
    tagline: localized(row.taglineFr, row.taglineEn),
    nextIntakeLabel: localized(row.nextIntakeLabelFr, row.nextIntakeLabelEn),
    mainLanguage: localized(row.mainLanguageFr, row.mainLanguageEn),
    whyStudy: localized(row.whyStudyFr, row.whyStudyEn),
    marketingDescription: localized(
      row.marketingDescriptionFr,
      row.marketingDescriptionEn,
    ),
    whyStudyBullets: {
      fr: row.whyStudyBulletsFr,
      en: row.whyStudyBulletsEn,
    },
    howItWorks: localized(row.howItWorksFr, row.howItWorksEn),
    costsOverview: localized(row.costsOverviewFr, row.costsOverviewEn),
    languageSection: localized(row.languageSectionFr, row.languageSectionEn),
    partnerSchools: localized(row.partnerSchoolsFr, row.partnerSchoolsEn),
    scholarshipsSection: localized(
      row.scholarshipsSectionFr,
      row.scholarshipsSectionEn,
    ),
    whatsAppPrefill: localized(row.whatsAppPrefillFr, row.whatsAppPrefillEn),
    mvpNote: localized(row.mvpNoteFr, row.mvpNoteEn),
    tuitionRange: localized(row.tuitionRangeFr, row.tuitionRangeEn),
    livingCostRange: localized(row.livingCostRangeFr, row.livingCostRangeEn),
    visaOverview: localized(row.visaOverviewFr, row.visaOverviewEn),
    admissionDifficulty: localized(
      row.admissionDifficultyFr,
      row.admissionDifficultyEn,
    ),
    popularFieldIds: row.popularFieldIds,
    displayOrder: row.displayOrder,
    isActive: row.isActive,
    nameFr: row.nameFr,
    nameEn: row.nameEn,
    taglineFr: row.taglineFr,
    taglineEn: row.taglineEn,
    nextIntakeLabelFr: row.nextIntakeLabelFr,
    nextIntakeLabelEn: row.nextIntakeLabelEn,
    whyStudyFr: row.whyStudyFr,
    whyStudyEn: row.whyStudyEn,
    tuitionRangeFr: row.tuitionRangeFr,
    tuitionRangeEn: row.tuitionRangeEn,
    livingCostRangeFr: row.livingCostRangeFr,
    livingCostRangeEn: row.livingCostRangeEn,
    visaOverviewFr: row.visaOverviewFr,
    visaOverviewEn: row.visaOverviewEn,
    admissionDifficultyFr: row.admissionDifficultyFr,
    admissionDifficultyEn: row.admissionDifficultyEn,
    lastVerifiedAt: row.lastVerifiedAt,
    sourceUrl: row.sourceUrl,
    verifiedById: row.verifiedById,
    verifiedByName: row.verifiedByName,
  };
}

export function mapInstitution(row: Institution) {
  return {
    id: row.id,
    name: localized(row.nameFr, row.nameEn),
    countryId: row.countryId,
    location: localized(row.locationFr, row.locationEn),
    overview: localized(row.overviewFr, row.overviewEn),
    studyLevels: row.studyLevels,
    tuitionLabel: localized(row.tuitionLabelFr, row.tuitionLabelEn),
    languageRequirements: localized(
      row.languageRequirementsFr,
      row.languageRequirementsEn,
    ),
    intakePeriods: row.intakePeriods,
    programIds: row.programIds,
    isPartner: row.isPartner,
    logoUrl: row.logoUrl ? commonsRasterDisplayUrl(row.logoUrl) : row.logoUrl,
    logoSourceUrl: row.logoSourceUrl,
    logoLicence: row.logoLicence,
    lastVerifiedAt: row.lastVerifiedAt,
    sourceUrl: row.sourceUrl,
    verifiedById: row.verifiedById,
    verifiedByName: row.verifiedByName,
  };
}

export function mapProgram(row: Program) {
  return {
    id: row.id,
    institutionId: row.institutionId,
    countryId: row.countryId,
    fieldId: row.fieldId,
    name: localized(row.nameFr, row.nameEn),
    level: localized(row.levelFr, row.levelEn),
    duration: localized(row.durationFr, row.durationEn),
    tuition: localized(row.tuitionFr, row.tuitionEn),
    language: localized(row.languageFr, row.languageEn),
    requirements: localizedList(row.requirementsFr, row.requirementsEn),
    // Multi-campus formations (OMNES): per-campus price/intake. Null otherwise.
    campusOfferings: row.campusOfferings ?? null,
    // Match-scoring inputs (P0-D). Nullable — missing values score as neutral
    // estimates server-side; exposed here so clients can show data provenance.
    minGpaRequired: row.minGpaRequired,
    tuitionMinEur: row.tuitionMinEur,
    applicationDeadline: row.applicationDeadline,
    teachingLanguages: row.teachingLanguages,
    // Flat keys kept for backward compatibility with older clients.
    nameFr: row.nameFr,
    nameEn: row.nameEn,
    levelFr: row.levelFr,
    levelEn: row.levelEn,
    durationFr: row.durationFr,
    durationEn: row.durationEn,
    tuitionFr: row.tuitionFr,
    tuitionEn: row.tuitionEn,
    languageFr: row.languageFr,
    languageEn: row.languageEn,
    requirementsFr: row.requirementsFr,
    requirementsEn: row.requirementsEn,
    lastVerifiedAt: row.lastVerifiedAt,
    sourceUrl: row.sourceUrl,
    verifiedById: row.verifiedById,
    verifiedByName: row.verifiedByName,
  };
}

/// Même règle de sélection que l'index public des bourses
/// (scholarships-index.service.ts, `selectCurrentCycle`) : un cycle ouvert,
/// sinon une prévision, sinon le plus récent. DUPLIQUÉE sciemment plutôt
/// qu'importée — les deux modules ne partagent aucune dépendance aujourd'hui,
/// et la règle tient en trois lignes ; si elle grossit, l'extraire.
function selectCurrentCycle(cycles: ScholarshipCycle[] | undefined) {
  if (!cycles?.length) return undefined;
  return (
    cycles.find((cycle) => cycle.status === 'open') ??
    cycles.find((cycle) => cycle.status === 'forecast') ??
    cycles[0]
  );
}

/// Plafond du `baseMatch` servi aux applications par `/catalog/scholarships`.
///
/// L'app en fait son score de bourse, et ne peut pas être corrigée avant sa
/// prochaine version : sans profil, elle affiche `baseMatch` TEL QUEL (la 2.2.0
/// en vente en badge « 78 % », la 2.3.0 en palier « Très bon match » dès 70) ;
/// avec un profil, il sert de socle auquel elle ajoute pays (+20), domaine
/// (+15), notes (+25/+10) et souhait de bourse (+10), plafonné à 98. Les fiches
/// publiées valent 70 à 80 : chaque bourse s'annonçait « très bon match » à un
/// étudiant dont l'app ne savait rien, et, profil rempli, le plafond de 98
/// était atteint si vite que le classement ne départageait presque plus rien.
///
/// 40 est la valeur que l'app renvoie elle-même, sans profil, pour les
/// filières, formations et établissements : sous les paliers « bon » (50) et
/// « très bon » (70), le champ reste présent et entier. Plafond plutôt que
/// remplacement : une valeur plus basse saisie en admin n'est jamais relevée.
/// La base n'est pas réécrite : l'admin et le tri de `/scholarships` lisent
/// toujours la valeur stockée.
export const PUBLIC_SCHOLARSHIP_BASE_MATCH_CEILING = 40;

function publicBaseMatch(stored: number): number {
  return Math.max(0, Math.min(stored, PUBLIC_SCHOLARSHIP_BASE_MATCH_CEILING));
}

export function mapScholarship(
  row: Scholarship & { cycles?: ScholarshipCycle[] },
) {
  const cycle = selectCurrentCycle(row.cycles);
  return {
    id: row.id,
    name: localized(row.nameFr, row.nameEn),
    countryId: row.countryId,
    levelEligible: localized(row.levelEligibleFr, row.levelEligibleEn),
    typeOfFunding: localized(row.typeOfFundingFr, row.typeOfFundingEn),
    deadlineLabel: localized(row.deadlineLabelFr, row.deadlineLabelEn),
    keyRequirements: localizedList(
      row.keyRequirementsFr,
      row.keyRequirementsEn,
    ),
    eligibility: localizedList(row.eligibilityFr, row.eligibilityEn),
    relatedFieldIds: row.relatedFieldIds,
    baseMatch: publicBaseMatch(row.baseMatch),
    deadlineAt: row.deadlineAt,
    // La CONFIANCE de la date, pas seulement la date. Pour 20 des 31 fiches
    // publiées, `deadlineAt` vient de `estimatedCloseAt` (import) : une
    // projection, pas un jalon. Sans ce champ, le calendrier d'échéances
    // affichait un compte à rebours au jour près sur une date que personne
    // n'a confirmée — l'onglet Bourses, lui, sait déjà se taire dans ce cas.
    // Absent de cycle ⇒ null : le client traite null comme « confirmé » pour
    // ne pas dégrader les fiches historiques sans cycle.
    dateConfidence: cycle?.dateConfidence ?? null,
    cycleStatus: cycle?.status ?? null,
    lastVerifiedAt: row.lastVerifiedAt,
    sourceUrl: row.sourceUrl,
    verifiedById: row.verifiedById,
    verifiedByName: row.verifiedByName,
  };
}
