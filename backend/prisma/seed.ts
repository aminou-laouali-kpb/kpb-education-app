import { randomBytes } from 'node:crypto';
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import {
  AccountType,
  InternalRole,
  NotificationCampaignStatus,
  NotificationChannel,
  ParcoursKind,
  Prisma,
  PrismaClient,
  PublicationStatus,
} from '@prisma/client';

import { mockAdminData } from '../src/common/data/mock-admin';
import { mockCatalog } from '../src/common/data/mock-catalog';
import { checkProductionSeed } from '../src/common/seed-safety';
import { assessLegacyScholarshipSeed } from '../src/modules/scholarships-index/data/legacy-scholarship-seed-safety';
import { PARCOURS_SEED } from '../src/modules/parcours/data/parcours.seed';
import * as bcrypt from 'bcrypt';

// Compose supplies DATABASE_URL (and NODE_ENV) to the API container, whose
// image ships no .env: an unconditional load threw ENOENT there before the
// production guard could even run.
if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

// Legacy demo operators, deactivated on every run (see the end of main).
const LEGACY_DEMO_ADMIN_EMAILS = [
  'amina@kpb.education',
  'moussa@kpb.education',
  'fatou@kpb.education',
];

/**
 * How many of the rows this seed writes already exist. Most of them are
 * upserted with a full `update`, so on a live database a re-run reverts admin
 * edits (and re-marks uOttawa as a partner): any hit means "not a first
 * install" for the production guard below.
 */
async function countExistingSeedRows(): Promise<number> {
  const ids = (rows: ReadonlyArray<{ id: string }>) => ({
    id: { in: rows.map((row) => row.id) },
  });
  const counts = await Promise.all([
    prisma.userProfile.count({ where: { id: 'demo-user' } }),
    prisma.field.count({ where: ids(mockCatalog.fields) }),
    prisma.institution.count({ where: ids(mockCatalog.institutions) }),
    prisma.program.count({ where: ids(mockCatalog.programs) }),
    prisma.scholarship.count({ where: ids(mockCatalog.scholarships) }),
    prisma.adminUser.count({
      where: {
        email: {
          in: [
            ...mockAdminData.adminUsers.map((user) => user.email),
            ...LEGACY_DEMO_ADMIN_EMAILS,
          ],
        },
      },
    }),
    prisma.serviceOffer.count({ where: ids(mockAdminData.serviceOffers) }),
    prisma.supportDestination.count({
      where: ids(mockAdminData.supportDestinations),
    }),
    prisma.article.count({
      where: { slug: { in: mockAdminData.articles.map((a) => a.slug) } },
    }),
    prisma.forumCategory.count({ where: ids(mockAdminData.forumCategories) }),
    prisma.forumTopicTag.count({ where: ids(mockAdminData.forumTags) }),
    prisma.forumModerationAction.count({
      where: ids(mockAdminData.moderationQueue),
    }),
    prisma.notificationTemplate.count({
      where: ids(mockAdminData.notificationTemplates),
    }),
    prisma.notificationCampaign.count({
      where: ids(mockAdminData.notificationCampaigns),
    }),
    prisma.notificationDelivery.count({
      where: ids(mockAdminData.notificationDeliveries),
    }),
    prisma.parcoursStory.count({
      where: { slug: { in: PARCOURS_SEED.map((story) => story.slug) } },
    }),
  ]);
  return counts.reduce((sum, count) => sum + count, 0);
}

