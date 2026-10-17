// ─────────────────────────────────────────────────────────────────────────────
// Communauté — filtre anti-arnaque AVANT publication (§9 du contrat).
//
// Les arnaques aux bourses suivent toujours le même chemin : sortir la victime
// de l'espace modéré (numéro, WhatsApp, e-mail, lien), puis demander de
// l'argent (« frais d'agent », Western Union, mobile money). Ce filtre
// intercepte ces deux étapes. Il ne REFUSE rien : un contenu signalé naît
// « en attente de revue », visible de son seul auteur, et entre dans la file
// de l'équipe. Une erreur du filtre coûte donc un délai, jamais un message.
//
// Fonction PURE (le contexte — liste blanche, termes ajoutés par l'équipe — est
// injecté) : chaque faux positif écarté ici a son test dans le spec.
// ─────────────────────────────────────────────────────────────────────────────

export const FILTER_FLAGS = [
  'phone',
  'email',
  'whatsapp',
  'money_request',
  'mobile_money',
  'external_link',
  'profanity',
  'blocked_term',
  'disposable_email',
] as const;
export type FilterFlag = (typeof FILTER_FLAGS)[number];

export interface FilterContext {
  /** Hôte (minuscules, sans `www.`) autorisé ? */
  isAllowedHost(host: string): boolean;
  /** Termes ajoutés par l'équipe, déjà repliés par `foldText`. */
  blockedTerms: readonly string[];
}

