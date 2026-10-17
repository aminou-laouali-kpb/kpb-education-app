/**
 * Codes de parrainage — une seule saisie pour deux familles de codes.
 *
 * - code PERSONNEL (`UserProfile.referralCode`) : 8 caractères sans ambiguïté,
 *   toujours en majuscules (« K7PQ2MZA ») ;
 * - code AMBASSADEUR (`Ambassador.code`) : « KTOU-AB-1a2b3c », casse mêlée.
 *
 * L'app installée met le texte saisi en MAJUSCULES avant l'envoi
 * (`referral_screen.dart`, `_redeem`) : un code ambassadeur n'aurait donc jamais
 * été retrouvé par une égalité stricte. La forme normalisée — majuscules, sans
 * espace, tiret, point ni soulignement — sert de clé aux deux familles
 * (`Ambassador.codeNormalized`).
 */
export function normalizeReferralCode(raw: string): string {
  return (raw ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '');
}

function ambassadorInitials(name: string): string {
  const parts = name
    .replace(/\(.*?\)/g, '')
    .split(/[\s—-]+/)
    .filter((p) => p && /[A-Za-zÀ-ÿ]/.test(p));
  if (parts.length === 0) return '★';
  if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

function hash31(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (Math.imul(31, h) + s.charCodeAt(i)) | 0;
  return h;
}

/**
 * Code ambassadeur stable dérivé de l'id (unique) du profil :
 * « KTOU-XX-###### ». Même algorithme qu'avant son extraction de
 * `AmbassadorService`, à un détail près : une initiale hors A–Z (« ★ » d'un nom
 * vide, « É ») devient « X », pour que le code survive à la normalisation. Les
 * codes déjà distribués sont stockés et ne sont jamais recalculés.
 */
export function ambassadorCodeFor(profileId: string, name: string): string {
  const ini = ambassadorInitials(name)
    .replace(/[^A-Z]/g, '')
    .padEnd(2, 'X')
    .slice(0, 2)
    .toUpperCase();
  const suffix = Math.abs(hash31(profileId)).toString(36).padStart(6, '0').slice(0, 6);
  return `KTOU-${ini}-${suffix}`;
}

/**
 * Nom public d'un participant : « Prénom I. » (la ville s'affiche à côté).
 * « aïcha konaté » → « Aïcha K. » ; un seul mot → ce mot.
 */
export function publicNameFromFullName(fullName: string): string {
  const tokens = (fullName ?? '')
    .replace(/[^\p{L}\p{M}\s'’-]/gu, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (tokens.length === 0) return '';
  const cap = (w: string) => w.charAt(0).toLocaleUpperCase('fr') + w.slice(1).toLocaleLowerCase('fr');
  const first = cap(tokens[0]);
  if (tokens.length === 1) return first;
  const last = tokens[tokens.length - 1];
  return `${first} ${last.charAt(0).toLocaleUpperCase('fr')}.`;
}

/**
 * Un nom public ne doit pas devenir un canal de fuite : pas d'e-mail, pas de
 * numéro de téléphone, pas plus de 40 caractères. Renvoie le motif du refus, ou
 * null.
 */
export function publicNameIssue(name: string): string | null {
  const trimmed = (name ?? '').trim();
  if (trimmed.length === 0) return 'public_name_empty';
  if (trimmed.length > 40) return 'public_name_too_long';
  if (trimmed.includes('@')) return 'public_name_contains_email';
  if (/\d{3,}/.test(trimmed.replace(/[\s.-]/g, ''))) return 'public_name_contains_digits';
  return null;
}

/** Ce qu'un ambassadeur voit d'un de ses filleuls : « Fatou S. ». */
export function refereeDisplayName(fullName: string): string {
  return publicNameFromFullName(fullName) || 'Filleul';
}
