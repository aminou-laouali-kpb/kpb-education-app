import { apiFetch } from './api-client';
import type { ForecastScholarshipBody } from './scholarship-opening';
import type {
  ActivateScholarshipBody,
  ActivateScholarshipResponse,
  CancelOpeningResponse,
  OpeningOverviewResponse,
  OpeningPreviewQuery,
  OpeningPreviewResponse,
  OpeningReportResponse,
  OpeningTodoResponse,
  StopOpeningResponse,
} from './scholarship-opening-types';

/**
 * Client de l'annonce d'ouverture des bourses (chantier C).
 *
 * Les formes sont celles du contrat partagé (`scholarship-opening-types.ts`,
 * miroir de `backend/…/opening/scholarship-opening.contract.ts`) et de
 * `docs/api-contracts.md`. Toutes ces routes sont derrière
 * AdminAuthGuard + RolesGuard (admin, super_admin, content_manager) ; la
 * limite « au-delà du seuil, administrateurs seulement » se joue côté serveur,
 * dans `activate`.
 *
 * Déploiement : `notify` et `expectedRecipients` sont refusés par un backend
 * antérieur au chantier (`forbidNonWhitelisted`) — cet admin se déploie
 * strictement après le backend.
 */

const BASE = '/admin/scholarships';

function scholarshipPath(scholarshipId: string): string {
  return `${BASE}/${encodeURIComponent(scholarshipId)}`;
}

function cyclePath(scholarshipId: string, cycleId: string): string {
  return `${scholarshipPath(scholarshipId)}/cycles/${encodeURIComponent(cycleId)}`;
}

/**
 * Aperçu d'une annonce : cycles, cible, complétude, audience, copie FR/EN et
 * derniers événements. Sans année, le serveur choisit le cycle par défaut.
 * Lecture seule ; `signal` permet d'abandonner un aperçu devenu obsolète.
 */
export function fetchOpeningPreview(
  scholarshipId: string,
  query: OpeningPreviewQuery = {},
  signal?: AbortSignal,
): Promise<OpeningPreviewResponse> {
  const params = new URLSearchParams();
  if (query.academicYear) params.set('academicYear', query.academicYear);
  if (query.opensAt) params.set('opensAt', query.opensAt);
  if (query.closesAt) params.set('closesAt', query.closesAt);
  const search = params.toString();
  return apiFetch<OpeningPreviewResponse>(
    `${scholarshipPath(scholarshipId)}/opening-preview${search ? `?${search}` : ''}`,
    { signal },
  );
}

/**
 * Ouvre (ou corrige) le cycle et, avec `notify: true`, programme l'annonce.
 * Erreurs à traiter : 409 `OPENING_AUDIENCE_CHANGED`, `OPENING_BUSY`,
 * `OPENING_NOT_RETROACTIVE`, 403 `OPENING_REQUIRES_ADMIN`, 400
 * `OPENING_CONFIRMATION_REQUIRED` (voir `activateErrorText`).
 */
export function activateScholarshipCycle(
  scholarshipId: string,
  body: ActivateScholarshipBody,
): Promise<ActivateScholarshipResponse> {
  return apiFetch<ActivateScholarshipResponse>(
    `${scholarshipPath(scholarshipId)}/activate`,
    { method: 'POST', body },
  );
}

/** Dates estimées d'un cycle (route existante, aucune notification). */
export function saveScholarshipForecast(
  scholarshipId: string,
  body: ForecastScholarshipBody,
): Promise<unknown> {
  return apiFetch<unknown>(`${scholarshipPath(scholarshipId)}/forecast`, {
    method: 'POST',
    body,
  });
}

/**
 * Annule une annonce programmée ; 409 `OPENING_NOT_SCHEDULED` sinon, ou 409
 * `OPENING_BUSY` quand l'envoi tient le cycle depuis plus de 5 s.
 */
export function cancelOpening(
  scholarshipId: string,
  cycleId: string,
): Promise<CancelOpeningResponse> {
  return apiFetch<CancelOpeningResponse>(
    `${cyclePath(scholarshipId, cycleId)}/opening/cancel`,
    { method: 'POST' },
  );
}

/** Arrête les push restants ; les entrées d'inbox restent visibles. */
export function stopOpening(
  scholarshipId: string,
  cycleId: string,
): Promise<StopOpeningResponse> {
  return apiFetch<StopOpeningResponse>(
    `${cyclePath(scholarshipId, cycleId)}/opening/stop`,
    { method: 'POST' },
  );
}

/** Rapport d'envoi d'un cycle (« acceptées par le fournisseur »…). */
export function fetchOpeningReport(
  scholarshipId: string,
  cycleId: string,
  signal?: AbortSignal,
): Promise<OpeningReportResponse> {
  return apiFetch<OpeningReportResponse>(
    `${cyclePath(scholarshipId, cycleId)}/opening-report`,
    { signal },
  );
}

/** Cycles servis ouverts jamais annoncés (carte « À faire »). */
export function fetchOpeningTodo(): Promise<OpeningTodoResponse> {
  return apiFetch<OpeningTodoResponse>(`${BASE}/opening-todo`);
}

/** Colonnes « Abonnés » et « Annoncé » de la liste. */
export function fetchOpeningOverview(): Promise<OpeningOverviewResponse> {
  return apiFetch<OpeningOverviewResponse>(`${BASE}/opening-overview`);
}
