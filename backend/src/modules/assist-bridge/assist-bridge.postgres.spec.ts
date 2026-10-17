import { randomUUID } from 'node:crypto';

import { HttpException } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

import { CommunityAccessService, type CommunityViewer } from '../community/community-access.service';
import { COMMUNITY_CHARTER_VERSION } from '../community/community.constants';
import { CommunityCatalogService } from '../community/community-catalog.service';
import { CommunityComposerService } from '../community/community-composer.service';
import { CommunityFilterConfigService } from '../community/community-filter-config.service';
import { CommunityModerationService } from '../community/community-moderation.service';
import { CommunityNotificationsService } from '../community/community-notifications.service';
import { CommunityPostsService } from '../community/community-posts.service';
import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import type { PushSenderService } from '../notifications/push-sender.service';
import type { PrismaService } from '../prisma/prisma.service';
import { ProfilesService } from '../profiles/profiles.service';
import type { StorageService } from '../storage/storage.service';
import { AssistBridgeQueueService } from './assist-bridge-queue.service';
import { AssistBridgeService } from './assist-bridge.service';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

async function statusOf(promise: Promise<unknown>): Promise<{ status: number; code?: string }> {
  try {
    await promise;
  } catch (error) {
    if (!(error instanceof HttpException)) throw error;
    const body = error.getResponse() as { code?: string };
    return { status: error.getStatus(), code: body.code };
  }
  throw new Error('expected a rejection');
}

const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;
const ENV = [
  'KPB_ASSIST_BRIDGE_MODE',
  'KPB_ASSIST_BRIDGE_COACH',
  'KPB_SCHOLARSHIP_MATCH_ENABLED',
  'KPB_EEF_ENABLED',
  'KPB_EEF_SPACE_ENABLED',
  'KPB_PUSH_QUIET_START',
  'KPB_PUSH_QUIET_END',
] as const;

/**
 * Bot « Passerelle » (C3 bis) de bout en bout sur PostgreSQL : publication,
 * réponse ou message au coach d'un élève → file → garde-fous → notification
 * privée (mode `on`) ou journal seul (`shadow`) ; idempotence, 72 h, 30 jours,
 * désinscription, sanction, fonction déjà utilisée, source masquée, source
 * coach fermée par défaut, clics, statistiques et liste sans texte coach,
 * export et suppression du compte.
 */
