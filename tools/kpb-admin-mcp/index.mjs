#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// KPB Admin MCP — expose l'API admin de KPB Education à l'agent notifications.
//
// Ce que l'agent peut faire ici :
//   • LIRE le contenu publié (bourses, établissements, parcours, articles,
//     vidéos) et savoir ce qui est NOUVEAU depuis son dernier passage ;
//   • LIRE l'historique des campagnes et leurs statistiques de livraison ;
//   • PRÉPARER une notification (brouillon + aperçu d'audience, rien n'est
//     envoyé), puis l'ENVOYER — en deux étapes distinctes.
//
// Pourquoi deux étapes : un push part vers de vrais élèves et ne se rattrape
// pas. `kpb_draft_notification` ne touche à rien ; seul
// `kpb_send_notification` écrit, et il exige la phrase exacte
// « ENVOYER <draftId> ». Cet outil ne doit JAMAIS être mis en liste
// d'autorisation dans Claude Code : la demande de permission est le feu vert
// humain.
//
// Envoi : on passe par les CAMPAGNES du backend (/admin/notifications) — traces
// de livraison et d'ouverture par élève, FR/EN selon la langue de chacun,
// visibles dans l'admin. Le backend livre par FCM (et par OneSignal pour les
// versions de l'app antérieures à FCM).
//
// Identifiants : un compte AdminUser dédié (rôle ContentManager ou Admin), lu
// dans l'environnement ou dans un `.env` git-ignoré à côté de ce script.
// ─────────────────────────────────────────────────────────────────────────────

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

// ── Env ──────────────────────────────────────────────────────────────────────
const HERE = dirname(fileURLToPath(import.meta.url));
function loadDotEnv() {
  try {
    const raw = readFileSync(join(HERE, '.env'), 'utf8');
    for (const line of raw.split('\n')) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2];
    }
  } catch {
    /* pas de .env — variables d'environnement seulement */
  }
}
loadDotEnv();

const API = (process.env.KPB_API_BASE_URL ?? 'https://api.kpbeducation.cloud/api')
  .replace(/\/+$/, '');
const STATE_DIR = process.env.KPB_AGENT_STATE_DIR ?? join(homedir(), '.kpb-agent');
const STATE_FILE = join(STATE_DIR, 'state.json');
const MAX_BROADCASTS_7D = Number(process.env.KPB_AGENT_MAX_BROADCASTS_7D ?? 3);
// Fenêtre de silence en UTC (le gros de la base vit entre UTC+0 et UTC+1).
const QUIET_START_UTC = Number(process.env.KPB_AGENT_QUIET_START_UTC ?? 20);
const QUIET_END_UTC = Number(process.env.KPB_AGENT_QUIET_END_UTC ?? 8);

// ── Routes que l'app sait ouvrir au tap ─────────────────────────────────────
// Miroir de `AppRoutes.normalizeExternalRoute` (lib/app/core/config/
// app_routes.dart). Une route hors liste n'est pas refusée par FCM :
// l'app la rejette en silence et dépose l'élève sur l'accueil. On la refuse
// donc ICI, au moment où l'agent peut encore la corriger.
const KNOWN_ROUTES = new Set([
  '/', '/search', '/new-case', '/orientation', '/eligibility',
  '/etudes-en-france', '/etudes-en-france/catalogue', '/saved', '/deadlines',
  '/alumni', '/salon', '/services', '/profile', '/scholarships', '/success-lab',
]);
// Routes à un segment variable (id ou slug), vide ou imbriqué refusé comme
// dans l'app. `/parcours/<slug>` : ouvrable depuis la PR #284 — un build plus
// ancien retombe sur l'accueil.
const PARAM_ROUTES = [
  /^\/scholarships\/[^/]+$/,
  /^\/parcours\/[^/]+$/,
  /^\/cases\/[^/]+$/,
  /^\/success-lab\/[^/]+(\/(diagnostic|study-review|schedule|submission|outcome))?$/,
];
function routeIsNavigable(route) {
  if (KNOWN_ROUTES.has(route)) return true;
  return PARAM_ROUTES.some((re) => re.test(route));
}

