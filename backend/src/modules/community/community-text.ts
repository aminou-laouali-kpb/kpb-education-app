// ─────────────────────────────────────────────────────────────────────────────
// Communauté — le texte d'un contenu : jetons de mention, hashtags, segments,
// extrait, texte cherchable (§5.3 du contrat docs/community-api-contract.md).
//
// Fonctions PURES : aucune base, aucune horloge. Le serveur est la seule
// moitié qui découpe le texte — l'app et l'admin rendent `segments` — pour que
// les deux clients ne divergent jamais sur ce qu'est une mention ou un lien.
// ─────────────────────────────────────────────────────────────────────────────

import { normalizeSearchText } from '../etudes-en-france/catalog/eef-search-text';
import { COMMUNITY_LIMITS } from './community.constants';

export const COMMUNITY_ENTITY_TYPES = [
  'scholarship',
  'country',
  'institution',
  'program',
] as const;
export type CommunityEntityTypeValue = (typeof COMMUNITY_ENTITY_TYPES)[number];

export function isEntityType(value: unknown): value is CommunityEntityTypeValue {
  return (
    typeof value === 'string' &&
    (COMMUNITY_ENTITY_TYPES as readonly string[]).includes(value)
  );
}

/** `@[libellé](type:id)` — l'expression EXACTE publiée dans le contrat. */
const MENTION_TOKEN_SOURCE =
  '@\\[([^\\]\\n]{1,80})\\]\\((scholarship|country|institution|program):([A-Za-z0-9_-]{1,64})\\)';

function mentionTokenRe(): RegExp {
  return new RegExp(MENTION_TOKEN_SOURCE, 'g');
}

export interface MentionRef {
  type: CommunityEntityTypeValue;
  id: string;
  /** Libellé tel qu'écrit par le client (remplacé par le libellé canonique). */
  label: string;
}

export function mentionKey(type: string, id: string): string {
  return `${type}:${id}`;
}

/** Les mentions d'un corps, dédoublonnées, dans l'ordre d'apparition. */
export function extractMentionRefs(body: string): MentionRef[] {
  const seen = new Set<string>();
  const out: MentionRef[] = [];
  for (const match of body.matchAll(mentionTokenRe())) {
    const type = match[2] as CommunityEntityTypeValue;
    const id = match[3];
    const key = mentionKey(type, id);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ type, id, label: match[1] });
  }
  return out;
}

/** Libellé d'un jeton : jamais de `]` ni de saut de ligne, 80 caractères au plus. */
function tokenLabel(label: string): string {
  const clean = label.replace(/[\]\n\r]/g, ' ').replace(/\s+/g, ' ').trim();
  return clean.slice(0, 80) || '?';
}

/** Réécrit chaque jeton avec le libellé canonique du catalogue. */
export function canonicalizeMentionTokens(
  body: string,
  canonicalLabels: ReadonlyMap<string, string>,
): string {
  return body.replace(mentionTokenRe(), (whole, _label, type, id) => {
    const label = canonicalLabels.get(mentionKey(type, id));
    return label === undefined ? whole : `@[${tokenLabel(label)}](${type}:${id})`;
  });
}

// ── Hashtags ────────────────────────────────────────────────────────────────

const HASHTAG_RE =
  /(^|[^\p{L}\p{N}_&/])#([\p{L}\p{N}_]{2,40})(?![\p{L}\p{N}_])/gu;

/** « #CampusFrance » et « #campusfrance » → « campusfrance ». */
export function hashtagKey(display: string): string {
  return display
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/œ/g, 'oe')
    .replace(/æ/g, 'ae')
    .replace(/[^a-z0-9_]/g, '');
}

export interface HashtagRef {
  tag: string;
  display: string;
}

function validHashtag(display: string): boolean {
  const key = hashtagKey(display);
  return (
    key.length >= COMMUNITY_LIMITS.hashtagMin &&
    key.length <= COMMUNITY_LIMITS.hashtagMax &&
    !/^[0-9_]+$/.test(key)
  );
}

/** Hashtags d'un texte (hors URL et hors jetons de mention), dédoublonnés. */
export function extractHashtags(text: string): HashtagRef[] {
  const seen = new Set<string>();
  const out: HashtagRef[] = [];
  const stripped = stripUrls(text.replace(mentionTokenRe(), ' '));
  for (const match of stripped.matchAll(HASHTAG_RE)) {
    const display = match[2];
    if (!validHashtag(display)) continue;
    const tag = hashtagKey(display);
    if (seen.has(tag)) continue;
    seen.add(tag);
    out.push({ tag, display });
  }
  return out;
}

// ── URL ─────────────────────────────────────────────────────────────────────

const URL_RE = /https?:\/\/[^\s<>"'`]+/gi;

function trimUrl(raw: string): string {
  return raw.replace(/[.,;:!?)\]}»"']+$/u, '');
}

function stripUrls(text: string): string {
  return text.replace(URL_RE, (url) => ' '.repeat(url.length));
}

