import type { EligibilityCriterion } from '../../scholarship-match/eligibility-criteria';

/**
 * Niveaux d'études du catalogue vérifié. `doctorate` est entré avec la
 * version 1.5.0 : Gates Cambridge finance « un doctorat, un MLitt ou une
 * formation d'un an » — la limite au master excluait à tort un doctorant.
 * Même vocabulaire que l'enum Prisma `ScholarshipEligibleLevel`.
 */
export const SCHOLARSHIP_STUDY_LEVELS = [
  'secondary',
  'bachelor',
  'master',
  'doctorate',
] as const;

export type ScholarshipStudyLevel =
  (typeof SCHOLARSHIP_STUDY_LEVELS)[number];

export const REQUIRED_OFFICIAL_SOURCE_KINDS = [
  'overview',
  'eligibility',
  'benefits',
  'application',
  'cycle',
] as const;

export type ScholarshipOfficialSourceKind =
  (typeof REQUIRED_OFFICIAL_SOURCE_KINDS)[number];

export type ScholarshipFundingType =
  | 'fully_funded'
  | 'partially_funded'
  | 'unknown';

export type ScholarshipApplicationRequirement =
  | 'automatic'
  | 'separate_application';

export type ScholarshipCycleStatus =
  | 'forecast'
  | 'open'
  | 'closed'
  | 'suspended';

export type ScholarshipDateConfidence = 'estimated' | 'confirmed';

export interface ScholarshipOfficialSource {
  kind: ScholarshipOfficialSourceKind;
  url: string;
  isOfficial: true;
  checkedAt: string;
  label: string;
}

export interface ScholarshipCatalogApplicationStep {
  stepNumber: number;
  titleFr: string;
  titleEn: string;
  descriptionFr: string;
  descriptionEn: string;
  estimatedDurationDays?: number;
}

export interface ScholarshipCatalogCycle {
  academicYear: string;
  status: ScholarshipCycleStatus;
  dateConfidence: ScholarshipDateConfidence;
  estimatedOpenAt?: string;
  estimatedCloseAt?: string;
  opensAt?: string;
  closesAt?: string;
  sourceUrl: string;
}

/**
 * Exact write shape supported by the current legacy Prisma Scholarship model.
 * Relations that already exist in the schema (steps and one annual cycle) are
 * kept beside the row and are created in the same transaction by the importer.
 */
export interface LegacyScholarshipCatalogPayload {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  countryNameFr: string;
  countryNameEn: string;
  levelEligibleFr: string;
  levelEligibleEn: string;
  typeOfFundingFr: string;
  typeOfFundingEn: string;
  fundingType: ScholarshipFundingType;
  applicationRequirement: ScholarshipApplicationRequirement;
  deadlineLabelFr: string;
  deadlineLabelEn: string;
  descriptionFr: string;
  descriptionEn: string;
  advantagesFr: string[];
  advantagesEn: string[];
  eligibilityFr: string[];
  eligibilityEn: string[];
  keyRequirementsFr: string[];
  keyRequirementsEn: string[];
  relatedFieldIds: string[];
  baseMatch: number;
  applicationUrl: string;
  sourceUrl: string;
  tags: string[];
}

/** Même vocabulaire que l'enum Prisma `ScholarshipFieldsScope`. */
export const SCHOLARSHIP_FIELDS_SCOPES = ['unknown', 'all', 'listed'] as const;
export type ScholarshipFieldsScope = (typeof SCHOLARSHIP_FIELDS_SCOPES)[number];

/**
 * Valeur de `structuredBy` d'un brouillon : critères RÉDIGÉS depuis le texte
 * de la fiche, que personne n'a encore relus contre la source officielle.
 */
export const DRAFT_STRUCTURED_BY = 'draft';

/**
 * L'éligibilité structurée d'une fiche (chantier D, catalogue 1.5.0).
 *
 * `structuredAt` est propre à la fiche et distinct de `verifiedAt` : le second
 * certifie que les pages officielles ont été relues, le premier qu'un éditeur
 * a confronté CES critères à ces pages. Tant qu'il est nul (brouillon), le
 * moteur n'exclut personne sur cette fiche (règle des 400 jours,
 * `scholarship-match/assess.ts`) : tout écart devient « à vérifier ».
 */
export interface ScholarshipCatalogEligibility {
  fieldsScope: ScholarshipFieldsScope;
  criteria: EligibilityCriterion[];
  /** ISO 8601 de la relecture humaine, ou `null` pour un brouillon. */
  structuredAt: string | null;
  /** Nom de l'éditeur, ou {@link DRAFT_STRUCTURED_BY} pour un brouillon. */
  structuredBy: string;
}

export interface VerifiedScholarshipCatalogRecord {
  catalogId: string;
  levels: ScholarshipStudyLevel[];
  scholarship: LegacyScholarshipCatalogPayload;
  applicationSteps: ScholarshipCatalogApplicationStep[];
  cycle: ScholarshipCatalogCycle;
  officialSources: ScholarshipOfficialSource[];
  verifiedAt: string;
  verifiedBy: string;
  /** Facultatif : une fiche sans bloc est « non structurée » (avertissement). */
  eligibility?: ScholarshipCatalogEligibility;
}

export type ScholarshipBacklogReason =
  | 'legacy_record_requires_official_verification'
  | 'legacy_record_incomplete';

export interface ScholarshipCatalogBacklogItem {
  legacyId: string;
  intendedLevels: ScholarshipStudyLevel[];
  reasons: ScholarshipBacklogReason[];
}

export interface ScholarshipCatalogVolumeTargets {
  uniqueRecords: number;
  secondary: number;
  bachelor: number;
  master: number;
  /** Facultatif (plancher 0) : une seule fiche doctorale à ce jour. */
  doctorate?: number;
}

export interface VersionedScholarshipCatalog {
  schemaVersion: 1;
  catalogVersion: string;
  volumeTargets: ScholarshipCatalogVolumeTargets;
  records: VerifiedScholarshipCatalogRecord[];
  backlog: ScholarshipCatalogBacklogItem[];
}