// ── État local : nouveautés déjà vues, annonces faites, brouillons ─────────
function loadState() {
  try {
    return JSON.parse(readFileSync(STATE_FILE, 'utf8'));
  } catch {
    return { seen: {}, announced: [], drafts: {}, sends: [] };
  }
}
function saveState(state) {
  mkdirSync(STATE_DIR, { recursive: true });
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

// ── Auth : login admin → JWT (cookie httpOnly) → Bearer ────────────────────
let token = null; // { value, expiresAt }

async function login() {
  const email = process.env.KPB_ADMIN_EMAIL?.trim();
  const password = process.env.KPB_ADMIN_PASSWORD?.trim();
  if (!email || !password) {
    throw new Error(
      'Identifiants manquants : définir KPB_ADMIN_EMAIL et KPB_ADMIN_PASSWORD ' +
        '(environnement ou tools/kpb-admin-mcp/.env).',
    );
  }
  const res = await fetch(`${API}/auth/admin/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) {
    throw new Error(`Connexion admin refusée (${res.status}) : ${await res.text()}`);
  }
  const cookies = res.headers.getSetCookie?.() ?? [res.headers.get('set-cookie') ?? ''];
  const match = cookies.join(';').match(/kpb_admin_token=([^;]+)/);
  if (!match) throw new Error("Connexion OK mais aucun cookie kpb_admin_token reçu.");
  // Le jeton vit 1 h ; on le renouvelle 5 min avant.
  token = { value: decodeURIComponent(match[1]), expiresAt: Date.now() + 55 * 60_000 };
  return (await res.json()).user;
}

async function api(method, path, body) {
  if (!token || token.expiresAt < Date.now()) await login();
  const doFetch = () =>
    fetch(`${API}${path}`, {
      method,
      headers: {
        authorization: `Bearer ${token.value}`,
        ...(body ? { 'content-type': 'application/json' } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
  let res = await doFetch();
  if (res.status === 401) {
    await login();
    res = await doFetch();
  }
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status} : ${text.slice(0, 800)}`);
  return text ? JSON.parse(text) : null;
}

// ── Helpers ─────────────────────────────────────────────────────────────────
const ok = (data) => ({ content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] });
const fail = (message) => ({ isError: true, content: [{ type: 'text', text: message }] });
const tool = (fn) => async (args) => {
  try {
    return await fn(args ?? {});
  } catch (error) {
    return fail(error instanceof Error ? error.message : String(error));
  }
};
const asList = (payload) =>
  Array.isArray(payload) ? payload : payload?.items ?? payload?.data ?? [];
const label = (item) =>
  item.nameFr ?? item.name ?? item.titleFr ?? item.title ?? item.fullName ?? item.slug ?? item.id;

// Sources de « nouveautés ». Chaque source rend des objets { id, label, extra }.
const SOURCES = {
  scholarships: async () =>
    // Seules les bourses approuvées ET actives sont visibles dans l'app. Une
    // bourse approuvée puis activée plus tard apparaîtra comme nouvelle à ce
    // moment-là — c'est voulu.
    asList(await api('GET', '/admin/scholarships/moderation?status=approved'))
      .filter((s) => s.isActive !== false)
      .map((s) => ({
      id: s.id,
      label: label(s),
      route: `/scholarships/${s.id}`,
      deadlineAt: s.deadlineAt ?? null,
      isActive: s.isActive ?? null,
    })),
  institutions: async () =>
    asList(await api('GET', '/catalog/institutions')).map((i) => ({
      id: i.id,
      label: label(i),
      countryId: i.countryId ?? i.country?.id ?? null,
      city: i.city ?? null,
    })),
  parcours: async () =>
    asList(await api('GET', '/admin/parcours'))
      .filter((p) => !p.status || p.status === 'published')
      .map((p) => ({ id: p.id, label: label(p), kind: p.kind ?? p.type ?? null, slug: p.slug ?? null })),
  articles: async () =>
    asList(await api('GET', '/admin/articles'))
      .filter((a) => !a.status || a.status === 'published')
      .map((a) => ({ id: a.id, label: label(a) })),
};