/** Minuscules, sans accents, apostrophes unifiées. */
export function foldText(raw: string): string {
  return raw
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[’‘`´]/g, "'")
    .replace(/œ/g, 'oe')
    .replace(/æ/g, 'ae');
}

/** Un terme en MOT ENTIER dans un texte replié (« Scunthorpe » ≠ « cunt »). */
export function containsWord(folded: string, term: string): boolean {
  if (!term) return false;
  const escaped = term
    .split(/\s+/)
    .map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
    .join('[\\s\'-]+');
  return new RegExp(`(^|[^a-z0-9])${escaped}($|[^a-z0-9])`).test(folded);
}

// ── Téléphones ──────────────────────────────────────────────────────────────

const PHONE_CANDIDATE_RE = /(?:\+|\b00)?\d[\d\s().-]{6,}\d/g;

const CURRENCY_AFTER_RE =
  /^\s*(?:f\s?cfa|fcfa|cfa|xof|xaf|€|eur\b|euros?\b|\$|usd\b|cad\b|dollars?\b|francs?\b|f\b|gnf\b|mad\b|dhs?\b|dirhams?\b|naira\b|ngn\b|ghs\b|cedis?\b|£|gbp\b|livres?\b|k€|millions?\b|mille\b)/i;
const CURRENCY_BEFORE_RE = /(?:€|\$|£|usd|eur|fcfa|cfa|xof|cad|gbp)\s*$/i;

/**
 * Une suite de 8 à 15 chiffres qui ressemble à un numéro. Écarte :
 * - les montants (devise juste avant ou après ; groupes de 3 chiffres « 15 000 000 ») ;
 * - les années et plages d'années (« 2026-2027 », « 2026 2027 ») ;
 * - les dates (le « / » ne fait pas partie des séparateurs : « 15/01/2027 » ne
 *   forme jamais une suite).
 */
export function containsPhoneNumber(text: string): boolean {
  for (const match of text.matchAll(PHONE_CANDIDATE_RE)) {
    const candidate = match[0].trim();
    const start = match.index ?? 0;
    const digits = candidate.replace(/\D/g, '');
    if (digits.length < 8 || digits.length > 15) continue;
    const international = candidate.startsWith('+') || candidate.startsWith('00');
    const before = text.slice(Math.max(0, start - 6), start);
    const after = text.slice(start + match[0].length, start + match[0].length + 12);
    if (CURRENCY_AFTER_RE.test(after) || CURRENCY_BEFORE_RE.test(before)) continue;
    // Années : 2026-2027, 2026 – 2027, 20262027 n'est pas une année.
    if (/^(19|20)\d{2}\s*[-–.\s]\s*(19|20)\d{2}$/.test(candidate)) continue;
    // Montant groupé par milliers, sans « + » : « 15 000 000 », « 1.500.000 ».
    const groups = candidate.split(/[\s.]+/).filter(Boolean);
    if (
      !international &&
      groups.length >= 2 &&
      /^\d{1,3}$/.test(groups[0]) &&
      groups.slice(1).every((g) => /^\d{3}$/.test(g))
    ) {
      continue;
    }
    return true;
  }
  return false;
}

// ── Coordonnées et sortie de l'espace modéré ────────────────────────────────

const EMAIL_RE = /[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}/i;
const OBFUSCATED_EMAIL_RE =
  /\b[a-z0-9._-]+\s*(?:\[at\]|\(at\)|\{at\}|\sat\s|arobase)\s*(?:gmail|yahoo|hotmail|outlook|icloud|live)\b/;

const DIRECT_CHAT_LINK_RE =
  /(wa\.me\/|chat\.whatsapp\.com|api\.whatsapp\.com|t\.me\/|telegram\.me\/)/;
const CHAT_APP_RE = /\b(whats\s?app|watsap+|wats\s?app|whatsap|telegram|signal|imo|viber)\b/;
const INVITATION_RE =
  /\b(ecri[st]?[- ]?moi|ecrivez[- ]?moi|ajoute[sz]?[- ]?moi|ajoutez[- ]?moi|contacte[sz]?[- ]?moi|contactez[- ]?moi|appelle[sz]?[- ]?moi|appelez[- ]?moi|joins[- ]?moi|rejoins[- ]?moi|rejoignez[- ]?moi|inbox|en prive|en pv|\bdm\b|\bmp\b|add me|text me|message me|contact me|reach me|call me|hit me up|pm me|dm me|inbox me)\b/;

// ── Argent ──────────────────────────────────────────────────────────────────

const MONEY_REQUEST_PATTERNS: readonly RegExp[] = [
  /frais d'?\s?agents?\b/,
  /\bagent agree\b/,
  /\bpaie[sz]?[- ]moi\b/,
  /\bpaye[sz]?[- ]moi\b/,
  /\bpayez[- ]moi\b/,
  /\benvoie[sz]?[- ](moi )?(de )?l'?argent\b/,
  /\benvoyez[- ](moi )?(de )?l'?argent\b/,
  /\benvoie[sz]?[- ]moi \d/,
  /\bwestern\s?union\b/,
  /\bmoney\s?gram\b/,
  /\bria (money|transfert|transfer)\b/,
  /\bgaranti[est]{0,2} (de |d')?(la |une |ton |ta |votre |ton |vos )?(admission|visa|bourse)s?\b/,
  /\b(admission|visa|bourse)s? (100 ?% )?garanti[est]{0,2}\b/,
  /\b100 ?% garanti/,
  /\bje (peux|vais|pourrai) (t'|vous )?(obtenir|avoir|trouver|decrocher|faire avoir) (la |une |ta |ton |votre )?(bourse|visa|admission)\b/,
  /\b(contre|moyennant) (une )?(petite )?(somme|paiement|remuneration|commission)\b/,
  /\b(depot|versement|virement) (sur|vers|a) (mon|ce|notre) (compte|numero)\b/,
  /\b(bitcoin|btc|usdt|binance|cryptos?)\b/,
  /\bcartes? cadeaux?\b/,
  /\bgift ?cards?\b/,
  /\bsend (me )?(the |some )?money\b/,
  /\bwire (me|the money|the fee)\b/,
  /\bagents? fees?\b/,
  /\bpay (me|my fee|the agent|to my account)\b/,
  /\bguaranteed? (admission|visa|scholarship)s?\b/,
  /\b(admission|visa|scholarship)s? guaranteed\b/,
  /\bi can (get|secure|obtain) you (a |the |your )?(scholarship|visa|admission)\b/,
];

const MOBILE_MONEY_PATTERNS: readonly RegExp[] = [
  /\borange\s?money\b/,
  /\bmtn\s?(mobile\s?)?money\b/,
  /\bmomo\b/,
  /\bmoov\s?(africa\s?)?money\b/,
  /\bairtel\s?money\b/,
  /\bflooz\b/,
  /\bt-?money\b/,
  /\bfree\s?money\b/,
  /\bm-?pesa\b/,
  /\bwizall\b/,
  /\bwari\b/,
  /\b(par|via|sur|avec|by|on|through|using) wave\b/,
  /\bwave (au|money|number|numero)\b/,
  /\b(compte|numero) wave\b/,
];

// ── Insultes de base FR / EN (mot entier, texte replié) ─────────────────────

const PROFANITY: readonly string[] = [
  // FR
  'connard', 'connards', 'connasse', 'connasses', 'salope', 'salopes', 'pute',
  'putes', 'encule', 'encules', 'enculee', 'enculer', 'fdp', 'ntm', 'batard',
  'batards', 'pd', 'pede', 'pedes', 'tapette', 'fils de pute', 'nique ta mere',
  'ta gueule', 'negre', 'negres', 'bougnoule', 'grosse merde',
  // EN
  'fuck', 'fucking', 'fucker', 'motherfucker', 'bitch', 'bitches', 'cunt',
  'asshole', 'bastard', 'nigger', 'nigga', 'faggot', 'whore', 'slut', 'retard',
  'dickhead',
];

/** Nombre de termes intégrés (affiché dans l'admin, jamais la liste). */
export const BUILTIN_BLOCKED_TERMS_COUNT = PROFANITY.length;

// ── Liens ───────────────────────────────────────────────────────────────────

const URL_HOST_RE = /https?:\/\/([^\s/?#:<>"']+)/gi;
const WWW_HOST_RE = /\bwww\.([a-z0-9-]+(?:\.[a-z0-9-]+)+)/gi;
const BARE_DOMAIN_RE =
  /(?<![@\w.-])([a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:com|net|org|info|biz|xyz|io|me|co|fr|ca|be|ch|ly|link|site|online|top|click|ru|cn|tk|ml|ga|cf|gq|app|live|store|shop|vip|club|gov|edu|uk|de|us|sn|ci|ne|cm|bj|tg|bf|gn|ma|tn|dz|ng|gh|ke|rw))(?![a-z0-9-])/gi;

export function normalizeHost(host: string): string {
  return host.toLowerCase().replace(/\.$/, '').replace(/^www\./, '');
}

/** Hôtes mentionnés dans un texte (URL, `www.`, domaine nu). */
export function linkedHosts(text: string): string[] {
  const hosts = new Set<string>();
  const withoutUrls = text.replace(URL_HOST_RE, (whole, host: string) => {
    hosts.add(normalizeHost(host));
    return ' '.repeat(whole.length);
  });
  const withoutWww = withoutUrls.replace(WWW_HOST_RE, (whole, host: string) => {
    hosts.add(normalizeHost(host));
    return ' '.repeat(whole.length);
  });
  // Les adresses e-mail sont drapeautées à part : leur domaine n'est pas un lien.
  const withoutEmails = withoutWww.replace(new RegExp(EMAIL_RE.source, 'gi'), ' ');
  for (const match of withoutEmails.matchAll(BARE_DOMAIN_RE)) {
    hosts.add(normalizeHost(match[1]));
  }
  return [...hosts].filter(Boolean);
}

/**
 * Analyse un texte (titre + corps d'un contenu de membre). Renvoie les
 * drapeaux levés, triés selon `FILTER_FLAGS` ; liste vide = rien à revoir.
 */
export function scanContent(text: string, ctx: FilterContext): FilterFlag[] {
  const flags = new Set<FilterFlag>();
  const folded = foldText(text);

  if (containsPhoneNumber(text)) flags.add('phone');
  if (EMAIL_RE.test(text) || OBFUSCATED_EMAIL_RE.test(folded)) flags.add('email');
  if (
    DIRECT_CHAT_LINK_RE.test(folded) ||
    (CHAT_APP_RE.test(folded) && (INVITATION_RE.test(folded) || /\d{6,}/.test(text.replace(/[\s.-]/g, ''))))
  ) {
    flags.add('whatsapp');
  }
  if (MONEY_REQUEST_PATTERNS.some((re) => re.test(folded))) flags.add('money_request');
  if (MOBILE_MONEY_PATTERNS.some((re) => re.test(folded))) flags.add('mobile_money');
  if (linkedHosts(text).some((host) => !ctx.isAllowedHost(host))) {
    flags.add('external_link');
  }
  if (PROFANITY.some((term) => containsWord(folded, term))) flags.add('profanity');
  if (ctx.blockedTerms.some((term) => containsWord(folded, term))) {
    flags.add('blocked_term');
  }

  return FILTER_FLAGS.filter((flag) => flags.has(flag));
}

// ── Liste blanche intégrée des liens (§9.2) ─────────────────────────────────
//
// Domaines officiels. `*.x` = x et tous ses sous-domaines ; une entrée nue ne
// vaut que pour elle-même (et `www.`, toujours retiré avant la comparaison).
// Complétée à l'exécution par les hôtes des liens officiels du catalogue et
// par les ajouts de l'équipe (CommunityFilterEntry).

export const BUILTIN_ALLOWED_DOMAINS: readonly string[] = [
  '*.campusfrance.org',
  '*.gouv.fr',
  'service-public.fr',
  'parcoursup.fr',
  'monmaster.gouv.fr',
  'france-visas.gouv.fr',
  'canada.ca',
  '*.gc.ca',
  'quebec.ca',
  '*.gouv.qc.ca',
  'gov.uk',
  '*.gov.uk',
  '*.gov',
  '*.edu',
  '*.ac.uk',
  '*.daad.de',
  'chevening.org',
  '*.europa.eu',
  'studyinjapan.go.jp',
  'mext.go.jp',
  '*.fulbrightonline.org',
  'educationusa.state.gov',
  '*.gov.au',
  'studyinaustralia.gov.au',
  'kpbeducation.cloud',
];

/** `host` est-il couvert par l'une des règles (`x` ou `*.x`) ? */
export function hostMatchesRules(host: string, rules: Iterable<string>): boolean {
  const h = normalizeHost(host);
  for (const raw of rules) {
    const rule = raw.trim().toLowerCase();
    if (!rule) continue;
    if (rule.startsWith('*.')) {
      const base = rule.slice(2);
      if (h === base || h.endsWith(`.${base}`)) return true;
    } else if (h === normalizeHost(rule)) {
      return true;
    }
  }
  return false;
}
