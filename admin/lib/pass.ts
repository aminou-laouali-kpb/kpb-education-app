import { apiFetch } from './api-client';

/**
 * Pass Karatou côté console : accorder un accès après un paiement vérifié,
 * lister, révoquer. Même règle que le webhook n8n (`/integrations/pass/grant`),
 * dont ce formulaire est le secours.
 */

export type PassGrantState = 'active' | 'upcoming' | 'expired' | 'revoked';

export interface PassGrantRow {
  id: string;
  account: { id: string; fullName: string; email: string };
  startsAt: string;
  endsAt: string;
  durationDays: number;
  paymentReference: string;
  amountXof: number | null;
  source: 'webhook' | 'admin' | string;
  grantedBy: string;
  note: string | null;
  createdAt: string;
  revokedAt: string | null;
  revokedBy: string | null;
  revokedReason: string | null;
  state: PassGrantState;
}

export interface PassGrantResult {
  status: 'granted' | 'already_granted';
  grantId: string;
  account: { id: string; fullName: string; email: string };
  startsAt: string;
  endsAt: string;
  activeUntil: string;
}

export interface PassGrantInput {
  email: string;
  durationDays: number;
  paymentReference: string;
  amountXof?: number;
  note?: string;
}

export interface PassDraft {
  email: string;
  durationDays: string;
  paymentReference: string;
  amountXof: string;
  note: string;
}

export const DURATION_PRESETS = [30, 90, 180, 365] as const;

export const EMPTY_PASS_DRAFT: PassDraft = {
  email: '',
  durationDays: '30',
  paymentReference: '',
  amountXof: '',
  note: '',
};

export class PassDraftError extends Error {}

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
/** Miroir du motif serveur (`backend/src/modules/pass/dto/pass.dto.ts`). */
const REFERENCE = /^[A-Za-z0-9][A-Za-z0-9._\-/ ]{2,119}$/;

/** Formulaire → payload, avec les refus que le serveur opposerait. */
export function toPassGrantInput(draft: PassDraft): PassGrantInput {
  const email = draft.email.trim();
  if (!EMAIL.test(email)) {
    throw new PassDraftError("E-mail invalide : celui avec lequel l'élève se connecte à l'app.");
  }
  const durationDays = Number(draft.durationDays);
  if (!Number.isInteger(durationDays) || durationDays < 1 || durationDays > 730) {
    throw new PassDraftError('La durée est un nombre de jours entre 1 et 730.');
  }
  const paymentReference = draft.paymentReference.trim();
  if (!REFERENCE.test(paymentReference)) {
    throw new PassDraftError(
      'Référence de paiement obligatoire (3 caractères au moins) : celle du reçu mobile money.',
    );
  }
  const input: PassGrantInput = { email, durationDays, paymentReference };
  const amount = draft.amountXof.trim().replace(/\s/g, '');
  if (amount) {
    const amountXof = Number(amount);
    if (!Number.isInteger(amountXof) || amountXof < 0) {
      throw new PassDraftError('Le montant est un nombre entier de FCFA.');
    }
    input.amountXof = amountXof;
  }
  const note = draft.note.trim();
  if (note) input.note = note.slice(0, 500);
  return input;
}

export async function fetchPassGrants(q?: string): Promise<PassGrantRow[]> {
  const query = q?.trim() ? `?q=${encodeURIComponent(q.trim())}` : '';
  const response = await apiFetch<{ items: PassGrantRow[] }>(`/admin/pass/grants${query}`);
  return response?.items ?? [];
}

export function grantPass(input: PassGrantInput): Promise<PassGrantResult> {
  return apiFetch<PassGrantResult>('/admin/pass/grants', { method: 'POST', body: input });
}

export async function revokePass(id: string, reason: string): Promise<void> {
  await apiFetch(`/admin/pass/grants/${encodeURIComponent(id)}/revoke`, {
    method: 'POST',
    body: { reason },
  });
}

/** `2026-12-22T10:00:00.000Z` → « 22/12/2026 ». */
export function formatDay(iso: string, locale = 'fr-FR'): string {
  return new Intl.DateTimeFormat(locale, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(iso));
}
