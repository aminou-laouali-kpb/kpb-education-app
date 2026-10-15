export type ModerationStatus = 'pending' | 'approved' | 'rejected';
export type ApplicationRequirement = 'automatic' | 'separate_application';
export type ScholarshipVideoStatus = 'draft' | 'published' | 'archived';

export interface ScholarshipStepEntry {
  id: string;
  stepNumber: number;
  titleFr: string;
  titleEn: string;
  descriptionFr: string;
  descriptionEn: string;
  estimatedDurationDays: number | null;
}

export interface ScholarshipVideoEntry {
  id: string;
  youtubeVideoId: string;
  titleFr?: string;
  titleEn?: string;
  descriptionFr?: string;
  descriptionEn?: string;
  thumbnailUrl?: string | null;
  durationSeconds?: number | null;
  languageCode?: string;
  status?: ScholarshipVideoStatus;
  isFeatured?: boolean;
  displayOrder?: number;
  watchUrl?: string;
  shareUrl?: string;
}

export interface ScholarshipEntry {
  id: string;
  nameFr: string;
  nameEn: string;
  countryId: string;
  countryNameFr?: string;
  countryNameEn?: string;
  levelEligibleFr?: string;
  levelEligibleEn?: string;
  typeOfFundingFr?: string;
  typeOfFundingEn?: string;
  descriptionFr?: string;
  descriptionEn?: string;
  advantagesFr?: string[];
  advantagesEn?: string[];
  eligibilityFr?: string[];
  eligibilityEn?: string[];
  keyRequirementsFr?: string[];
  keyRequirementsEn?: string[];
  relatedFieldIds?: string[];
  baseMatch?: number;
  sourceUrl: string;
  applicationUrl: string;
  deadlineAt: string | null;
  moderationStatus: ModerationStatus;
  lastVerifiedAt: string | null;
  tags: string[];
  isActive?: boolean;
  // Éligibilité structurée (« Mes 10 bourses », chantier D4). Facultatifs :
  // un backend antérieur ne les sert pas (la fiche est alors « non analysée »).
  eligibleLevels?: string[];
  fieldsScope?: 'unknown' | 'all' | 'listed';
  eligibilityCriteria?: unknown;
  eligibilityStructuredAt?: string | null;
  eligibilityStructuredBy?: string | null;
  applicationRequirement: ApplicationRequirement;
  applicationSteps: ScholarshipStepEntry[];
  videos?: ScholarshipVideoEntry[];
  currentCycle: {
    id: string;
    academicYear: string;
    status: 'forecast' | 'open' | 'closed' | 'suspended';
    dateConfidence: 'estimated' | 'confirmed';
    estimatedOpenAt: string | null;
    estimatedCloseAt: string | null;
    opensAt: string | null;
    closesAt: string | null;
  } | null;
}
