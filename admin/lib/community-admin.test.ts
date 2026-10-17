import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { afterEach, describe, expect, it, vi } from 'vitest';

import { InternalRole } from './admin-capabilities';
import {
  ASSIST_EVENT_STATUSES,
  ASSIST_LIST_STATUSES,
  ASSIST_NEED_IDS,
  ASSIST_SKIP_REASONS,
  ASSIST_SOURCES,
  assistExcerpt,
  assistSkippedEntries,
  availableContentActions,
  BADGES,
  BOT_LIST_STATUSES,
  BOT_STATUSES,
  botDraftActions,
  isBotDraftStale,
  safeSourceUrl,
  validateBotText,
  buildSanctionPayload,
  COMMUNITY_TABS,
  communityAdminApi,
  communityErrorMessageKey,
  communityHref,
  communityPermissions,
  CONTENT_STATUSES,
  enumMessageKey,
  FILTER_FLAGS,
  isNewAccount,
  KNOWN_ERROR_CODES,
  LOG_ACTIONS,
  mostReportedMembers,
  normalizeDomainInput,
  normalizeTermInput,
  plainText,
  POST_TYPES,
  type QueueItem,
  QUEUE_KINDS,
  readCommunityError,
  REPORT_REASONS,
  resolveCommunityTab,
  SHORTCUT_KEYS,
  shortcutFor,
  sortQueue,
  STATUS_REASONS,
  urgencyScore,
  validateReason,
  validateTeamPost,
  validateTeamReply,
  visibleCommunityTabs,
  visibleIdentity,
} from './community-admin';

// ── Messages ────────────────────────────────────────────────────────────────

