import { randomUUID } from 'node:crypto';

import { AccountType, CaseStatus, CaseType, PrismaClient } from '@prisma/client';

import { REPRISES, compterLignes, reprendre } from './legacy-english-copy';

/**
 * Preuve de comportement de la reprise des dossiers existants, sur un vrai
 * Postgres : la table de règles est du SQL (`=`, `~`, `regexp_replace`), et
 * seul Postgres dit ce que ce SQL fait. Les tests unitaires ne vérifient que la
 * cohérence de la table avec le service.
 *
 * On monte un dossier tel que le code d'AVANT le correctif l'écrivait, mot pour
 * mot, puis on vérifie trois choses : il ressort en français ; ce qu'un
 * conseiller a écrit à la main reste intact ; et une seconde exécution ne
 * touche plus rien.
 *
 *   createdb kpb_reprise_test
 *   DATABASE_URL=postgresql://…/kpb_reprise_test npx prisma db push
 *   KPB_RUN_POSTGRES_INTEGRATION=true DATABASE_URL=… npx jest …postgres.spec.ts
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

describePostgres('reprise des dossiers existants — intégration PostgreSQL', () => {
  const prisma = new PrismaClient();
  const suffixe = randomUUID();
  const userId = `reprise-user-${suffixe}`;
  const caseId = `reprise-case-${suffixe}`;
  let pieceDemandeeParConseiller = '';
  // Une conseillère : « Awa Traoré a été attribué » était l'accord fautif que
  // la reprise corrige en mettant « Votre dossier » en sujet.
  const conseillere = 'Awa Traoré';

  /** Ce qu'un conseiller a écrit lui-même : la reprise ne doit pas y toucher. */
  const ecritMain =
    'Relance envoyée à Sciences Po, réponse attendue avant le 30 septembre.';

  beforeAll(async () => {
    await prisma.userProfile.create({
      data: {
        id: userId,
        accountType: AccountType.student,
        preferredLanguage: 'fr',
        fullName: 'Étudiant de reprise',
        email: `reprise-${suffixe}@example.test`,
        phone: '+2250700000000',
        countryOfResidence: 'CI',
      },
    });

    // Le dossier tel que `cases.service.ts` l'écrivait AVANT le correctif.
    await prisma.case.create({
      data: {
        id: caseId,
        referenceCode: `KPB-REPRISE-${suffixe.slice(0, 8)}`,
        userId,
        type: CaseType.consultation,
        status: CaseStatus.counselor_assigned,
        title: 'Consultation',
        description: 'Dossier de test de reprise.',
        contextLabel: 'Test',
        nextStepTitle: 'A counselor has been assigned',
        nextStepDescription: `${conseillere} has been assigned to your case and will contact you shortly.`,
      },
    });

    await prisma.caseTimelineEvent.createMany({
      data: [
        {
          caseId,
          status: CaseStatus.submitted,
          title: 'Case submitted',
          description: 'The student created a new case from the mobile app.',
        },
        {
          caseId,
          status: CaseStatus.counselor_assigned,
          title: 'Counselor assigned',
          description: `${conseillere} was assigned automatically (round-robin).`,
        },
        {
          caseId,
          status: CaseStatus.under_review,
          title: 'Document uploaded',
          description: 'Carte d’identité was uploaded to the case.',
        },
        {
          caseId,
          status: CaseStatus.counselor_assigned,
          title: 'Case reassigned',
          description: `Auto-reassigned after 10h inactivity to ${conseillere}.`,
        },
        {
          // Écrit à la main par un conseiller : hors de portée de la reprise.
          caseId,
          status: CaseStatus.in_progress,
          title: 'Point de suivi',
          description: ecritMain,
        },
      ],
    });

    await prisma.caseMessage.create({
      data: {
        caseId,
        senderRole: 'system',
        senderName: 'KPB Operations',
        body: `Thank you. ${conseillere} has been assigned to your request.`,
      },
    });

    // Créée d'office dans la même seconde que le dossier : à supprimer.
    const dossier = await prisma.case.findUniqueOrThrow({ where: { id: caseId } });
    await prisma.caseDocument.create({
      data: {
        caseId,
        title: 'Academic profile',
        isProvided: false,
        createdAt: dossier.createdAt,
      },
    });
    // Demandée par un conseiller deux jours plus tard : à garder.
    const demandee = await prisma.caseDocument.create({
      data: {
        caseId,
        title: 'Profil académique',
        isProvided: false,
        createdAt: new Date(dossier.createdAt.getTime() + 2 * 86_400_000),
      },
    });
    pieceDemandeeParConseiller = demandee.id;
  });

  afterAll(async () => {
    await prisma.caseTimelineEvent.deleteMany({ where: { caseId } });
    await prisma.caseMessage.deleteMany({ where: { caseId } });
    await prisma.caseDocument.deleteMany({ where: { caseId } });
    await prisma.case.deleteMany({ where: { id: caseId } });
    await prisma.userProfile.deleteMany({ where: { id: userId } });
    await prisma.$disconnect();
  });

  const frise = async () =>
    (
      await prisma.caseTimelineEvent.findMany({
        where: { caseId },
        select: { title: true, description: true },
      })
    ).map((e) => `${e.title} | ${e.description}`);

  it('repasse en français les six colonnes lues par l’étudiant', async () => {
    const touchees = await prisma.$transaction((tx) => reprendre(tx));
    // 1 dossier (2 colonnes, 1 UPDATE chacune) + 4 jalons + 1 message + 1 doc.
    expect(touchees).toBeGreaterThanOrEqual(8);

    const dossier = await prisma.case.findUniqueOrThrow({ where: { id: caseId } });
    expect(dossier.nextStepTitle).toBe('Un conseiller vous a été attribué');
    expect(dossier.nextStepDescription).toBe(
      'Awa Traoré suit votre dossier et vous contactera prochainement.',
    );

    expect(await frise()).toEqual(
      expect.arrayContaining([
        'Demande envoyée | Votre demande a été créée depuis l’application.',
        'Conseiller attribué | Votre dossier a été attribué à Awa Traoré.',
        'Document ajouté | Le document « Carte d’identité » a été ajouté au dossier.',
        'Dossier réattribué | Votre dossier a été réattribué à Awa Traoré.',
      ]),
    );

    const message = await prisma.caseMessage.findFirstOrThrow({ where: { caseId } });
    expect(message.body).toBe('Merci pour votre demande. Awa Traoré suit votre dossier.');

    // La pièce créée d'office n'est pas traduite : elle est supprimée (audit
    // build 57, n° 5c) ; celle qu'un conseiller a demandée plus tard reste.
    const docs = await prisma.caseDocument.findMany({ where: { caseId } });
    expect(docs.map((d) => d.title)).toEqual(['Profil académique']);
    expect(docs[0].id).toBe(pieceDemandeeParConseiller);
  });

  it('ne laisse plus aucune ligne correspondre à une règle', async () => {
    const restant = await Promise.all(
      REPRISES.map((r) => compterLignes(prisma, r)),
    );
    expect(restant.reduce((s, n) => s + n, 0)).toBe(0);
  });

  it('ne touche pas une phrase écrite par un conseiller', async () => {
    expect(await frise()).toContain(`Point de suivi | ${ecritMain}`);
  });

  it('est rejouable : une seconde exécution ne réécrit rien', async () => {
    const avant = await frise();
    const touchees = await prisma.$transaction((tx) => reprendre(tx));
    expect(touchees).toBe(0);
    expect(await frise()).toEqual(avant);
  });
});
