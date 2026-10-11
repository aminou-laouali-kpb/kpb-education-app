import type { FundingType } from '../scholarship-source.interface';

/**
 * Helpers shared by the GreatYop and MastereTn scrapers.
 *
 * Each one fixes a way the scrapers used to publish wrong data (measured on the
 * live sites on 10/10/2026):
 * - funding was detected on the RAW HTML, where WordPress CSS always contains
 *   `100%` → every scholarship came out `fully_funded`;
 * - the country was the first entry of a fixed list found ANYWHERE in the text,
 *   so a "Study in Italy" related link made an EPFL article Italian;
 * - `countryId` was a slug ("switzerland") while `Country.id` is alpha-3
 *   ("che"), so the country filter never matched a scraped row;
 * - a date without a year ("December 15") was dropped, and deadlines were
 *   stored at 00:00 UTC, so the last day was lost;
 * - static pages (/about-us/, /privacy-policy/…) were imported as scholarships;
 * - `fetch` had no timeout.
 */

/** Fetch timeout per page, so a hanging source cannot stall the refresh. */
export const SCRAPER_FETCH_TIMEOUT_MS = 15_000;

/** Visible text of an HTML fragment (tags, scripts and styles removed). */
export function htmlToText(html: string): string {
  return html
    .replace(/<(script|style)[^>]*>[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Funding type from the title and the ARTICLE TEXT — never the raw page. */
export function detectFundingType(title: string, articleText: string): FundingType {
  const text = `${title} ${articleText}`.toLowerCase();
  const fully = [
    'fully funded',
    'fully-funded',
    'full scholarship',
    'full tuition',
    '100% tuition',
    '100% funded',
    'entièrement financé',
    'entièrement financée',
    'bourse complète',
    'prise en charge totale',
  ];
  if (fully.some((needle) => text.includes(needle))) return 'fully_funded';
  const partial = [
    'partially funded',
    'partial scholarship',
    'partial funding',
    'stipend only',
    'tuition waiver',
    'partiellement financé',
    'bourse partielle',
    'allocation mensuelle',
  ];
  if (partial.some((needle) => text.includes(needle))) return 'partially_funded';
  return 'unknown';
}

type CountryEntry = { id: string; en: string; fr: string; aliases: string[] };

/** Destination countries the scrapers recognise, keyed by `Country.id`. */
export const SCRAPER_COUNTRIES: CountryEntry[] = [
  { id: 'jpn', en: 'Japan', fr: 'Japon', aliases: ['Japan', 'Japon', 'Japanese'] },
  { id: 'fra', en: 'France', fr: 'France', aliases: ['France', 'French Government'] },
  { id: 'deu', en: 'Germany', fr: 'Allemagne', aliases: ['Germany', 'Allemagne', 'German'] },
  {
    id: 'usa',
    en: 'United States',
    fr: 'États-Unis',
    aliases: ['United States', 'USA', 'U.S.', 'États-Unis', 'Etats-Unis'],
  },
  { id: 'can', en: 'Canada', fr: 'Canada', aliases: ['Canada', 'Canadian'] },
  {
    id: 'gbr',
    en: 'United Kingdom',
    fr: 'Royaume-Uni',
    aliases: ['United Kingdom', 'UK', 'Royaume-Uni', 'England', 'Scotland'],
  },
  { id: 'aus', en: 'Australia', fr: 'Australie', aliases: ['Australia', 'Australie'] },
  { id: 'chn', en: 'China', fr: 'Chine', aliases: ['China', 'Chine', 'Chinese Government'] },
  {
    id: 'kor',
    en: 'South Korea',
    fr: 'Corée du Sud',
    aliases: ['South Korea', 'Korea', 'Corée du Sud', 'Corée'],
  },
  { id: 'tur', en: 'Turkey', fr: 'Turquie', aliases: ['Turkey', 'Türkiye', 'Turkiye', 'Turquie'] },
  { id: 'ita', en: 'Italy', fr: 'Italie', aliases: ['Italy', 'Italie'] },
  { id: 'esp', en: 'Spain', fr: 'Espagne', aliases: ['Spain', 'Espagne'] },
  { id: 'mar', en: 'Morocco', fr: 'Maroc', aliases: ['Morocco', 'Maroc'] },
  { id: 'tun', en: 'Tunisia', fr: 'Tunisie', aliases: ['Tunisia', 'Tunisie'] },
  { id: 'sen', en: 'Senegal', fr: 'Sénégal', aliases: ['Senegal', 'Sénégal'] },
  { id: 'che', en: 'Switzerland', fr: 'Suisse', aliases: ['Switzerland', 'Suisse', 'Swiss', 'EPFL', 'ETH Zurich'] },
  { id: 'bel', en: 'Belgium', fr: 'Belgique', aliases: ['Belgium', 'Belgique'] },
  { id: 'nld', en: 'Netherlands', fr: 'Pays-Bas', aliases: ['Netherlands', 'Pays-Bas', 'Holland', 'Dutch'] },
  { id: 'swe', en: 'Sweden', fr: 'Suède', aliases: ['Sweden', 'Suède', 'Swedish'] },
  { id: 'nor', en: 'Norway', fr: 'Norvège', aliases: ['Norway', 'Norvège'] },
  { id: 'fin', en: 'Finland', fr: 'Finlande', aliases: ['Finland', 'Finlande'] },
  { id: 'hun', en: 'Hungary', fr: 'Hongrie', aliases: ['Hungary', 'Hongrie', 'Stipendium Hungaricum'] },
  { id: 'irl', en: 'Ireland', fr: 'Irlande', aliases: ['Ireland', 'Irlande'] },
];

export type DetectedCountry = { id: string; en: string; fr: string };

export const INTERNATIONAL: DetectedCountry = {
  id: 'international',
  en: 'International',
  fr: 'International',
};

function countOccurrences(text: string, alias: string): number {
  const escaped = alias.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp(`(^|[^\\p{L}])${escaped}(?=$|[^\\p{L}])`, 'gu');
  return (text.match(re) ?? []).length;
}

/**
 * Destination country: the one named in the TITLE wins (earliest mention);
 * otherwise the one mentioned MOST in the article text. A single passing
 * mention (a related-post link) no longer decides.
 */
export function detectCountry(title: string, articleText: string): DetectedCountry {
  let best: { entry: CountryEntry; index: number } | null = null;
  for (const entry of SCRAPER_COUNTRIES) {
    for (const alias of entry.aliases) {
      const re = new RegExp(
        `(^|[^\\p{L}])${alias.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?=$|[^\\p{L}])`,
        'u',
      );
      const m = re.exec(title);
      if (m && (best === null || m.index < best.index)) {
        best = { entry, index: m.index };
      }
    }
  }
  if (best) return pick(best.entry);

  let top: { entry: CountryEntry; count: number } | null = null;
  for (const entry of SCRAPER_COUNTRIES) {
    const count = entry.aliases.reduce(
      (sum, alias) => sum + countOccurrences(articleText, alias),
      0,
    );
    if (count > 0 && (top === null || count > top.count)) top = { entry, count };
  }
  // At least two mentions in the body: one stray mention is not a destination.
  return top && top.count >= 2 ? pick(top.entry) : INTERNATIONAL;
}

function pick(entry: CountryEntry): DetectedCountry {
  return { id: entry.id, en: entry.en, fr: entry.fr };
}

/** Country entry from an English or French display name (legacy callers). */
export function countryFromName(name: string): DetectedCountry {
  const lower = name.trim().toLowerCase();
  const entry = SCRAPER_COUNTRIES.find((c) =>
    [c.en, c.fr, ...c.aliases].some((alias) => alias.toLowerCase() === lower),
  );
  return entry ? pick(entry) : INTERNATIONAL;
}

const MONTHS: Record<string, number> = {
  january: 0, jan: 0, janvier: 0,
  february: 1, feb: 1, fevrier: 1, février: 1,
  march: 2, mar: 2, mars: 2,
  april: 3, apr: 3, avril: 3,
  may: 4, mai: 4,
  june: 5, jun: 5, juin: 5,
  july: 6, jul: 6, juillet: 6,
  august: 7, aug: 7, aout: 7, août: 7,
  september: 8, sep: 8, sept: 8, septembre: 8,
  october: 9, oct: 9, octobre: 9,
  november: 10, nov: 10, novembre: 10,
  december: 11, dec: 11, decembre: 11, décembre: 11,
};

/**
 * Deadline at the END of the stated day (23:59:59Z, the convention of the
 * verified catalogue). A date without a year takes the next occurrence after
 * `now` (a "December 15" read in October is this December; read in January it
 * was last December, i.e. already closed → next year is wrong too, so a date
 * more than 30 days in the past rolls to next year, otherwise stays).
 */
export function parseDeadline(text: string, now: Date = new Date()): Date | null {
  const candidates: Array<{ day: number; month: number; year?: number }> = [];
  const monthAlt = Object.keys(MONTHS).sort((a, b) => b.length - a.length).join('|');
  // "December 15, 2026" / "December 15"
  for (const m of text.matchAll(
    new RegExp(`\\b(${monthAlt})\\.?\\s+(\\d{1,2})(?!\\d)(?:st|nd|rd|th)?(?:,?\\s*(\\d{4}))?`, 'giu'),
  )) {
    candidates.push({ month: MONTHS[m[1].toLowerCase()], day: Number(m[2]), year: m[3] ? Number(m[3]) : undefined });
  }
  // "15 December 2026" / "15 mars"
  for (const m of text.matchAll(
    new RegExp(`(?<!\\d)(\\d{1,2})(?:er|st|nd|rd|th)?\\s+(${monthAlt})\\b\\.?(?:\\s+(\\d{4}))?`, 'giu'),
  )) {
    candidates.push({ day: Number(m[1]), month: MONTHS[m[2].toLowerCase()], year: m[3] ? Number(m[3]) : undefined });
  }
  for (const c of candidates) {
    if (c.month === undefined || c.day < 1 || c.day > 31) continue;
    let year = c.year ?? now.getUTCFullYear();
    let date = new Date(Date.UTC(year, c.month, c.day, 23, 59, 59));
    if (date.getUTCDate() !== c.day) continue; // 31 février…
    if (c.year === undefined && date.getTime() < now.getTime() - 30 * 86_400_000) {
      year += 1;
      date = new Date(Date.UTC(year, c.month, c.day, 23, 59, 59));
    }
    return date;
  }
  return null;
}

const STATIC_SLUGS = new Set([
  'about', 'about-us', 'a-propos', 'contact', 'contact-us', 'nous-contacter',
  'privacy', 'privacy-policy', 'politique-de-confidentialite', 'terms',
  'terms-and-conditions', 'termes', 'disclaimer', 'advertise', 'sitemap',
  'wp-json', 'wp-admin', 'wp-content', 'feed', 'accueil', 'home', 'blog',
]);

/**
 * Whether a listing link points at an ARTICLE: not a static page, and a slug
 * of at least three words (real posts are "epfl-excellence-fellowship-2027").
 */
export function isArticleLink(url: string): boolean {
  let slug: string;
  try {
    slug = new URL(url).pathname.replace(/^\/+|\/+$/g, '');
  } catch {
    return false;
  }
  if (!slug || slug.includes('/')) return false;
  if (STATIC_SLUGS.has(slug) || slug.startsWith('wp-')) return false;
  return slug.split('-').filter(Boolean).length >= 3;
}

/** `fetch` with a timeout and the scraper's headers. */
export async function fetchPageHtml(
  url: string,
  headers: Record<string, string>,
): Promise<string> {
  const res = await fetch(url, {
    headers,
    signal: AbortSignal.timeout(SCRAPER_FETCH_TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return res.text();
}