// ── Garde-fous communs au brouillon ET à l'envoi ────────────────────────────
// Un brouillon vit 24 h : l'heure, le plafond et les doublons doivent être
// revérifiés au moment de l'envoi, sur l'état relu à cet instant. Sinon un
// brouillon fait à 19 h 59 partirait après 20 h, et deux brouillons faits
// avant le premier envoi annonceraient tous deux le même contenu.
const DAY = 86_400_000;
// Instant où la campagne atteint réellement les élèves (anciennes entrées :
// `sentAt`). Une campagne échouée n'a atteint personne : elle ne compte pas.
const deliveredAt = (s) => Date.parse(s.deliverAt ?? s.sentAt);
const countsAsBroadcast = (s) => s.broadcast && s.status !== 'failed';

function broadcastsNear(state, at) {
  // Toute fenêtre de 7 jours qui contient `at` doit rester sous le plafond :
  // on compte donc les diffusions à moins de 7 jours AVANT ou APRÈS.
  return state.sends.filter((s) => countsAsBroadcast(s) && Math.abs(deliveredAt(s) - at) < 7 * DAY).length;
}

// Même lecture que le backend (`resolveExcludedCountries`) : tableau ou liste
// séparée par des virgules, casse et espaces ignorés.
function excludesSuspendedCountries(filters) {
  const raw = filters?.exceptCountries;
  const entries = Array.isArray(raw) ? raw : typeof raw === 'string' ? raw.split(',') : [];
  return entries.some((e) => typeof e === 'string' && e.trim().toLowerCase() === 'eef_suspended');
}

// L'audience peut-elle atteindre des élèves d'un pays suspendu ? Une audience qui
// exclut le jeton `eef_suspended` ne le peut pas : l'avertir serait contredire
// l'aperçu qui confirme l'exclusion. `country_of_residence` et `country` ciblent
// un pays choisi à dessein : ils ne sont pas un envoi large qui oublie l'exclusion.
function reachesSuspendedCountries(d) {
  if (!['all_students', 'all_users', 'eef_interest', 'all_students_except_countries', 'study_level'].includes(d.audienceType)) {
    return false;
  }
  return !excludesSuspendedCountries(d.filters);
}

function guardrailProblems(d, state) {
  const problems = [];
  if (!routeIsNavigable(d.route)) {
    problems.push(
      `Route « ${d.route} » non navigable dans l'app : l'élève atterrirait sur l'accueil. ` +
        `Routes valides : ${[...KNOWN_ROUTES].join(', ')}, /scholarships/<id>, /parcours/<slug>.`,
    );
  }
  const sendAt = d.scheduledFor ? new Date(d.scheduledFor) : new Date();
  if (sendAt.getTime() < Date.now() - 60_000) {
    problems.push(`scheduledFor ${sendAt.toISOString()} est déjà passé.`);
  }
  const broadcast = d.audienceType !== 'single_user';
  const near = broadcastsNear(state, sendAt.getTime());
  if (broadcast && near >= MAX_BROADCASTS_7D) {
    problems.push(
      `Plafond atteint : ${near} diffusions à moins de 7 jours de ${sendAt.toISOString()} (max ${MAX_BROADCASTS_7D}). ` +
        "Regrouper les annonces ou décaler. Les pushs automatiques du backend s'ajoutent déjà à ceux-ci.",
    );
  }
  const already = d.contentIds.filter((id) => state.announced.includes(id));
  if (already.length) problems.push(`Contenu déjà annoncé : ${already.join(', ')}.`);
  const h = sendAt.getUTCHours();
  const quiet = QUIET_START_UTC > QUIET_END_UTC ? h >= QUIET_START_UTC || h < QUIET_END_UTC : h >= QUIET_START_UTC && h < QUIET_END_UTC;
  if (quiet) {
    problems.push(
      `Envoi à ${sendAt.toISOString()} dans la fenêtre de silence (${QUIET_START_UTC} h–${QUIET_END_UTC} h UTC). ` +
        'Fournir un scheduledFor en journée (idéal : 12 h–13 h ou 17 h–19 h UTC).',
    );
  }
  return problems;
}

