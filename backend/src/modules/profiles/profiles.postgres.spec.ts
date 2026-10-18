import { randomUUID } from "node:crypto";

import {
  AccountType,
  AdmissionDecision,
  AiDiagnosticStatus,
  ArtifactProcessingStatus,
  ConsentPurpose,
  EvidenceVerificationStatus,
  FundingDecision,
  OutcomeEvidenceKind,
  PrismaClient,
} from "@prisma/client";

import type { PrismaService } from "../prisma/prisma.service";
import type { StorageService } from "../storage/storage.service";
import { ProfilesService } from "./profiles.service";

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === "true"
    ? describe
    : describe.skip;

describePostgres("ProfilesService — PostgreSQL privacy integration", () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID();
  const userId = `privacy-user-${suffix}`;
  const scholarshipId = `privacy-scholarship-${suffix}`;
  const cycleId = `privacy-cycle-${suffix}`;
  const workspaceId = `privacy-workspace-${suffix}`;
  const noticeId = `privacy-notice-${suffix}`;
  const consentId = `privacy-consent-${suffix}`;
  const diagnosticId = `privacy-diagnostic-${suffix}`;
  const budgetPeriodId = `privacy-budget-${suffix}`;
  const pilotId = `privacy-pilot-${suffix}`;
  const cohortId = `privacy-cohort-${suffix}`;
  const membershipId = `privacy-membership-${suffix}`;
  const assessmentId = `privacy-assessment-${suffix}`;
  const assignmentId = `privacy-assignment-${suffix}`;
  const pilotIdempotencyIds = [
    `privacy-idempotency-membership-${suffix}`,
    `privacy-idempotency-assessment-${suffix}`,
    `privacy-idempotency-assignment-${suffix}`,
  ];
  const evidenceIds = {
    submission: `privacy-evidence-submission-${suffix}`,
    admission: `privacy-evidence-admission-${suffix}`,
    funding: `privacy-evidence-funding-${suffix}`,
  };
  const entityIds = {
    submission: `privacy-submission-${suffix}`,
    admission: `privacy-admission-${suffix}`,
    funding: `privacy-funding-${suffix}`,
  };
  const storageKeys = [
    `2026-07-18/${randomUUID()}.pdf`,
    `2026-07-18/${randomUUID()}.pdf`,
    `2026-07-18/${randomUUID()}.pdf`,
  ];
  // Profile photo: a private object like any other user upload.
  const avatarStorageKey = `2026-08-12/${randomUUID()}.jpg`;
  // Flat-reference residues that no cascade reaches (see the deleteMe fix).
  const counsellorId = `privacy-counsellor-${suffix}`;
  const ownAmbassadorId = `privacy-ambassador-own-${suffix}`;
  const referrerAmbassadorId = `privacy-ambassador-referrer-${suffix}`;
  const ownRefereeProfileId = `privacy-own-referee-${suffix}`;

  const deleteObject = jest.fn().mockResolvedValue(undefined);
  const storage = {
    keyFromUrl: () => null,
    delete: deleteObject,
  } as unknown as StorageService;
  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as PrismaService;

  beforeAll(async () => {
    const now = new Date();
    await prisma.userProfile.create({
      data: {
        id: userId,
        accountType: AccountType.student,
        preferredLanguage: "fr",
        fullName: "Privacy Integration Student",
        email: `privacy-${suffix}@example.test`,
        phone: "+22790000000",
        countryOfResidence: "Niger",
        avatarStorageKey,
      },
    });
    // ── Résidus à référence « plate » que deleteMe doit purger (RGPD, droit à
    // l'effacement). Le harnais historique n'en seedait AUCUN, donc il ne pouvait
    // pas rougir sur ce gap (STORE_READINESS §6, revue P1 #244) — on les pose ici.
    await prisma.counsellor.create({
      data: {
        id: counsellorId,
        fullName: "Privacy Test Counsellor",
        email: `counsellor-${suffix}@example.test`,
        phone: "+22790000010",
        countryOfResidence: "Niger",
        bioFr: "Bio",
        bioEn: "Bio",
        // Compteurs cohérents avec l'unique avis publié ci-dessous : deleteMe doit
        // les ramener à 0/0 quand l'avis part (P2 #246).
        avgRating: 5,
        reviewCount: 1,
      },
    });
    // (1) Avis rédigé PAR l'utilisateur : porte son nom civil + son texte.
    await prisma.counsellorReview.create({
      data: {
        counsellorId,
        reviewerName: "Privacy Integration Student",
        reviewerUserId: userId,
        rating: 5,
        body: "Suivi impeccable — merci.",
        // Publié : sa suppression doit recalculer les compteurs du conseiller.
        isPublished: true,
      },
    });
    // (2) L'utilisateur EN TANT QU'ambassadeur : sa ligne porte le payoutAccount,
    // et son ledger (referral/commission/withdrawal) doit tomber par cascade FK.
    await prisma.ambassador.create({
      data: {
        id: ownAmbassadorId,
        userProfileId: userId,
        code: `AMB-OWN-${suffix}`,
        payoutAccount: "+22790000000",
      },
    });
    await prisma.ambassadorReferral.create({
      data: {
        ambassadorId: ownAmbassadorId,
        refereeProfileId: ownRefereeProfileId,
        refereeName: "Filleul de test",
      },
    });
    await prisma.commission.create({
      data: {
        ambassadorId: ownAmbassadorId,
        amountFCFA: 1000,
        reason: "referral_signup",
      },
    });
    await prisma.withdrawal.create({
      data: { ambassadorId: ownAmbassadorId, amountFCFA: 5000 },
    });
    // (3) L'utilisateur EN TANT QUE filleul d'un AUTRE ambassadeur (le parrain) :
    // son nom vit dans une ligne appartenant au parrain, hors de toute cascade
    // partant de lui. Le parrain, lui, doit SURVIVRE (garde anti-sur-suppression).
    await prisma.ambassador.create({
      data: {
        id: referrerAmbassadorId,
        userProfileId: `privacy-referrer-${suffix}`,
        code: `AMB-REF-${suffix}`,
      },
    });
    await prisma.ambassadorReferral.create({
      data: {
        ambassadorId: referrerAmbassadorId,
        refereeProfileId: userId,
        refereeName: "Privacy Integration Student",
      },
    });
    await prisma.scholarship.create({
      data: {
        id: scholarshipId,
        nameFr: "Bourse test confidentialité",
        nameEn: "Privacy test scholarship",
        countryId: "test",
        levelEligibleFr: "Master",
        levelEligibleEn: "Master",
        typeOfFundingFr: "Complète",
        typeOfFundingEn: "Full",
        deadlineLabelFr: "Test",
        deadlineLabelEn: "Test",
        keyRequirementsFr: [],
        keyRequirementsEn: [],
        relatedFieldIds: [],
        sourceKey: `privacy-${suffix}`,
      },
    });
    await prisma.scholarshipCycle.create({
      data: {
        id: cycleId,
        scholarshipId,
        academicYear: `privacy-${suffix}`,
      },
    });
    // Une notification in-app (annonce d'ouverture) : elle doit figurer dans
    // l'export, sans les détails d'exploitation du worker d'envoi.
    await prisma.userNotification.create({
      data: {
        userId,
        scholarshipId,
        cycleId,
        kind: "scholarship_opened",
        dedupeKey: `privacy-notification-${suffix}`,
        titleFr: "La bourse test est ouverte",
        titleEn: "The test scholarship is open",
        bodyFr: "Tu peux candidater.",
        bodyEn: "You can apply.",
        route: `/scholarships/${scholarshipId}`,
        data: { notificationKey: "scholarship_opened" },
        pushedAt: now,
        pushStatus: "accepted",
        pushProvider: "fcm",
        pushLockedBy: `privacy-worker-${suffix}`,
        pushLastError: "privacy-internal-error",
        pushBatchId: `privacy-batch-${suffix}`,
      },
    });
    await prisma.consentNotice.create({
      data: {
        id: noticeId,
        purpose: ConsentPurpose.outcome_evidence,
        version: `privacy-${suffix}`,
        languageCode: "fr",
        contentHash: "a".repeat(64),
        effectiveAt: new Date(now.getTime() - 60_000),
      },
    });
    await prisma.consentReceipt.create({
      data: {
        id: consentId,
        userId,
        purpose: ConsentPurpose.outcome_evidence,
        noticeId,
        languageCode: "fr",
        channel: "integration_test",
        grantedAt: now,
      },
    });
    await prisma.scholarshipWorkspace.create({
      data: {
        id: workspaceId,
        userId,
        scholarshipId,
        scholarshipCycleId: cycleId,
      },
    });
    await prisma.impactPilot.create({
      data: {
        id: pilotId,
        code: `privacy-${suffix}`,
        name: "Privacy integration pilot",
        hypothesis: "Account erasure removes pilot research data.",
        countryCodes: ["NE"],
        targetPopulation: { studyLevel: "master" },
        primaryMetrics: { keys: ["verified_admissions"] },
        guardrailMetrics: { keys: ["withdrawals"] },
        protocolVersion: "privacy-v1",
        ownerAdminId: `privacy-admin-${suffix}`,
      },
    });
    await prisma.impactCohort.create({
      data: {
        id: cohortId,
        pilotId,
        code: "privacy-cohort",
        label: "Privacy cohort",
        cohortType: "treatment",
        inclusionRules: {},
        exclusionRules: {},
      },
    });
    await prisma.impactCohortMembership.create({
      data: {
        id: membershipId,
        cohortId,
        userId,
        workspaceId,
        consentReceiptId: consentId,
        countryCodeLocked: "NE",
        profileRubricVersion: "privacy-v1",
        baselineSnapshot: { privateNeed: "financial_support" },
      },
    });
    await prisma.pilotAssessment.create({
      data: {
        id: assessmentId,
        membershipId,
        assessmentType: "baseline",
        instrumentVersion: "privacy-v1",
        answers: { privateAnswer: "student-specific response" },
        score: 5,
      },
    });
    await prisma.experimentAssignment.create({
      data: {
        id: assignmentId,
        membershipId,
        experimentKey: `privacy-${suffix}`,
        experimentVersion: "v1",
        armCode: "treatment",
        assignmentSeedHash: "d".repeat(64),
      },
    });
    for (const [index, resourceType, resourceId, responseSnapshot] of [
      [
        0,
        "ImpactCohortMembership",
        membershipId,
        {
          userId,
          workspaceId,
          baselineSnapshot: { privateNeed: "financial_support" },
        },
      ],
      [
        1,
        "PilotRecord",
        assessmentId,
        {
          membershipId,
          answers: { privateAnswer: "student-specific response" },
        },
      ],
      [2, "PilotRecord", assignmentId, { membershipId, armCode: "treatment" }],
    ] as const) {
      await prisma.idempotencyRecord.create({
        data: {
          id: pilotIdempotencyIds[index],
          actorType: "admin",
          actorId: `privacy-admin-${suffix}`,
          operation: `privacy-pilot-operation-${index}-${suffix}`,
          idempotencyKey: `privacy-pilot-key-${index}-${suffix}`,
          payloadHash: "e".repeat(64),
          status: "completed",
          resourceType,
          resourceId,
          responseCode: 201,
          responseSnapshot,
          completedAt: now,
          expiresAt: new Date(now.getTime() + 86_400_000),
        },
      });
    }

    const evidenceFixtures = [
      [
        evidenceIds.submission,
        OutcomeEvidenceKind.submission_confirmation,
        storageKeys[0],
      ],
      [
        evidenceIds.admission,
        OutcomeEvidenceKind.admission_decision,
        storageKeys[1],
      ],
      [evidenceIds.funding, OutcomeEvidenceKind.funding_award, storageKeys[2]],
    ] as const;
    for (const [id, kind, storageKey] of evidenceFixtures) {
      await prisma.outcomeEvidenceAsset.create({
        data: {
          id,
          workspaceId,
          ownerUserId: userId,
          consentReceiptId: consentId,
          kind,
          storageKey,
          originalFileName: `${kind}.pdf`,
          mimeType: "application/pdf",
          sizeBytes: 128,
          sha256: "b".repeat(64),
          processingStatus: ArtifactProcessingStatus.clean,
          uploadedAt: now,
        },
      });
    }

    await prisma.applicationSubmission.create({
      data: {
        id: entityIds.submission,
        workspaceId,
        version: 1,
        submittedAt: now,
        applicationRefHash: "c".repeat(64),
        evidenceId: evidenceIds.submission,
        verificationStatus: EvidenceVerificationStatus.self_reported,
      },
    });
    await prisma.applicationDecisionRecord.create({
      data: {
        id: entityIds.admission,
        workspaceId,
        version: 1,
        issuedByName: "Privacy Test University",
        admissionDecision: AdmissionDecision.admitted,
        receivedAt: now,
        evidenceId: evidenceIds.admission,
        verificationStatus: EvidenceVerificationStatus.self_reported,
      },
    });
    await prisma.fundingDecisionRecord.create({
      data: {
        id: entityIds.funding,
        workspaceId,
        admissionDecisionId: entityIds.admission,
        version: 1,
        issuedByName: "Privacy Test University",
        fundingDecision: FundingDecision.full,
        fundingAmountMinor: 1_000_000n,
        fundingCurrency: "XOF",
        receivedAt: now,
        evidenceId: evidenceIds.funding,
        verificationStatus: EvidenceVerificationStatus.self_reported,
      },
    });
    for (const [entityType, entityId, evidenceId] of [
      ["submission", entityIds.submission, evidenceIds.submission],
      ["admission", entityIds.admission, evidenceIds.admission],
      ["funding", entityIds.funding, evidenceIds.funding],
    ] as const) {
      await prisma.outcomeEvidenceLink.create({
        data: {
          id: `privacy-link-${entityType}-${suffix}`,
          entityType,
          entityId,
          evidenceId,
          linkedByUserId: userId,
          isPrimary: true,
        },
      });
    }

    await prisma.aiDiagnostic.create({
      data: {
        id: diagnosticId,
        workspaceId,
        entitlementKey: `privacy-entitlement-${suffix}`,
        status: AiDiagnosticStatus.succeeded,
        promptVersion: "privacy-v1",
      },
    });
    await prisma.aiUsageAttempt.create({
      data: {
        diagnosticId,
        attemptKey: `privacy-attempt-${suffix}`,
        attemptNumber: 1,
        feature: "success_lab",
        provider: "test",
        model: "test",
        promptVersion: "privacy-v1",
        actorKey: `actor-${userId}`,
        providerRequestId: `provider-${userId}`,
        outcome: "success",
        estimatedCostMicrosUsd: 12n,
      },
    });
    await prisma.aiBudgetPeriod.create({
      data: {
        id: budgetPeriodId,
        feature: `privacy-${suffix}`,
        periodKey: `privacy-${suffix}`,
        budgetMicrosUsd: 1_000n,
        startsAt: new Date(now.getTime() - 60_000),
        endsAt: new Date(now.getTime() + 60_000),
      },
    });
    await prisma.aiBudgetTransaction.create({
      data: {
        budgetPeriodId,
        diagnosticId,
        dedupeKey: `privacy-budget-transaction-${suffix}`,
        reason: "privacy_test",
        spentDeltaMicrosUsd: 12n,
      },
    });
    await prisma.analyticsEvent.create({
      data: {
        eventId: `privacy-event-${suffix}`,
        idempotencyKey: `privacy-event-${suffix}`,
        eventName: "privacy.integration.created",
        schemaVersion: 1,
        occurredAt: now,
        source: "integration_test",
        workspaceId,
        properties: { userProvided: true },
      },
    });
  });

  afterAll(async () => {
    // Production deliberately makes pilot records append-only. The temporary
    // integration fixture must therefore bypass triggers only while cleaning
    // its uniquely-prefixed rows.
    //
    // UNE TRANSACTION, ET `SET LOCAL` — PAS UN `SET` DE SESSION. La version
    // précédente posait `SET session_replication_role = replica` via le client
    // du pool, puis enchaînait les deleteMany : or chaque requête Prisma peut
    // prendre N'IMPORTE QUELLE connexion du pool, et le SET n'en couvrait
    // qu'une. Le 24/08/2026 la CI l'a payé sur la PR #237 : le nettoyage est
    // tombé sur une connexion restée en `origin` et le déclencheur
    // « ImpactPilot records cannot be deleted » a tué la suite — dont les
    // tests, eux, étaient verts. Reproduit hors CI avec un pool de 2 : après
    // un SET de session, `SHOW session_replication_role` rend `origin` OU
    // `replica` selon la connexion servie. Le restore `= origin` du `finally`
    // avait le défaut symétrique : posé sur la mauvaise connexion, il laissait
    // l'autre en `replica` — déclencheurs éteints — pour toute la suite du
    // processus.
    //
    // La transaction interactive épingle UNE connexion pour toutes les
    // instructions, et `SET LOCAL` meurt avec elle : rien à restaurer, rien à
    // empoisonner.
    try {
      await prisma.$transaction(
        async (tx) => {
          await tx.$executeRawUnsafe(
            "SET LOCAL session_replication_role = replica",
          );

        await tx.idempotencyRecord.deleteMany({
          where: { id: { in: pilotIdempotencyIds } },
        });
        await tx.impactCohortMembership.deleteMany({
          where: { id: membershipId },
        });
        await tx.impactCohort.deleteMany({ where: { id: cohortId } });
        await tx.impactPilot.deleteMany({ where: { id: pilotId } });
        await tx.outcomeEvidenceLink.deleteMany({
          where: { linkedByUserId: userId },
        });
        await tx.fundingDecisionRecord.updateMany({
          where: { workspaceId },
          data: { supersedesId: null, admissionDecisionId: null },
        });
        await tx.fundingDecisionRecord.deleteMany({ where: { workspaceId } });
        await tx.applicationDecisionRecord.updateMany({
          where: { workspaceId },
          data: { supersedesId: null },
        });
        await tx.applicationDecisionRecord.deleteMany({
          where: { workspaceId },
        });
        await tx.applicationSubmission.deleteMany({ where: { workspaceId } });
        await tx.outcomeEvidenceAsset.deleteMany({ where: { workspaceId } });
        await tx.aiUsageAttempt.updateMany({
          where: { diagnosticId },
          data: { diagnosticId: null, actorKey: null, providerRequestId: null },
        });
        await tx.aiBudgetTransaction.updateMany({
          where: { diagnosticId },
          data: { diagnosticId: null },
        });
        await tx.analyticsEvent.deleteMany({ where: { workspaceId } });
        await tx.scholarshipWorkspace.deleteMany({
          where: { id: workspaceId },
        });
        await tx.consentReceipt.deleteMany({ where: { id: consentId } });
        await tx.userProfile.deleteMany({ where: { id: userId } });
        await tx.aiBudgetTransaction.deleteMany({
          where: { budgetPeriodId },
        });
        await tx.aiBudgetPeriod.deleteMany({ where: { id: budgetPeriodId } });
        await tx.aiUsageAttempt.deleteMany({
          where: { attemptKey: `privacy-attempt-${suffix}` },
        });
        await tx.scholarship.deleteMany({ where: { id: scholarshipId } });
        await tx.consentNotice.deleteMany({ where: { id: noticeId } });
        // Résidus seedés pour ce test. Les triggers/FK sont coupés ici
        // (session_replication_role = replica), donc on efface chaque enfant
        // explicitement — y compris quand deleteMe n'a pas été atteint.
        await tx.commission.deleteMany({
          where: { ambassadorId: { in: [ownAmbassadorId, referrerAmbassadorId] } },
        });
        await tx.withdrawal.deleteMany({
          where: { ambassadorId: { in: [ownAmbassadorId, referrerAmbassadorId] } },
        });
        await tx.ambassadorReferral.deleteMany({
          where: { ambassadorId: { in: [ownAmbassadorId, referrerAmbassadorId] } },
        });
        await tx.ambassador.deleteMany({
          where: { id: { in: [ownAmbassadorId, referrerAmbassadorId] } },
        });
        await tx.counsellorReview.deleteMany({ where: { counsellorId } });
        await tx.counsellor.deleteMany({ where: { id: counsellorId } });
        },
        // Une vingtaine d'instructions sur un Postgres de CI : le plafond par
        // défaut (5 s) est trop juste un jour de runner lent.
        { timeout: 30_000 },
      );
    } finally {
      await prisma.$disconnect();
    }
  });

  it("exports all private outcome data and deletes it in FK-safe order", async () => {
    const service = new ProfilesService(prismaService, storage);

    const exported = await service.exportMe(userId);
    const exportRecord = exported as typeof exported & Record<string, unknown>;
    const workspaces = exportRecord.scholarshipWorkspaces as Array<{
      diagnostics: unknown[];
      outcomeEvidence: unknown[];
      submissions: unknown[];
      admissionDecisions: unknown[];
      fundingDecisions: Array<{ fundingAmountMinor: string }>;
    }>;
    expect(workspaces).toHaveLength(1);
    expect(workspaces[0].diagnostics).toHaveLength(1);
    expect(workspaces[0].outcomeEvidence).toHaveLength(3);
    expect(workspaces[0].submissions).toHaveLength(1);
    expect(workspaces[0].admissionDecisions).toHaveLength(1);
    expect(workspaces[0].fundingDecisions).toHaveLength(1);
    expect(workspaces[0].fundingDecisions[0].fundingAmountMinor).toBe(
      "1000000",
    );
    expect(exportRecord.analyticsEvents).toHaveLength(1);
    expect(exportRecord.impactCohortMemberships).toEqual([
      expect.objectContaining({
        id: membershipId,
        assessments: [expect.objectContaining({ id: assessmentId })],
        experimentAssignment: expect.objectContaining({ id: assignmentId }),
      }),
    ]);
    expect(() => JSON.stringify(exported)).not.toThrow();
    // The photo is reported as a flag; its private storage key never ships.
    expect(exportRecord.profile).toMatchObject({ hasAvatar: true });
    expect(JSON.stringify(exported)).not.toContain(avatarStorageKey);
    expect(JSON.stringify(exported)).not.toContain("avatarStorageKey");
    // Notifications in-app : rendues, sans clé de déduplication, verrou,
    // identifiant du worker, lot ni erreur du fournisseur.
    expect(exportRecord.notifications).toEqual([
      expect.objectContaining({
        kind: "scholarship_opened",
        scholarshipId,
        cycleId,
        titleFr: "La bourse test est ouverte",
        bodyEn: "You can apply.",
        route: `/scholarships/${scholarshipId}`,
        readAt: null,
        pushStatus: "accepted",
      }),
    ]);
    const notificationJson = JSON.stringify(exportRecord.notifications);
    for (const internal of [
      `privacy-notification-${suffix}`,
      `privacy-worker-${suffix}`,
      "privacy-internal-error",
      `privacy-batch-${suffix}`,
      "pushLockedBy",
      "dedupeKey",
    ]) {
      expect(notificationJson).not.toContain(internal);
    }

    await expect(service.deleteMe(userId)).resolves.toEqual({
      deleted: true,
      authIdentityRemoved: false,
    });

    expect(
      await prisma.userProfile.findUnique({ where: { id: userId } }),
    ).toBeNull();
    expect(
      await prisma.scholarshipWorkspace.count({ where: { id: workspaceId } }),
    ).toBe(0);
    expect(
      await prisma.outcomeEvidenceAsset.count({
        where: { ownerUserId: userId },
      }),
    ).toBe(0);
    expect(await prisma.consentReceipt.count({ where: { userId } })).toBe(0);
    expect(await prisma.userNotification.count({ where: { userId } })).toBe(0);
    expect(await prisma.analyticsEvent.count({ where: { workspaceId } })).toBe(
      0,
    );
    expect(
      await prisma.idempotencyRecord.count({
        where: { id: { in: pilotIdempotencyIds } },
      }),
    ).toBe(0);

    const retainedUsage = await prisma.aiUsageAttempt.findUnique({
      where: { attemptKey: `privacy-attempt-${suffix}` },
    });
    expect(retainedUsage).toMatchObject({
      diagnosticId: null,
      actorKey: null,
      providerRequestId: null,
    });
    const retainedBudget = await prisma.aiBudgetTransaction.findUnique({
      where: { dedupeKey: `privacy-budget-transaction-${suffix}` },
    });
    expect(retainedBudget?.diagnosticId).toBeNull();
    expect(deleteObject.mock.calls.map(([key]) => key).sort()).toEqual(
      [...storageKeys, avatarStorageKey].sort(),
    );

    // ── Résidus effacés (chaque count === 0 rougit si l'on retire sa purge).
    // (1) L'avis (nom civil + texte) rédigé par l'utilisateur.
    expect(
      await prisma.counsellorReview.count({
        where: { reviewerUserId: userId },
      }),
    ).toBe(0);
    // (2) Sa ligne ambassadeur ET tout son ledger, emporté par la cascade FK.
    expect(
      await prisma.ambassador.count({ where: { userProfileId: userId } }),
    ).toBe(0);
    expect(
      await prisma.ambassadorReferral.count({
        where: { ambassadorId: ownAmbassadorId },
      }),
    ).toBe(0);
    expect(
      await prisma.commission.count({
        where: { ambassadorId: ownAmbassadorId },
      }),
    ).toBe(0);
    expect(
      await prisma.withdrawal.count({
        where: { ambassadorId: ownAmbassadorId },
      }),
    ).toBe(0);
    // (3) Son nom en tant que filleul, dans la ligne du parrain.
    expect(
      await prisma.ambassadorReferral.count({
        where: { refereeProfileId: userId },
      }),
    ).toBe(0);

    // ── Non-sur-suppression : ce qui n'appartient PAS à l'utilisateur survit.
    // Le conseiller survit, MAIS ses compteurs dénormalisés sont recalculés :
    // l'unique avis publié (celui de l'utilisateur) est parti → 0/0. Sans le
    // recalcul, reviewCount resterait à 1 (P2 #246).
    const counsellorAfter = await prisma.counsellor.findUnique({
      where: { id: counsellorId },
      select: { avgRating: true, reviewCount: true },
    });
    expect(counsellorAfter).toMatchObject({ avgRating: 0, reviewCount: 0 });
    // L'ambassadeur PARRAIN, qui n'est pas cet utilisateur.
    expect(
      await prisma.ambassador.count({ where: { id: referrerAmbassadorId } }),
    ).toBe(1);
  });
});
