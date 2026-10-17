/**
 * Fenêtre d'une campagne : des JOURS dans un fuseau, convertis en instants UTC.
 *
 * « Du 1er au 10 novembre 2026, heure d'Afrique de l'Ouest » se lit
 * `startDate = 2026-11-01`, `endDate = 2026-11-10` (dernier jour INCLUS), fuseau
 * `Africa/Lagos` (UTC+1, sans heure d'été). Les instants stockés sont :
 *
 * - `startsAt` = minuit local du premier jour  → 2026-10-31T23:00:00Z ;
 * - `endsAt`   = minuit local du lendemain du dernier jour (borne EXCLUSIVE)
 *                → 2026-11-10T23:00:00Z.
 *
 * Un filleul rattaché le 10/11 à 23 h 59 heure de Niamey compte ; à minuit pile,
 * non. La conversion passe par `Intl` (ICU complet de Node) : elle reste juste
 * pour un fuseau à heure d'été si une campagne en utilise un un jour.
 */

const LOCAL_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;
const LOCAL_DATE_TIME = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/;

export const DEFAULT_CAMPAIGN_TIME_ZONE = 'Africa/Lagos';

export function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone }).format(new Date(0));
    return true;
  } catch {
    return false;
  }
}

/** Décalage (ms) du fuseau à l'instant donné : heure locale − UTC. */
function offsetMs(instant: number, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(new Date(instant));
  const get = (type: string) =>
    Number(parts.find((p) => p.type === type)?.value ?? '0');
  const asUtc = Date.UTC(
    get('year'),
    get('month') - 1,
    get('day'),
    get('hour'),
    get('minute'),
    get('second'),
  );
  const flooredInstant = Math.floor(instant / 1000) * 1000;
  return asUtc - flooredInstant;
}

/** « 2026-11-01T00:00 » lu dans `timeZone` → instant UTC. */
export function zonedLocalToUtc(local: string, timeZone: string): Date {
  const m = LOCAL_DATE_TIME.exec(local);
  if (!m) throw new Error(`Invalid local date-time: ${local}`);
  if (!isValidTimeZone(timeZone)) throw new Error(`Invalid time zone: ${timeZone}`);
  const [, y, mo, d, h, mi, s] = m;
  const naive = Date.UTC(
    Number(y),
    Number(mo) - 1,
    Number(d),
    Number(h),
    Number(mi),
    Number(s ?? '0'),
  );
  // Deux passes : la seconde corrige un décalage différent de part et d'autre
  // d'un changement d'heure.
  let guess = naive - offsetMs(naive, timeZone);
  guess = naive - offsetMs(guess, timeZone);
  return new Date(guess);
}

/** Jour local (AAAA-MM-JJ) d'un instant dans `timeZone`. */
export function localDateOf(instant: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(instant);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '';
  return `${get('year')}-${get('month')}-${get('day')}`;
}

function nextDay(date: string): string {
  const m = LOCAL_DATE.exec(date);
  if (!m) throw new Error(`Invalid date: ${date}`);
  const t = Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]) + 1);
  return new Date(t).toISOString().slice(0, 10);
}

export function isValidLocalDate(date: string): boolean {
  const m = LOCAL_DATE.exec(date);
  if (!m) return false;
  const t = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  return t.toISOString().slice(0, 10) === date;
}

export interface CampaignWindow {
  startsAt: Date;
  endsAt: Date;
}

/** Jours inclusifs → [startsAt, endsAt[ en UTC. */
export function campaignWindowFromDays(
  startDate: string,
  endDate: string,
  timeZone: string = DEFAULT_CAMPAIGN_TIME_ZONE,
): CampaignWindow {
  if (!isValidLocalDate(startDate) || !isValidLocalDate(endDate)) {
    throw new Error('Dates must be YYYY-MM-DD.');
  }
  if (endDate < startDate) throw new Error('endDate is before startDate.');
  return {
    startsAt: zonedLocalToUtc(`${startDate}T00:00`, timeZone),
    endsAt: zonedLocalToUtc(`${nextDay(endDate)}T00:00`, timeZone),
  };
}

/** L'inverse, pour l'affichage : [startsAt, endsAt[ → jours inclusifs locaux. */
export function campaignDaysFromWindow(
  window: CampaignWindow,
  timeZone: string,
): { startDate: string; endDate: string } {
  return {
    startDate: localDateOf(window.startsAt, timeZone),
    // endsAt est exclusif : le dernier jour est celui de la milliseconde d'avant.
    endDate: localDateOf(new Date(window.endsAt.getTime() - 1), timeZone),
  };
}

export function isWithinWindow(at: Date, window: CampaignWindow): boolean {
  const t = at.getTime();
  return t >= window.startsAt.getTime() && t < window.endsAt.getTime();
}

export type CampaignPhase = 'upcoming' | 'running' | 'ended';

export function campaignPhase(window: CampaignWindow, now: Date): CampaignPhase {
  if (now.getTime() < window.startsAt.getTime()) return 'upcoming';
  if (now.getTime() < window.endsAt.getTime()) return 'running';
  return 'ended';
}
