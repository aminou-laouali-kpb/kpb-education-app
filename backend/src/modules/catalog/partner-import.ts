// ─────────────────────────────────────────────────────────────────────────────
// Partner-catalogue import — the pure half.
//
// Lives under src/ (not scripts/) because jest is rooted on src/: keeping the
// parsing, the mapping tables and the money handling here is what makes them
// testable. scripts/import-partner-universities.ts is the thin CLI around it.
// ─────────────────────────────────────────────────────────────────────────────
import { createHash } from 'node:crypto';

// ── Mapping tables ──────────────────────────────────────────────────────────
// Both are CLOSED: an unmapped value aborts the run instead of writing an
// orphan. `Institution.countryId` and `Program.fieldId` are plain indexed
// columns, not foreign keys (see scripts/verify-catalog-country-refs.ts), so
// nothing downstream would catch a typo — the row would simply never surface
// under any filter.
export const COUNTRY_BY_LABEL: Record<string, string> = {
  France: 'fra',
  Maroc: 'mar',
  Espagne: 'esp',
  USA: 'usa',
  'EAU (Dubaï)': 'are',
  Turquie: 'tur',
};

export const FIELD_BY_LABEL: Record<string, string> = {
  'Informatique & IA': 'd01',
  'Commerce & Management': 'd02',
  'Ingénierie & Sciences': 'd03',
  'Santé & Sciences de la Vie': 'd04',
  'Architecture & BTP': 'd05',
  'Design, Médias & Communication': 'd06',
  'Droit & Sciences Politiques': 'd07',
  'Tourisme & Hôtellerie': 'd10',
};

/// ISO-639-1 codes for `Program.teachingLanguages`. Production is empty on this
/// column everywhere today (the OMNES seeder never filled it), so this import
/// sets the precedent: codes here, human-readable label in `languageFr`.
export const LANGUAGES_BY_LABEL: Record<string, string[]> = {
  Français: ['fr'],
  Anglais: ['en'],
  'Bilingue FR/EN': ['fr', 'en'],
  'Bilingue EN/FR': ['en', 'fr'],
  'FR/EN': ['fr', 'en'],
  'EN/FR': ['en', 'fr'],
  'Non précisée': [],
};

export type Target = {
  id: string;
  csvName: string;
  countryId: string;
  nameFr: string;
  nameEn: string;
  /// Campuses, when the CSV's "Ville" column packs several behind "·".
  campuses: string[];
};

export const TARGETS: Target[] = [
  {
    id: 'partner-mundiapolis',
    csvName: 'Université Mundiapolis',
    countryId: 'mar',
    nameFr: 'Université Mundiapolis',
    nameEn: 'Mundiapolis University',
    campuses: ['Casablanca — Roudani', 'Nouaceur', 'Casa Anfa'],
  },
  {
    // Already in production with zero programmes attached.
    id: 'partner-schiller-europe',
    csvName: 'Schiller International University — Europe',
    countryId: 'esp',
    nameFr: 'Schiller International University — Europe',
    nameEn: 'Schiller International University — Europe',
    campuses: ['Madrid', 'Paris', 'Heidelberg'],
  },
  {
    // Same university as above, other continent. Kept as its OWN institution
    // rather than a campus of the European entity: a student filtering on
    // "USA" must find it, and campuses do not carry a country.
    id: 'partner-schiller-tampa',
    csvName: 'Schiller International University — Tampa',
    countryId: 'usa',
    nameFr: 'Schiller International University — Tampa',
    nameEn: 'Schiller International University — Tampa',
    campuses: ['Tampa, Floride'],
  },
];

/// Lignes du CSV qui NE SONT PAS des écoles : les blocs « ECE / ESCE / INSEEC —
/// Rentrée décalée 2027 » sont des listes de formations (incomplètes, la
/// source de vérité est la grille SPRING 27, voir `import:omnes-spring`). Elles
/// ne doivent jamais devenir un établissement, même ajoutées par erreur à
/// `TARGETS` : `assertTargetsAreSchools` arrête l'import.
export const NON_SCHOOL_CSV_LABEL = /rentr[ée]e\s+d[ée]cal[ée]e/i;

export function assertTargetsAreSchools(targets: readonly Target[]): string[] {
  return targets
    .filter((t) => NON_SCHOOL_CSV_LABEL.test(t.csvName) || NON_SCHOOL_CSV_LABEL.test(t.nameFr))
    .map((t) => `${t.id} : « ${t.csvName} » n’est pas une école (bloc de rentrée décalée)`);
}

/// Degree levels the catalogue recognises once normalised by the admin service.
export const KNOWN_LEVELS = new Set([
  'Bachelor',
  'BBA',
  'Master',
  'MBA / DBA',
  'Doctorat',
  'Bac+2',
]);

