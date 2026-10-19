// ─────────────────────────────────────────────────────────────────────────────
// Bot « Passerelle » (chantier C3 bis) — réglages et constantes.
//
// Le bot repère un BESOIN dans ce que l'élève a écrit LUI-MÊME (« je cherche à
// faire relire mon CV », « Campus France, je suis perdu », « quelle bourse pour
// moi ? ») et lui envoie une notification PRIVÉE qui renvoie vers la bonne
// fonction de l'app, puis vers WhatsApp s'il veut plus d'aide. Jamais de
// réponse publique. Exploitation : docs/runbook-bot-passerelle.md.
//
//   KPB_ASSIST_BRIDGE_MODE = shadow (défaut) | on | off
//     · shadow : détecte et journalise (garde-fous compris), n'envoie RIEN —
//                la console montre ce qui serait parti ;
//     · on     : envoie (fil in-app + push par le chemin commun) ;
//     · off    : aucune détection, aucun envoi (les événements restent lisibles).
//   Toute autre valeur (faute de frappe) vaut `shadow` : jamais `on` par
//   accident, et jamais un bot éteint en silence.
//
//   KPB_ASSIST_BRIDGE_COACH = false (défaut) | true
//     Source PRIVÉE : les messages de l'élève au coach IA. FERMÉE par défaut ;
//     à n'ouvrir qu'après mise à jour de la politique de confidentialité
//     (À VALIDER propriétaire). Même ouverte, le texte du coach n'est jamais
//     stocké : seulement l'id du besoin, la règle et l'id du message.
// ─────────────────────────────────────────────────────────────────────────────

export type AssistBridgeMode = 'off' | 'shadow' | 'on';

export function assistBridgeMode(): AssistBridgeMode {
  const raw = process.env.KPB_ASSIST_BRIDGE_MODE?.trim().toLowerCase();
  if (raw === 'on' || raw === 'off') return raw;
  return 'shadow';
}

/** Seule la valeur `true` (casse et espaces tolérés) ouvre la source coach. */
export function assistBridgeCoachEnabled(): boolean {
  return process.env.KPB_ASSIST_BRIDGE_COACH?.trim().toLowerCase() === 'true';
}

/** `kind` de la notification (`UserNotification.kind`, charge push `type`). */
export const ASSIST_BRIDGE_KIND = 'assist_bridge';

/** Clé de désinscription (`UserProfile.disabledNotificationTypes`). */
export const ASSIST_BRIDGE_OPT_OUT = 'assist_bridge';

/**
 * Expéditeur affiché : le mot « bot » n'apparaît jamais comme auteur. Même
 * badge que les réponses du bot Vérif (« Assistant KPB »), au nom de l'équipe.
 */
export const ASSIST_BRIDGE_SENDER = 'kpb_assistant';

/** Au plus UNE notification passerelle par élève sur cette fenêtre (heures). Validé le 18/10/2026. */
export const ASSIST_BRIDGE_USER_CAP_HOURS = 72;

/** Un même besoin n'est pas re-proposé à l'élève avant ce délai (jours). Validé le 18/10/2026. */
export const ASSIST_BRIDGE_NEED_COOLDOWN_DAYS = 30;

/** « Fonction déjà utilisée récemment » : fenêtre de la vérification (jours). */
export const ASSIST_BRIDGE_FEATURE_RECENT_DAYS = 14;

/**
 * Un besoin repéré pendant les heures calmes attend la fin de la fenêtre ;
 * au-delà de ce délai sans envoi possible, il est abandonné (`expired`).
 */
export const ASSIST_BRIDGE_EXPIRY_HOURS = 48;

/** Conservation des événements (jours) — 12 mois, validés par le propriétaire le 18/10/2026. */
export const ASSIST_BRIDGE_RETENTION_DAYS = 365;

/** Événements traités par passage de la tâche (chaque minute). */
export const ASSIST_BRIDGE_BATCH = 25;

/** Échecs techniques tolérés avant d'abandonner un événement (`skipped/error`). */
export const ASSIST_BRIDGE_MAX_ATTEMPTS = 3;

/** Extrait d'un contenu PUBLIC de la communauté montré dans la console. */
export const ASSIST_BRIDGE_EXCERPT_MAX = 120;
