// ─────────────────────────────────────────────────────────────────────────────
// Communauté (C1 + C2) — les constantes du contrat docs/community-api-contract.md.
//
// Une valeur changée ici change le contrat : §4 (limites, quotas, pagination),
// §9 (charte, seuil de signalements), §12 (rétention). Les tests de contrôleur
// et de service lisent ces constantes plutôt que de recopier les nombres.
// ─────────────────────────────────────────────────────────────────────────────

export const COMMUNITY_LIMITS = {
  titleMin: 8,
  titleMax: 120,
  postBodyMin: 20,
  postBodyMax: 5000,
  replyBodyMin: 2,
  replyBodyMax: 3000,
  reportDetailsMax: 500,
  adminReasonMin: 3,
  adminReasonMax: 500,
  mentionsPerContent: 10,
  hashtagsPerPost: 10,
  hashtagMin: 2,
  hashtagMax: 40,
  searchMin: 2,
  searchMax: 100,
  excerptMax: 240,
  countRefsMax: 50,
} as const;

export const COMMUNITY_PAGINATION = {
  defaultLimit: 20,
  maxLimit: 50,
  repliesDefaultLimit: 30,
  repliesMaxLimit: 100,
  suggestDefaultLimit: 8,
  suggestMaxLimit: 20,
} as const;

/** « Nouveau compte » = profil créé il y a moins de 7 jours (§4.3). */
export const COMMUNITY_NEW_ACCOUNT_DAYS = 7;

export const COMMUNITY_QUOTAS = {
  postsPerDay: { newAccount: 3, established: 10 },
  repliesPerHour: { newAccount: 10, established: 30 },
  reportsPerDay: 20,
} as const;

/** Fenêtre de modification par l'auteur (§4.4). */
export const COMMUNITY_EDIT_WINDOW_MS = 15 * 60 * 1000;

/** Signalements ouverts de membres distincts qui masquent provisoirement (§9.3). */
export const COMMUNITY_REPORT_HIDE_THRESHOLD = 3;

/** Publications épinglées simultanément (§8.6). */
export const COMMUNITY_MAX_PINNED = 3;

/** Contenus supprimés par l'auteur ou l'équipe : purge définitive après (§12). */
export const COMMUNITY_DELETED_RETENTION_DAYS = 30;

/** Fenêtre des candidats du fil « Pour toi » (§10). */
export const COMMUNITY_FOR_YOU_WINDOW_DAYS = 60;

/** Regroupement des notifications de réponse (§11). */
export const COMMUNITY_NOTIFICATION_GROUP_HOURS = 24;

/** Clé de désinscription dans `UserProfile.disabledNotificationTypes` (§11). */
export const COMMUNITY_NOTIFICATION_OPT_OUT = 'community';

export const COMMUNITY_AUDIT_PURPOSE = 'community_moderation';

// ── Charte (§9.4) ───────────────────────────────────────────────────────────
//
// Quatre règles courtes, tutoiement (docs/voice-guide.md), aucune promesse
// d'admission. Changer un texte de fond = nouvelle version : chaque membre la
// ré-accepte avant sa prochaine écriture.

export const COMMUNITY_CHARTER_VERSION = '2026-10-v1';

export interface CharterRule {
  id: string;
  title: { fr: string; en: string };
  body: { fr: string; en: string };
}

export const COMMUNITY_CHARTER = {
  title: { fr: 'Charte de la communauté', en: 'Community guidelines' },
  rules: [
    {
      id: 'kind',
      title: { fr: 'Bienveillance', en: 'Be kind' },
      body: {
        fr: "Tu t'adresses à des élèves comme toi. Pas d'insulte, pas de moquerie, pas de harcèlement.",
        en: 'You are talking to students like you. No insults, no mockery, no harassment.',
      },
    },
    {
      id: 'no_money',
      title: { fr: "Jamais d'argent", en: 'Never money' },
      body: {
        fr: "Personne ici ne vend de bourse ni de visa. Ne paie jamais un « agent » rencontré dans la communauté, et signale toute demande d'argent.",
        en: 'Nobody here sells scholarships or visas. Never pay an "agent" you met in the community, and report any request for money.',
      },
    },
    {
      id: 'no_contact',
      title: { fr: 'Pas de coordonnées', en: 'No contact details' },
      body: {
        fr: "Ne partage ni numéro, ni WhatsApp, ni e-mail, ni adresse — les tiens comme ceux des autres. Les messages qui en contiennent attendent la revue de l'équipe.",
        en: "Don't share phone numbers, WhatsApp, email or addresses — yours or anyone else's. Messages that contain them wait for team review.",
      },
    },
    {
      id: 'truth',
      title: { fr: 'Des infos vérifiables', en: 'Verifiable information' },
      body: {
        fr: "Partage ton expérience et cite les sources officielles. L'équipe KPB peut marquer une réponse comme vérifiée.",
        en: 'Share your experience and cite official sources. The KPB team can mark an answer as verified.',
      },
    },
  ] satisfies CharterRule[],
};