type Messages = Record<string, unknown>;
const load = (locale: string): Messages =>
  JSON.parse(readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'));
const fr = load('fr');
const en = load('en');

function lookup(messages: Messages, key: string): unknown {
  return key
    .split('.')
    .reduce<unknown>(
      (current, part) => (current && typeof current === 'object' ? (current as Messages)[part] : undefined),
      messages,
    );
}

function leafKeys(value: unknown, prefix = ''): string[] {
  if (value && typeof value === 'object') {
    return Object.entries(value as Messages).flatMap(([key, child]) =>
      leafKeys(child, prefix ? `${prefix}.${key}` : key),
    );
  }
  return [prefix];
}

function expectInBothLocales(key: string) {
  expect({ key, fr: typeof lookup(fr, key) }).toEqual({ key, fr: 'string' });
  expect({ key, en: typeof lookup(en, key) }).toEqual({ key, en: 'string' });
}

const COMPONENTS_DIR = join(__dirname, '..', 'components', 'community');
const SOURCES = [
  ...readdirSync(COMPONENTS_DIR)
    .filter((f) => f.endsWith('.tsx') && !f.endsWith('.test.tsx'))
    .map((f) => readFileSync(join(COMPONENTS_DIR, f), 'utf8')),
  readFileSync(join(__dirname, 'community-admin.ts'), 'utf8'),
];

describe('messages de la console communauté', () => {
  it('mêmes clés et mêmes variables en français et en anglais, aucun texte vide', () => {
    const frKeys = leafKeys(lookup(fr, 'communityAdmin'), 'communityAdmin').sort();
    expect(leafKeys(lookup(en, 'communityAdmin'), 'communityAdmin').sort()).toEqual(frKeys);
    const vars = (text: unknown) => [...String(text).matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();
    for (const key of frKeys) {
      expect({ key, vars: vars(lookup(en, key)) }).toEqual({ key, vars: vars(lookup(fr, key)) });
      expect(String(lookup(fr, key)).trim()).not.toBe('');
      expect(String(lookup(en, key)).trim()).not.toBe('');
    }
  });

  it('couvrent chaque clé écrite en toutes lettres dans les composants', () => {
    const used = new Set<string>();
    for (const source of SOURCES) {
      for (const m of source.matchAll(/['`](communityAdmin\.[A-Za-z_.]+[A-Za-z_])['`]/g)) used.add(m[1]);
    }
    expect(used.size).toBeGreaterThan(150);
    for (const key of used) expectInBothLocales(key);
  });

  it('couvrent les clés dynamiques (actions, sanctions, onglets, raccourcis, files, erreurs)', () => {
    for (const a of ['restore', 'hide', 'delete', 'dismiss_reports']) {
      for (const part of ['title', 'body', 'cta', 'done']) expectInBothLocales(`communityAdmin.action.${a}.${part}`);
    }
    for (const k of ['warning', 'read_only', 'ban']) {
      for (const part of ['title', 'body', 'cta', 'done']) expectInBothLocales(`communityAdmin.sanction.${k}.${part}`);
    }
    for (const tab of COMMUNITY_TABS) expectInBothLocales(`communityAdmin.tab.${tab}`);
    for (const [, action] of SHORTCUT_KEYS) expectInBothLocales(`communityAdmin.shortcuts.${action}`);
    for (const kind of QUEUE_KINDS) expectInBothLocales(`communityAdmin.queue.kind.${kind}`);
    for (const code of KNOWN_ERROR_CODES) expectInBothLocales(`communityAdmin.errors.${code}`);
    for (const key of [
      'reasonRequired',
      'reasonTooShort',
      'reasonTooLong',
      'durationInvalid',
      'bodyRequired',
      'bodyTooLong',
      'titleLength',
      'postBodyLength',
      'domainInvalid',
      'termInvalid',
      'unavailable',
      'forbidden',
      'rateLimited',
      'server',
    ]) {
      expectInBothLocales(`communityAdmin.errors.${key}`);
    }
  });

  it('ont un libellé pour chaque valeur d’énumération du contrat', () => {
    const groups: Array<[Parameters<typeof enumMessageKey>[0], readonly string[]]> = [
      ['flag', FILTER_FLAGS],
      ['reportReason', REPORT_REASONS],
      ['status', CONTENT_STATUSES],
      ['statusReason', STATUS_REASONS],
      ['badge', BADGES],
      ['postType', POST_TYPES],
      ['sanction', ['warning', 'read_only', 'ban']],
      ['target', ['post', 'reply', 'member']],
      ['logAction', LOG_ACTIONS],
    ];
    for (const [group, values] of groups) {
      for (const value of values) {
        const key = enumMessageKey(group, value);
        expect(key).not.toBeNull();
        expectInBothLocales(key as string);
      }
    }
  });

  it('une valeur inconnue (contrat additif) n’a pas de clé : affichée brute', () => {
    expect(enumMessageKey('flag', 'crypto_wallet')).toBeNull();
    expect(enumMessageKey('badge', 'mentor')).toBeNull();
  });
});

// ── Rôles ───────────────────────────────────────────────────────────────────

describe('rôles (présentation seulement)', () => {
  const roles = Object.values(InternalRole);
  const who = (pick: (p: ReturnType<typeof communityPermissions>) => boolean) =>
    roles.filter((r) => pick(communityPermissions(r))).sort();

  it('R = Moderator, ContentManager, Admin, SuperAdmin', () => {
    expect(who((p) => p.moderate)).toEqual(
      [InternalRole.Moderator, InternalRole.ContentManager, InternalRole.Admin, InternalRole.SuperAdmin].sort(),
    );
  });

  it('S (sanctions) = Moderator, Admin, SuperAdmin — pas ContentManager', () => {
    expect(who((p) => p.sanction)).toEqual([InternalRole.Moderator, InternalRole.Admin, InternalRole.SuperAdmin].sort());
  });

  it('C (filtre) = Admin, SuperAdmin', () => {
    expect(who((p) => p.configureFilters)).toEqual([InternalRole.Admin, InternalRole.SuperAdmin].sort());
  });

  it('identité réelle réservée aux administrateurs (minimisation)', () => {
    expect(who((p) => p.viewIdentity)).toEqual([InternalRole.Admin, InternalRole.SuperAdmin].sort());
  });

  it('lecture des discussions = R + Counselor (révision 1)', () => {
    expect(who((p) => p.read)).toEqual(
      [
        InternalRole.Counselor,
        InternalRole.Moderator,
        InternalRole.ContentManager,
        InternalRole.Admin,
        InternalRole.SuperAdmin,
      ].sort(),
    );
  });

  it('conseiller : « Contenus » seul, ni modération, ni sanction, ni identité', () => {
    const p = communityPermissions(InternalRole.Counselor);
    expect(p).toEqual({ read: true, moderate: false, sanction: false, configureFilters: false, viewIdentity: false });
    const tabs = visibleCommunityTabs(p);
    expect(tabs).toEqual(['content']);
    // Un lien vers la file ou un membre retombe sur « Contenus ».
    expect(resolveCommunityTab({ tab: 'queue', post: null, member: null }, tabs)).toBe('content');
    expect(resolveCommunityTab({ tab: null, post: null, member: 'cm_1' }, tabs)).toBe('content');
  });

  it('rôle inconnu ou absent : aucun droit, aucun onglet', () => {
    for (const role of [null, undefined, 'advisor', InternalRole.Commercial]) {
      const p = communityPermissions(role);
      expect(p).toEqual({ read: false, moderate: false, sanction: false, configureFilters: false, viewIdentity: false });
      expect(visibleCommunityTabs(p)).toEqual([]);
    }
    expect(visibleCommunityTabs(communityPermissions(InternalRole.ContentManager))).toContain('taxonomy');
  });

  it('sans le droit d’identité, ni e-mail ni nom complet', () => {
    const author = {
      kind: 'member',
      memberId: 'cm_1',
      displayName: 'Aïcha K.',
      countryName: 'Niger',
      badges: [],
      fullName: 'Aïcha Kader',
      email: 'aicha@example.org',
      accountCreatedAt: '2026-10-15T00:00:00.000Z',
    };
    expect(visibleIdentity(author, false)).toEqual({ fullName: null, email: null, accountCreatedAt: null });
    expect(visibleIdentity(author, true).email).toBe('aicha@example.org');
  });
});

// ── Saisie ──────────────────────────────────────────────────────────────────

describe('motif obligatoire et sanctions', () => {
  it('motif : 3 à 500 caractères, espaces de bord retirés', () => {
    expect(validateReason('')).toBe('reasonRequired');
    expect(validateReason('   ')).toBe('reasonRequired');
    expect(validateReason(' ab ')).toBe('reasonTooShort');
    expect(validateReason('abc')).toBeNull();
    expect(validateReason('x'.repeat(500))).toBeNull();
    expect(validateReason('x'.repeat(501))).toBe('reasonTooLong');
  });

  it('lecture seule : durée 1..365 obligatoire', () => {
    const base = { kind: 'read_only' as const, reason: 'Spam répété', hideContent: false };
    expect(buildSanctionPayload({ ...base, durationDays: '' })).toEqual({ ok: false, errors: { durationDays: 'durationInvalid' } });
    expect(buildSanctionPayload({ ...base, durationDays: '0' }).ok).toBe(false);
    expect(buildSanctionPayload({ ...base, durationDays: '366' }).ok).toBe(false);
    expect(buildSanctionPayload({ ...base, durationDays: '2.5' }).ok).toBe(false);
    expect(buildSanctionPayload({ ...base, durationDays: '7' })).toEqual({
      ok: true,
      body: { kind: 'read_only', reason: 'Spam répété', durationDays: 7 },
    });
  });

  it('avertissement et bannissement : jamais de durée ; hideContent seulement au bannissement', () => {
    expect(buildSanctionPayload({ kind: 'warning', reason: 'Ton agressif', durationDays: '7', hideContent: true })).toEqual({
      ok: true,
      body: { kind: 'warning', reason: 'Ton agressif' },
    });
    expect(buildSanctionPayload({ kind: 'ban', reason: 'Arnaque avérée', durationDays: '7', hideContent: true })).toEqual({
      ok: true,
      body: { kind: 'ban', reason: 'Arnaque avérée', hideContent: true },
    });
  });

  it('motif manquant : refusé avant tout appel', () => {
    expect(buildSanctionPayload({ kind: 'ban', reason: ' ', durationDays: '', hideContent: false })).toEqual({
      ok: false,
      errors: { reason: 'reasonRequired' },
    });
  });

  it('actions de contenu selon l’état (§8.4)', () => {
    expect(availableContentActions({ status: 'pending_review', statusReason: 'auto_filter', openReportCount: 0 })).toEqual([
      'restore',
      'hide',
      'delete',
    ]);
    expect(availableContentActions({ status: 'visible', statusReason: null, openReportCount: 2 })).toEqual([
      'hide',
      'delete',
      'dismiss_reports',
    ]);
    expect(availableContentActions({ status: 'hidden', statusReason: 'moderation', openReportCount: 0 })).toEqual([
      'restore',
      'delete',
    ]);
    // Supprimé par son auteur : rien à rétablir (409 côté serveur).
    expect(availableContentActions({ status: 'deleted', statusReason: 'author_deleted', openReportCount: 1 })).toEqual([]);
    expect(availableContentActions({ status: 'deleted', statusReason: 'moderation_deleted', openReportCount: 0 })).toEqual([
      'restore',
    ]);
  });

  it('réponse et publication de l’équipe : limites du contrat', () => {
    expect(validateTeamReply(' a ')).toBe('bodyRequired');
    expect(validateTeamReply('Bonjour !')).toBeNull();
    expect(validateTeamReply('x'.repeat(3001))).toBe('bodyTooLong');
    expect(validateTeamPost({ title: 'Court', body: 'x'.repeat(20) })).toEqual({ title: 'titleLength' });
    expect(validateTeamPost({ title: 'Un titre correct', body: 'trop court' })).toEqual({ body: 'postBodyLength' });
  });

  it('liste blanche : hôte nu ou suffixe, URL collée ramenée à l’hôte', () => {
    expect(normalizeDomainInput('https://www.Univ-Lyon1.fr/formations?x=1')).toBe('univ-lyon1.fr');
    expect(normalizeDomainInput('*.univ-lyon1.fr')).toBe('*.univ-lyon1.fr');
    expect(normalizeDomainInput('pas un domaine')).toBeNull();
    expect(normalizeDomainInput('localhost')).toBeNull();
    expect(normalizeTermInput('  frais   d’agent ')).toBe('frais d’agent');
    expect(normalizeTermInput('x')).toBeNull();
  });
});

// ── File ────────────────────────────────────────────────────────────────────

function item(partial: Partial<QueueItem> & { key: string }): QueueItem {
  return {
    targetType: 'post',
    post: null,
    reply: null,
    member: null,
    parentPost: null,
    reports: [],
    openReportCount: 0,
    flaggedAt: '2026-10-17T08:00:00.000Z',
    waitingHours: 1,
    ...partial,
  };
}

const post = (flags: string[], isMinor = false) => ({
  id: 'cp_1',
  type: 'question',
  title: 'Titre',
  author: { kind: 'member', memberId: 'cm_1', displayName: 'A. B.', countryName: null, badges: [], isMinor },
  createdAt: '2026-10-17T08:00:00.000Z',
  status: 'pending_review',
  statusReason: 'auto_filter',
  filterFlags: flags,
});

describe('file : urgence et ancienneté', () => {
  it('score explicable : arnaque, signalement grave, signalements, mineur, délai dépassé', () => {
    expect(urgencyScore(item({ key: 'a' }))).toBe(0);
    expect(urgencyScore(item({ key: 'b', post: post(['money_request']) }))).toBe(5);
    expect(urgencyScore(item({ key: 'c', post: post(['external_link'], true) }))).toBe(2);
    expect(
      urgencyScore(
        item({
          key: 'd',
          openReportCount: 9,
          waitingHours: 30,
          reports: [{ id: 'r', targetType: 'post', targetId: 'cp_1', reason: 'scam', status: 'open', createdAt: '' }],
        }),
      ),
    ).toBe(4 + 5 + 3);
  });

  it('« plus ancien d’abord » et « plus urgent d’abord » (départage : ancienneté)', () => {
    const old = item({ key: 'old', waitingHours: 20 });
    const scam = item({ key: 'scam', waitingHours: 2, post: post(['whatsapp']) });
    const mid = item({ key: 'mid', waitingHours: 10 });
    expect(sortQueue([scam, mid, old], 'oldest').map((i) => i.key)).toEqual(['old', 'mid', 'scam']);
    expect(sortQueue([old, mid, scam], 'urgency').map((i) => i.key)).toEqual(['scam', 'old', 'mid']);
  });

  it('membres les plus signalés d’abord', () => {
    const member = (id: string) => ({ kind: 'member', memberId: id, displayName: id, countryName: null, badges: [] });
    const rows = mostReportedMembers([
      item({ key: 'm1', targetType: 'member', member: member('m1'), openReportCount: 1 }),
      item({ key: 'p', post: post([]) }),
      item({ key: 'm2', targetType: 'member', member: member('m2'), openReportCount: 4 }),
    ]);
    expect(rows.map((r) => r.key)).toEqual(['m2', 'm1']);
  });

  it('raccourcis : ignorés pendant la saisie et avec un modificateur', () => {
    expect(shortcutFor({ key: 'j' })).toBe('next');
    expect(shortcutFor({ key: 'M' })).toBe('hide');
    expect(shortcutFor({ key: 'b' })).toBe('ban');
    expect(shortcutFor({ key: 'b', targetTag: 'TEXTAREA' })).toBeNull();
    expect(shortcutFor({ key: 'b', targetTag: 'input' })).toBeNull();
    expect(shortcutFor({ key: 'b', targetEditable: true })).toBeNull();
    expect(shortcutFor({ key: 'r', ctrlKey: true })).toBeNull();
    expect(shortcutFor({ key: 'r', metaKey: true })).toBeNull();
    expect(shortcutFor({ key: 'z' })).toBeNull();
  });

  it('compte récent : moins de 7 jours, dérivé de la date', () => {
    const now = Date.parse('2026-10-17T12:00:00.000Z');
    expect(isNewAccount({ accountCreatedAt: '2026-10-12T12:00:00.000Z' }, now)).toBe(true);
    expect(isNewAccount({ accountCreatedAt: '2026-10-01T12:00:00.000Z' }, now)).toBe(false);
    expect(isNewAccount({ accountCreatedAt: null }, now)).toBe(false);
    // Révision 1 : le drapeau du serveur prime sur la date.
    expect(isNewAccount({ accountCreatedAt: '2026-10-01T12:00:00.000Z', isNewAccount: true }, now)).toBe(true);
    expect(isNewAccount({ accountCreatedAt: '2026-10-16T12:00:00.000Z', isNewAccount: false }, now)).toBe(false);
  });

  it('texte brut depuis les segments (mentions et hashtags lisibles)', () => {
    expect(
      plainText({
        segments: [
          { kind: 'text', text: 'Qui a eu ' },
          { kind: 'mention', type: 'scholarship', id: 'x', label: 'Bourse Eiffel' },
          { kind: 'text', text: ' ? ' },
          { kind: 'hashtag', tag: 'campusfrance', display: 'CampusFrance' },
          { kind: 'futur' },
        ],
      }),
    ).toBe('Qui a eu @Bourse Eiffel ? #CampusFrance');
    expect(plainText({ body: 'brut' })).toBe('brut');
  });
});

// ── Erreurs ─────────────────────────────────────────────────────────────────

function apiError(status: number, body: unknown) {
  const text = typeof body === 'string' ? body : JSON.stringify(body);
  return Object.assign(new Error('x'), { status, body: text });
}

describe('erreurs', () => {
  it('route absente (backend plus ancien) → « bientôt », pas une alerte', () => {
    const info = readCommunityError(
      apiError(404, { message: 'Cannot GET /api/admin/community/queue?kind=all', error: 'Not Found', statusCode: 404 }),
    );
    expect(info.unavailable).toBe(true);
    expect(communityErrorMessageKey(info)).toBe('communityAdmin.errors.unavailable');
  });

  it('404 avec un code du contrat : vraie erreur, message dédié', () => {
    const info = readCommunityError(apiError(404, { statusCode: 404, code: 'community_post_not_found', message: 'Post not found.' }));
    expect(info.unavailable).toBe(false);
    expect(communityErrorMessageKey(info)).toBe('communityAdmin.errors.community_post_not_found');
  });

  it('409 limite d’épinglage, avec details', () => {
    const info = readCommunityError(apiError(409, { statusCode: 409, code: 'community_pin_limit', details: { max: 3 }, message: 'x' }));
    expect(info.details).toEqual({ max: 3 });
    expect(communityErrorMessageKey(info)).toBe('communityAdmin.errors.community_pin_limit');
  });

  it('403 rôle, 429, 5xx et panne réseau', () => {
    expect(communityErrorMessageKey(readCommunityError(apiError(403, { statusCode: 403, message: 'Forbidden resource' })))).toBe(
      'communityAdmin.errors.forbidden',
    );
    expect(communityErrorMessageKey(readCommunityError(apiError(429, 'Too Many Requests')))).toBe('communityAdmin.errors.rateLimited');
    expect(communityErrorMessageKey(readCommunityError(apiError(502, '<html>')))).toBe('communityAdmin.errors.server');
    expect(communityErrorMessageKey(readCommunityError(new TypeError('Failed to fetch')))).toBe('communityAdmin.errors.server');
  });

  it('400 de validation sans code : le message du serveur est gardé', () => {
    expect(communityErrorMessageKey(readCommunityError(apiError(400, { statusCode: 400, message: ['reason too short'] })))).toBeNull();
  });
});

// ── Navigation ──────────────────────────────────────────────────────────────

describe('navigation dans l’URL', () => {
  it('liens d’onglet, de discussion et de membre', () => {
    expect(communityHref({ tab: 'queue' })).toBe('/community');
    expect(communityHref({ tab: 'settings' })).toBe('/community?tab=settings');
    expect(communityHref({ tab: 'content', post: 'cp_1' })).toBe('/community?tab=content&post=cp_1');
  });

  it('une discussion ouvre « Contenus », un membre « Membres », sinon la file', () => {
    expect(resolveCommunityTab({ tab: null, post: 'cp_1', member: null })).toBe('content');
    expect(resolveCommunityTab({ tab: 'log', post: null, member: 'cm_1' })).toBe('members');
    expect(resolveCommunityTab({ tab: 'nimporte', post: null, member: null })).toBe('queue');
    expect(resolveCommunityTab({ tab: 'dashboard', post: null, member: null })).toBe('dashboard');
  });
});

// ── Appels ──────────────────────────────────────────────────────────────────

describe('appels du contrat', () => {
  afterEach(() => vi.unstubAllGlobals());

  function stub(response: unknown = {}) {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify(response)),
    });
    vi.stubGlobal('fetch', fetchMock);
    return fetchMock;
  }

  const call = (mock: ReturnType<typeof vi.fn>) => {
    const [url, init] = mock.mock.calls[0] as [string, { method: string; body?: string }];
    return { path: url.replace('http://127.0.0.1:4000/api', ''), method: init.method, body: init.body ? JSON.parse(init.body) : undefined };
  };

  it('file, action avec motif, sanction, vérification (PUT), épinglage (PUT)', async () => {
    let mock = stub({ counts: {}, items: [], nextCursor: null });
    await communityAdminApi.queue('auto_hidden');
    expect(call(mock)).toEqual({ path: '/admin/community/queue?kind=auto_hidden&limit=30', method: 'GET', body: undefined });

    mock = stub();
    await communityAdminApi.replyAction('cr_9', { action: 'hide', reason: 'Numéro WhatsApp', notifyAuthor: false });
    expect(call(mock)).toEqual({
      path: '/admin/community/replies/cr_9/actions',
      method: 'POST',
      body: { action: 'hide', reason: 'Numéro WhatsApp', notifyAuthor: false },
    });

    mock = stub();
    await communityAdminApi.sanction('cm_1', { kind: 'read_only', reason: 'Spam', durationDays: 7 });
    expect(call(mock)).toEqual({
      path: '/admin/community/members/cm_1/sanctions',
      method: 'POST',
      body: { kind: 'read_only', reason: 'Spam', durationDays: 7 },
    });

    mock = stub();
    await communityAdminApi.setVerified('cr_2', true);
    expect(call(mock)).toEqual({ path: '/admin/community/replies/cr_2/verified', method: 'PUT', body: { verified: true } });

    mock = stub();
    await communityAdminApi.setPinned('cp_1', false);
    expect(call(mock)).toEqual({ path: '/admin/community/posts/cp_1/pin', method: 'PUT', body: { pinned: false } });

    mock = stub();
    await communityAdminApi.teamReply('cp_1', { body: 'Bonjour', as: 'kpb_advisor', verified: true });
    expect(call(mock)).toEqual({
      path: '/admin/community/posts/cp_1/replies',
      method: 'POST',
      body: { body: 'Bonjour', as: 'kpb_advisor', verified: true },
    });
  });

  it('révision 1 : sanctions en cours, classement des signalements d’un membre', async () => {
    let mock = stub({ items: [], nextCursor: null });
    await communityAdminApi.sanctions();
    expect(call(mock)).toEqual({ path: '/admin/community/sanctions?status=active&limit=30', method: 'GET', body: undefined });
    mock = stub({ items: [], nextCursor: null });
    await communityAdminApi.sanctions('all', 'abc');
    expect(call(mock).path).toBe('/admin/community/sanctions?status=all&cursor=abc&limit=30');
    mock = stub({ memberId: 'cm_1', dismissed: 2 });
    await expect(communityAdminApi.dismissMemberReports('cm_1', 'Signalements infondés')).resolves.toEqual({
      memberId: 'cm_1',
      dismissed: 2,
    });
    expect(call(mock)).toEqual({
      path: '/admin/community/members/cm_1/reports/dismiss',
      method: 'POST',
      body: { reason: 'Signalements infondés' },
    });
  });

  it('recherche : filtres vides omis, identifiants encodés', async () => {
    let mock = stub({ items: [], nextCursor: null });
    await communityAdminApi.posts({ q: 'campus france', status: '', type: 'question' });
    expect(call(mock).path).toBe('/admin/community/posts?q=campus+france&type=question&limit=20');
    mock = stub({});
    await communityAdminApi.member('cm/../x');
    expect(call(mock).path).toBe('/admin/community/members/cm%2F..%2Fx');
  });
});

// ── Bot « Vérif » (révision 2) ──────────────────────────────────────────────

describe('bot « Vérif »', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('onglet « Bot Vérif » : rôle R seulement, jamais le conseiller', () => {
    expect(COMMUNITY_TABS).toContain('bot');
    for (const role of [InternalRole.Moderator, InternalRole.ContentManager, InternalRole.Admin, InternalRole.SuperAdmin]) {
      expect(visibleCommunityTabs(communityPermissions(role))).toContain('bot');
    }
    const counselor = visibleCommunityTabs(communityPermissions(InternalRole.Counselor));
    expect(counselor).not.toContain('bot');
    expect(resolveCommunityTab({ tab: 'bot', post: null, member: null }, counselor)).toBe('content');
    expect(communityHref({ tab: 'bot' })).toBe('/community?tab=bot');
  });

  it('libellés : statuts, filtres, badge et codes d’erreur du bot dans les deux langues', () => {
    for (const status of BOT_STATUSES) expectInBothLocales(`communityAdmin.bot.status.${status}`);
    for (const status of BOT_LIST_STATUSES) if (status !== 'all') expectInBothLocales(`communityAdmin.bot.status.${status}`);
    for (const mode of ['review', 'auto', 'off']) {
      expectInBothLocales(`communityAdmin.bot.mode.${mode}`);
      expectInBothLocales(`communityAdmin.bot.modeHint.${mode}`);
    }
    for (const reason of [
      'not_question', 'no_intent', 'no_entity', 'ambiguous_entity', 'entity_not_public', 'team_post', 'error',
      'post_not_visible', 'facts_changed',
    ]) expectInBothLocales(`communityAdmin.bot.reason.${reason}`);
    for (const intent of ['status', 'deadline', 'truth', 'scam', 'fees', 'partner', 'exists', 'documents', 'intake', 'visa']) {
      expectInBothLocales(`communityAdmin.bot.intent.${intent}`);
    }
    for (const level of ['high', 'medium', 'low']) expectInBothLocales(`communityAdmin.bot.confidence.${level}`);
    for (const type of ['scholarship', 'institution', 'program', 'country']) expectInBothLocales(`communityAdmin.bot.entity.${type}`);
    expect(BADGES).toContain('kpb_assistant');
    expect(enumMessageKey('badge', 'kpb_assistant')).toBe('communityAdmin.enum.badge.kpb_assistant');
    expect(lookup(fr, 'communityAdmin.enum.badge.kpb_assistant')).toBe('Assistant KPB');
    expect(KNOWN_ERROR_CODES).toContain('community_bot_draft_obsolete');
    const info = readCommunityError({
      status: 409,
      body: JSON.stringify({ code: 'community_bot_draft_obsolete', details: { reason: 'facts_changed' } }),
      message: 'x',
    });
    expect(communityErrorMessageKey(info)).toBe('communityAdmin.errors.community_bot_draft_obsolete');
  });

  it('obsolète : statut, ou contrôle en direct (publication masquée, faits changés)', () => {
    expect(isBotDraftStale({ status: 'obsolete' })).toBe(true);
    expect(isBotDraftStale({ status: 'proposed' }, { postVisible: true, factsChanged: false })).toBe(false);
    expect(isBotDraftStale({ status: 'proposed' }, { postVisible: false, factsChanged: false })).toBe(true);
    expect(isBotDraftStale({ status: 'proposed' }, { postVisible: true, factsChanged: true })).toBe(true);
    expect(isBotDraftStale({ status: 'published' }, { postVisible: false, factsChanged: true })).toBe(false);
  });

  it('actions selon l’état : publier seulement un brouillon proposé et à jour', () => {
    const fresh = { postVisible: true, factsChanged: false };
    expect(botDraftActions({ status: 'proposed' }, fresh)).toEqual({ publish: true, reject: true, regenerate: true });
    expect(botDraftActions({ status: 'proposed' }, { postVisible: true, factsChanged: true })).toEqual({ publish: false, reject: true, regenerate: true });
    expect(botDraftActions({ status: 'obsolete' })).toEqual({ publish: false, reject: true, regenerate: true });
    expect(botDraftActions({ status: 'published' })).toEqual({ publish: false, reject: false, regenerate: false });
    expect(botDraftActions({ status: 'rejected' })).toEqual({ publish: false, reject: false, regenerate: true });
    expect(botDraftActions({ status: 'statut_futur' })).toEqual({ publish: false, reject: false, regenerate: true });
  });

  it('texte : bornes d’une réponse ; sources : http(s) seulement', () => {
    expect(validateBotText(' ')).toBe('bodyRequired');
    expect(validateBotText('x'.repeat(3001))).toBe('bodyTooLong');
    expect(validateBotText('Bonjour !')).toBeNull();
    expect(safeSourceUrl('https://www.campusfrance.org/fr')).toBe('https://www.campusfrance.org/fr');
    expect(safeSourceUrl('javascript:alert(1)')).toBeNull();
    expect(safeSourceUrl('pas une url')).toBeNull();
    expect(safeSourceUrl(null)).toBeNull();
  });

  it('appels : liste, détail, publier (texte modifié + vérifiée), rejeter, régénérer, statistiques', async () => {
    const stubbed = (response: unknown = {}) => {
      const fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 200, text: vi.fn().mockResolvedValue(JSON.stringify(response)) });
      vi.stubGlobal('fetch', fetchMock);
      return fetchMock;
    };
    const call = (mock: ReturnType<typeof vi.fn>) => {
      const [url, init] = mock.mock.calls[0] as [string, { method: string; body?: string }];
      return { path: url.replace('http://127.0.0.1:4000/api', ''), method: init.method, body: init.body ? JSON.parse(init.body) : undefined };
    };
    let mock = stubbed({ items: [], nextCursor: null });
    await communityAdminApi.botDrafts('proposed');
    expect(call(mock)).toEqual({ path: '/admin/community/bot/drafts?status=proposed&limit=20', method: 'GET', body: undefined });
    mock = stubbed({});
    await communityAdminApi.botDraft('cbd/1');
    expect(call(mock).path).toBe('/admin/community/bot/drafts/cbd%2F1');
    mock = stubbed({});
    await communityAdminApi.botPublish('cbd_1', { text: 'Texte relu', verified: true });
    expect(call(mock)).toEqual({ path: '/admin/community/bot/drafts/cbd_1/publish', method: 'POST', body: { text: 'Texte relu', verified: true } });
    mock = stubbed({});
    await communityAdminApi.botReject('cbd_1', 'Hors sujet');
    expect(call(mock)).toEqual({ path: '/admin/community/bot/drafts/cbd_1/reject', method: 'POST', body: { reason: 'Hors sujet' } });
    mock = stubbed({});
    await communityAdminApi.botRegenerate('cbd_1');
    expect(call(mock)).toMatchObject({ path: '/admin/community/bot/drafts/cbd_1/regenerate', method: 'POST' });
    mock = stubbed({});
    await communityAdminApi.botStats(7);
    expect(call(mock).path).toBe('/admin/community/bot/stats?days=7');
  });
});

// ── Bot « Passerelle » (révision 3) ─────────────────────────────────────────

describe('bot « Passerelle »', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('onglet « Bot Passerelle » : rôle R seulement, jamais le conseiller', () => {
    expect(COMMUNITY_TABS).toContain('assistBridge');
    for (const role of [InternalRole.Moderator, InternalRole.ContentManager, InternalRole.Admin, InternalRole.SuperAdmin]) {
      expect(visibleCommunityTabs(communityPermissions(role))).toContain('assistBridge');
    }
    const counselor = visibleCommunityTabs(communityPermissions(InternalRole.Counselor));
    expect(counselor).not.toContain('assistBridge');
    expect(resolveCommunityTab({ tab: 'assistBridge', post: null, member: null }, counselor)).toBe('content');
    expect(communityHref({ tab: 'assistBridge' })).toBe('/community?tab=assistBridge');
  });

  it('libellés : modes, statuts, besoins, sources, motifs dans les deux langues', () => {
    for (const mode of ['shadow', 'on', 'off']) {
      expectInBothLocales(`communityAdmin.assistBridge.mode.${mode}`);
      expectInBothLocales(`communityAdmin.assistBridge.modeHint.${mode}`);
    }
    for (const status of ASSIST_EVENT_STATUSES) expectInBothLocales(`communityAdmin.assistBridge.status.${status}`);
    expect(ASSIST_LIST_STATUSES[0]).toBe('all');
    for (const need of ASSIST_NEED_IDS) expectInBothLocales(`communityAdmin.assistBridge.need.${need}`);
    for (const source of ASSIST_SOURCES) expectInBothLocales(`communityAdmin.assistBridge.source.${source}`);
    for (const reason of ASSIST_SKIP_REASONS) expectInBothLocales(`communityAdmin.assistBridge.reason.${reason}`);
    for (const col of ['need', 'detected', 'sent', 'wouldSend', 'openedFeature', 'openedWhatsapp', 'dismissed', 'skipped']) {
      expectInBothLocales(`communityAdmin.assistBridge.stats.${col}`);
    }
  });

  it('extrait : jamais pour la source coach, même si le serveur en renvoyait un', () => {
    expect(assistExcerpt({ source: 'coach_message', excerpt: 'texte privé' })).toBeNull();
    expect(assistExcerpt({ source: 'source_future', excerpt: 'x' })).toBeNull();
    expect(assistExcerpt({ source: 'community_post', excerpt: '  Quelle bourse pour moi ?  ' })).toBe('Quelle bourse pour moi ?');
    expect(assistExcerpt({ source: 'community_reply', excerpt: null })).toBeNull();
  });

  it('motifs d’abandon : non nuls, du plus fréquent au moins fréquent', () => {
    expect(assistSkippedEntries({ shadow: 4, opt_out: 0, user_cap: 2, need_cooldown: 2 })).toEqual([
      ['shadow', 4],
      ['need_cooldown', 2],
      ['user_cap', 2],
    ]);
    expect(assistSkippedEntries(undefined)).toEqual([]);
  });

  it('appels : statistiques, événements filtrés (statut « tous » omis), catalogue', async () => {
    const stubbed = (response: unknown = {}) => {
      const fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 200, text: vi.fn().mockResolvedValue(JSON.stringify(response)) });
      vi.stubGlobal('fetch', fetchMock);
      return fetchMock;
    };
    const path = (mock: ReturnType<typeof vi.fn>) => (mock.mock.calls[0] as [string])[0].replace('http://127.0.0.1:4000/api', '');
    let mock = stubbed({});
    await communityAdminApi.assistStats(7);
    expect(path(mock)).toBe('/admin/community/assist-bridge/stats?days=7');
    mock = stubbed({ items: [], nextCursor: null });
    await communityAdminApi.assistEvents({ status: 'all' });
    expect(path(mock)).toBe('/admin/community/assist-bridge/events?limit=20');
    mock = stubbed({ items: [], nextCursor: null });
    await communityAdminApi.assistEvents({ status: 'sent', needId: 'visa', source: 'coach_message' }, 'abc', 10);
    expect(path(mock)).toBe('/admin/community/assist-bridge/events?status=sent&needId=visa&source=coach_message&cursor=abc&limit=10');
    mock = stubbed({});
    await communityAdminApi.assistCatalog();
    expect(path(mock)).toBe('/admin/community/assist-bridge/catalog');
  });
});
