// ─────────────────────────────────────────────────────────────────────────────
// Conventions du catalogue OMNES — la moitié pure de `seed:omnes`.
//
// Sorties de scripts/seed-omnes-programs.ts, à l'identique, pour que l'import
// de la rentrée décalée (`import:omnes-spring`) dérive EXACTEMENT les mêmes
// identifiants, niveaux, durées et domaines que le seed d'automne : une même
// formation doit retomber sur le même `omnes-p-<hash>`, sinon la grille de
// printemps créerait un doublon de chaque fiche existante.
//
// Vit sous src/ parce que jest est enraciné sur src/ (voir partner-import.ts).
// ─────────────────────────────────────────────────────────────────────────────
import { createHash } from 'node:crypto';

export const OMNES_INSTITUTION_ID_PREFIX = 'omnes-';
export const OMNES_PROGRAM_ID_PREFIX = 'omnes-p-';

/** Une ligne normalisée d'une grille OMNES (automne ou printemps). */
export type OmnesRow = {
  school: string;
  campus: string;
  programName: string;
  programFamily: string;
  degreeLevel: string;
  admissionLevel: string;
  language: string;
  paymentUpfront: number | null;
  paymentInstallments: number | null;
  intakeDate: string | null;
};

export function slugify(value: string, max = 40): string {
  return value
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, max);
}

/** Institution = school (campus-agnostic). e.g. "INSEEC" -> "omnes-inseec". */
export function omnesInstitutionId(school: string): string {
  return `${OMNES_INSTITUTION_ID_PREFIX}${slugify(school)}`;
}

/**
 * Strip the campus from a programme name so the same formation collapses to one
 * row across campuses. OMNES names follow "School - Type - Campus - Code -
 * Specialty"; the campus is one " - "-delimited segment, so we drop exactly
 * that segment (safe against a city name also appearing inside the specialty).
 */
export function normalizeFormationName(name: string, campus: string): string {
  const parts = name.split(' - ');
  const target = campus.trim().toLowerCase();
  const idx = parts.findIndex((p) => p.trim().toLowerCase() === target);
  if (idx !== -1) parts.splice(idx, 1);
  return parts.join(' - ').replace(/\s+/g, ' ').trim();
}

/** Stable id for a formation, identical across all its campuses. */
export function omnesProgramId(school: string, formationName: string): string {
  const key = `${school}|${formationName}`;
  const hash = createHash('sha256').update(key).digest('hex').slice(0, 16);
  return `${OMNES_PROGRAM_ID_PREFIX}${hash}`;
}

/// Field ids of the d01..d12 taxonomy (src/modules/orientation/
/// orientation-fields.data.ts) — the one the app filters on and the catalog
/// scores against. The former 'computer_science' / 'engineering' / 'business'
/// are the three demo fields of prisma/seed.ts: a formation filed under them
/// never surfaced under any real field.
export function inferFieldId(row: Pick<OmnesRow, 'programName' | 'programFamily'>): string {
  const text = `${row.programName} ${row.programFamily}`.toLowerCase();
  if (
    /informat|computer|cyber|data|digital|développeur|developpeur|ia\b|intelligence artificielle|dev\b|software/.test(
      text,
    )
  ) {
    return 'd01'; // Informatique & Intelligence Artificielle
  }
  if (/engineer|ingenier|ingénier|aeronaut|aéronaut/.test(text)) {
    return 'd03'; // Ingénierie & Sciences
  }
  return 'd02'; // Commerce & Management
}

export function studyLevelsFor(row: Pick<OmnesRow, 'programFamily'>): string[] {
  const levels = new Set<string>();
  const family = row.programFamily.toLowerCase();
  if (family.includes('bachelor') || family.includes('bba')) levels.add('Bachelor');
  if (family.includes('msc') || family.includes('master') || family.includes('pge')) {
    levels.add('Master');
  }
  if (family.includes('grande ecole') || family.includes('visa')) {
    levels.add('Master');
    levels.add('Grande École');
  }
  if (levels.size === 0) levels.add(row.programFamily);
  return [...levels];
}

