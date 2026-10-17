import { randomUUID } from 'node:crypto';

import { HttpException } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import type { PushSenderService } from '../notifications/push-sender.service';
import type { PrismaService } from '../prisma/prisma.service';
import { ProfilesService } from '../profiles/profiles.service';
import type { StorageService } from '../storage/storage.service';
import { COMMUNITY_CHARTER_VERSION } from './community.constants';
import { CommunityAccessService, type CommunityViewer } from './community-access.service';
import { CommunityCatalogService } from './community-catalog.service';
import { CommunityComposerService } from './community-composer.service';
import { CommunityFilterConfigService } from './community-filter-config.service';
import { forYouScore } from './community-for-you';
import { CommunityModerationService } from './community-moderation.service';
import { CommunityNotificationsService } from './community-notifications.service';
import { CommunityPostsService } from './community-posts.service';
import { CommunityPurgeCronService } from './community-purge-cron.service';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

async function codeOf(promise: Promise<unknown>): Promise<{ status: number; code?: string }> {
  try {
    await promise;
  } catch (error) {
    if (!(error instanceof HttpException)) throw error;
    const body = error.getResponse() as { code?: string };
    return { status: error.getStatus(), code: body.code };
  }
  throw new Error('expected a rejection');
}

/**
 * Scénario complet de la communauté, sur PostgreSQL : charte → publication
 * avec mentions et hashtag → espaces et compteurs → réponses (notification
 * regroupée) → « utile » → filtre anti-arnaque (masquage visible du seul
 * auteur) → blocage → signalements et masquage au seuil → modération et
 * sanction → réponse vérifiée par l'équipe → fil « Pour toi » à horloge fixée →
 * statistiques → export → suppression de compte (compteurs recalculés) → purge.
 */