// ── Serveur ─────────────────────────────────────────────────────────────────
const server = new McpServer({ name: 'kpb-admin', version: '1.0.0' });

server.registerTool(
  'kpb_session',
  { description: "Vérifie la connexion à l'API admin KPB et renvoie le compte connecté (email, rôle)." },
  tool(async () => ok({ api: API, user: await login() })),
);

server.registerTool(
  'kpb_dashboard',
  { description: "Tableau de bord admin : compteurs globaux (élèves, dossiers, contenu)." },
  tool(async () => ok(await api('GET', '/admin/dashboard'))),
);

server.registerTool(
  'kpb_list_scholarships',
  {
    description:
      'Bourses par statut de modération. `approved` = publiées dans l\'app ; `pending` = file de revue (NE JAMAIS annoncer une bourse pending).',
    inputSchema: { status: z.enum(['approved', 'pending', 'rejected']).default('approved') },
  },
  tool(async ({ status }) => ok(await api('GET', `/admin/scholarships/moderation?status=${status}`))),
);

server.registerTool(
  'kpb_list_institutions',
  {
    description: 'Établissements (universités, écoles) du catalogue, filtrables par pays.',
    inputSchema: { countryId: z.string().optional() },
  },
  tool(async ({ countryId }) =>
    ok(await api('GET', `/catalog/institutions${countryId ? `?countryId=${encodeURIComponent(countryId)}` : ''}`)),
  ),
);

server.registerTool(
  'kpb_list_parcours',
  { description: 'Parcours inspirants et témoignages (vidéo ou texte), tels que gérés dans l\'admin.' },
  tool(async () => ok(await api('GET', '/admin/parcours'))),
);

server.registerTool(
  'kpb_list_articles',
  { description: "Articles éditoriaux de l'app." },
  tool(async () => ok(await api('GET', '/admin/articles'))),
);

server.registerTool(
  'kpb_youtube_playlist',
  { description: 'Vidéos de la playlist YouTube KPB affichée dans l\'app.' },
  tool(async () => ok(await api('GET', '/content/youtube-playlist'))),
);

server.registerTool(
  'kpb_whats_new',
  {
    description:
      "Contenu publié apparu depuis le dernier passage (bourses approuvées, établissements, parcours, articles). " +
      "Au tout premier appel, enregistre une base de référence et ne renvoie rien de « nouveau ». " +
      "`commit: true` marque les nouveautés comme vues — à faire APRÈS avoir traité le rapport.",
    inputSchema: {
      sources: z.array(z.enum(['scholarships', 'institutions', 'parcours', 'articles'])).optional(),
      commit: z.boolean().default(false),
    },
  },
  tool(async ({ sources, commit }) => {
    const state = loadState();
    const wanted = sources?.length ? sources : Object.keys(SOURCES);
    const report = {};
    for (const key of wanted) {
      let items;
      try {
        items = await SOURCES[key]();
      } catch (error) {
        report[key] = { error: error instanceof Error ? error.message : String(error) };
        continue;
      }
      const seen = new Set(state.seen[key] ?? []);
      const baseline = !state.seen[key];
      const fresh = baseline ? [] : items.filter((i) => !seen.has(i.id));
      report[key] = { total: items.length, baseline, new: fresh };
      // Union, jamais remplacement : la liste des bourses est plafonnée à 200
      // (triée par date de vérification) ; un id qui sort puis revient ne doit
      // pas être redécouvert comme « nouveau ».
      if (commit || baseline) state.seen[key] = [...new Set([...seen, ...items.map((i) => i.id)])];
    }
    saveState(state);
    return ok({ committed: commit, report });
  }),
);