describePostgres('Passerelle — PostgreSQL', () => {
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
  const queue = new AssistBridgeQueueService(prismaService);
  const posts = new CommunityPostsService(prismaService, access, composer, filterConfig, notifications, catalog, undefined, queue);
  const moderation = new CommunityModerationService(
    prismaService,
    access,
    composer,
    filterConfig,
    notifications,
    posts,
    undefined,
    queue,
  );
  const bridge = new AssistBridgeService(prismaService, dispatcher);

  const previous = Object.fromEntries(ENV.map((k) => [k, process.env[k]]));
  const admin = { id: `adm-${sfx}`, fullName: 'Fatou Diallo', role: 'admin' };
  const ids: Record<string, string> = {};
  const packageCode = `visa-kit-${sfx}`;
  // Midi UTC à venir : hors des heures calmes du Niger (UTC+1), quel que soit
  // l'instant où la suite tourne.
  const noon = new Date();
  noon.setUTCHours(12, 0, 0, 0);
  if (noon.getTime() < Date.now()) noon.setTime(noon.getTime() + DAY);
  // Pas de 10 minutes : tout reste entre 12 h et 15 h UTC, loin de la nuit.
  const at = (step: number) => new Date(noon.getTime() + step * 10 * 60 * 1000);

  async function student(key: string, fullName: string, extra: { disabledNotificationTypes?: string[] } = {}) {
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
        ...extra,
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

  const eventOf = (source: 'community_post' | 'community_reply' | 'coach_message', sourceId: string) =>
    prisma.assistBridgeEvent.findUnique({ where: { source_sourceId: { source, sourceId } } });

  const bridgeNotifications = (key: string) =>
    prisma.userNotification.findMany({ where: { userId: ids[key], kind: 'assist_bridge' } });

  beforeAll(async () => {
    for (const k of ENV) delete process.env[k];
    process.env.KPB_SCHOLARSHIP_MATCH_ENABLED = 'true';
    await prisma.servicePackage.create({
      data: {
        code: packageCode,
        nameFr: 'Kit visa',
        nameEn: 'Visa kit',
        summaryFr: '-',
        summaryEn: '-',
        descriptionFr: '-',
        descriptionEn: '-',
        category: 'visa_kit',
        priceXOF: 10000,
        isActive: true,
      },
    });
    for (const [key, name] of [
      ['alice', 'Aïcha Konaté'],
      ['bob', 'Moussa Diallo'],
      ['carol', 'Awa Sossou'],
      ['eve', 'Fanta Keita'],
      ['frank', 'Issa Ouédraogo'],
      ['gina', 'Mariam Cissé'],
    ]) {
      await student(key, name);
    }
    await student('dave', 'Ali Traoré', { disabledNotificationTypes: ['assist_bridge'] });
  });

  afterAll(async () => {
    for (const k of ENV) {
      if (previous[k] === undefined) delete process.env[k];
      else process.env[k] = previous[k];
    }
    const all = Object.values(ids);
    await prisma.assistBridgeEvent.deleteMany({ where: { userId: { in: all } } });
    await prisma.communityMember.deleteMany({ where: { userId: { in: all } } });
    await prisma.coachConversation.deleteMany({ where: { userId: { in: all } } });
    await prisma.scholarshipMatchRun.deleteMany({ where: { userId: { in: all } } });
    await prisma.forumModerationAction.deleteMany({ where: { adminId: admin.id } });
    await prisma.adminAuditEvent.deleteMany({ where: { actorAdminId: admin.id } });
    await prisma.userNotification.deleteMany({ where: { userId: { in: all } } });
    await prisma.userProfile.deleteMany({ where: { id: { in: all } } });
    await prisma.servicePackage.deleteMany({ where: { code: packageCode } });
    await prisma.$disconnect();
  });

  let alicePost = '';

  it('shadow (défaut) : détecte et journalise, n’envoie rien ; idempotent', async () => {
    const post = await ask('alice', 'Relecture de CV', 'Bonjour, je cherche quelqu’un pour relire mon CV avant de postuler, qui peut m’aider ?');
    alicePost = post.id;
    const event = await eventOf('community_post', post.id);
    expect(event).toMatchObject({ userId: ids.alice, needId: 'document_review', status: 'detected', ruleVersion: 'ab-1' });
    // Une seconde mise en file ne crée rien : un même message ne déclenche jamais deux fois.
    expect(await queue.enqueueCommunity('post', post.id)).toBe(false);
    expect(await prisma.assistBridgeEvent.count({ where: { source: 'community_post', sourceId: post.id } })).toBe(1);

    const run = await bridge.processQueue(at(0));
    expect(run.processed).toBeGreaterThanOrEqual(1);
    expect(await eventOf('community_post', post.id)).toMatchObject({ status: 'skipped', statusReason: 'shadow', mode: 'shadow', sentAt: null });
    expect(await bridgeNotifications('alice')).toHaveLength(0);
  });

  it('on : notification privée (fil + chemin push), charge complète, sans numéro', async () => {
    process.env.KPB_ASSIST_BRIDGE_MODE = 'on';
    const post = await ask('bob', 'Quelle bourse pour moi ?', 'Je cherche une bourse pour faire un master en France, des idées ?');
    await bridge.processQueue(at(1));
    const event = (await eventOf('community_post', post.id))!;
    expect(event).toMatchObject({ status: 'sent', mode: 'on', needId: 'scholarship_match', pushOutcome: 'push_unconfigured' });
    const [notif] = await bridgeNotifications('bob');
    expect(notif).toMatchObject({ route: '/scholarship-match', dedupeKey: `assist_bridge:${event.id}`, titleFr: 'Trouve tes bourses dans l’app' });
    expect(notif.data).toEqual({
      needId: 'scholarship_match',
      feature: 'scholarship_match',
      eventId: event.id,
      whatsapp: 'kpb',
      sender: 'kpb_assistant',
      ruleVersion: 'ab-1',
    });
    expect(`${notif.bodyFr} ${JSON.stringify(notif.data)}`).not.toMatch(/\+?\d[\d\s]{7,}/);
    // Jamais de réponse publique : la publication n'a reçu aucune réponse.
    expect(await prisma.communityReply.count({ where: { postId: post.id } })).toBe(0);
  });

  it('72 h : un second besoin du même élève attend ; 30 jours : le même besoin n’est pas re-proposé', async () => {
    const visa = await ask('bob', 'Question sur le visa', 'Comment préparer ma demande de visa étudiant ? J’ai besoin d’aide pour les documents');
    await bridge.processQueue(at(2));
    expect(await eventOf('community_post', visa.id)).toMatchObject({ status: 'skipped', statusReason: 'user_cap' });

    const again = await ask('bob', 'Encore une bourse', 'Quelles bourses pour un master en informatique ? Je cherche encore');
    await bridge.processQueue(new Date(noon.getTime() + 4 * DAY));
    expect(await eventOf('community_post', again.id)).toMatchObject({ status: 'skipped', statusReason: 'need_cooldown' });
    expect(await bridgeNotifications('bob')).toHaveLength(1);
  });

  it('désinscription (clé assist_bridge) : rien n’est écrit, pas même la ligne du fil', async () => {
    const post = await ask('dave', 'Bourse ?', 'Je cherche une bourse pour étudier au Canada, qui peut m’aider ?');
    await bridge.processQueue(at(5));
    expect(await eventOf('community_post', post.id)).toMatchObject({ status: 'skipped', statusReason: 'opt_out' });
    expect(await bridgeNotifications('dave')).toHaveLength(0);
  });

  it('sanction (lecture seule) : exclu', async () => {
    const post = await ask('carol', 'Campus France', 'Campus France, je suis perdue, je ne sais pas par où commencer');
    const member = await viewer('carol');
    await prisma.communitySanction.create({
      data: { memberId: member.memberId, kind: 'read_only', reason: 'Test', endsAt: new Date(Date.now() + 7 * DAY), createdByAdminId: admin.id, createdByName: admin.fullName },
    });
    process.env.KPB_EEF_SPACE_ENABLED = 'true';
    await bridge.processQueue(at(6));
    expect(await eventOf('community_post', post.id)).toMatchObject({ status: 'skipped', statusReason: 'sanctioned' });
  });

  it('fonction déjà utilisée (run « Mes 10 bourses » < 14 j) ; fonction coupée', async () => {
    await prisma.scholarshipMatchRun.create({
      data: {
        userId: ids.eve,
        algorithmVersion: 'sm-1',
        trigger: 'wizard',
        profileHash: 'p',
        catalogHash: 'c',
        inputsSummary: {},
        items: [],
        excludedSummary: {},
        createdAt: new Date(at(7).getTime() - 3 * DAY),
      },
    });
    const used = await ask('eve', 'Question bourse master', 'Je cherche une bourse pour mon master, quelle bourse pour moi ?');
    await bridge.processQueue(at(7));
    expect(await eventOf('community_post', used.id)).toMatchObject({ status: 'skipped', statusReason: 'feature_used' });

    // Espace « Études en France » fermé : jamais une notification vers une porte close.
    delete process.env.KPB_EEF_SPACE_ENABLED;
    const eef = await ask('gina', 'Études en France', 'Comment ça marche la procédure Campus France ? Je suis perdue');
    await bridge.processQueue(at(8));
    expect(await eventOf('community_post', eef.id)).toMatchObject({ status: 'skipped', statusReason: 'feature_unavailable' });
  });

  it('jamais un contenu masqué : filtré à la publication (aucun événement) ou masqué avant traitement', async () => {
    const filtered = await ask('gina', 'Relecture', 'Qui peut relire mon CV ? Écris-moi au +227 90 11 22 33');
    expect((await prisma.communityPost.findUniqueOrThrow({ where: { id: filtered.id } })).status).not.toBe('visible');
    expect(await eventOf('community_post', filtered.id)).toBeNull();

    const later = await ask('gina', 'Ma lettre de motivation', 'Quelqu’un peut corriger ma lettre de motivation ? Je ne suis pas sûre du ton');
    expect((await eventOf('community_post', later.id))?.status).toBe('detected');
    await prisma.communityPost.update({ where: { id: later.id }, data: { status: 'hidden', statusReason: 'moderation' } });
    await bridge.processQueue(at(9));
    expect(await eventOf('community_post', later.id)).toMatchObject({ status: 'skipped', statusReason: 'source_not_visible' });
  });

  it('réponse : le besoin est attribué à l’AUTEUR de la réponse, jamais à celui de la publication', async () => {
    const reply = await posts.createReply(
      await viewer('frank'),
      alicePost,
      { body: 'Moi aussi je cherche quelqu’un pour relire ma lettre de motivation, qui peut m’aider ?' },
      'fr',
    );
    const event = await eventOf('community_reply', reply.id);
    expect(event).toMatchObject({ userId: ids.frank, needId: 'document_review' });
    await bridge.processQueue(at(10));
    expect(await eventOf('community_reply', reply.id)).toMatchObject({ status: 'sent' });
    expect(await bridgeNotifications('frank')).toHaveLength(1);
    expect(await bridgeNotifications('alice')).toHaveLength(0);
  });

  it('heures calmes : report (notBefore), puis envoi au matin', async () => {
    const post = await ask('gina', 'Orientation', 'Je ne sais pas quelle école choisir après mon bac, des conseils ?');
    const night = new Date(noon.getTime() + 10 * HOUR); // 22 h UTC = 23 h au Niger
    await bridge.processQueue(night);
    const deferred = (await eventOf('community_post', post.id))!;
    expect(deferred).toMatchObject({ status: 'detected', attempts: 0 });
    expect(deferred.notBefore!.getTime()).toBeGreaterThan(night.getTime());
    // Pas dû avant `notBefore`.
    expect((await bridge.processQueue(new Date(night.getTime() + HOUR))).processed).toBe(0);
    await bridge.processQueue(deferred.notBefore!);
    expect(await eventOf('community_post', post.id)).toMatchObject({ status: 'sent', needId: 'school_choice' });
  });

  let coachEventId = '';

  it('source coach : FERMÉE par défaut ; ouverte, l’événement ne garde aucun texte', async () => {
    const conv = await prisma.coachConversation.create({
      data: { userId: ids.carol, messages: { create: { role: 'user', content: 'Je cherche une bourse pour un master, quelle bourse pour moi ?' } } },
      include: { messages: true },
    });
    const message = conv.messages[0];
    expect(await queue.enqueueCoach(ids.carol, message.id, message.content)).toBe(false);
    expect(await eventOf('coach_message', message.id)).toBeNull();

    process.env.KPB_ASSIST_BRIDGE_COACH = 'true';
    // Carol est sanctionnée dans la communauté : on prend Alice, jamais notifiée.
    const conv2 = await prisma.coachConversation.create({
      data: { userId: ids.alice, messages: { create: { role: 'user', content: 'Comment préparer ma demande de visa étudiant ? Besoin d’aide' } } },
      include: { messages: true },
    });
    const m2 = conv2.messages[0];
    expect(await queue.enqueueCoach(ids.alice, m2.id, m2.content)).toBe(true);
    const event = (await eventOf('coach_message', m2.id))!;
    coachEventId = event.id;
    expect(JSON.stringify(event)).not.toContain('visa étudiant');
    await bridge.processQueue(at(11));
    expect(await eventOf('coach_message', m2.id)).toMatchObject({ status: 'sent', needId: 'visa' });

    // Refermée après détection : l'événement en attente est abandonné.
    const conv3 = await prisma.coachConversation.create({
      data: { userId: ids.eve, messages: { create: { role: 'user', content: 'Je voudrais être accompagné pour monter mon dossier de candidature' } } },
      include: { messages: true },
    });
    const m3 = conv3.messages[0];
    expect(await queue.enqueueCoach(ids.eve, m3.id, m3.content)).toBe(true);
    delete process.env.KPB_ASSIST_BRIDGE_COACH;
    await bridge.processQueue(at(12));
    expect(await eventOf('coach_message', m3.id)).toMatchObject({ status: 'skipped', statusReason: 'coach_source_off' });
  });

  it('clics : ouvert fonction / WhatsApp / fermé, pour le destinataire seulement', async () => {
    const event = (await prisma.assistBridgeEvent.findFirst({ where: { userId: ids.bob, status: 'sent' } }))!;
    expect(await bridge.recordAction(ids.bob, event.id, 'opened_feature', at(13))).toEqual({ id: event.id, status: 'opened_feature' });
    await bridge.recordAction(ids.bob, event.id, 'opened_whatsapp', at(14));
    await bridge.recordAction(ids.bob, event.id, 'opened_feature', at(15));
    const after = (await prisma.assistBridgeEvent.findUnique({ where: { id: event.id } }))!;
    // La première date est gardée ; le statut suit la dernière action.
    expect(after.openedFeatureAt?.toISOString()).toBe(at(13).toISOString());
    expect(after.openedWhatsappAt?.toISOString()).toBe(at(14).toISOString());
    expect(after.status).toBe('opened_feature');
    expect(await statusOf(bridge.recordAction(ids.alice, event.id, 'dismissed'))).toMatchObject({
      status: 404,
      code: 'assist_bridge_event_not_found',
    });
    const skipped = (await prisma.assistBridgeEvent.findFirst({ where: { userId: ids.dave, status: 'skipped' } }))!;
    expect(await statusOf(bridge.recordAction(ids.dave, skipped.id, 'dismissed'))).toMatchObject({ status: 404 });
  });

  it('rétablissement par l’équipe : un contenu de membre rétabli est analysé', async () => {
    const post = await ask('frank', 'Question sur le visa', 'Comment obtenir mon visa étudiant pour la France ? Qui peut m’aider ?');
    await prisma.assistBridgeEvent.deleteMany({ where: { source: 'community_post', sourceId: post.id } });
    await prisma.communityPost.update({ where: { id: post.id }, data: { status: 'pending_review', statusReason: 'reports_threshold' } });
    await moderation.contentAction(
      'post',
      post.id,
      { action: 'restore', reason: 'Contenu conforme' },
      { id: admin.id, fullName: admin.fullName, role: 'admin' },
      randomUUID(),
      'fr',
    );
    expect(await eventOf('community_post', post.id)).toMatchObject({ userId: ids.frank, needId: 'visa', status: 'detected' });
  });

  it('off : aucune détection, aucun traitement', async () => {
    process.env.KPB_ASSIST_BRIDGE_MODE = 'off';
    try {
      const post = await ask('gina', 'Relecture', 'Qui peut relire mon CV ? Je cherche des conseils');
      expect(await eventOf('community_post', post.id)).toBeNull();
      expect(await bridge.processQueue(at(16))).toEqual({ processed: 0, sent: 0, skipped: 0, deferred: 0 });
    } finally {
      process.env.KPB_ASSIST_BRIDGE_MODE = 'on';
    }
  });

  it('console : statistiques par besoin ; liste sans texte pour le coach, extrait pour un contenu public', async () => {
    const stats = await bridge.stats(30, at(17));
    expect(stats.mode).toBe('on');
    expect(stats.coachSource).toBe(false);
    expect(stats.totals.detected).toBeGreaterThanOrEqual(10);
    const scholarship = stats.needs.find((n) => n.needId === 'scholarship_match')!;
    expect(scholarship.sent).toBeGreaterThanOrEqual(1);
    expect(scholarship.openedFeature).toBeGreaterThanOrEqual(1);
    expect(scholarship.openedWhatsapp).toBeGreaterThanOrEqual(1);
    expect(scholarship.skipped.need_cooldown).toBeGreaterThanOrEqual(1);
    expect(stats.totals.skipped.shadow).toBeGreaterThanOrEqual(1);
    expect(stats.totals.skipped.opt_out).toBeGreaterThanOrEqual(1);
    expect(stats.bySource.coach_message).toBeGreaterThanOrEqual(2);

    const coach = await bridge.list({ source: 'coach_message' }, undefined, 50);
    expect(coach.items.length).toBeGreaterThanOrEqual(2);
    for (const item of coach.items) {
      expect(item.excerpt).toBeNull();
      expect(item.postId).toBeNull();
      expect(JSON.stringify(item)).not.toMatch(/visa étudiant|dossier de candidature/);
    }
    expect(coach.items.map((i) => i.id)).toContain(coachEventId);
    const community = await bridge.list({ source: 'community_post', needId: 'scholarship_match' }, undefined, 50);
    expect(community.items.some((i) => i.excerpt === 'Quelle bourse pour moi ?')).toBe(true);
    const hidden = await bridge.list({ status: 'skipped' }, undefined, 100);
    // Un contenu masqué ne montre jamais d'extrait.
    expect(hidden.items.filter((i) => i.statusReason === 'source_not_visible').every((i) => i.excerpt === null)).toBe(true);
    // Pagination.
    const page = await bridge.list({}, undefined, 2);
    expect(page.nextCursor).toBeTruthy();
    const next = await bridge.list({}, page.nextCursor!, 2);
    expect(next.items[0].id).not.toBe(page.items[0].id);
    expect(bridge.catalog()).toMatchObject({ version: 'ab-1', mode: 'on' });
  });

  it('purge : au-delà de 12 mois, l’événement disparaît', async () => {
    const old = await prisma.assistBridgeEvent.create({
      data: {
        userId: ids.gina,
        source: 'community_post',
        sourceId: `old-${sfx}`,
        needId: 'visa',
        ruleId: 'visa.prepare',
        ruleVersion: 'ab-1',
        status: 'skipped',
        statusReason: 'shadow',
        createdAt: new Date(Date.now() - 400 * DAY),
      },
    });
    expect(await bridge.purge()).toBeGreaterThanOrEqual(1);
    expect(await prisma.assistBridgeEvent.findUnique({ where: { id: old.id } })).toBeNull();
  });

  it('RGPD : export des événements ; suppression du compte en cascade', async () => {
    const storage = { keyFromUrl: () => null, delete: jest.fn() } as unknown as StorageService;
    const profiles = new ProfilesService(prismaService, storage);
    const exported = (await profiles.exportMe(ids.bob)) as unknown as { assistBridgeEvents: Array<Record<string, unknown>> };
    expect(exported.assistBridgeEvents.length).toBeGreaterThanOrEqual(3);
    expect(exported.assistBridgeEvents[0]).toEqual(
      expect.objectContaining({ source: 'community_post', needId: 'scholarship_match', status: 'opened_feature' }),
    );
    expect(Object.keys(exported.assistBridgeEvents[0])).not.toContain('userId');

    const fetchSpy = jest.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(null, { status: 200 }));
    try {
      await profiles.deleteMe(ids.bob);
    } finally {
      fetchSpy.mockRestore();
    }
    expect(await prisma.assistBridgeEvent.count({ where: { userId: ids.bob } })).toBe(0);
    delete ids.bob;
  });
});
