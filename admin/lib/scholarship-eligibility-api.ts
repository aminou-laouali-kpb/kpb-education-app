import { apiFetch } from './api-client';
import type { EligibilityDraft } from './scholarship-eligibility';
import { eligibilityPatchBody } from './scholarship-eligibility';
import type {
  EligibilityCoverageResponse,
  EligibilityOptionsResponse,
  MatchPreviewBody,
  MatchPreviewResponse,
} from './scholarship-eligibility-types';

/**
 * Client de l'éligibilité structurée (chantier D4). Routes derrière
 * AdminAuthGuard + RolesGuard (admin, super_admin, content_manager).
 *
 * Déploiement : le PATCH porte `eligibleLevels`, `fieldsScope`,
 * `eligibilityCriteria` et `markStructured`, que seul un backend D4 sait lire —
 * cet admin se déploie après le backend.
 */

const BASE = '/admin/scholarships';

/** Couverture des bourses publiques (la porte de lancement). */
export function fetchEligibilityCoverage(): Promise<EligibilityCoverageResponse> {
  return apiFetch<EligibilityCoverageResponse>(`${BASE}/eligibility-coverage`);
}

/** Pays ISO 3166-1 (table du serveur) et constantes de l'éditeur. */
export function fetchEligibilityOptions(): Promise<EligibilityOptionsResponse> {
  return apiFetch<EligibilityOptionsResponse>(`${BASE}/eligibility-options`);
}

/** « Tester un profil » : le moteur, sans rien persister. */
export function postMatchPreview(
  body: MatchPreviewBody,
  signal?: AbortSignal,
): Promise<MatchPreviewResponse> {
  return apiFetch<MatchPreviewResponse>(`${BASE}/match-preview`, {
    method: 'POST',
    body,
    signal,
  });
}

/** La ligne renvoyée par le PATCH (champs d'éligibilité seulement). */
export interface SavedEligibility {
  eligibleLevels?: string[];
  fieldsScope?: string;
  eligibilityCriteria?: unknown;
  eligibilityStructuredAt?: string | null;
  eligibilityStructuredBy?: string | null;
}

/**
 * Enregistre niveaux, domaines et critères. `markStructured: true` tamponne
 * « Conditions vérifiées » (refusé par le serveur sans niveau) ; `false`
 * retire le tampon. Une 400 porte `issues` (voir `readEligibilityError`).
 */
export function saveEligibility(
  scholarshipId: string,
  draft: EligibilityDraft,
  markStructured?: boolean,
): Promise<SavedEligibility> {
  return apiFetch<SavedEligibility>(
    `/admin/catalog/scholarships/${encodeURIComponent(scholarshipId)}`,
    { method: 'PATCH', body: eligibilityPatchBody(draft, markStructured) },
  );
}

/** Retire le tampon sans toucher au contenu. */
export function unstampEligibility(scholarshipId: string): Promise<SavedEligibility> {
  return apiFetch<SavedEligibility>(
    `/admin/catalog/scholarships/${encodeURIComponent(scholarshipId)}`,
    { method: 'PATCH', body: { markStructured: false } },
  );
}

let optionsPromise: Promise<EligibilityOptionsResponse> | null = null;

/**
 * La table des pays change au déploiement, pas pendant une session : un seul
 * appel par onglet, rejoué après un échec.
 */
export function loadEligibilityOptionsOnce(): Promise<EligibilityOptionsResponse> {
  if (!optionsPromise) {
    optionsPromise = fetchEligibilityOptions().catch((error: unknown) => {
      optionsPromise = null;
      throw error;
    });
  }
  return optionsPromise;
}
