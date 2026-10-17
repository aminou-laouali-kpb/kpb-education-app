/**
 * Domaines d'e-mail jetables — liste VERSIONNÉE.
 *
 * Un filleul dont l'e-mail tombe dans cette liste n'est pas supprimé : il est
 * marqué « à vérifier » (`disposable_email`) et ne compte pas tant que l'équipe
 * ne l'a pas validé. Changer la liste = incrémenter la version ; le recalcul
 * suivant applique la nouvelle liste à toute la campagne (le calcul est
 * rejouable, rien n'est figé avant le gel).
 *
 * Source : relevé manuel des services d'adresses temporaires les plus courants
 * (17/10/2026). Ni Gmail, ni Yahoo, ni Outlook, ni les fournisseurs africains
 * (orange.*, etc.) — ce sont des adresses durables.
 */
export const DISPOSABLE_EMAIL_DOMAINS_VERSION = '2026-10-17.v1';

export const DISPOSABLE_EMAIL_DOMAINS: ReadonlySet<string> = new Set([
  '10minutemail.com',
  '10minutemail.net',
  '20minutemail.com',
  '33mail.com',
  'anonbox.net',
  'burnermail.io',
  'byom.de',
  'cool.fr.nf',
  'courriel.fr.nf',
  'discard.email',
  'discardmail.com',
  'dispostable.com',
  'dropmail.me',
  'email-fake.com',
  'emailondeck.com',
  'emailfake.com',
  'fakeinbox.com',
  'fakemail.net',
  'getairmail.com',
  'getnada.com',
  'guerrillamail.biz',
  'guerrillamail.com',
  'guerrillamail.de',
  'guerrillamail.info',
  'guerrillamail.net',
  'guerrillamail.org',
  'guerrillamailblock.com',
  'harakirimail.com',
  'inboxbear.com',
  'incognitomail.org',
  'jetable.fr.nf',
  'jetable.org',
  'mail-temp.com',
  'mail.tm',
  'mailcatch.com',
  'maildrop.cc',
  'mailinator.com',
  'mailinator.net',
  'mailnesia.com',
  'mailpoof.com',
  'mintemail.com',
  'moakt.com',
  'mohmal.com',
  'mytemp.email',
  'nada.email',
  'nospam.ze.tc',
  'sharklasers.com',
  'spam4.me',
  'spambox.us',
  'spamgourmet.com',
  'temp-mail.io',
  'temp-mail.org',
  'tempail.com',
  'tempinbox.com',
  'tempmail.com',
  'tempmail.dev',
  'tempmail.net',
  'tempmailo.com',
  'tempr.email',
  'throwawaymail.com',
  'tmail.ws',
  'tmpmail.net',
  'tmpmail.org',
  'trashmail.com',
  'trashmail.de',
  'trashmail.net',
  'yopmail.com',
  'yopmail.fr',
  'yopmail.net',
]);

export function emailDomain(email: string): string {
  const at = (email ?? '').lastIndexOf('@');
  return at < 0 ? '' : email.slice(at + 1).trim().toLowerCase();
}

/** Vrai pour un domaine de la liste ou l'un de ses sous-domaines. */
export function isDisposableEmail(email: string): boolean {
  const domain = emailDomain(email);
  if (!domain) return false;
  const labels = domain.split('.');
  for (let i = 0; i < labels.length - 1; i += 1) {
    if (DISPOSABLE_EMAIL_DOMAINS.has(labels.slice(i).join('.'))) return true;
  }
  return false;
}