server.registerTool(
  'kpb_announcement_history',
  {
    description:
      "Historique local des annonces faites par l'agent (quoi, quand, à qui, id de campagne). À lire AVANT de proposer une annonce pour éviter les répétitions.",
    inputSchema: { limit: z.number().int().min(1).max(200).default(30) },
  },
  tool(async ({ limit }) => {
    const state = loadState();
    const now = Date.now();
    const last7d = state.sends.filter(
      (s) => countsAsBroadcast(s) && deliveredAt(s) > now - 7 * DAY && deliveredAt(s) <= now,
    ).length;
    const upcoming = state.sends.filter((s) => countsAsBroadcast(s) && deliveredAt(s) > now).length;
    return ok({
      broadcastsLast7Days: last7d,
      scheduledUpcoming: upcoming,
      maxBroadcastsPer7Days: MAX_BROADCASTS_7D,
      sends: state.sends.slice(-limit).reverse(),
    });
  }),
);

server.registerTool(
  'kpb_list_campaigns',
  { description: 'Campagnes de notifications du backend (toutes origines : admin humain et agent), les plus récentes d\'abord.',
    inputSchema: { limit: z.number().int().min(1).max(100).default(20) } },
  tool(async ({ limit }) => {
    const { items } = await api('GET', '/admin/notifications/campaigns');
    return ok(items.slice(0, limit));
  }),
);

server.registerTool(
  'kpb_campaign_stats',
  { description: "Statistiques d'une campagne : envoyés, livrés, échoués, taux de livraison, et ouvertures (`opened`, `openRate` = ouvertures / push livrés, signalées par l'app au tap).",
    inputSchema: { campaignId: z.string() } },
  tool(async ({ campaignId }) => ok(await api('GET', `/admin/notifications/campaigns/${campaignId}/stats`))),
);

const audienceSchema = {
  audienceType: z
    .enum(['all_students', 'all_users', 'country', 'country_of_residence', 'study_level', 'account_type', 'single_user', 'case_status', 'eef_interest', 'all_students_except_countries'])
    .default('all_students'),
  filters: z.record(z.unknown()).default({}),
};

server.registerTool(
  'kpb_preview_audience',
  {
    description:
      "Combien d'élèves une audience toucherait (total + répartition FR/EN), sans rien envoyer. " +
      'Filtres : country→{countryId}, country_of_residence→{countryCode}, study_level→{levels:[...]}, account_type→{accountType}, single_user→{userId}, all_students_except_countries→{exceptCountries:[...] | "eef_suspended"} (EXIGÉ), eef_interest→{} ou {exceptCountries:[...]} (déclarants Études en France ; "eef_suspended" = les pays suspendus servis par /config/app). ATTENTION : `country` filtre sur le pays de RÉSIDENCE, pas sur le pays visé.',
    inputSchema: audienceSchema,
  },
  tool(async (a) => ok(await api('POST', '/admin/notifications/campaigns/preview', a))),
);

const localized = (max) => z.object({ fr: z.string().min(1).max(max), en: z.string().min(1).max(max) });

