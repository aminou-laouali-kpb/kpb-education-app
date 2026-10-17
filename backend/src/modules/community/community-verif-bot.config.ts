// ─────────────────────────────────────────────────────────────────────────────
// Bot « Vérif » (chantier Communauté C3) — réglages et constantes.
//
// Décision du propriétaire (17/10/2026) : VALIDATION HUMAINE D'ABORD. Le bot
// prépare une réponse depuis les données vérifiées du catalogue ; un admin la
// publie en un clic. Le passage en automatique se fait plus tard, par ce
// réglage, sans nouvelle build (docs/runbook-bot-verif.md).
//
//   KPB_COMMUNITY_VERIF_BOT_MODE = review (défaut) | auto | off
//     · review : brouillons dans la file admin, rien n'est publié seul ;
//     · auto   : publie seul un brouillon de confiance HAUTE dont les faits
//                demandés sont tous renseignés et frais ; le reste attend un
//                admin comme en `review` ;
//     · off    : aucune détection, aucun brouillon (la file reste lisible).
//   Toute autre valeur (faute de frappe) vaut `review` : jamais `auto` par
//   accident, et jamais un bot éteint en silence.
//
//   KPB_COMMUNITY_VERIF_BOT_LLM = false (défaut) | true
//     Reformulation par le LLM existant (llm.service.ts), STRICTEMENT contrainte
//     aux faits ; repli sur le modèle déterministe à la moindre entorse.
// ─────────────────────────────────────────────────────────────────────────────

export type VerifBotMode = 'review' | 'auto' | 'off';

export function verifBotMode(): VerifBotMode {
  const raw = process.env.KPB_COMMUNITY_VERIF_BOT_MODE?.trim().toLowerCase();
  if (raw === 'auto' || raw === 'off') return raw;
  return 'review';
}

export function verifBotLlmEnabled(): boolean {
  return process.env.KPB_COMMUNITY_VERIF_BOT_LLM?.trim().toLowerCase() === 'true';
}

/** Nom affiché des réponses du bot (comme « Équipe KPB », non traduit). */
export const KPB_ASSISTANT_NAME = 'Assistant KPB';

/**
 * `authorAdminId` d'une réponse publiée SEULE (mode `auto`) : la contrainte
 * `CommunityReply_author_check` exige un auteur d'équipe pour tout contenu non
 * membre. Une publication par un admin porte, elle, l'id de cet admin.
 */
export const VERIF_BOT_SYSTEM_AUTHOR_ID = 'kpb-verif-bot';

/**
 * Fraîcheur des données : au-delà, le fait est dit « à revérifier » et le
 * brouillon n'est jamais publié seul. Bourses : 30 jours, le plafond du
 * validateur du catalogue (`MAX_VERIFICATION_AGE_DAYS`) — une campagne bouge
 * vite. Écoles, formations, pays : 180 jours (rentrées et frais changent une
 * fois par an). À VALIDER.
 */
export const VERIF_BOT_STALE_DAYS = {
  scholarship: 30,
  institution: 180,
  program: 180,
  country: 180,
} as const;

/** Entités citées au plus par brouillon (priorité : bourse, formation, école, pays). */
export const VERIF_BOT_MAX_ENTITIES = 3;

/** Brouillons traités par passage de la tâche (chaque minute). */
export const VERIF_BOT_BATCH = 10;

/** Échecs techniques tolérés avant d'abandonner un brouillon (`skipped/error`). */
export const VERIF_BOT_MAX_ATTEMPTS = 3;

/** Le texte publié reste sous la limite d'une réponse (§4.2). */
export const VERIF_BOT_TEXT_MAX = 2900;

/** Documents cités au plus (le reste : « voir la fiche »). */
export const VERIF_BOT_MAX_DOCUMENTS = 6;