export function urlHost(url: string): string | null {
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return null;
    return parsed.hostname.toLowerCase();
  } catch {
    return null;
  }
}

// ── Segments ────────────────────────────────────────────────────────────────

export type Segment =
  | { kind: 'text'; text: string }
  | { kind: 'mention'; type: CommunityEntityTypeValue; id: string; label: string }
  | { kind: 'hashtag'; tag: string; display: string }
  | { kind: 'link'; url: string; text: string };

export interface MentionLabels {
  labelFr: string;
  labelEn: string;
}

export type Lang = 'fr' | 'en';

export function pickLang(raw: unknown): Lang {
  return typeof raw === 'string' && raw.toLowerCase().startsWith('en') ? 'en' : 'fr';
}

function pushText(out: Segment[], text: string): void {
  if (!text) return;
  const last = out[out.length - 1];
  if (last && last.kind === 'text') last.text += text;
  else out.push({ kind: 'text', text });
}

function segmentPlain(
  text: string,
  out: Segment[],
  isAllowedHost: (host: string) => boolean,
): void {
  let cursor = 0;
  for (const match of text.matchAll(URL_RE)) {
    const start = match.index ?? 0;
    const url = trimUrl(match[0]);
    segmentHashtags(text.slice(cursor, start), out);
    const host = urlHost(url);
    if (host && isAllowedHost(host)) out.push({ kind: 'link', url, text: url });
    else pushText(out, url);
    cursor = start + url.length;
  }
  segmentHashtags(text.slice(cursor), out);
}

function segmentHashtags(text: string, out: Segment[]): void {
  let cursor = 0;
  for (const match of text.matchAll(HASHTAG_RE)) {
    const display = match[2];
    if (!validHashtag(display)) continue;
    const hashStart = (match.index ?? 0) + match[1].length;
    pushText(out, text.slice(cursor, hashStart));
    out.push({ kind: 'hashtag', tag: hashtagKey(display), display });
    cursor = hashStart + 1 + display.length;
  }
  pushText(out, text.slice(cursor));
}

/**
 * Découpe un corps en segments. Une mention dont la ligne n'est pas connue
 * (contenu antérieur, entité retirée) garde le libellé de son jeton.
 */
export function buildSegments(
  body: string,
  mentions: ReadonlyMap<string, MentionLabels>,
  lang: Lang,
  isAllowedHost: (host: string) => boolean,
): Segment[] {
  const out: Segment[] = [];
  let cursor = 0;
  for (const match of body.matchAll(mentionTokenRe())) {
    const start = match.index ?? 0;
    segmentPlain(body.slice(cursor, start), out, isAllowedHost);
    const type = match[2] as CommunityEntityTypeValue;
    const id = match[3];
    const known = mentions.get(mentionKey(type, id));
    const label = known ? (lang === 'en' ? known.labelEn : known.labelFr) : match[1];
    out.push({ kind: 'mention', type, id, label });
    cursor = start + match[0].length;
  }
  segmentPlain(body.slice(cursor), out, isAllowedHost);
  return out;
}

/** Le corps en texte brut : chaque jeton devient « @libellé ». */
export function plainText(
  body: string,
  mentions: ReadonlyMap<string, MentionLabels>,
  lang: Lang,
): string {
  return body.replace(mentionTokenRe(), (_w, label, type, id) => {
    const known = mentions.get(mentionKey(type, id));
    return `@${known ? (lang === 'en' ? known.labelEn : known.labelFr) : label}`;
  });
}

/** Extrait ≤ 240 caractères, coupé au mot, suffixe « … ». */
export function excerptOf(
  body: string,
  mentions: ReadonlyMap<string, MentionLabels>,
  lang: Lang,
  max: number = COMMUNITY_LIMITS.excerptMax,
): string {
  const flat = plainText(body, mentions, lang).replace(/\s+/g, ' ').trim();
  if (flat.length <= max) return flat;
  const cut = flat.slice(0, max - 1);
  const lastSpace = cut.lastIndexOf(' ');
  const base = lastSpace > max * 0.6 ? cut.slice(0, lastSpace) : cut;
  return `${base.replace(/[\s.,;:!?-]+$/u, '')}…`;
}

/** Ce qu'on écrit dans `CommunityPost.searchText`. */
export function communitySearchText(input: {
  title: string;
  body: string;
  hashtags: readonly HashtagRef[];
  mentionLabels: readonly MentionLabels[];
}): string {
  const labels = input.mentionLabels.flatMap((m) => [m.labelFr, m.labelEn]);
  return normalizeSearchText(
    [
      input.title,
      input.body.replace(mentionTokenRe(), ' '),
      ...input.hashtags.map((h) => h.tag),
      ...labels,
    ].join(' '),
  );
}

/** Les mots d'une recherche, normalisés comme `searchText`. */
export function searchTerms(q: string): string[] {
  return [...new Set(normalizeSearchText(q).split(' ').filter(Boolean))].slice(0, 8);
}
