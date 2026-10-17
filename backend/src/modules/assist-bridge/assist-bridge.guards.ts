// ─────────────────────────────────────────────────────────────────────────────
// Bot « Passerelle » (C3 bis) — GARDE-FOUS, en fonction PURE.
//
// Le service rassemble les faits (profil, sanctions, source, fonction, envois
// passés, heure locale) ; cette fonction décide, dans un ordre fixe et
// documenté (§15.3 du contrat). Pure pour être testée sans base.
// ─────────────────────────────────────────────────────────────────────────────

import {
  ASSIST_BRIDGE_EXPIRY_HOURS,
  ASSIST_BRIDGE_NEED_COOLDOWN_DAYS,
  ASSIST_BRIDGE_USER_CAP_HOURS,
  type AssistBridgeMode,
} from './assist-bridge.config';

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

/** Motifs de `skipped` (console, statistiques, contrat §15.3). */
export const ASSIST_SKIP_REASONS = [
  'not_student',
  'opt_out',
  'sanctioned',
  'source_not_visible',
  'coach_source_off',
  'feature_unavailable',
  'feature_used',
  'need_cooldown',
  'user_cap',
  'expired',
  'shadow',
  'error',
] as const;
export type AssistSkipReason = (typeof ASSIST_SKIP_REASONS)[number];

export interface AssistFacts {
  mode: Exclude<AssistBridgeMode, 'off'>;
  now: Date;
  detectedAt: Date;
  isStudent: boolean;
  optedOut: boolean;
  /** Lecture seule ou bannissement en cours dans la communauté. */
  sanctioned: boolean;
  /** La source existe encore, est visible, et a bien été écrite par l'élève. */
  sourceVisible: boolean;
  /** Source coach alors que le réglage `KPB_ASSIST_BRIDGE_COACH` est refermé. */
  coachSourceClosed: boolean;
  featureAvailable: boolean;
  featureUsedRecently: boolean;
  /** Dernier envoi (ou envoi simulé en `shadow`) de CE besoin à l'élève. */
  lastNeedSentAt: Date | null;
  /** Dernier envoi (ou envoi simulé en `shadow`) de N'IMPORTE QUEL besoin. */
  lastAnySentAt: Date | null;
  /** Heure locale de l'élève dans la fenêtre calme des push. */
  quietHours: boolean;
}

export type AssistDecision =
  | { action: 'send' }
  | { action: 'skip'; reason: AssistSkipReason }
  | { action: 'defer' };

/**
 * L'ordre compte : ce qui touche le DROIT d'envoyer (élève, désinscription,
 * sanction, source) passe avant ce qui touche la PERTINENCE (fonction,
 * délais), puis le MOMENT (heures calmes). `shadow` applique tout, sauf
 * l'attente des heures calmes, et s'arrête juste avant l'envoi.
 */
export function decide(f: AssistFacts): AssistDecision {
  if (!f.isStudent) return { action: 'skip', reason: 'not_student' };
  if (f.optedOut) return { action: 'skip', reason: 'opt_out' };
  if (f.sanctioned) return { action: 'skip', reason: 'sanctioned' };
  if (f.coachSourceClosed) return { action: 'skip', reason: 'coach_source_off' };
  if (!f.sourceVisible) return { action: 'skip', reason: 'source_not_visible' };
  if (!f.featureAvailable) return { action: 'skip', reason: 'feature_unavailable' };
  if (f.featureUsedRecently) return { action: 'skip', reason: 'feature_used' };
  const t = f.now.getTime();
  if (f.lastNeedSentAt && t - f.lastNeedSentAt.getTime() < ASSIST_BRIDGE_NEED_COOLDOWN_DAYS * DAY_MS) {
    return { action: 'skip', reason: 'need_cooldown' };
  }
  if (f.lastAnySentAt && t - f.lastAnySentAt.getTime() < ASSIST_BRIDGE_USER_CAP_HOURS * HOUR_MS) {
    return { action: 'skip', reason: 'user_cap' };
  }
  if (f.mode === 'shadow') return { action: 'skip', reason: 'shadow' };
  if (t - f.detectedAt.getTime() > ASSIST_BRIDGE_EXPIRY_HOURS * HOUR_MS) {
    return { action: 'skip', reason: 'expired' };
  }
  if (f.quietHours) return { action: 'defer' };
  return { action: 'send' };
}