server.registerTool(
  'kpb_draft_notification',
  {
    description:
      "Prépare une notification SANS l'envoyer : vérifie le texte, la route, l'audience, les garde-fous, et calcule le nombre de destinataires. " +
      "Renvoie un draftId à présenter à l'humain avec le récapitulatif. Titre ≤ 50 caractères, corps ≤ 150, FR ET EN obligatoires.",
    inputSchema: {
      name: z.string().min(3).max(90).describe('Nom interne, ex. « Nouvelle bourse — Mastercard Foundation 2027 »'),
      reason: z.enum(['new_scholarship', 'new_institution', 'content_highlight', 'other']),
      title: localized(50),
      body: localized(150),
      route: z.string().describe("Écran ouvert au tap, ex. /scholarships/<id>, /parcours/<slug>, /etudes-en-france, /alumni"),
      ...audienceSchema,
      scheduledFor: z.string().datetime().optional().describe('ISO 8601 UTC. Absent = envoi immédiat au feu vert.'),
      contentIds: z.array(z.string()).default([]).describe('Ids du contenu annoncé (bourse, établissement…), pour l\'historique anti-doublon.'),
    },
  },
  tool(async (d) => {
    const state = loadState();
    const broadcast = d.audienceType !== 'single_user';
    const problems = guardrailProblems(d, state);
    const warnings = [];
    if (d.audienceType === 'all_users') warnings.push('all_users inclut les comptes parents et partenaires — préférer all_students sauf intention explicite.');
    for (const lang of ['fr', 'en']) {
      if (/[A-Z]{6,}/.test(d.title[lang] + d.body[lang])) warnings.push(`Majuscules en rafale dans le texte ${lang}.`);
    }

    const preview = await api('POST', '/admin/notifications/campaigns/preview', {
      audienceType: d.audienceType,
      filters: d.filters,
    });
    if (preview.filterMissing) problems.push(`L'audience ${d.audienceType} exige son filtre.`);
    // Un filtre PRÉSENT mais mal formé (jeton d'exclusion mal écrit…) : le backend
    // le dit, et refuse l'envoi. Le répéter ici évite un brouillon « envoyable ».
    if (preview.filterInvalid) problems.push(`Filtre inutilisable : ${preview.filterInvalid}.`);
    if (preview.recipients === 0) problems.push('Audience vide : 0 destinataire.');

    // ── Études en France ────────────────────────────────────────────────
    // `/etudes-en-france/catalogue` n'existe que dans les builds 2.3.0 (54) et
    // suivantes ET quand l'espace est ouvert : sur une build 49 à 53 le tap
    // atterrit sur l'accueil. On cible `/etudes-en-france`, qui arbitre
    // vitrine / hub / « bientôt » selon le drapeau serveur.
    if (d.route.startsWith('/etudes-en-france/')) {
      problems.push("Cible /etudes-en-france, jamais un sous-écran : /etudes-en-france/catalogue n'existe que dans les builds 54+ et espace ouvert (build 49 à 53 : l'élève atterrit sur l'accueil).");
    }
    // Une annonce vers l'espace envoyée sans exclure les pays suspendus part vers
    // des élèves dont l'État dit que les dossiers ne sont pas traités.
    if (d.route.startsWith('/etudes-en-france') && reachesSuspendedCountries(d)) {
      warnings.push('Cette annonce vise Études en France sans exclure les pays suspendus : préférer all_students_except_countries ou eef_interest avec {"exceptCountries":["eef_suspended"]}.');
    }
    if (preview.excludedCountries) {
      warnings.push(`Exclusion lue : ${preview.excludedCountries.join(', ')} → ${preview.excludedRecipients} compte(s) retiré(s). Vérifier que ce nombre n'est pas 0.`);
    }

    const draftId = `d_${randomBytes(4).toString('hex')}`;
    const draft = { ...d, draftId, broadcast, preview, createdAt: new Date().toISOString() };
    if (!problems.length) {
      state.drafts[draftId] = draft;
      saveState(state);
    }
    return ok({
      sendable: problems.length === 0,
      draftId: problems.length ? null : draftId,
      problems,
      warnings,
      recap: {
        name: d.name,
        audience: `${d.audienceType} ${JSON.stringify(d.filters)}`,
        recipients: preview.recipients,
        byLanguage: preview.byLanguage,
        when: d.scheduledFor ?? 'immédiat, au feu vert',
        route: d.route,
        fr: `${d.title.fr} — ${d.body.fr}`,
        en: `${d.title.en} — ${d.body.en}`,
      },
      nextStep: problems.length
        ? 'Corriger les problèmes puis refaire un brouillon.'
        : `Présenter ce récapitulatif à l'humain. N'appeler kpb_send_notification qu'après son accord explicite, avec confirmation « ENVOYER ${draftId} ».`,
    });
  }),
);

