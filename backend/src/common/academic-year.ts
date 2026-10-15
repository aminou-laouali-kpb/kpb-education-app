import { registerDecorator, type ValidationOptions } from 'class-validator';

import { servedCycleStatus } from './public-scholarship-where';

/**
 * L'année académique d'un cycle de bourse : « 2027 » ou « 2027-2028 ».
 *
 * ## Pourquoi un module
 *
 * L'admin la saisit en texte libre et le serveur ne vérifiait que sa FORME
 * (`^\d{4}(?:-\d{4})?$`). « 2027-2029 » passait, et devenait un cycle que plus
 * personne ne retrouve : `@@unique([scholarshipId, academicYear])` en fait une
 * autre ligne que « 2027-2028 », donc une autre annonce d'ouverture. Avec la
 * clé de déduplication par cycle (`scholarship-opened:<cycleId>:<userId>`),
 * une faute de frappe vaut une seconde annonce aux mêmes étudiants.
 *
 * La forme reste celle que les admins déjà déployés envoient (contrat) ; la
 * règle ajoutée est « deux années consécutives ». Le catalogue n'en contient
 * pas d'autres (`2026-2027`, `2027-2028`, `2028-2029`) ; la requête de
 * contrôle avant déploiement est dans `docs/api-contracts.md`.
 */
export const ACADEMIC_YEAR_PATTERN = /^\d{4}(?:-\d{4})?$/;

/** Bornes [début, fin] d'une année bien formée ; « 2027 » vaut [2027, 2027]. */
function academicYearBounds(value: string): [number, number] | null {
  if (!ACADEMIC_YEAR_PATTERN.test(value)) return null;
  const [start, end] = value.split('-');
  const first = Number(start);
  return [first, end === undefined ? first : Number(end)];
}

/** « 2027 » ou « 2027-2028 » ; refuse « 2027-2029 », « 2028-2027 », « 27-28 ». */
export function isConsecutiveAcademicYear(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  const bounds = academicYearBounds(value);
  if (!bounds) return false;
  const [start, end] = bounds;
  return value.includes('-') ? end === start + 1 : true;
}

/**
 * Ordre chronologique : par année de début, puis de fin (« 2027 » avant
 * « 2027-2028 »). Une valeur mal formée compte comme la plus ancienne, pour
 * qu'un tri décroissant ne la prenne jamais pour « la plus récente ».
 */
export function compareAcademicYear(a: string, b: string): number {
  const left = academicYearBounds(a);
  const right = academicYearBounds(b);
  if (!left || !right) {
    if (left) return 1;
    if (right) return -1;
    return a.localeCompare(b);
  }
  return left[0] - right[0] || left[1] - right[1];
}

/** L'année suivante, même forme : « 2027-2028 » → « 2028-2029 », « 2027 » → « 2028 ». */
export function nextAcademicYear(year: string): string {
  const bounds = academicYearBounds(year);
  if (!bounds) {
    throw new RangeError('academicYear must look like 2026 or 2026-2027');
  }
  const next = bounds[0] + 1;
  return year.includes('-') ? `${next}-${next + 1}` : String(next);
}

/** La forme minimale d'un cycle dont `defaultOpeningAcademicYear` a besoin. */
export interface OpeningYearCycle {
  academicYear: string;
  status: string;
  activatedAt: Date | null;
  closesAt: Date | null;
  estimatedCloseAt: Date | null;
}

/**
 * L'année que l'aperçu d'ouverture propose par défaut :
 * - le cycle le plus récent (par année) s'il n'a pas été activé, ou s'il est
 *   SERVI ouvert (`servedCycleStatus`, donc clôture non passée) ;
 * - sinon l'année suivante ;
 * - sans cycle, `${y}-${y+1}` (année UTC de `now`), le défaut de l'admin actuel.
 *
 * Les cycles dont l'année n'est pas consécutive sont ignorés : les proposer
 * rendrait le formulaire impossible à valider (`@IsAcademicYear`).
 */
export function defaultOpeningAcademicYear(
  cycles: readonly OpeningYearCycle[],
  now: Date = new Date(),
): string {
  const newest = cycles
    .filter((cycle) => isConsecutiveAcademicYear(cycle.academicYear))
    .sort((a, b) => compareAcademicYear(b.academicYear, a.academicYear))[0];
  if (!newest) {
    const year = now.getUTCFullYear();
    return `${year}-${year + 1}`;
  }
  if (newest.activatedAt == null) return newest.academicYear;
  const served = servedCycleStatus(
    newest.status,
    newest.closesAt,
    newest.estimatedCloseAt,
    now,
  );
  return served === 'open'
    ? newest.academicYear
    : nextAcademicYear(newest.academicYear);
}

/**
 * Décorateur class-validator : une année bien formée ET consécutive. S'ajoute
 * à `@Matches(ACADEMIC_YEAR_PATTERN)` sans le remplacer, pour que le message
 * des admins déjà déployés reste le même sur une faute de forme.
 */
export function IsAcademicYear(validationOptions?: ValidationOptions) {
  return (object: object, propertyName: string): void => {
    registerDecorator({
      name: 'isAcademicYear',
      target: object.constructor,
      propertyName,
      options: {
        message:
          '$property must be one year (2027) or two consecutive years (2027-2028)',
        ...validationOptions,
      },
      validator: {
        validate: (value: unknown) => isConsecutiveAcademicYear(value),
      },
    });
  };
}