async function main() {
  // Production guard: refused on a production database that already holds
  // any of these rows, unless KPB_ALLOW_PRODUCTION_SEED=1 (see
  // src/common/seed-safety.ts). A true first install runs as before.
  const guard = await checkProductionSeed({
    seed: 'prisma:seed',
    countExistingRows: countExistingSeedRows,
  });
  if (!guard.allowed) {
    console.error(guard.message);
    process.exitCode = 1;
    return;
  }
  if (guard.message) console.warn(guard.message);

  // Demo student profile — only for dev/demo. Gate behind SEED_DEMO so a
  // production `prisma:seed` (catalog/admin) doesn't create a fake user.
  if (process.env.SEED_DEMO === '1') {
    await prisma.userProfile.upsert({
      where: { id: 'demo-user' },
      update: {},
      create: {
        id: 'demo-user',
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName: 'Aissatou Ibrahim',
        email: 'aissatou@example.com',
        phone: '+22790000000',
        whatsApp: '+22790000000',
        countryOfResidence: 'Niger',
        currentLevel: 'High school',
        targetLevel: 'Bachelor',
        languageLevel: 'Intermediate',
        gradeRange: '12 - 14/20',
        wantsScholarship: true,
      },
    });
  }

  for (const field of mockCatalog.fields as any[]) {
    await prisma.field.upsert({
      where: { id: field.id },
      update: {
        nameFr: field.name.fr,
        nameEn: field.name.en,
        descriptionFr: field.description.fr,
        descriptionEn: field.description.en,
        subjectsFr: field.subjects?.map((s: any) => s.fr) ?? [],
        subjectsEn: field.subjects?.map((s: any) => s.en) ?? [],
        careersFr: field.careers?.map((c: any) => c.fr) ?? [],
        careersEn: field.careers?.map((c: any) => c.en) ?? [],
        dailyLifeFr: field.dailyLife?.map((d: any) => d.fr) ?? [],
        dailyLifeEn: field.dailyLife?.map((d: any) => d.en) ?? [],
        skillsFr: field.skills?.map((s: any) => s.fr) ?? [],
        skillsEn: field.skills?.map((s: any) => s.en) ?? [],
        personalityTraitsFr: field.personalityTraits?.map((p: any) => p.fr) ?? [],
        personalityTraitsEn: field.personalityTraits?.map((p: any) => p.en) ?? [],
        relatedCountryIds: field.relatedCountryIds ?? [],
        relatedScholarshipIds: field.relatedScholarshipIds ?? [],
      },
      create: {
        id: field.id,
        nameFr: field.name.fr,
        nameEn: field.name.en,
        descriptionFr: field.description.fr,
        descriptionEn: field.description.en,
        subjectsFr: field.subjects?.map((s: any) => s.fr) ?? [],
        subjectsEn: field.subjects?.map((s: any) => s.en) ?? [],
        careersFr: field.careers?.map((c: any) => c.fr) ?? [],
        careersEn: field.careers?.map((c: any) => c.en) ?? [],
        dailyLifeFr: field.dailyLife?.map((d: any) => d.fr) ?? [],
        dailyLifeEn: field.dailyLife?.map((d: any) => d.en) ?? [],
        skillsFr: field.skills?.map((s: any) => s.fr) ?? [],
        skillsEn: field.skills?.map((s: any) => s.en) ?? [],
        personalityTraitsFr: field.personalityTraits?.map((p: any) => p.fr) ?? [],
        personalityTraitsEn: field.personalityTraits?.map((p: any) => p.en) ?? [],
        relatedCountryIds: field.relatedCountryIds ?? [],
        relatedScholarshipIds: field.relatedScholarshipIds ?? [],
      },
    });
  }

  // Countries are owned by `seed:countries-m5` (run via `seed:catalog`), which
  // seeds the active ISO-coded destinations (can, fra, deu, ...) with the full
  // marketing content and the required unique `code`. We deliberately do NOT
  // upsert countries from mockCatalog here: doing so would either fail on a
  // fresh M5 schema (Country.code is required & unique) or clobber the rich M5
  // content with the sparse demo copy. The demo institutions/programs below
  // reference those ISO ids.

  for (const param of mockCatalog.institutions as any[]) {
    await prisma.institution.upsert({
      where: { id: param.id },
      update: {
        nameFr: param.name?.fr ?? '',
        nameEn: param.name?.en ?? '',
        countryId: param.countryId,
        locationFr: param.location?.fr ?? '',
        locationEn: param.location?.en ?? '',
        overviewFr: param.overview?.fr ?? '',
        overviewEn: param.overview?.en ?? '',
        studyLevels: param.levels ?? [],
        tuitionLabelFr: param.tuitionLabel?.fr ?? '',
        tuitionLabelEn: param.tuitionLabel?.en ?? '',
        languageRequirementsFr: param.languageRequirements?.fr ?? '',
        languageRequirementsEn: param.languageRequirements?.en ?? '',
        intakePeriods: param.intakePeriods ?? [],
        programIds: param.programIds ?? [],
        isPartner: param.partner ?? false,
      },
      create: {
        id: param.id,
        nameFr: param.name?.fr ?? '',
        nameEn: param.name?.en ?? '',
        countryId: param.countryId,
        locationFr: param.location?.fr ?? '',
        locationEn: param.location?.en ?? '',
        overviewFr: param.overview?.fr ?? '',
        overviewEn: param.overview?.en ?? '',
        studyLevels: param.levels ?? [],
        tuitionLabelFr: param.tuitionLabel?.fr ?? '',
        tuitionLabelEn: param.tuitionLabel?.en ?? '',
        languageRequirementsFr: param.languageRequirements?.fr ?? '',
        languageRequirementsEn: param.languageRequirements?.en ?? '',
        intakePeriods: param.intakePeriods ?? [],
        programIds: param.programIds ?? [],
        isPartner: param.partner ?? false,
      },
    });
  }

  for (const program of mockCatalog.programs as any[]) {
    await prisma.program.upsert({
      where: { id: program.id },
      update: {
        institutionId: program.institutionId,
        countryId: program.countryId,
        fieldId: program.fieldId,
        nameFr: program.name?.fr ?? '',
        nameEn: program.name?.en ?? '',
        levelFr: program.level?.fr ?? '',
        levelEn: program.level?.en ?? '',
        durationFr: program.duration?.fr ?? '',
        durationEn: program.duration?.en ?? '',
        tuitionFr: program.tuition?.fr ?? '',
        tuitionEn: program.tuition?.en ?? '',
        languageFr: program.language?.fr ?? '',
        languageEn: program.language?.en ?? '',
        requirementsFr: program.requirements?.map((r: any) => r.fr) ?? [],
        requirementsEn: program.requirements?.map((r: any) => r.en) ?? [],
      },
      create: {
        id: program.id,
        institutionId: program.institutionId,
        countryId: program.countryId,
        fieldId: program.fieldId,
        nameFr: program.name?.fr ?? '',
        nameEn: program.name?.en ?? '',
        levelFr: program.level?.fr ?? '',
        levelEn: program.level?.en ?? '',
        durationFr: program.duration?.fr ?? '',
        durationEn: program.duration?.en ?? '',
        tuitionFr: program.tuition?.fr ?? '',
        tuitionEn: program.tuition?.en ?? '',
        languageFr: program.language?.fr ?? '',
        languageEn: program.language?.en ?? '',
        requirementsFr: program.requirements?.map((r: any) => r.fr) ?? [],
        requirementsEn: program.requirements?.map((r: any) => r.en) ?? [],
      },
    });
  }

  // Legacy scholarships are demo/research inputs, not verified production
  // facts. Create missing rows only: `skipDuplicates` guarantees that a later
  // seed can never overwrite copy, moderation or dates edited in the admin.
  // Every newly-created legacy row stays inactive + pending until a human has
  // verified official sources and explicitly publishes it.
  const incompleteLegacyScholarships: Array<{
    id: string;
    missing: string[];
  }> = [];
  const legacyScholarshipRows: Prisma.ScholarshipCreateManyInput[] = (
    mockCatalog.scholarships as any[]
  ).map((scholarship) => {
    const assessment = assessLegacyScholarshipSeed(scholarship);
    if (!assessment.complete) {
      incompleteLegacyScholarships.push({
        id: scholarship.id,
        missing: assessment.missing,
      });
    }
    const rawDeadline = scholarship.deadlineAt
      ? new Date(scholarship.deadlineAt)
      : null;
    const deadlineAt =
      rawDeadline && !Number.isNaN(rawDeadline.getTime()) ? rawDeadline : null;
    const fundingType =
      scholarship.fundingType === 'fully_funded' ||
      scholarship.fundingType === 'partially_funded'
        ? scholarship.fundingType
        : 'unknown';
    return {
      id: scholarship.id,
      nameFr: scholarship.name?.fr ?? '',
      nameEn: scholarship.name?.en ?? '',
      countryId: scholarship.countryId,
      countryNameFr: scholarship.countryName?.fr ?? '',
      countryNameEn: scholarship.countryName?.en ?? '',
      levelEligibleFr: scholarship.levelEligible?.fr ?? '',
      levelEligibleEn: scholarship.levelEligible?.en ?? '',
      typeOfFundingFr: scholarship.typeOfFunding?.fr ?? '',
      typeOfFundingEn: scholarship.typeOfFunding?.en ?? '',
      fundingType,
      applicationRequirement:
        scholarship.applicationRequirement === 'automatic'
          ? 'automatic'
          : 'separate_application',
      deadlineLabelFr: scholarship.deadlineLabel?.fr ?? '',
      deadlineLabelEn: scholarship.deadlineLabel?.en ?? '',
      descriptionFr: scholarship.description?.fr ?? '',
      descriptionEn: scholarship.description?.en ?? '',
      advantagesFr: scholarship.advantages?.map((a: any) => a.fr) ?? [],
      advantagesEn: scholarship.advantages?.map((a: any) => a.en) ?? [],
      eligibilityFr: scholarship.eligibility?.map((e: any) => e.fr) ?? [],
      eligibilityEn: scholarship.eligibility?.map((e: any) => e.en) ?? [],
      keyRequirementsFr:
        scholarship.keyRequirements?.map((k: any) => k.fr) ?? [],
      keyRequirementsEn:
        scholarship.keyRequirements?.map((k: any) => k.en) ?? [],
      relatedFieldIds: scholarship.relatedFieldIds ?? [],
      baseMatch: scholarship.baseMatch ?? 30,
      applicationUrl: scholarship.applicationUrl ?? null,
      sourceUrl: scholarship.sourceUrl ?? null,
      deadlineAt,
      tags: [
        ...new Set([
          ...(scholarship.tags ?? []),
          'legacy-seed',
          'needs-official-verification',
        ]),
      ],
      isActive: false,
      moderationStatus: 'pending',
    };
  });
  const scholarshipSeedResult = await prisma.scholarship.createMany({
    data: legacyScholarshipRows,
    skipDuplicates: true,
  });
  console.log(
    `Legacy scholarships: ${scholarshipSeedResult.count} created, ` +
      `${legacyScholarshipRows.length - scholarshipSeedResult.count} existing rows left untouched.`,
  );
  if (incompleteLegacyScholarships.length > 0) {
    console.warn(
      'Incomplete legacy scholarships remain inactive/pending:',
      JSON.stringify(incompleteLegacyScholarships),
    );
  }

  // Seed internal operators. New accounts get a per-user random temporary
  // password (bcrypt-hashed; plaintext printed once below). Re-seeding an
  // existing account refreshes its profile but NEVER overwrites a set password.
  const seededAdminCredentials: { email: string; tempPassword: string }[] = [];
  for (const user of mockAdminData.adminUsers) {
    const existing = await prisma.adminUser.findUnique({
      where: { email: user.email },
      select: { id: true },
    });
    if (existing) {
      await prisma.adminUser.update({
        where: { email: user.email },
        data: {
          fullName: user.fullName,
          role: user.role as InternalRole,
          isActive: user.isActive,
          languageScope: user.languageScope,
          workload: user.workload,
        },
      });
    } else {
      const tempPassword = randomBytes(9).toString('base64url');
      const passwordHash = await bcrypt.hash(tempPassword, 12);
      await prisma.adminUser.create({
        data: {
          id: user.id,
          fullName: user.fullName,
          email: user.email,
          role: user.role as InternalRole,
          isActive: user.isActive,
          languageScope: user.languageScope,
          workload: user.workload,
          passwordHash,
        },
      });
      seededAdminCredentials.push({ email: user.email, tempPassword });
    }
  }

  // Retire the legacy demo accounts so they can no longer log in (deactivate
  // rather than delete — they may be referenced by historical case assignments).
  await prisma.adminUser.updateMany({
    where: { email: { in: LEGACY_DEMO_ADMIN_EMAILS } },
    data: { isActive: false },
  });

  if (seededAdminCredentials.length > 0) {
    console.log(
      '\n=== Admin temporary passwords (store securely, share privately) ===',
    );
    for (const cred of seededAdminCredentials) {
      console.log(`  ${cred.email}: ${cred.tempPassword}`);
    }
    console.log(
      'Each admin can re-issue one later from Users → Reset temp password.\n',
    );
  }

  for (const offer of mockAdminData.serviceOffers) {
    await prisma.serviceOffer.upsert({
      where: { id: offer.id },
      update: {
        nameFr: offer.name.fr,
        nameEn: offer.name.en,
        offerType: offer.offerType,
        destinationIds: offer.destinationIds,
        studyLevels: offer.studyLevels,
        priceLabelFr: offer.priceLabel.fr,
        priceLabelEn: offer.priceLabel.en,
        benefitsFr: offer.benefits.fr,
        benefitsEn: offer.benefits.en,
        ctaLabelFr: offer.ctaLabel.fr,
        ctaLabelEn: offer.ctaLabel.en,
        status: offer.status as PublicationStatus,
      },
      create: {
        id: offer.id,
        nameFr: offer.name.fr,
        nameEn: offer.name.en,
        offerType: offer.offerType,
        destinationIds: offer.destinationIds,
        studyLevels: offer.studyLevels,
        priceLabelFr: offer.priceLabel.fr,
        priceLabelEn: offer.priceLabel.en,
        benefitsFr: offer.benefits.fr,
        benefitsEn: offer.benefits.en,
        ctaLabelFr: offer.ctaLabel.fr,
        ctaLabelEn: offer.ctaLabel.en,
        status: offer.status as PublicationStatus,
      },
    });
  }

  for (const destination of mockAdminData.supportDestinations) {
    await prisma.supportDestination.upsert({
      where: { id: destination.id },
      update: {
        countryId: destination.countryId,
        countryNameFr: destination.countryName.fr,
        countryNameEn: destination.countryName.en,
        supportLanguages: destination.supportLanguages,
        availableServiceTypes: destination.availableServiceTypes,
        conditionsFr: destination.conditions.fr,
        conditionsEn: destination.conditions.en,
        counselorNames: destination.counselorNames,
        isVisible: destination.isVisible,
        status: destination.status as PublicationStatus,
      },
      create: {
        id: destination.id,
        countryId: destination.countryId,
        countryNameFr: destination.countryName.fr,
        countryNameEn: destination.countryName.en,
        supportLanguages: destination.supportLanguages,
        availableServiceTypes: destination.availableServiceTypes,
        conditionsFr: destination.conditions.fr,
        conditionsEn: destination.conditions.en,
        counselorNames: destination.counselorNames,
        isVisible: destination.isVisible,
        status: destination.status as PublicationStatus,
      },
    });
  }

  for (const article of mockAdminData.articles) {
    await prisma.article.upsert({
      where: { slug: article.slug },
      update: {
        category: article.category,
        titleFr: article.title.fr,
        titleEn: article.title.en,
        summaryFr: article.summary.fr,
        summaryEn: article.summary.en,
        contentFr: article.content.fr,
        contentEn: article.content.en,
        tags: article.tags,
        authorName: article.authorName,
        status: article.status as PublicationStatus,
        publishedAt: article.publishedAt ? new Date(article.publishedAt) : null,
      },
      create: {
        id: article.id,
        slug: article.slug,
        category: article.category,
        titleFr: article.title.fr,
        titleEn: article.title.en,
        summaryFr: article.summary.fr,
        summaryEn: article.summary.en,
        contentFr: article.content.fr,
        contentEn: article.content.en,
        tags: article.tags,
        authorName: article.authorName,
        status: article.status as PublicationStatus,
        publishedAt: article.publishedAt ? new Date(article.publishedAt) : null,
      },
    });
  }

  for (const category of mockAdminData.forumCategories) {
    await prisma.forumCategory.upsert({
      where: { id: category.id },
      update: {
        labelFr: category.label.fr,
        labelEn: category.label.en,
        descriptionFr: category.description.fr,
        descriptionEn: category.description.en,
        displayOrder: category.displayOrder,
        status: category.status as PublicationStatus,
      },
      create: {
        id: category.id,
        labelFr: category.label.fr,
        labelEn: category.label.en,
        descriptionFr: category.description.fr,
        descriptionEn: category.description.en,
        displayOrder: category.displayOrder,
        status: category.status as PublicationStatus,
      },
    });
  }

  for (const tag of mockAdminData.forumTags) {
    await prisma.forumTopicTag.upsert({
      where: { id: tag.id },
      update: {
        labelFr: tag.label.fr,
        labelEn: tag.label.en,
        descriptionFr: tag.description.fr,
        descriptionEn: tag.description.en,
        displayOrder: tag.displayOrder,
        status: tag.status as PublicationStatus,
      },
      create: {
        id: tag.id,
        labelFr: tag.label.fr,
        labelEn: tag.label.en,
        descriptionFr: tag.description.fr,
        descriptionEn: tag.description.en,
        displayOrder: tag.displayOrder,
        status: tag.status as PublicationStatus,
      },
    });
  }

  for (const action of mockAdminData.moderationQueue) {
    const moderatorName = 'KPB moderation desk';
    const moderatorRole = InternalRole.moderator;

    await prisma.forumModerationAction.upsert({
      where: { id: action.id },
      update: {
        targetType: action.targetType,
        targetId: action.targetId,
        reason: action.reason,
        action: action.action,
        moderatorName,
        moderatorRole,
      },
      create: {
        id: action.id,
        targetType: action.targetType,
        targetId: action.targetId,
        reason: action.reason,
        action: action.action,
        moderatorName,
        moderatorRole,
      },
    });
  }

  for (const template of mockAdminData.notificationTemplates) {
    await prisma.notificationTemplate.upsert({
      where: { id: template.id },
      update: {
        name: template.name,
        titleFr: template.title.fr,
        titleEn: template.title.en,
        bodyFr: template.body.fr,
        bodyEn: template.body.en,
        channels: template.channels as NotificationChannel[],
        isCritical: template.isCritical,
      },
      create: {
        id: template.id,
        name: template.name,
        titleFr: template.title.fr,
        titleEn: template.title.en,
        bodyFr: template.body.fr,
        bodyEn: template.body.en,
        channels: template.channels as NotificationChannel[],
        isCritical: template.isCritical,
      },
    });
  }

  for (const campaign of mockAdminData.notificationCampaigns) {
    await prisma.notificationCampaign.upsert({
      where: { id: campaign.id },
      update: {
        templateId: campaign.templateId,
        name: campaign.name,
        audienceType: campaign.audienceType,
        filters: campaign.filters,
        channels: campaign.channels as NotificationChannel[],
        scheduledFor: campaign.scheduledFor
          ? new Date(campaign.scheduledFor)
          : null,
        status: campaign.status as NotificationCampaignStatus,
        linkedCaseId: campaign.linkedCaseId,
      },
      create: {
        id: campaign.id,
        templateId: campaign.templateId,
        name: campaign.name,
        audienceType: campaign.audienceType,
        filters: campaign.filters,
        channels: campaign.channels as NotificationChannel[],
        scheduledFor: campaign.scheduledFor
          ? new Date(campaign.scheduledFor)
          : null,
        status: campaign.status as NotificationCampaignStatus,
        linkedCaseId: campaign.linkedCaseId,
      },
    });
  }

  for (const delivery of mockAdminData.notificationDeliveries) {
    await prisma.notificationDelivery.upsert({
      where: { id: delivery.id },
      update: {
        campaignId: delivery.campaignId,
        recipientId: delivery.recipientId,
        recipientName: delivery.recipientName,
        channel: delivery.channel as NotificationChannel,
        status: delivery.status,
        deliveredAt: delivery.deliveredAt ? new Date(delivery.deliveredAt) : null,
      },
      create: {
        id: delivery.id,
        campaignId: delivery.campaignId,
        recipientId: delivery.recipientId,
        recipientName: delivery.recipientName,
        channel: delivery.channel as NotificationChannel,
        status: delivery.status,
        deliveredAt: delivery.deliveredAt ? new Date(delivery.deliveredAt) : null,
      },
    });
  }

  // Parcours & Témoignages — curated videos + legacy written interviews.
  // Keyed by the stable slug so re-seeding is idempotent (it always converges
  // to the same state). NOTE: `update` rewrites every seeded field, so the
  // seed is authoritative — re-running reverts admin edits (status, order,
  // featured, copy) on seeded rows. Admin-created rows have their own slugs
  // and are never touched.
  for (const story of PARCOURS_SEED) {
    const data = {
      kind: story.kind as ParcoursKind,
      fieldId: story.fieldId,
      tags: story.tags,
      personName: story.personName,
      roleFr: story.roleFr,
      roleEn: story.roleEn,
      titleFr: story.titleFr,
      titleEn: story.titleEn,
      hookFr: story.hookFr,
      hookEn: story.hookEn,
      summaryFr: story.summaryFr,
      summaryEn: story.summaryEn,
      thumbnailUrl: story.thumbnailUrl,
      photoUrl: story.photoUrl,
      youtubeId: story.youtubeId,
      durationMinutes: story.durationMinutes,
      interviewFr:
        (story.interviewFr as unknown as Prisma.InputJsonValue | null) ??
        Prisma.JsonNull,
      interviewEn:
        (story.interviewEn as unknown as Prisma.InputJsonValue | null) ??
        Prisma.JsonNull,
      status: story.status as PublicationStatus,
      isActive: story.isActive,
      featured: story.featured,
      displayOrder: story.displayOrder,
      popularity: story.popularity,
      source: story.source,
    };
    await prisma.parcoursStory.upsert({
      where: { slug: story.slug },
      update: data,
      create: { slug: story.slug, ...data },
    });
  }
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
