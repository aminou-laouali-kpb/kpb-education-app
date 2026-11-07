import {
  ValidatorConstraint,
  type ValidatorConstraintInterface,
} from 'class-validator';

export const MINIMUM_ACCOUNT_AGE = 16;

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Une date de naissance est une date de calendrier, pas un instant : on la
 * range à minuit UTC du jour saisi.
 *
 * Avant le 07/11/2026 (audit de la 57, T4-06), `new Date(input.birthDate)`
 * lisait « 1990-03-15T00:00:00.000 » (l'app envoie le minuit local, sans
 * fuseau) dans le fuseau du serveur (`TZ=Africa/Niamey`, UTC+1) : la base
 * gardait 1990-03-14T23:00Z et l'app affichait le 14.
 *
 * Règle : une chaîne sans fuseau est lue en UTC ; puis on arrondit au minuit
 * UTC le plus proche. Cela couvre aussi une app qui renverrait l'ancienne
 * valeur (« 1990-03-14T23:00:00.000Z » → 15 mars) et tout minuit local d'un
 * fuseau à moins de 12 h d'UTC.
 */
export function birthDateAtUtcMidnight(value: string | Date): Date {
  let instant: Date;
  if (value instanceof Date) {
    instant = new Date(value);
  } else {
    const text = value.trim();
    const hasZone = /([zZ]|[+-]\d{2}:?\d{2})$/.test(text);
    const isDateOnly = /^\d{4}-\d{2}-\d{2}$/.test(text);
    instant = new Date(isDateOnly || hasZone ? text : `${text}Z`);
  }
  if (Number.isNaN(instant.getTime())) return instant;
  return new Date(Math.round(instant.getTime() / DAY_MS) * DAY_MS);
}

/** Calendar-age check used by both HTTP validation and the service boundary. */
export function isAtLeastAge(
  value: string | Date,
  minimumAge = MINIMUM_ACCOUNT_AGE,
  now = new Date(),
): boolean {
  const birthDate = value instanceof Date ? new Date(value) : new Date(value);
  if (Number.isNaN(birthDate.getTime()) || birthDate.getTime() > now.getTime()) {
    return false;
  }

  const threshold = new Date(now);
  threshold.setUTCFullYear(threshold.getUTCFullYear() - minimumAge);
  return birthDate.getTime() <= threshold.getTime();
}

@ValidatorConstraint({ name: 'minimumAccountAge', async: false })
export class MinimumAccountAgeConstraint
  implements ValidatorConstraintInterface
{
  validate(value: unknown): boolean {
    return (
      (typeof value === 'string' || value instanceof Date) &&
      isAtLeastAge(value)
    );
  }

  defaultMessage(): string {
    return `birthDate must show an age of at least ${MINIMUM_ACCOUNT_AGE}.`;
  }
}
