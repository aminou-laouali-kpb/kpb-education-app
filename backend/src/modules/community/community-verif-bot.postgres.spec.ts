import { randomUUID } from 'node:crypto';

import { HttpException } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

import type { LlmService } from '../ai/llm.service';
import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import type { PushSenderService } from '../notifications/push-sender.service';
import type { PrismaService } from '../prisma/prisma.service';
import { COMMUNITY_CHARTER_VERSION } from './community.constants';
import { CommunityAccessService, type CommunityViewer } from './community-access.service';
import { CommunityCatalogService } from './community-catalog.service';
import { CommunityComposerService } from './community-composer.service';
import { CommunityFilterConfigService } from './community-filter-config.service';
import { CommunityModerationService } from './community-moderation.service';
import { CommunityNotificationsService } from './community-notifications.service';
import { CommunityPostsService } from './community-posts.service';
import { CommunityVerifBotCatalogService } from './community-verif-bot-catalog.service';
import { CommunityVerifBotQueueService } from './community-verif-bot-queue.service';
import { CommunityVerifBotService } from './community-verif-bot.service';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

async function codeOf(promise: Promise<unknown>): Promise<{ status: number; code?: string; details?: unknown }> {
  try {
    await promise;
  } catch (error) {
    if (!(error instanceof HttpException)) throw error;
    const body = error.getResponse() as { code?: string; details?: unknown };
    return { status: error.getStatus(), code: body.code, details: body.details };
  }
  throw new Error('expected a rejection');
}

const DAY = 24 * 3600 * 1000;
const MODE = 'KPB_COMMUNITY_VERIF_BOT_MODE';
const LLM = 'KPB_COMMUNITY_VERIF_BOT_LLM';

/**
 * Bot « Vérif » (C3) de bout en bout sur PostgreSQL : question d'un élève →
 * file → brouillon (faits du catalogue, sources) → publication par un admin
 * (texte modifié, réponse vérifiée) → réponse « Assistant KPB » visible côté
 * élève ; idempotence, obsolescence (publication supprimée, faits changés),
 * re-vérification au moment de publier, faux positifs, modes review / auto /
 * off, garde-fou du LLM, rejet, statistiques.
 */