server.registerTool(
  'kpb_send_test_push',
  {
    description:
      "Envoie le brouillon à UN seul compte (celui de l'humain, pour voir le rendu sur son téléphone). Aucune campagne, aucun historique élève.",
    inputSchema: { draftId: z.string(), userId: z.string(), lang: z.enum(['fr', 'en']).default('fr') },
  },
  tool(async ({ draftId, userId, lang }) => {
    const draft = loadState().drafts[draftId];
    if (!draft) return fail(`Brouillon ${draftId} introuvable (déjà envoyé ou jamais validé).`);
    return ok(
      await api('POST', '/admin/push/test', {
        userId,
        title: draft.title[lang],
        body: draft.body[lang],
        route: draft.route,
      }),
    );
  }),
);

server.registerTool(
  'kpb_send_notification',
  {
    description:
      "ENVOIE un brouillon validé à de vrais élèves (crée le modèle FR/EN puis la campagne backend). IRRÉVERSIBLE. " +
      "N'appeler qu'après l'accord explicite de l'humain dans la conversation ; `confirmation` doit valoir exactement « ENVOYER <draftId> ».",
    inputSchema: { draftId: z.string(), confirmation: z.string() },
  },
  tool(async ({ draftId, confirmation }) => {
    if (confirmation.trim() !== `ENVOYER ${draftId}`) {
      return fail(`Confirmation invalide. Attendu exactement : « ENVOYER ${draftId} ».`);
    }
    const state = loadState();
    const draft = state.drafts[draftId];
    if (!draft) return fail(`Brouillon ${draftId} introuvable (déjà envoyé ou jamais validé).`);
    if (Date.now() - Date.parse(draft.createdAt) > 24 * 3_600_000) {
      return fail('Brouillon de plus de 24 h : refaire un brouillon (audience et contenu ont pu changer).');
    }
    const problems = guardrailProblems(draft, state);
    if (problems.length) {
      return fail(`Envoi refusé, les garde-fous ne passent plus :\n- ${problems.join('\n- ')}`);
    }

    const template = await api('POST', '/admin/notifications/templates', {
      name: `[agent] ${draft.name}`.slice(0, 120),
      title: draft.title,
      body: draft.body,
      channels: ['push'],
      isCritical: false,
    });
    const campaign = await api('POST', '/admin/notifications/campaigns', {
      name: `[agent] ${draft.name}`.slice(0, 120),
      templateId: template.id,
      audienceType: draft.audienceType,
      filters: draft.filters,
      channels: ['push'],
      route: draft.route,
      ...(draft.scheduledFor ? { scheduledFor: draft.scheduledFor } : {}),
    });

    // Une campagne immédiate qui n'atteint aucun appareil revient `failed`.
    // Personne n'a rien reçu : on ne marque pas le contenu comme annoncé et on
    // garde le brouillon pour réessayer une fois la cause corrigée.
    const failed = campaign.status === 'failed';
    const now = new Date().toISOString();
    if (!failed) {
      delete state.drafts[draftId];
      state.announced.push(...draft.contentIds);
    }
    state.sends.push({
      sentAt: now,
      deliverAt: draft.scheduledFor ?? now,
      draftId,
      name: draft.name,
      reason: draft.reason,
      broadcast: draft.broadcast,
      audienceType: draft.audienceType,
      filters: draft.filters,
      recipients: draft.preview.recipients,
      route: draft.route,
      contentIds: draft.contentIds,
      campaignId: campaign.id,
      status: campaign.status,
    });
    saveState(state);
    if (failed) {
      return fail(
        `Campagne ${campaign.id} créée mais ÉCHOUÉE : aucun appareil atteint. Contenu NON marqué comme annoncé, ` +
          `brouillon ${draftId} conservé. Vérifier kpb_campaign_stats et les journaux du conteneur api (FCM / OneSignal) avant de réessayer.`,
      );
    }
    return ok({
      campaignId: campaign.id,
      status: campaign.status,
      scheduledFor: campaign.scheduledFor,
      hint: 'Vérifier kpb_campaign_stats dans quelques minutes : un statut « failed » signifie 0 livraison.',
    });
  }),
);

await server.connect(new StdioServerTransport());