/// Normalise a raw OMNES family + degree level to a clean canonical degree
/// label (Bachelor · BBA · Master · MBA / DBA · Doctorat · Bac+2, plus
/// Graduate certificate · Diplôme collégial for Canadian colleges). Mirrors the
/// Flutter `programLevelLabel` (lib/app/core/utils/study_level.dart) so the
/// catalogue shows consistent, épuré labels instead of "MSc · Bac+5", "PGE"…
export function normalizeDegreeLevel(raw: string): string {
  const s = raw.toLowerCase();
  if (s.includes('doctorat') || s.includes('phd') || s.includes('bac+8')) {
    return 'Doctorat';
  }
  if (s.includes('mba') || s.includes('dba')) return 'MBA / DBA';
  if (
    s.includes('bac+5') || s.includes('bac +5') || s.includes('master') ||
    s.includes('msc') || s.includes('pge') || s.includes('grande ecole') ||
    s.includes('grande école') || s.includes('mastere') || s.includes('visa')
  ) {
    return 'Master';
  }
  if (s.includes('bba') || s.includes('bac+4') || s.includes('bac +4')) {
    return 'BBA';
  }
  if (
    s.includes('bac+3') || s.includes('bac +3') || s.includes('bachelor') ||
    s.includes('licence')
  ) {
    return 'Bachelor';
  }
  // Collèges canadiens (catalogue Amérique du Nord, 17/10/2026) : le
  // certificat postdiplôme de l'Ontario (« Ontario College Graduate
  // Certificate ») et les diplômes collégiaux (diplôme / diplôme avancé de
  // l'Ontario, DEC du Québec, diplôme du CCNB) ne sont ni des licences ni des
  // masters.
  if (
    s.includes('graduate certificate') || s.includes('postgraduate certificate') ||
    s.includes('post-graduate certificate') || s.includes('certificat postdiplôme')
  ) {
    return 'Graduate certificate';
  }
  if (
    s.includes('diplôme collégial') || s.includes('diplome collegial') ||
    s.includes("diplôme d'études collégiales") || s.includes('college diploma') ||
    s.includes('advanced diploma')
  ) {
    return 'Diplôme collégial';
  }
  if (s.includes('bac+2') || s.includes('bac +2')) return 'Bac+2';
  return raw.trim();
}

export function formatLevel(
  row: Pick<OmnesRow, 'programFamily' | 'degreeLevel'>,
): { fr: string; en: string } {
  const label = normalizeDegreeLevel(
    `${row.programFamily} ${row.degreeLevel}`.trim(),
  );
  return { fr: label, en: label };
}

export function formatDuration(
  row: Pick<OmnesRow, 'degreeLevel'>,
): { fr: string; en: string } {
  const level = row.degreeLevel.toLowerCase();
  if (level.includes('bac+5') || level.includes('bac +5')) {
    return { fr: '5 ans', en: '5 years' };
  }
  if (level.includes('bac+3') || level.includes('bac +3')) {
    return { fr: '3 ans', en: '3 years' };
  }
  if (level.includes('bac+2') || level.includes('bac +2')) {
    return { fr: '2 ans', en: '2 years' };
  }
  return { fr: row.degreeLevel || '—', en: row.degreeLevel || '—' };
}

export function euro(value: number): string {
  return `${Math.round(value).toLocaleString('fr-FR')} €`;
}

/**
 * Headline tuition for a formation across its campuses. A single price when all
 * campuses align, otherwise a "min – max … selon le campus" range. Per-campus
 * detail lives in `campusOfferings`.
 */
export function formatTuitionSummary(
  offerings: readonly { tuitionUpfront: number | null }[],
): { fr: string; en: string } {
  const prices = offerings
    .map((o) => o.tuitionUpfront)
    .filter((p): p is number => typeof p === 'number' && !Number.isNaN(p));
  if (prices.length === 0) return { fr: 'Sur demande', en: 'On request' };
  const min = Math.min(...prices);
  const max = Math.max(...prices);
  if (min === max) return { fr: `${euro(min)}/an`, en: `${euro(min)}/year` };
  return {
    fr: `${euro(min)} – ${euro(max)}/an selon le campus`,
    en: `${euro(min)} – ${euro(max)}/year by campus`,
  };
}

export function intakeLabel(intakeDate: string | null): string[] {
  if (!intakeDate) return ['Rentrée automne'];
  return [intakeDate];
}

/** Libellé lisible d'un code langue OMNES (FR / EN / MX). */
export function normalizeOmnesLanguage(raw: unknown): string {
  const value = String(raw ?? '').trim().toUpperCase();
  switch (value) {
    case 'FR':
      return 'Français';
    case 'EN':
      return 'Anglais';
    case 'MX':
      return 'Mixte FR/EN';
    default:
      return String(raw ?? '').trim();
  }
}

export function toNumberOrNull(raw: unknown): number | null {
  if (raw == null) return null;
  const text = String(raw).replace(/[^\d.,-]/g, '').replace(',', '.').trim();
  if (!text) return null;
  const parsed = Number(text);
  return Number.isFinite(parsed) ? parsed : null;
}
