import { isAtLeastAge } from '../../profiles/profile-age.policy';

/**
 * « Profil complété » au sens de la compétition ambassadeurs.
 *
 * La décision du propriétaire (17/10/2026) compte un filleul quand son compte
 * est créé, son e-mail vérifié et son profil complété. Ce fichier fixe le
 * troisième point d'après ce que l'app INSTALLÉE (2.3.0, build 56) collecte
 * réellement et rend obligatoire à l'onboarding (`onboarding_screen.dart`,
 * `_next`, relu au commit de la build 56) :
 *
 * - page 1 : prénom + nom, e-mail, téléphone (obligatoires), date de naissance
 *   (élève), accord du tuteur si mineur, consentement → `phone`, `birthDate`,
 *   `guardianConsentedAt` ;
 * - page 2 : niveaux (préremplis, donc toujours posés) ;
 * - page 3 : au moins un domaine ET au moins un pays visé → `fieldIds`,
 *   `targetCountryIds`.
 *
 * Le consentement n'est PAS testé sur `UserProfile.consentedAt` (audit 57,
 * F15) : aucune build ne l'envoie, le DTO ne l'accepte pas
 * (`forbidNonWhitelisted`) et le serveur ne l'écrit nulle part — la colonne
 * reste NULL pour tous les comptes, et l'exiger rendait tout filleul à jamais
 * « en attente ». La case est en revanche OBLIGATOIRE à l'onboarding (2.3.0
 * comme 2.3.1 : `_identityIssue` rend `consent_missing` tant qu'elle n'est pas
 * cochée, avant toute synchronisation du profil) : un profil qui porte
 * téléphone, date de naissance, domaines et pays visés est passé par elle. On
 * ne fabrique pas non plus de date de consentement côté serveur : ce serait
 * une preuve inventée.
 *
 * Le pays de résidence n'est PAS exigé : il est facultatif dans l'onboarding de
 * la build 56. La ville n'est pas collectée du tout. Le nom n'est pas testé : le
 * serveur en pose un par défaut (partie locale de l'e-mail) à la première
 * connexion, indiscernable d'un nom saisi.
 *
 * Le même prédicat existe en SQL dans la migration
 * `20261028120000_profile_completion_without_consent` (qui reprend le
 * rattrapage 3 de `20261022120000_referral_campaigns` sans `consentedAt`) :
 * les deux doivent rester identiques.
 */
export interface CompletionProfile {
  accountType: string;
  phone: string | null;
  birthDate: Date | null;
  guardianConsentedAt: Date | null;
  fieldIds: readonly string[] | null;
  targetCountryIds: readonly string[] | null;
}

/** Les colonnes à lire pour évaluer le prédicat (sélection Prisma). */
export const PROFILE_COMPLETION_SELECT = {
  accountType: true,
  phone: true,
  birthDate: true,
  guardianConsentedAt: true,
  fieldIds: true,
  targetCountryIds: true,
} as const;

export const ADULT_AGE = 18;

/** Mineur à l'instant `at` (moins de 18 ans révolus). */
export function isMinorAt(birthDate: Date, at: Date): boolean {
  return !isAtLeastAge(birthDate, ADULT_AGE, at);
}

export function isProfileComplete(p: CompletionProfile, now: Date): boolean {
  if (p.accountType !== 'student') return false;
  if (!p.phone || p.phone.trim() === '') return false;
  if (!p.birthDate) return false;
  if (!p.fieldIds || p.fieldIds.length === 0) return false;
  if (!p.targetCountryIds || p.targetCountryIds.length === 0) return false;
  if (isMinorAt(p.birthDate, now) && !p.guardianConsentedAt) return false;
  return true;
}

/**
 * E-mail vérifié : le profil est rattaché à un utilisateur Supabase. L'app ne
 * connaît que deux chemins de connexion — code à 6 chiffres reçu par e-mail
 * (`verifyOTP`) et Google — et le serveur ne crée ou ne relie un profil qu'à
 * partir d'un jeton Supabase valide portant l'e-mail
 * (`SupabaseAuthService.resolveProfile`).
 */
export function isEmailVerified(p: { supabaseUserId: string | null }): boolean {
  return Boolean(p.supabaseUserId);
}
