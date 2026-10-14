import { createHash } from 'node:crypto';

/**
 * Le calcul horaire des push différés (boîte d'envoi des annonces
 * d'ouverture) : quand reprendre après les heures calmes, où commence le jour
 * local, et le décalage stable d'un élève.
 *
 * Même convention que le dispatcher (`notification-dispatch.service.ts`) :
 * fenêtre calme [`KPB_PUSH_QUIET_START`, `KPB_PUSH_QUIET_END`) — 21 h → 8 h par
 * défaut —, décalage horaire entier tiré du pays de résidence
 * (`country-timezone.ts`, UTC+0 par défaut = Africa/Abidjan), sans heure
 * d'été. C'est une garde douce, pas un ordonnanceur : ±1 h aux marges est
 * accepté.
 *
 * Tout est pur : l'heure est passée en argument, jamais lue.
 */

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

export const DEFAULT_QUIET_START_HOUR = 21;
export const DEFAULT_QUIET_END_HOUR = 8;

export interface QuietHours {
  startHour: number;
  endHour: number;
}

/** Mêmes noms, défauts et bornes que le dispatcher : vide ou illisible = défaut. */
function readHour(
  env: Readonly<Record<string, string | undefined>>,
  name: string,
  fallback: number,
): number {
  const raw = env[name]?.trim();
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(23, Math.max(0, parsed));
}

export function readQuietHours(
  env: Readonly<Record<string, string | undefined>> = process.env,
): QuietHours {
  return {
    startHour: readHour(env, 'KPB_PUSH_QUIET_START', DEFAULT_QUIET_START_HOUR),
    endHour: readHour(env, 'KPB_PUSH_QUIET_END', DEFAULT_QUIET_END_HOUR),
  };
}

/**
 * Le prochain instant, STRICTEMENT après `now`, où l'heure locale vaut
 * `hour:00` (décalage entier `offsetHours`).
 */
export function nextLocalHour(
  now: Date,
  offsetHours: number,
  hour: number,
): Date {
  const offsetMs = offsetHours * HOUR_MS;
  const local = now.getTime() + offsetMs;
  const localMidnight = Math.floor(local / DAY_MS) * DAY_MS;
  let candidate = localMidnight + hour * HOUR_MS;
  if (candidate <= local) candidate += DAY_MS;
  return new Date(candidate - offsetMs);
}

/** L'instant UTC de minuit local du jour local qui contient `now`. */
export function localDayStart(now: Date, offsetHours: number): Date {
  const offsetMs = offsetHours * HOUR_MS;
  const local = now.getTime() + offsetMs;
  return new Date(Math.floor(local / DAY_MS) * DAY_MS - offsetMs);
}

/**
 * Décalage stable d'un élève dans [0, maxMinutes) min, à la seconde : à 8 h,
 * les envois différés d'une nuit ne partent pas tous à la même seconde, et
 * toutes les lignes d'un même élève bougent ensemble (même valeur).
 */
export function userJitterMs(userId: string, maxMinutes = 20): number {
  const spanSeconds = Math.max(1, Math.trunc(maxMinutes * 60));
  const word = createHash('sha256').update(userId).digest().readUInt32BE(0);
  return (word % spanSeconds) * 1000;
}