describePostgres('Bot Vérif — PostgreSQL', () => {
  const prisma = new PrismaClient();
  const sfx = randomUUID().slice(0, 8);
  const prismaService = {
    isEnabled: true,
    execute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma),
    tryExecute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma).catch(() => null),
  } as unknown as PrismaService;
  const catalog = new CommunityCatalogService(prismaService);
  const filterConfig = new CommunityFilterConfigService(prismaService, catalog);
  const composer = new CommunityComposerService(catalog, filterConfig);
  const access = new CommunityAccessService(prismaService);
  const dispatcher = new NotificationDispatchService(prismaService, {
    isConfigured: false,
  } as unknown as PushSenderService);
  const notifications = new CommunityNotificationsService(prismaService, dispatcher);
  const queue = new CommunityVerifBotQueueService(prismaService);
  const posts = new CommunityPostsService(prismaService, access, composer, filterConfig, notifications, catalog, queue);
  const moderation = new CommunityModerationService(prismaService, access, composer, filterConfig, notifications, posts, queue);
  const llm = { completeJson: jest.fn() };
  const bot = new CommunityVerifBotService(
    prismaService,
    new CommunityVerifBotCatalogService(prismaService),
    composer,
    notifications,
    moderation,
    llm as unknown as LlmService,
  );

  const previous = { mode: process.env[MODE], llm: process.env[LLM] };
  const admin = { id: `adm-${sfx}`, fullName: 'Fatou Diallo', role: 'admin' };
  const ids: Record<string, string> = {};
  const countryId = `cty-${sfx}`;
  const eiffelId = `sch-${sfx}`;
  const zorglubId = `sch2-${sfx}`;
  const institutionId = `inst-${sfx}`;
  const verifiedAt = new Date(Date.now() - 2 * DAY);
  const closesAt = new Date(Date.now() + 60 * DAY);
  const draftIds: string[] = [];

  async function student(key: string, fullName: string) {
    const id = `${key}-${sfx}`;
    await prisma.userProfile.create({
      data: {
        id,
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName,
        email: `${key}-${sfx}@gmail.com`,
        phone: '+227 90 00 00 00',
        countryOfResidence: 'Niger',
        createdAt: new Date('2026-09-01T00:00:00Z'),
      },
    });
    ids[key] = id;
  }

  async function viewer(key: string): Promise<CommunityViewer> {
    let v = await access.resolveViewer(ids[key], 'student');
    if (v.charterVersion !== COMMUNITY_CHARTER_VERSION) {
      await access.acceptCharter(v, COMMUNITY_CHARTER_VERSION);
      v = await access.resolveViewer(ids[key], 'student');
    }
    return v;
  }

  async function ask(key: string, title: string, body: string, type: 'question' | 'experience' | 'advice' = 'question') {
    return posts.createPost(await viewer(key), { type, title, body }, 'fr');
  }

  async function draftOf(postId: string) {
    const draft = await prisma.communityBotDraft.findUnique({ where: { postId } });
    if (draft && !draftIds.includes(draft.id)) draftIds.push(draft.id);
    return draft;
  }

  const eiffel = `@[Eiffel](scholarship:${eiffelId})`;

  beforeAll(async () => {
    process.env[MODE] = 'review';
    delete process.env[LLM];
    await prisma.country.create({
      data: {
        id: countryId,
        code: `Y${sfx.slice(0, 5)}`.toUpperCase(),
        nameFr: `Francie ${sfx}`,
        nameEn: `Frankland ${sfx}`,
        whyStudyFr: '-',
        whyStudyEn: '-',
        tuitionRangeFr: '-',
        tuitionRangeEn: '-',
        livingCostRangeFr: '-',
        livingCostRangeEn: '-',
        visaOverviewFr: '-',
        visaOverviewEn: '-',
        admissionDifficultyFr: '-',
        admissionDifficultyEn: '-',
        popularFieldIds: [],
      },
    });
    for (const [id, nameFr, nameEn] of [
      [eiffelId, `Bourse Eiffel ${sfx}`, `Eiffel Scholarship ${sfx}`],
      [zorglubId, `Bourse Zorglub ${sfx}`, `Zorglub Scholarship ${sfx}`],
    ]) {
      await prisma.scholarship.create({
        data: {
          id,
          nameFr,
          nameEn,
          countryId,
          levelEligibleFr: 'Master',
          levelEligibleEn: 'Master',
          typeOfFundingFr: 'Complète',
          typeOfFundingEn: 'Full',
          deadlineLabelFr: 'Janvier',
          deadlineLabelEn: 'January',
          keyRequirementsFr: ['CV', 'Lettre de motivation'],
          keyRequirementsEn: ['CV', 'Cover letter'],
          relatedFieldIds: [],
          isActive: true,
          moderationStatus: 'approved',
          lastVerifiedAt: verifiedAt,
          applicationUrl: `https://www.campusfrance.org/fr/${id}`,
          sourceUrl: `https://www.campusfrance.org/fr/${id}`,
          cycles: {
            create: {
              academicYear: '2027-2028',
              status: 'open',
              dateConfidence: 'confirmed',
              opensAt: new Date(Date.now() - 10 * DAY),
              closesAt,
            },
          },
        },
      });
    }
    await prisma.institution.create({
      data: {
        id: institutionId,
        nameFr: `Institut Zébulon ${sfx}`,
        nameEn: `Zebulon Institute ${sfx}`,
        countryId,
        locationFr: '-',
        locationEn: '-',
        overviewFr: '-',
        overviewEn: '-',
        studyLevels: [],
        tuitionLabelFr: '9 500 € par an',
        tuitionLabelEn: '€9,500 per year',
        languageRequirementsFr: '-',
        languageRequirementsEn: '-',
        intakePeriods: ['01/09/2030'],
        programIds: [],
        isPartner: true,
        websiteUrl: 'https://www.campusfrance.org/fr/zebulon',
        lastVerifiedAt: verifiedAt,
      },
    });
    for (const [key, name] of [
      ['alice', 'Aïcha Konaté'],
      ['bob', 'Moussa Diallo'],
      ['carol', 'Awa Sossou'],
      ['dave', 'Ali Traoré'],
      ['eve', 'Fanta Keita'],
    ]) {
      await student(key, name);
    }
  });

  afterAll(async () => {
    if (previous.mode === undefined) delete process.env[MODE];
    else process.env[MODE] = previous.mode;
    if (previous.llm === undefined) delete process.env[LLM];
    else process.env[LLM] = previous.llm;
    const all = Object.values(ids);
    await prisma.communityMember.deleteMany({ where: { userId: { in: all } } });
    await prisma.communityPost.deleteMany({ where: { authorAdminId: admin.id } });
    await prisma.forumModerationAction.deleteMany({ where: { adminId: admin.id } });
    await prisma.adminAuditEvent.deleteMany({
      where: { OR: [{ actorAdminId: admin.id }, { entityType: 'community_bot_draft', entityId: { in: draftIds } }] },
    });
    await prisma.userNotification.deleteMany({ where: { userId: { in: all } } });
    await prisma.userProfile.deleteMany({ where: { id: { in: all } } });
    await prisma.scholarship.deleteMany({ where: { id: { in: [eiffelId, zorglubId] } } });
    await prisma.institution.deleteMany({ where: { id: institutionId } });
    await prisma.country.deleteMany({ where: { id: countryId } });
    await prisma.$disconnect();
  });

  let alicePost = '';
  let aliceDraft = '';

  it('question avec mention → file → brouillon proposé, faits et sources ; idempotent', async () => {
    const post = await ask('alice', 'La bourse Eiffel est-elle ouverte ?', `Bonjour, ${eiffel} est encore ouverte ? Quelle est la date limite ?`);
    alicePost = post.id;
    expect((await draftOf(post.id))?.status).toBe('queued');
    // Une seconde mise en file ne crée rien : au plus un brouillon par publication.
    expect(await queue.enqueue(post.id)).toBe(true);
    expect(await prisma.communityBotDraft.count({ where: { postId: post.id } })).toBe(1);

    const run = await bot.processQueue();
    expect(run.processed).toBeGreaterThanOrEqual(1);
    const draft = (await draftOf(post.id))!;
    aliceDraft = draft.id;
    expect(draft).toMatchObject({ status: 'proposed', lang: 'fr', confidence: 'high', complete: true, writer: 'template' });
    expect(draft.intents).toEqual(expect.arrayContaining(['status', 'deadline']));
    const facts = draft.facts as { entities: { kind: string; status: { kind: string }; source: { url: string; verifiedAt: string } }[] };
    expect(facts.entities[0]).toMatchObject({
      kind: 'scholarship',
      status: { kind: 'open' },
      source: { url: `https://www.campusfrance.org/fr/${eiffelId}`, verifiedAt: verifiedAt.toISOString() },
    });
    const day = (date: Date) =>
      `${String(date.getUTCDate()).padStart(2, '0')}/${String(date.getUTCMonth() + 1).padStart(2, '0')}/${date.getUTCFullYear()}`;
    expect(draft.proposedText).toContain(`Clôture confirmée : le ${day(closesAt)}.`);
    expect(draft.proposedText).toContain(`vérifié le ${day(verifiedAt)}, source : https://www.campusfrance.org/fr/${eiffelId}`);
    expect(draft.proposedText).toContain(`@[Bourse Eiffel ${sfx}](scholarship:${eiffelId})`);

    // Rejouer la tâche ne refait rien.
    const before = draft.updatedAt.getTime();
    await bot.processQueue();
    expect((await draftOf(post.id))!.updatedAt.getTime()).toBe(before);

    const listed = await bot.list('proposed', undefined, 50);
    expect(listed.mode).toBe('review');
    const item = listed.items.find((i) => i.id === aliceDraft)!;
    expect(item.post).toMatchObject({ id: alicePost, status: 'visible' });
    expect(item.sources[0]).toMatchObject({ url: `https://www.campusfrance.org/fr/${eiffelId}`, stale: false });
    const detail = await bot.detail(aliceDraft, 'moderator', 'fr');
    expect(detail.live).toEqual({ postVisible: true, factsChanged: false });
    expect(detail.post.author.fullName).toBeNull();
  });

  it('modifier puis publier et marquer vérifiée → réponse « Assistant KPB » visible côté élève', async () => {
    const draft = (await draftOf(alicePost))!;
    const text = `${draft.proposedText}\nBon courage pour ton dossier !`;
    const result = await bot.publish(aliceDraft, { text, verified: true }, admin, `req-${sfx}`, 'fr');
    expect(result.draft).toMatchObject({ status: 'published', publishedVerified: true, autoPublished: false, processedBy: { adminId: admin.id } });
    expect(result.reply).toMatchObject({ author: { kind: 'kpb_assistant', displayName: 'Assistant KPB', badges: ['kpb_assistant'] }, isVerified: true });

    // Côté élève (l'autrice et un autre membre) : la réponse, son badge, sa date de vérification.
    for (const key of ['alice', 'bob']) {
      const page = await posts.getPost(await viewer(key), alicePost, 'fr');
      expect(page.post.hasVerifiedAnswer).toBe(true);
      const reply = page.replies.items[0];
      expect(reply.author).toEqual({ kind: 'kpb_assistant', memberId: null, displayName: 'Assistant KPB', countryName: null, badges: ['kpb_assistant'] });
      expect(reply.assistant).toEqual({ sourceVerifiedAt: verifiedAt.toISOString() });
      expect(reply.body).toContain('Bon courage pour ton dossier !');
      expect(reply.segments.some((s) => s.kind === 'mention')).toBe(true);
    }

    expect(await prisma.adminAuditEvent.count({ where: { action: 'community.bot_publish', entityId: aliceDraft, actorAdminId: admin.id } })).toBe(1);
    expect(await prisma.forumModerationAction.count({ where: { action: 'verify_answer', adminId: admin.id, postId: alicePost } })).toBe(1);
    expect(await prisma.userNotification.count({ where: { userId: ids.alice, kind: { in: ['community_reply', 'community_verified_answer'] } } })).toBeGreaterThanOrEqual(1);
    expect(await codeOf(bot.publish(aliceDraft, {}, admin, 'r', 'fr'))).toMatchObject({ status: 409, code: 'community_invalid_transition' });
  });

  it('obsolète : publication supprimée par son auteur ; publier → 409', async () => {
    const post = await ask('bob', 'Cet institut est-il partenaire ?', `Est-ce que @[Zébulon](institution:${institutionId}) est partenaire de KPB ?`);
    await bot.processQueue();
    const draft = (await draftOf(post.id))!;
    expect(draft.status).toBe('proposed');
    expect(draft.proposedText).toContain('est un établissement partenaire de KPB');
    await posts.deletePost(await viewer('bob'), post.id);
    const listed = await bot.list('proposed', undefined, 50);
    expect(listed.items.map((i) => i.id)).not.toContain(draft.id);
    expect(await prisma.communityBotDraft.findUnique({ where: { id: draft.id } })).toMatchObject({ status: 'obsolete', statusReason: 'post_not_visible' });
    expect(await codeOf(bot.publish(draft.id, {}, admin, 'r', 'fr'))).toMatchObject({
      status: 409,
      code: 'community_bot_draft_obsolete',
      details: { reason: 'post_not_visible' },
    });
  });

  it('re-vérification à la publication : faits changés → obsolète ; régénérer → proposé, publiable', async () => {
    const post = await ask('carol', 'Date limite Zorglub ?', `Quelle est la date limite de @[Zorglub](scholarship:${zorglubId}) cette année ?`);
    await bot.processQueue();
    const draft = (await draftOf(post.id))!;
    expect(draft.status).toBe('proposed');
    await prisma.scholarshipCycle.updateMany({ where: { scholarshipId: zorglubId }, data: { closesAt: new Date(closesAt.getTime() + 10 * DAY) } });
    expect((await bot.detail(draft.id, 'admin', 'fr')).live.factsChanged).toBe(true);
    expect(await codeOf(bot.publish(draft.id, {}, admin, 'r', 'fr'))).toMatchObject({
      status: 409,
      code: 'community_bot_draft_obsolete',
      details: { reason: 'facts_changed' },
    });
    expect((await draftOf(post.id))!.status).toBe('obsolete');
    const regenerated = await bot.regenerate(draft.id, admin, 'r');
    expect(regenerated.status).toBe('proposed');
    expect(regenerated.factsHash).not.toBe(draft.factsHash);
    await bot.publish(draft.id, {}, admin, 'r', 'fr');
    expect((await draftOf(post.id))!.status).toBe('published');
    expect(await prisma.adminAuditEvent.count({ where: { action: 'community.bot_regenerate', entityId: draft.id } })).toBe(1);
  });

  it('faux positifs et limites : témoignage, sans entité, sans motif, équipe, contenu masqué', async () => {
    const experience = await ask('dave', 'Mon parcours avec Eiffel', `J'ai eu ${eiffel} avant la date limite, voici mon expérience complète.`, 'experience');
    expect(await draftOf(experience.id)).toBeNull();

    const noEntity = await ask('dave', 'Date limite des bourses ?', 'Quelle est la date limite en général pour les bourses ?');
    const noIntent = await ask('dave', 'Entretien pour Eiffel', `Qui a déjà passé l’entretien de ${eiffel} ? Racontez-moi !`);
    await bot.processQueue();
    expect(await draftOf(noEntity.id)).toMatchObject({ status: 'skipped', statusReason: 'no_entity', proposedText: null });
    expect(await draftOf(noIntent.id)).toMatchObject({ status: 'skipped', statusReason: 'no_intent' });

    const team = await moderation.teamPost(
      { type: 'question', title: 'La bourse Eiffel est ouverte', body: `Oui, ${eiffel} est ouverte : date limite sur la fiche.`, as: 'kpb_team' },
      admin,
      'r',
      'fr',
    );
    expect(await queue.enqueue(team.id)).toBe(false);
    expect(await draftOf(team.id)).toBeNull();

    // Masqué par le filtre (numéro de téléphone) : jamais en file.
    const hidden = await ask('dave', 'Bourse Eiffel ouverte ?', `${eiffel} est ouverte ? Appelle-moi au +227 90 12 34 56.`);
    expect(hidden.moderation?.status).toBe('pending_review');
    expect(await draftOf(hidden.id)).toBeNull();
  });

  it('résolution par le nom (sans mention) : brouillon de confiance moyenne', async () => {
    const post = await ask('eve', 'Zorglub encore ouverte ?', `La bourse Zorglub ${sfx} est-elle encore ouverte ?`);
    await bot.processQueue();
    const draft = (await draftOf(post.id))!;
    expect(draft).toMatchObject({ status: 'proposed', confidence: 'medium' });
    expect(draft.entities).toEqual([expect.objectContaining({ type: 'scholarship', id: zorglubId, resolvedBy: 'name' })]);
  });

  it('mode auto : publie seul le brouillon sûr, laisse le moins sûr à l’équipe', async () => {
    process.env[MODE] = 'auto';
    try {
      const sure = await ask('eve', 'Eiffel ouverte ?', `Est-ce que ${eiffel} est ouverte en ce moment ?`);
      const unsure = await ask('eve', 'Zorglub ouverte ?', `La bourse Zorglub ${sfx} est-elle ouverte, et jusqu’à quand ?`);
      const run = await bot.processQueue();
      expect(run.autoPublished).toBe(1);
      const published = (await draftOf(sure.id))!;
      expect(published).toMatchObject({ status: 'published', autoPublished: true, processedByAdminId: null });
      expect(await prisma.adminAuditEvent.count({ where: { action: 'community.bot_auto_publish', entityId: published.id, actorAdminId: null } })).toBe(1);
      const page = await posts.getPost(await viewer('eve'), sure.id, 'fr');
      expect(page.replies.items[0]).toMatchObject({ author: { kind: 'kpb_assistant' }, isVerified: false });
      expect((await draftOf(unsure.id))!.status).toBe('proposed');
    } finally {
      process.env[MODE] = 'review';
    }
  });

  it('mode off : aucune mise en file, aucun traitement', async () => {
    process.env[MODE] = 'off';
    try {
      const post = await ask('carol', 'Eiffel ouverte ?', `${eiffel} est-elle ouverte cette année ?`);
      expect(await draftOf(post.id)).toBeNull();
      expect(await bot.processQueue()).toEqual({ processed: 0, proposed: 0, autoPublished: 0 });
      expect((await bot.stats(30)).mode).toBe('off');
    } finally {
      process.env[MODE] = 'review';
    }
  });

  it('LLM : un faux LLM qui invente une date est refusé (repli) ; une reformulation fidèle passe', async () => {
    process.env[LLM] = 'true';
    try {
      llm.completeJson.mockResolvedValueOnce({ data: { text: `Bonne nouvelle : la Bourse Eiffel ferme le 15/02/2031, dépêche-toi !` }, model: 'fake' });
      const liar = await ask('bob', 'Eiffel : date limite ?', `Quelle est la date limite de ${eiffel} ?`);
      await bot.processQueue();
      expect(await draftOf(liar.id)).toMatchObject({ status: 'proposed', writer: 'template', llmFallbackReason: 'unknown_number' });

      llm.completeJson.mockImplementationOnce(async ({ user }: { user: string }) => ({
        data: { text: user.replace('Bonjour !', 'Salut !') },
        model: 'fake',
      }));
      const honest = await ask('alice', 'Eiffel : statut ?', `${eiffel} est ouverte ou fermée ?`);
      await bot.processQueue();
      const draft = (await draftOf(honest.id))!;
      expect(draft).toMatchObject({ writer: 'llm', llmFallbackReason: null });
      expect(draft.proposedText).toMatch(/^Salut !/);
      expect(draft.proposedText).toContain('vérifié le');

      llm.completeJson.mockResolvedValueOnce({ data: {}, model: 'local-fallback' });
      const down = await ask('carol', 'Eiffel : clôture ?', `Quand ferme ${eiffel} ?`);
      await bot.processQueue();
      expect(await draftOf(down.id)).toMatchObject({ writer: 'template', llmFallbackReason: 'llm_unavailable' });
    } finally {
      delete process.env[LLM];
    }
  });

  it('rejeter avec motif ; statistiques', async () => {
    const listed = await bot.list('proposed', undefined, 50);
    const target = listed.items[0];
    expect(await codeOf(bot.reject(target.id, 'x', admin, 'r'))).toMatchObject({ status: 400 });
    const rejected = await bot.reject(target.id, 'Réponse déjà donnée par un alumni.', admin, 'r');
    expect(rejected).toMatchObject({ status: 'rejected', rejectReason: 'Réponse déjà donnée par un alumni.' });
    expect(await codeOf(bot.reject(target.id, 'Encore ?', admin, 'r'))).toMatchObject({ status: 409 });
    const stats = await bot.stats(30);
    expect(stats.mode).toBe('review');
    expect(stats.current.published).toBeGreaterThanOrEqual(3);
    expect(stats.current.rejected).toBeGreaterThanOrEqual(1);
    expect(stats.autoPublished).toBeGreaterThanOrEqual(1);
    expect(stats.publishedVerified).toBeGreaterThanOrEqual(1);
    expect(stats.medianHandlingHours).not.toBeNull();
  });
});