/// Mirror of `normalizeDegreeLevel` in admin-catalog.service.ts, plus the one
/// French case that referential does not cover: a "diplôme d'ingénieur" is a
/// five-year degree, i.e. Master level.
export function normalizeLevel(raw: string): string {
  const s = (raw ?? '').toLowerCase();
  if (s.includes('doctorat') || s.includes('phd')) return 'Doctorat';
  if (s.includes('mba') || s.includes('dba')) return 'MBA / DBA';
  if (s.includes('ingénieur') || s.includes('ingenieur')) return 'Master';
  if (
    s.includes('master') || s.includes('msc') || s.includes('pge') ||
    s.includes('mastere') || s.includes('bac+5')
  ) {
    return 'Master';
  }
  if (s.includes('bba') || s.includes('bac+4')) return 'BBA';
  if (s.includes('bachelor') || s.includes('licence') || s.includes('bac+3')) {
    return 'Bachelor';
  }
  if (s.includes('bac+2')) return 'Bac+2';
  return (raw ?? '').trim();
}

/// Tuition floor in EUR, or null. Deliberately narrow: only a euro amount is
/// converted. A USD or MAD figure is left null rather than converted at a rate
/// that would be stale the day after it is written — `tuitionFr` keeps the
/// human-readable original either way.
export function parseTuitionMinEur(raw: string): number | null {
  const s = (raw ?? '').trim();
  if (!s || !s.includes('€')) return null;
  // Take the FIRST number in a range like "6 690 € – 7 025 €/an".
  const m = /(\d[\d\s  .]*)\s*€/.exec(s);
  if (!m) return null;
  const digits = m[1].replace(/[\s  .]/g, '');
  const n = Number.parseInt(digits, 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/// Columns this import is willing to BACKFILL on an institution that already
/// exists. Strictly empty → non-empty: the script's contract is "fills gaps,
/// never clobbers", and a blank column is a gap. Anything already written — by
/// hand, or by another tool — is left untouched.
///
/// Needed because the institution write is an `upsert` with an EMPTY `update`:
/// without this, a fiche created before a column was sourced stays blank
/// forever, which is exactly what happened to Mundiapolis's `overview`.
export const BACKFILLABLE = [
  'overviewFr',
  'overviewEn',
  'locationFr',
  'locationEn',
] as const;

export type BackfillableKey = (typeof BACKFILLABLE)[number];

/// « Vide » signifie ici la chaîne VIDE, sans `trim()`, et c'est délibéré.
///
/// Le comblement doit être exécutable comme un `UPDATE … WHERE col = ''`, seule
/// forme réellement atomique : entre la lecture du plan et l'écriture, un
/// administrateur peut avoir rempli la colonne, et un `update` inconditionnel
/// écraserait son texte (revue de #272). Une comparaison après `trim()` ne
/// s'exprime pas dans ce `WHERE`, donc la définition du vide doit être celle
/// que la base sait vérifier — sinon la garantie « ne jamais écraser » ne tient
/// que dans le code appelant, c'est-à-dire nulle part.
///
/// Conséquence assumée : une colonne ne contenant que des espaces n'est PAS
/// comblée. C'est le choix conservateur — on ne remplace rien qu'on ne sache
/// prouver vide au moment même de l'écriture.
export function institutionBlankFills(
  existing: Partial<Record<BackfillableKey, string | null>>,
  incoming: Partial<Record<BackfillableKey, string | null>>,
): Partial<Record<BackfillableKey, string>> {
  const out: Partial<Record<BackfillableKey, string>> = {};
  for (const key of BACKFILLABLE) {
    const current = existing[key] ?? '';
    const next = (incoming[key] ?? '').trim();
    if (current === '' && next !== '') out[key] = next;
  }
  return out;
}

export function stableId(prefix: string, key: string): string {
  return `${prefix}${createHash('sha256').update(key).digest('hex').slice(0, 16)}`;
}

// ── Minimal CSV reader (quoted fields, embedded commas and newlines) ─────────
export function parseCsv(text: string): Record<string, string>[] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;
  const src = text.replace(/^﻿/, '').replace(/\r\n/g, '\n');
  for (let i = 0; i < src.length; i += 1) {
    const c = src[i];
    if (quoted) {
      if (c === '"') {
        if (src[i + 1] === '"') { cell += '"'; i += 1; } else { quoted = false; }
      } else cell += c;
      continue;
    }
    if (c === '"') { quoted = true; continue; }
    if (c === ',') { row.push(cell); cell = ''; continue; }
    if (c === '\n') { row.push(cell); rows.push(row); row = []; cell = ''; continue; }
    cell += c;
  }
  if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
  const [header, ...body] = rows.filter((r) => r.some((v) => v.trim() !== ''));
  return body.map((r) =>
    Object.fromEntries(header.map((h, i) => [h.trim(), (r[i] ?? '').trim()])),
  );
}

export type PlannedProgram = {
  id: string;
  nameFr: string;
  levelFr: string;
  rawLevel: string;
  fieldId: string;
  durationFr: string;
  tuitionFr: string;
  tuitionMinEur: number | null;
  languageFr: string;
  teachingLanguages: string[];
  campusOfferings: { campus: string; tuitionUpfront: number | null; tuitionInstallments: number | null; intake: string | null }[] | null;
};

