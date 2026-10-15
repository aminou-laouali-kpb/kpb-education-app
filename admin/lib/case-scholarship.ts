import { scholarshipAdminHref } from './scholarship-eligibility';

/**
 * La bourse liée à un dossier (« Mes 10 bourses » → « Être accompagné »).
 *
 * Le serveur expose `scholarshipId` (nullable) et, s'il le peut, un résumé
 * `scholarship { id, nameFr, nameEn, … }`. Les deux sont FACULTATIFS : un
 * backend antérieur n'envoie ni l'un ni l'autre, une bourse supprimée laisse
 * `scholarshipId` à null (SET NULL), et un résumé absent n'empêche pas
 * d'afficher l'identifiant.
 */
export interface CaseScholarshipFields {
  scholarshipId?: string | null;
  scholarship?: {
    id?: string | null;
    nameFr?: string | null;
    nameEn?: string | null;
    sourceUrl?: string | null;
    applicationUrl?: string | null;
  } | null;
}

export interface LinkedScholarshipView {
  id: string;
  /** Nom dans la langue de l'admin, sinon l'autre, sinon l'identifiant. */
  label: string;
  /** Vrai quand seul l'identifiant est connu. */
  nameMissing: boolean;
  /** Lien vers la fiche dans le back-office, ou la page officielle, ou rien. */
  href: string | null;
  external: boolean;
}

function clean(value: string | null | undefined): string | null {
  const trimmed = typeof value === 'string' ? value.trim() : '';
  return trimmed === '' ? null : trimmed;
}

function httpUrl(value: string | null | undefined): string | null {
  const url = clean(value);
  if (!url) return null;
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' || parsed.protocol === 'http:' ? url : null;
  } catch {
    return null;
  }
}

/**
 * `canOpenAdminPage` : le rôle peut-il ouvrir la file des bourses (éditeurs
 * de contenu) ? Sinon (un conseiller), le lien mène à la page officielle de
 * la bourse quand le serveur la donne, et à rien sinon.
 */
export function linkedScholarshipView(
  item: CaseScholarshipFields,
  locale: 'fr' | 'en',
  canOpenAdminPage: boolean,
): LinkedScholarshipView | null {
  const id = clean(item.scholarshipId) ?? clean(item.scholarship?.id);
  if (!id) return null;
  const summary = item.scholarship ?? null;
  const preferred = locale === 'en' ? summary?.nameEn : summary?.nameFr;
  const fallback = locale === 'en' ? summary?.nameFr : summary?.nameEn;
  const name = clean(preferred) ?? clean(fallback);
  const official = httpUrl(summary?.sourceUrl) ?? httpUrl(summary?.applicationUrl);
  return {
    id,
    label: name ?? id,
    nameMissing: name === null,
    href: canOpenAdminPage ? scholarshipAdminHref(id) : official,
    external: !canOpenAdminPage && official !== null,
  };
}
