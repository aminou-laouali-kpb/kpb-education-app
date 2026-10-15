import type { Prisma } from '@prisma/client';

import type { VerifiedScholarshipCatalogRecord } from './scholarship-catalog.types';

/**
 * Traduit une fiche du catalogue vérifié en données de création Prisma.
 *
 * Vit sous `src/` pour que la CLI compilée dans `dist/` puisse l'utiliser en
 * production : le corps de cette fonction était auparavant enfermé dans
 * `scripts/import-scholarship-catalog.ts`, hors du périmètre de compilation et
 * absent de l'image Docker.
 */
export function buildScholarshipCreateData(
  record: VerifiedScholarshipCatalogRecord,
  catalogVersion: string,
) {
  const scholarship = record.scholarship;
  // Un cycle estimé ne doit pas alimenter `deadlineAt` avec une date présentée
  // comme ferme : c'est `dateConfidence` qui tranche, et le client refuse
  // d'afficher un compte à rebours sur une date estimée.
  const deadline =
    record.cycle.dateConfidence === 'confirmed'
      ? record.cycle.closesAt
      : record.cycle.estimatedCloseAt;
  return {
    id: scholarship.id,
    nameFr: scholarship.nameFr,
    nameEn: scholarship.nameEn,
    countryId: scholarship.countryId,
    countryNameFr: scholarship.countryNameFr,
    countryNameEn: scholarship.countryNameEn,
    levelEligibleFr: scholarship.levelEligibleFr,
    levelEligibleEn: scholarship.levelEligibleEn,
    typeOfFundingFr: scholarship.typeOfFundingFr,
    typeOfFundingEn: scholarship.typeOfFundingEn,
    fundingType: scholarship.fundingType,
    applicationRequirement: scholarship.applicationRequirement,
    deadlineLabelFr: scholarship.deadlineLabelFr,
    deadlineLabelEn: scholarship.deadlineLabelEn,
    descriptionFr: scholarship.descriptionFr,
    descriptionEn: scholarship.descriptionEn,
    advantagesFr: scholarship.advantagesFr,
    advantagesEn: scholarship.advantagesEn,
    eligibilityFr: scholarship.eligibilityFr,
    eligibilityEn: scholarship.eligibilityEn,
    keyRequirementsFr: scholarship.keyRequirementsFr,
    keyRequirementsEn: scholarship.keyRequirementsEn,
    relatedFieldIds: scholarship.relatedFieldIds,
    baseMatch: scholarship.baseMatch,
    applicationUrl: scholarship.applicationUrl,
    sourceUrl: scholarship.sourceUrl,
    deadlineAt: deadline ? new Date(deadline) : null,
    lastVerifiedAt: new Date(record.verifiedAt),
    verifiedById: 'catalog-import',
    verifiedByName: record.verifiedBy,
    // L'import ne publie jamais : la publication est une décision distincte,
    // prise par `publish` ou par un relecteur dans l'admin.
    isActive: false,
    moderationStatus: 'pending' as const,
    tags: [...new Set([...scholarship.tags, `catalog:${catalogVersion}`])],
    // Éligibilité structurée (chantier D). `eligibleLevels` reprend `levels`
    // tel quel : c'est la donnée que relit un éditeur. Le tampon est celui de
    // la relecture des CRITÈRES (`eligibility.structuredAt`), jamais
    // `verifiedAt` : un brouillon arrive donc non tamponné, et le moteur
    // n'exclut personne dessus. Sans bloc, la fiche reste « non structurée ».
    eligibleLevels: [...record.levels],
    fieldsScope: record.eligibility?.fieldsScope ?? ('unknown' as const),
    eligibilityCriteria: (record.eligibility?.criteria ??
      []) as unknown as Prisma.InputJsonValue,
    eligibilityStructuredAt: record.eligibility?.structuredAt
      ? new Date(record.eligibility.structuredAt)
      : null,
    eligibilityStructuredBy: record.eligibility?.structuredBy ?? null,
    applicationSteps: {
      create: record.applicationSteps.map((step) => ({
        stepNumber: step.stepNumber,
        titleFr: step.titleFr,
        titleEn: step.titleEn,
        descriptionFr: step.descriptionFr,
        descriptionEn: step.descriptionEn,
        estimatedDurationDays: step.estimatedDurationDays,
      })),
    },
    cycles: {
      create: {
        academicYear: record.cycle.academicYear,
        status: record.cycle.status,
        dateConfidence: record.cycle.dateConfidence,
        estimatedOpenAt: record.cycle.estimatedOpenAt
          ? new Date(record.cycle.estimatedOpenAt)
          : null,
        estimatedCloseAt: record.cycle.estimatedCloseAt
          ? new Date(record.cycle.estimatedCloseAt)
          : null,
        opensAt: record.cycle.opensAt ? new Date(record.cycle.opensAt) : null,
        closesAt: record.cycle.closesAt ? new Date(record.cycle.closesAt) : null,
        sourceUrl: record.cycle.sourceUrl,
        verifiedAt: new Date(record.verifiedAt),
      },
    },
  };
}