describePostgres('Communauté — PostgreSQL', () => {
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
  const posts = new CommunityPostsService(prismaService, access, composer, filterConfig, notifications, catalog);
  const moderation = new CommunityModerationService(prismaService, access, composer, filterConfig, notifications, posts);
  const purge = new CommunityPurgeCronService(prismaService);

  // Horloge du scénario : trois heures avant l'instant réel (à la minute). Les
  // lignes écrites par le chemin commun des notifications portent l'heure réelle
  // de la base ; un T0 figé dans le passé casserait la fenêtre de regroupement.
  const T0 = new Date(Math.floor(Date.now() / 60_000) * 60_000 - 3 * 3_600_000);
  const at = (minutes: number) => new Date(T0.getTime() + minutes * 60_000);
  const admin = { id: `adm-${sfx}`, fullName: 'Fatou Diallo', role: 'admin' };
  const moderator = { id: `mod-${sfx}`, fullName: 'Ibrahim Sow', role: 'moderator' };
  const ids: Record<string, string> = {};
  const countryId = `cty-${sfx}`;
  const scholarshipId = `sch-${sfx}`;
  let alicePost = '';
  let bobReply = '';

  async function student(key: string, fullName: string, createdAt = new Date('2026-09-01T00:00:00Z')) {
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
        createdAt,
        targetCountryIds: [countryId],
        scholarshipTargetLevel: 'master',
      },
    });
    ids[key] = id;
    return id;
  }

  async function viewer(key: string, charter = true): Promise<CommunityViewer> {
    let v = await access.resolveViewer(ids[key], 'student');
    if (charter && v.charterVersion !== COMMUNITY_CHARTER_VERSION) {
      await access.acceptCharter(v, COMMUNITY_CHARTER_VERSION, T0);
      v = await access.resolveViewer(ids[key], 'student');
    }
    return v;
  }

  beforeAll(async () => {
    await prisma.country.create({
      data: {
        id: countryId,
        code: `Z${sfx.slice(0, 5)}`.toUpperCase(),
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
    await prisma.scholarship.create({
      data: {
        id: scholarshipId,
        nameFr: `Bourse Eiffel ${sfx}`,
        nameEn: `Eiffel Scholarship ${sfx}`,
        countryId,
        levelEligibleFr: 'Master',
        levelEligibleEn: 'Master',
        typeOfFundingFr: 'Complète',
        typeOfFundingEn: 'Full',
        deadlineLabelFr: 'Janvier',
        deadlineLabelEn: 'January',
        keyRequirementsFr: [],
        keyRequirementsEn: [],
        relatedFieldIds: [],
        isActive: true,
        moderationStatus: 'approved',
        lastVerifiedAt: new Date('2026-10-01T00:00:00Z'),
        eligibleLevels: ['master'],
      },
    });
    await student('alice', 'Aïcha Konaté');
    await student('bob', 'Moussa Diallo');
    await student('carol', 'Awa Sossou');
    await student('dave', 'Ali Traoré');
    await student('eve', 'Fanta Keita');
    await student('mallory', 'Jean Arnaque');
    // Alice suit la bourse (favori) : source « mes suivis » du fil « Pour toi ».
    await prisma.savedItem.create({ data: { userId: ids.alice, itemType: 'scholarship', itemId: scholarshipId } });
  });

  afterAll(async () => {
    const all = Object.values(ids).filter((id) => id.endsWith(sfx));
    await prisma.communityMember.deleteMany({ where: { userId: { in: all } } });
    await prisma.communityPost.deleteMany({ where: { authorAdminId: { in: [admin.id, moderator.id] } } });
    await prisma.communityReport.deleteMany({ where: { reporterMemberId: null, targetKey: { contains: sfx } } });
    await prisma.forumModerationAction.deleteMany({ where: { adminId: { in: [admin.id, moderator.id] } } });
    await prisma.adminAuditEvent.deleteMany({ where: { actorAdminId: { in: [admin.id, moderator.id] } } });
    await prisma.userNotification.deleteMany({ where: { userId: { in: all } } });
    await prisma.savedItem.deleteMany({ where: { userId: { in: all } } });
    await prisma.userProfile.deleteMany({ where: { id: { in: all } } });
    await prisma.scholarship.deleteMany({ where: { id: scholarshipId } });
    await prisma.country.deleteMany({ where: { id: countryId } });
    await prisma.$disconnect();
  });

  it('exige la charte avant la première publication, puis l’historise', async () => {
    const alice = await viewer('alice', false);
    const refused = await codeOf(
      posts.createPost(alice, { type: 'question', title: 'Délai Campus France ?', body: 'x'.repeat(30) }, 'fr', at(0)),
    );
    expect(refused).toEqual({ status: 403, code: 'community_charter_required' });
    const accepted = await access.acceptCharter(alice, COMMUNITY_CHARTER_VERSION, T0);
    expect(accepted.acceptedVersion).toBe(COMMUNITY_CHARTER_VERSION);
    expect(await prisma.communityCharterAcceptance.count({ where: { memberId: alice.memberId } })).toBe(1);
    expect(await codeOf(access.acceptCharter(alice, '1999-v0', T0))).toMatchObject({ status: 409 });
  });

  it('publie avec mentions structurées et hashtag ; libellé canonique ; espace et compteurs', async () => {
    const alice = await viewer('alice');
    const post = await posts.createPost(
      alice,
      {
        type: 'question',
        title: 'Délai de réponse Campus France ?',
        body: `Qui a eu @[eifel](scholarship:${scholarshipId}) pour la @[fr](country:${countryId}) ? #CampusFrance`,
      },
      'fr',
      at(1),
    );
    alicePost = post.id;
    expect(post.moderation).toBeNull();
    expect(post.body).toContain(`@[Bourse Eiffel ${sfx}](scholarship:${scholarshipId})`);
    expect(post.mentions.map((m) => m.type)).toEqual(['scholarship', 'country']);
    expect(post.hashtags).toEqual([{ tag: 'campusfrance', display: 'CampusFrance' }]);
    expect(post.segments.some((s) => s.kind === 'mention')).toBe(true);
    expect(post.viewer).toMatchObject({ isAuthor: true, isFollowing: true });

    const invalid = await codeOf(
      posts.createPost(alice, { type: 'advice', title: 'Un conseil utile', body: '@[x](scholarship:nope) '.repeat(2) + 'texte' }, 'fr', at(2)),
    );
    expect(invalid).toEqual({ status: 400, code: 'community_invalid_mention' });

    expect(await posts.entityCount('scholarship', scholarshipId)).toEqual({
      type: 'scholarship',
      id: scholarshipId,
      discussionCount: 1,
    });
    const counts = await posts.entityCounts(`scholarship:${scholarshipId},country:${countryId},program:none`);
    expect(counts.items.map((i) => i.discussionCount)).toEqual([1, 1, 0]);
    const space = await posts.entitySpace(alice, 'scholarship', scholarshipId, 'recent', undefined, 20, 'en', at(2));
    expect(space.entity.label).toBe(`Eiffel Scholarship ${sfx}`);
    expect(space.items.map((i) => i.id)).toEqual([alicePost]);
  });

  it('réponses : compteurs, notification de l’auteur REGROUPÉE, abonnés notifiés', async () => {
    const bob = await viewer('bob');
    const carol = await viewer('carol');
    const reply = await posts.createReply(bob, alicePost, { body: 'Moi, réponse en 3 semaines.' }, 'fr', at(10));
    bobReply = reply.id;
    await posts.createReply(carol, alicePost, { body: 'Pareil, environ un mois.' }, 'fr', at(12));

    const row = await prisma.communityPost.findUniqueOrThrow({ where: { id: alicePost } });
    expect(row).toMatchObject({ replyCount: 2, answerCount: 2 });
    expect(row.lastActivityAt.toISOString()).toBe(at(12).toISOString());

    const aliceNotes = await prisma.userNotification.findMany({ where: { userId: ids.alice, kind: 'community_reply' } });
    expect(aliceNotes).toHaveLength(1);
    expect(aliceNotes[0].titleFr).toBe('2 nouvelles réponses à ta question');
    expect(aliceNotes[0].route).toBe(`/community/posts/${alicePost}`);
    expect(aliceNotes[0].data).toMatchObject({ postId: alicePost, count: '2' });
    // Bob suit la discussion depuis sa réponse : la réponse de Carol le notifie.
    expect(await prisma.userNotification.count({ where: { userId: ids.bob, kind: 'community_followed_reply' } })).toBe(1);
    // Personne n'est notifié de sa propre réponse.
    expect(await prisma.userNotification.count({ where: { userId: ids.carol, kind: 'community_followed_reply' } })).toBe(0);
  });

  it('« utile » unique par personne, jamais sur son propre contenu', async () => {
    const alice = await viewer('alice');
    expect(await posts.setReplyHelpful(alice, bobReply, true, at(13))).toEqual({ helpfulCount: 1, hasMarkedHelpful: true });
    expect(await posts.setReplyHelpful(alice, bobReply, true, at(13))).toEqual({ helpfulCount: 1, hasMarkedHelpful: true });
    expect(await codeOf(posts.setPostHelpful(alice, alicePost, true, at(13)))).toEqual({
      status: 400,
      code: 'community_cannot_react_own',
    });
    const bob = await viewer('bob');
    await posts.setPostHelpful(bob, alicePost, true, at(14));
    expect((await prisma.communityPost.findUniqueOrThrow({ where: { id: alicePost } })).helpfulCount).toBe(1);
    const profile = await access.memberProfile(alice, bob.memberId);
    expect(profile.member.displayName).toBe('Moussa D.');
    expect(profile.stats).toEqual({ helpfulAnswersCount: 1, postsCount: 0, repliesCount: 1 });
  });

  it('anti-arnaque : un numéro WhatsApp masque la réponse, visible de son seul auteur', async () => {
    const mallory = await viewer('mallory');
    const scam = await posts.createReply(
      mallory,
      alicePost,
      { body: 'Je garantis la bourse, écris-moi sur WhatsApp au +227 90 11 22 33' },
      'fr',
      at(15),
    );
    expect(scam.moderation).toMatchObject({ status: 'pending_review', reason: 'auto_filter' });
    const stored = await prisma.communityReply.findUniqueOrThrow({ where: { id: scam.id } });
    expect(stored.filterFlags).toEqual(expect.arrayContaining(['phone', 'whatsapp', 'money_request']));

    const bob = await viewer('bob');
    const seenByBob = await posts.listReplies(bob, alicePost, undefined, undefined, 'fr', at(16));
    expect(seenByBob.items.map((r) => r.id)).not.toContain(scam.id);
    const seenByMallory = await posts.listReplies(mallory, alicePost, undefined, undefined, 'fr', at(16));
    expect(seenByMallory.items.find((r) => r.id === scam.id)?.moderation?.status).toBe('pending_review');
    // Les compteurs ne voient pas un contenu en attente, et l'auteur n'est pas notifié.
    expect((await prisma.communityPost.findUniqueOrThrow({ where: { id: alicePost } })).replyCount).toBe(2);
    ids.scamReply = scam.id;
  });

  it('blocage dans les deux sens : fils, détail, profil', async () => {
    const carol = await viewer('carol');
    const bob = await viewer('bob');
    const carolPost = await posts.createPost(
      carol,
      { type: 'experience', title: 'Mon visa étudiant en 10 jours', body: 'Voici comment s’est passé mon rendez-vous au consulat.' },
      'fr',
      at(20),
    );
    ids.carolPost = carolPost.id;
    await access.block(carol, bob.memberId);

    const bobFeed = await posts.feed(bob, { tab: 'recent' }, 'fr', at(21));
    expect(bobFeed.items.map((i) => i.id)).not.toContain(carolPost.id);
    expect(await codeOf(posts.getPost(bob, carolPost.id, 'fr', at(21)))).toEqual({ status: 404, code: 'community_post_not_found' });
    const carolView = await posts.getPost(carol, alicePost, 'fr', at(21));
    expect(carolView.replies.items.map((r) => r.id)).not.toContain(bobReply);
    expect(await codeOf(access.memberProfile(bob, carol.memberId))).toMatchObject({ status: 404 });
    expect((await access.memberProfile(carol, bob.memberId)).viewer.isBlocked).toBe(true);
    await access.unblock(carol, bob.memberId);
    expect((await posts.feed(bob, { tab: 'recent' }, 'fr', at(22))).items.map((i) => i.id)).toContain(carolPost.id);
  });

  it('« Sans réponse » et recherche plein texte sans accents', async () => {
    const dave = await viewer('dave');
    const lonely = await posts.createPost(
      dave,
      { type: 'question', title: 'Lettre de motivation Chevening ?', body: 'Combien de mots pour la lettre de motivation ?' },
      'fr',
      at(25),
    );
    ids.davePost = lonely.id;
    const unanswered = await posts.feed(dave, { tab: 'unanswered' }, 'fr', at(26));
    expect(unanswered.items.map((i) => i.id)).toContain(lonely.id);
    expect(unanswered.items.map((i) => i.id)).not.toContain(alicePost);

    const byWord = await posts.search(dave, 'delai reponse', undefined, undefined, 20, 'fr', at(26));
    expect(byWord.items.map((i) => i.id)).toEqual([alicePost]);
    const byTag = await posts.search(dave, '#campusfrance', undefined, undefined, 20, 'fr', at(26));
    expect(byTag.items.map((i) => i.id)).toEqual([alicePost]);
    const tags = await posts.suggestHashtags('camp', 5);
    expect(tags.items[0]).toMatchObject({ tag: 'campusfrance', postCount: 1 });
  });

  it('signalements : doublon idempotent, masquage provisoire au 3e signaleur, file admin', async () => {
    const mallory = await viewer('mallory');
    const bait = await posts.createPost(
      mallory,
      { type: 'advice', title: 'Le meilleur conseil du monde', body: 'Contacte un agent sérieux pour réussir ton dossier.' },
      'fr',
      at(30),
    );
    ids.malloryPost = bait.id;
    expect(bait.moderation).toBeNull();

    const reporters = ['alice', 'dave', 'eve'];
    for (const [i, key] of reporters.entries()) {
      const v = await viewer(key);
      const result = await moderation.report(v, { targetType: 'post', targetId: bait.id, reason: 'scam' }, at(31 + i));
      expect(result.created).toBe(true);
    }
    const again = await moderation.report(await viewer('alice'), { targetType: 'post', targetId: bait.id, reason: 'spam' }, at(35));
    expect(again.created).toBe(false);
    await moderation.report(await viewer('eve'), { targetType: 'member', targetId: mallory.memberId, reason: 'scam' }, at(36));

    const row = await prisma.communityPost.findUniqueOrThrow({ where: { id: bait.id } });
    expect(row).toMatchObject({ status: 'pending_review', statusReason: 'reports_threshold', openReportCount: 3 });

    const queue = await moderation.queue('moderator', 'all', undefined, 50, 'fr', at(40));
    const keys = queue.items.map((i) => i.key);
    expect(keys).toEqual(expect.arrayContaining([`post:${bait.id}`, `reply:${ids.scamReply}`, `member:${mallory.memberId}`]));
    expect(queue.counts.members).toBeGreaterThanOrEqual(1);
    const item = queue.items.find((i) => i.key === `post:${bait.id}`)!;
    expect(item.openReportCount).toBe(3);
    // Un modérateur ne reçoit ni le nom complet ni l'e-mail de l'élève.
    expect(item.post?.author).toMatchObject({ fullName: null, email: null, isMinor: null, isNewAccount: false });
    const asAdmin = await moderation.queue('admin', 'reported', undefined, 50, 'fr', at(40));
    const adminItem = asAdmin.items.find((i) => i.key === `post:${bait.id}`)!;
    expect(adminItem.post?.author).toMatchObject({ fullName: 'Jean Arnaque', email: `mallory-${sfx}@gmail.com` });
  });

  it('modération : masquer, sanctionner (lecture seule), notifier, journaliser', async () => {
    const hidden = await moderation.contentAction(
      'post',
      ids.malloryPost,
      { action: 'hide', reason: 'Racolage pour un faux agent' },
      moderator,
      `rq-${sfx}-1`,
      'fr',
      at(45),
    );
    expect(hidden).toMatchObject({ status: 'hidden', statusReason: 'moderation', openReportCount: 0 });
    expect(await prisma.communityReport.count({ where: { postId: ids.malloryPost, status: 'actioned' } })).toBe(3);
    await moderation.contentAction('reply', ids.scamReply, { action: 'delete', reason: 'Arnaque' }, moderator, `rq-${sfx}-2`, 'fr', at(46));

    const mallory = await viewer('mallory');
    const sanction = await moderation.createSanction(
      mallory.memberId,
      { kind: 'read_only', reason: 'Tentative d’arnaque', durationDays: 7 },
      moderator,
      `rq-${sfx}-3`,
      at(47),
    );
    expect(sanction).toMatchObject({ kind: 'read_only', active: true });
    expect(await prisma.communityReport.count({ where: { targetMemberId: mallory.memberId, status: 'actioned' } })).toBe(1);

    const blocked = await codeOf(
      posts.createPost(mallory, { type: 'advice', title: 'Encore un conseil', body: 'x'.repeat(40) }, 'fr', new Date()),
    );
    expect(blocked).toEqual({ status: 403, code: 'community_read_only' });
    // Signaler reste permis sous sanction.
    await expect(
      moderation.report(mallory, { targetType: 'post', targetId: ids.davePost, reason: 'other' }, at(48)),
    ).resolves.toMatchObject({ created: true });

    const notes = await prisma.userNotification.findMany({ where: { userId: ids.mallory, kind: 'community_moderation' } });
    expect(notes.map((n) => (n.data as { event: string }).event).sort()).toEqual(['deleted', 'hidden', 'read_only']);
    const log = await moderation.moderationLog(undefined, 50);
    expect(log.items.map((l) => l.action)).toEqual(expect.arrayContaining(['hide', 'delete', 'sanction_read_only']));
    expect(await prisma.adminAuditEvent.count({ where: { actorAdminId: moderator.id, purposeCode: 'community_moderation' } })).toBe(3);

    const active = await moderation.listSanctions('moderator', 'active', undefined, 20, at(49));
    expect(active.items.map((s) => s.id)).toContain(sanction.id);
  });

  it('« Réponse vérifiée par KPB » : une seule, en tête, notifie auteur et abonnés', async () => {
    const team = await moderation.teamReply(
      alicePost,
      { body: 'Le délai officiel est de 4 à 6 semaines.', as: 'kpb_team', verified: true },
      admin,
      `rq-${sfx}-4`,
      'fr',
      at(50),
    );
    expect(team).toMatchObject({ isVerified: true, author: { kind: 'kpb_team', displayName: 'Équipe KPB', badges: ['kpb_team'] } });
    expect((await prisma.communityPost.findUniqueOrThrow({ where: { id: alicePost } })).hasVerifiedAnswer).toBe(true);
    expect(await prisma.userNotification.count({ where: { userId: ids.alice, kind: 'community_verified_answer' } })).toBe(1);

    await moderation.setVerified(bobReply, true, admin, `rq-${sfx}-5`, 'fr', at(51));
    const verified = await prisma.communityReply.findMany({ where: { postId: alicePost, isVerified: true } });
    expect(verified.map((r) => r.id)).toEqual([bobReply]);
    const alice = await viewer('alice');
    const detail = await posts.getPost(alice, alicePost, 'fr', at(52));
    expect(detail.replies.items[0]).toMatchObject({ id: bobReply, isVerified: true });
  });

  it('fil « Pour toi » : ordre SQL = formule publiée, à horloge fixée, pages sans doublon', async () => {
    const alice = await viewer('alice');
    const bob = await viewer('bob');
    const asOf = at(120);
    // Bob ne suit pas la bourse mais vise le pays mentionné.
    const feed = await posts.feed(bob, { tab: 'for_you', limit: 50 }, 'fr', asOf);
    const items = feed.items;
    expect(items.map((i) => i.id)).not.toContain(ids.malloryPost);
    const aliceItem = items.find((i) => i.id === alicePost)!;
    // 3 réponses visibles + 1 « utile » : ln(1 + 3 + 2) = ln 6 → « popular ».
    expect(aliceItem.forYouReasons).toEqual([
      'target_country',
      'target_level',
      'followed_discussion',
      'verified_answer',
      'popular',
    ]);

    const rows = await prisma.communityPost.findMany({ where: { id: { in: items.map((i) => i.id) } }, include: { mentions: true, follows: true } });
    const mirror = rows
      .map((r) => ({
        id: r.id,
        score: forYouScore({
          ageHours: (asOf.getTime() - r.createdAt.getTime()) / 3_600_000,
          followedScholarship: false,
          targetCountry: r.mentions.some((m) => m.countryId === countryId),
          targetLevel: r.mentions.some((m) => m.entityType === 'scholarship' && m.levels.includes('master')),
          followedDiscussion: r.follows.some((f) => f.memberId === bob.memberId),
          replyCount: r.replyCount,
          helpfulCount: r.helpfulCount,
          hasVerifiedAnswer: r.hasVerifiedAnswer,
        }),
      }))
      .sort((a, b) => b.score - a.score || (a.id < b.id ? 1 : -1));
    expect(items.map((i) => i.id)).toEqual(mirror.map((m) => m.id));

    // Déterminisme : même horloge, même résultat ; pagination par 1 sans trou ni doublon.
    const again = await posts.feed(bob, { tab: 'for_you', limit: 50 }, 'fr', asOf);
    expect(again.items.map((i) => i.id)).toEqual(items.map((i) => i.id));
    const paged: string[] = [];
    let page = await posts.feed(bob, { tab: 'for_you', limit: 1 }, 'fr', asOf);
    paged.push(...page.items.map((i) => i.id));
    while (page.nextCursor && paged.length < 60) {
      // L'horloge est dans le curseur : l'heure réelle passée ici n'y change rien.
      page = await posts.feed(bob, { tab: 'for_you', limit: 1, cursor: page.nextCursor }, 'fr', new Date());
      paged.push(...page.items.map((i) => i.id));
    }
    expect(paged).toEqual(items.map((i) => i.id));

    // Alice suit la bourse : la raison apparaît pour ses contenus d'autrui (ici aucun) ;
    // ses propres publications n'entrent jamais dans son fil.
    const aliceFeed = await posts.feed(alice, { tab: 'for_you', limit: 50 }, 'fr', asOf);
    expect(aliceFeed.items.map((i) => i.id)).not.toContain(alicePost);
  });

  it('épinglage : en tête de la première page, jamais dans `items`', async () => {
    const teamPost = await moderation.teamPost(
      { type: 'advice', title: 'Bienvenue dans la communauté', body: 'Lis la charte et pose tes questions sur les bourses.', as: 'kpb_team', pinned: true },
      admin,
      `rq-${sfx}-6`,
      'fr',
      at(60),
    );
    const bob = await viewer('bob');
    const feed = await posts.feed(bob, { tab: 'recent', limit: 50 }, 'fr', at(61));
    expect(feed.pinned.map((p) => p.id)).toContain(teamPost.id);
    expect(feed.items.map((p) => p.id)).not.toContain(teamPost.id);
    await moderation.setPinned(teamPost.id, false, admin, `rq-${sfx}-7`, 'fr', at(62));
  });

  it('statistiques simples', async () => {
    const stats = await moderation.stats(30, at(200));
    expect(stats.posts.total).toBeGreaterThanOrEqual(4);
    expect(stats.replies.byTeam).toBeGreaterThanOrEqual(1);
    expect(stats.reports.resolved).toBeGreaterThanOrEqual(4);
    expect(stats.autoHidden).toBeGreaterThanOrEqual(1);
    expect(stats.autoHiddenMedianHandlingHours).not.toBeNull();
    expect(stats.daily.length).toBeGreaterThanOrEqual(30);
  });

  it('export RGPD : publications, réponses, réactions, signalements, sanctions', async () => {
    const storage = { keyFromUrl: () => null, delete: jest.fn() } as unknown as StorageService;
    const profiles = new ProfilesService(prismaService, storage);
    const exported = (await profiles.exportMe(ids.mallory)) as unknown as { community: Record<string, unknown[]> };
    expect(exported.community.posts).toHaveLength(1);
    expect(exported.community.replies).toHaveLength(1);
    expect(exported.community.reportsFiled).toHaveLength(1);
    expect(exported.community.sanctions).toHaveLength(1);
    const alice = (await profiles.exportMe(ids.alice)) as unknown as { community: Record<string, unknown[]> };
    expect(alice.community.helpfulReactions).toHaveLength(1);
    expect(alice.community.charterAcceptances).toHaveLength(1);
  });

  it('suppression du compte : contenus effacés, compteurs d’autrui recalculés, signalements rédigés gardés', async () => {
    const storage = { keyFromUrl: () => null, delete: jest.fn() } as unknown as StorageService;
    const profiles = new ProfilesService(prismaService, storage);
    const bob = await viewer('bob');
    const fetchSpy = jest.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(null, { status: 200 }));
    try {
      await profiles.deleteMe(ids.bob);
    } finally {
      fetchSpy.mockRestore();
    }
    expect(await prisma.communityMember.count({ where: { id: bob.memberId } })).toBe(0);
    expect(await prisma.communityReply.count({ where: { authorMemberId: bob.memberId } })).toBe(0);
    const post = await prisma.communityPost.findUniqueOrThrow({ where: { id: alicePost } });
    // Restent : la réponse de Carol et celle de l'équipe ; « utile » de Bob retiré.
    expect(post).toMatchObject({ replyCount: 2, helpfulCount: 0, hasVerifiedAnswer: false });
    delete ids.bob;

    // Mallory supprime son compte : son signalement rédigé survit sans auteur.
    const mallory = await viewer('mallory');
    const fetchSpy2 = jest.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(null, { status: 200 }));
    try {
      await profiles.deleteMe(ids.mallory);
    } finally {
      fetchSpy2.mockRestore();
    }
    const kept = await prisma.communityReport.findMany({ where: { targetKey: `post:${ids.davePost}` } });
    expect(kept).toHaveLength(1);
    expect(kept[0].reporterMemberId).toBeNull();
    expect(await prisma.forumModerationAction.count({ where: { memberId: mallory.memberId } })).toBe(0);
    expect(await prisma.forumModerationAction.count({ where: { adminId: moderator.id } })).toBeGreaterThanOrEqual(3);
    await prisma.communityReport.deleteMany({ where: { id: { in: kept.map((k) => k.id) } } });
    delete ids.mallory;
  });

  it('purge : un contenu supprimé depuis plus de 30 jours disparaît', async () => {
    const dave = await viewer('dave');
    await posts.deletePost(dave, ids.davePost, at(70));
    expect(await purge.purge(new Date(at(70).getTime() + 29 * 86_400_000))).toMatchObject({ posts: 0 });
    const result = await purge.purge(new Date(at(70).getTime() + 31 * 86_400_000));
    expect(result.posts).toBeGreaterThanOrEqual(1);
    expect(await prisma.communityPost.count({ where: { id: ids.davePost } })).toBe(0);
  });
});
