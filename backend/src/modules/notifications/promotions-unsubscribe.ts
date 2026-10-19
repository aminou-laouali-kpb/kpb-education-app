import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Le lien de désinscription des e-mails promotionnels (correctifs 57, XC-06).
 *
 * Chaque e-mail d'une campagne `promotional` porte un lien signé :
 * `<KPB_PUBLIC_API_URL>/public/promotions/unsubscribe?u=<id>&t=<jeton>`.
 * Le jeton est un HMAC-SHA256 de l'identifiant du compte, tronqué : sans le
 * secret, on ne peut pas désinscrire quelqu'un d'autre. Il n'expire pas — un
 * lien de désinscription doit marcher dans un vieil e-mail.
 *
 * Secret : `KPB_PROMOTIONS_UNSUBSCRIBE_SECRET`, sinon `KPB_JWT_SECRET` (même
 * repli que `KPB_REFERRAL_SIGNAL_SECRET`). Sans aucun des deux, AUCUN lien ne
 * peut être construit : l'exécuteur n'envoie alors PAS l'e-mail promotionnel
 * (livraison marquée en échec) plutôt que d'envoyer un e-mail sans issue.
 */

/** L'API publique, préfixe `/api` compris (même valeur que l'app en production). */
const DEFAULT_PUBLIC_API_URL = 'https://api.kpbeducation.cloud/api';

const TOKEN_LENGTH = 32;

export function promotionsUnsubscribeSecret(
  env: NodeJS.ProcessEnv = process.env,
): string | null {
  return (
    env.KPB_PROMOTIONS_UNSUBSCRIBE_SECRET?.trim() ||
    env.KPB_JWT_SECRET?.trim() ||
    null
  );
}

export function promotionsUnsubscribeToken(userId: string, secret: string): string {
  return createHmac('sha256', secret)
    .update(`kpb-promotions-unsubscribe:${userId}`)
    .digest('base64url')
    .slice(0, TOKEN_LENGTH);
}

/** Comparaison à temps constant ; faux pour toute entrée mal formée. */
export function verifyPromotionsUnsubscribeToken(
  userId: unknown,
  token: unknown,
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  const secret = promotionsUnsubscribeSecret(env);
  if (!secret) return false;
  if (typeof userId !== 'string' || typeof token !== 'string') return false;
  if (!userId || userId.length > 64 || token.length !== TOKEN_LENGTH) return false;
  const expected = Buffer.from(promotionsUnsubscribeToken(userId, secret));
  const given = Buffer.from(token);
  return expected.length === given.length && timingSafeEqual(expected, given);
}

/** Le lien complet, ou `null` quand aucun secret n'est configuré. */
export function promotionsUnsubscribeUrl(
  userId: string,
  env: NodeJS.ProcessEnv = process.env,
): string | null {
  const secret = promotionsUnsubscribeSecret(env);
  if (!secret) return null;
  const base = (env.KPB_PUBLIC_API_URL?.trim() || DEFAULT_PUBLIC_API_URL).replace(/\/+$/, '');
  const token = promotionsUnsubscribeToken(userId, secret);
  return `${base}/public/promotions/unsubscribe?u=${encodeURIComponent(userId)}&t=${token}`;
}

/** Le pied de chaque e-mail promotionnel. */
export function promotionsEmailFooter(url: string, lang: 'fr' | 'en'): string {
  return lang === 'en'
    ? [
        '—',
        'You receive this email because you agreed to receive news and offers from KPB Education.',
        `Unsubscribe in one click: ${url}`,
        'Or in the app: Profile → Preferences.',
      ].join('\n')
    : [
        '—',
        'Tu reçois cet e-mail parce que tu as accepté de recevoir les nouvelles et offres de KPB Education.',
        `Te désinscrire en un clic : ${url}`,
        "Ou dans l'app : Profil → Préférences.",
      ].join('\n');
}
