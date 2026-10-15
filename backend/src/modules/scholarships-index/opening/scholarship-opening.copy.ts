// ─────────────────────────────────────────────────────────────────────────────
// Les textes de l'annonce d'ouverture (chantier C).
//
// Règles :
// - l'élève est tutoyé ;
// - le nom de la bourse va dans le CORPS (Android tronque les titres) ;
// - les dates sont lues en UTC : l'admin enregistre `closesAt` à
//   `T23:59:59.999Z`, qu'un fuseau à l'ouest de Greenwich lirait la veille ;
// - la langue (EN si `preferredLanguage` commence par `en`, sinon FR) est
//   choisie à l'envoi ; l'inbox garde les deux.
//
// Une bourse dont la date d'ouverture est encore à venir n'est jamais dite
// « ouverte » : la variante « Dates confirmées » la remplace.
// ─────────────────────────────────────────────────────────────────────────────

import type {
  LocalizedPushCopy,
  OpeningCopyVariant,
  OpeningPreviewCopyVariant,
} from './scholarship-opening.contract';

export type OpeningLanguage = 'fr' | 'en';

const MONTHS: Record<OpeningLanguage, readonly string[]> = {
  fr: [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ],
  en: [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ],
};

/** « 1er novembre », « 5 novembre » ; "1 November". Toujours en UTC. */
export function formatDateUtc(date: Date, lang: OpeningLanguage): string {
  const day = date.getUTCDate();
  const month = MONTHS[lang][date.getUTCMonth()];
  if (lang === 'fr') return `${day === 1 ? '1er' : String(day)} ${month}`;
  return `${day} ${month}`;
}

/** EN si la langue préférée commence par `en` (comme le dispatcher), sinon FR. */
export function openingLanguage(
  preferredLanguage: string | null | undefined,
): OpeningLanguage {
  return (preferredLanguage ?? '').trim().toLowerCase().startsWith('en')
    ? 'en'
    : 'fr';
}

export interface OpeningNames {
  fr: string;
  en: string;
}

/** Les trois variantes d'une ligne d'inbox, dans les deux langues. */
export interface OpeningCopySet {
  /** `dates_confirmed` quand l'ouverture est encore à venir à l'instant de l'envoi. */
  variant: OpeningPreviewCopyVariant;
  fr: Record<OpeningCopyVariant, LocalizedPushCopy>;
  en: Record<OpeningCopyVariant, LocalizedPushCopy>;
}

function deadlineClause(
  closesAt: Date | null,
  lang: OpeningLanguage,
): string | null {
  if (!closesAt) return null;
  return lang === 'fr'
    ? `candidatures jusqu'au ${formatDateUtc(closesAt, 'fr')}`
    : `apply by ${formatDateUtc(closesAt, 'en')}`;
}

function alertCopy(
  name: string,
  closesAt: Date | null,
  lang: OpeningLanguage,
): LocalizedPushCopy {
  const deadline = deadlineClause(closesAt, lang);
  if (lang === 'fr') {
    return {
      title: "C'est ouvert",
      body: `${name} : ${deadline ?? 'les candidatures sont ouvertes'}. Ouvre la fiche pour voir les étapes.`,
    };
  }
  return {
    title: 'Applications are open',
    body: `${name}: ${deadline ?? 'applications are open'}. Open the page to see the steps.`,
  };
}

function favoriteCopy(
  name: string,
  closesAt: Date | null,
  lang: OpeningLanguage,
): LocalizedPushCopy {
  const deadline = deadlineClause(closesAt, lang);
  if (lang === 'fr') {
    return {
      title: 'Une bourse que tu suis est ouverte',
      body: `${name} : ${deadline ?? 'les candidatures sont ouvertes'}. Tu l'avais mise en favori.`,
    };
  }
  return {
    title: 'A scholarship you follow is open',
    body: `${name}: ${deadline ?? 'applications are open'}. You saved it as a favourite.`,
  };
}

function datesConfirmedCopy(
  name: string,
  opensAt: Date | null,
  closesAt: Date | null,
  lang: OpeningLanguage,
): LocalizedPushCopy {
  if (lang === 'fr') {
    const window =
      opensAt && closesAt
        ? `candidatures du ${formatDateUtc(opensAt, 'fr')} au ${formatDateUtc(closesAt, 'fr')}`
        : opensAt
          ? `candidatures à partir du ${formatDateUtc(opensAt, 'fr')}`
          : (deadlineClause(closesAt, 'fr') ?? 'dates confirmées');
    return { title: 'Dates confirmées', body: `${name} : ${window}.` };
  }
  const window =
    opensAt && closesAt
      ? `applications open ${formatDateUtc(opensAt, 'en')} and close ${formatDateUtc(closesAt, 'en')}`
      : opensAt
        ? `applications open ${formatDateUtc(opensAt, 'en')}`
        : (deadlineClause(closesAt, 'en') ?? 'dates confirmed');
  return { title: 'Dates confirmed', body: `${name}: ${window}.` };
}

/**
 * Les textes d'une annonce, construits au moment de l'envoi (`now`) : une
 * correction de dates pendant les 120 s d'attente est donc prise en compte.
 *
 * @param closesAt la clôture confirmée, à défaut l'estimée
 */
export function buildOpeningCopy(
  names: OpeningNames,
  opensAt: Date | null,
  closesAt: Date | null,
  now: Date,
): OpeningCopySet {
  const datesConfirmed =
    opensAt !== null && opensAt.getTime() > now.getTime();
  const build = (lang: OpeningLanguage) => ({
    alert: alertCopy(names[lang], closesAt, lang),
    favorite: favoriteCopy(names[lang], closesAt, lang),
    dates_confirmed: datesConfirmedCopy(names[lang], opensAt, closesAt, lang),
  });
  return {
    variant: datesConfirmed ? 'dates_confirmed' : 'opened',
    fr: build('fr'),
    en: build('en'),
  };
}

/**
 * Le push groupé (jamais une ligne d'inbox) : `names` du plus récent au plus
 * ancien, un par ligne regroupée — sa longueur est le nombre annoncé.
 *
 * `variant` : `opened` seulement si TOUTES les lignes annoncent une ouverture.
 * Dès qu'une ligne est un « Dates confirmées » (ouverture encore à venir), le
 * titre reste neutre : un groupé ne dit jamais « ouvertes » pour une bourse
 * qui ne l'est pas.
 */
export function buildBundleCopy(
  names: readonly string[],
  lang: OpeningLanguage,
  variant: OpeningPreviewCopyVariant,
): LocalizedPushCopy {
  const n = names.length;
  const [a = '', b = ''] = names;
  const opened = variant === 'opened';
  if (lang === 'fr') {
    const list =
      n <= 1
        ? a
        : n === 2
          ? `${a} et ${b}`
          : n === 3
            ? `${a}, ${b} et 1 autre`
            : `${a}, ${b} et ${n - 2} autres`;
    return opened
      ? {
          title: `${n} bourses que tu suis sont ouvertes`,
          body: `${list}. Regarde les dates limites.`,
        }
      : {
          title: `${n} bourses que tu suis ont du nouveau`,
          body: `${list}. Regarde les dates.`,
        };
  }
  const list =
    n <= 1 ? a : n === 2 ? `${a} and ${b}` : `${a}, ${b} and ${n - 2} more`;
  return opened
    ? {
        title: `${n} scholarships you follow are open`,
        body: `${list}. Check the deadlines.`,
      }
    : {
        title: `${n} scholarships you follow have updates`,
        body: `${list}. Check the dates.`,
      };
}
