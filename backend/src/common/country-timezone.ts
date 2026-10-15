// ─────────────────────────────────────────────────────────────────────────────
// Approximate UTC offset (whole hours) by country of residence.
//
// Used only to gate time-of-day-sensitive pushes (quiet hours). `countryOfResidence`
// is a free-form string captured at onboarding and is NOT normalized, so it is
// resolved case/accent-insensitively through the shared ISO table
// (iso-countries.ts: alpha-2, alpha-3, FR/EN names and aliases).
//
// Offsets deliberately ignore DST and half-hour zones: quiet hours is a soft guard
// (don't ping someone at 3am), not a scheduler, so ±1h at the margins is fine.
// Unknown or empty values fall back to UTC+0 (GMT) — the modal offset for
// francophone West Africa (Senegal, Mali, Côte d'Ivoire, Burkina Faso, Guinea…).
// ─────────────────────────────────────────────────────────────────────────────

import { resolveCountryCode } from './iso-countries';

export const DEFAULT_UTC_OFFSET_HOURS = 0;

// Fuseau par pays, indexé par le code alpha-3 de la table partagée
// (iso-countries.ts) : la résidence est d'abord résolue en pays — mêmes noms
// FR/EN, alias et codes alpha-2/alpha-3 que le test « Mes 10 bourses » —, puis
// son fuseau est lu ici. Gardé compact et centré sur le marché KPB (Afrique
// francophone) et les destinations d'études, puisqu'un parent peut résider à
// l'étranger.
const OFFSET_BY_COUNTRY: ReadonlyMap<string, number> = new Map<string, number>([
  ...[
    'sen', 'mli', 'civ', 'bfa', 'gin', 'tgo', 'mrt', 'gmb', 'gha', 'gbr', 'prt',
  ].map((code) => [code, 0] as const),
  ...[
    'ner', 'nga', 'ben', 'cmr', 'tcd', 'gab', 'cog', 'cod', 'caf', 'dza', 'tun',
    'mar', 'fra', 'bel', 'deu', 'esp', 'ita', 'che',
  ].map((code) => [code, 1] as const),
  ...['egy', 'zaf', 'rwa', 'bdi'].map((code) => [code, 2] as const),
  ...['tur', 'mdg', 'ken', 'sau', 'qat'].map((code) => [code, 3] as const),
  ...['are', 'mus'].map((code) => [code, 4] as const),
  ['chn', 8],
  // Le Canada couvre plusieurs fuseaux : défaut à l'Est (Québec/Montréal), où
  // s'installent la plupart des élèves KPB partis au Canada. États-Unis idem.
  ['can', -5],
  ['usa', -5],
]);

/** Whole-hour UTC offset for a residence string, or UTC+0 when unknown. */
export function utcOffsetHoursForCountry(country?: string | null): number {
  const code = resolveCountryCode(country);
  if (!code) return DEFAULT_UTC_OFFSET_HOURS;
  return OFFSET_BY_COUNTRY.get(code) ?? DEFAULT_UTC_OFFSET_HOURS;
}

/** Local hour (0–23) at `utcDate` for the given whole-hour offset. */
export function localHourFor(utcDate: Date, offsetHours: number): number {
  return (((utcDate.getUTCHours() + offsetHours) % 24) + 24) % 24;
}

/**
 * Local day of week (0 = Sunday … 6 = Saturday) at `utcDate` for the given
 * whole-hour offset. Needed for "send on Monday morning local time" schedules,
 * where the offset can push a user into the previous/next day.
 */
export function localWeekdayFor(utcDate: Date, offsetHours: number): number {
  const shifted = new Date(utcDate.getTime() + offsetHours * 60 * 60 * 1000);
  return shifted.getUTCDay();
}

/**
 * True when the local hour falls in the quiet window [startHour, endHour).
 * The window wraps midnight when startHour > endHour (e.g. 21 → 8 covers
 * 21,22,23,0,1,…,7). A degenerate start === end window is treated as "never
 * quiet" so a misconfiguration can never silence every push.
 */
export function isWithinQuietHours(
  utcDate: Date,
  offsetHours: number,
  startHour: number,
  endHour: number,
): boolean {
  if (startHour === endHour) return false;
  const hour = localHourFor(utcDate, offsetHours);
  return startHour > endHour
    ? hour >= startHour || hour < endHour
    : hour >= startHour && hour < endHour;
}
