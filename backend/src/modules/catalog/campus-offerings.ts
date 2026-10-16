// ─────────────────────────────────────────────────────────────────────────────
// Offres par campus (`Program.campusOfferings`) — fusion ADDITIVE.
//
// Une offre = un campus + une rentrée, avec son prix. Depuis la rentrée décalée
// OMNES (printemps 2027) et IGENSIA (mars ET septembre 2027), une même
// formation peut avoir PLUSIEURS offres sur le même campus : Paris en
// septembre 2026, Paris en mars 2027, chacune à son prix. Deux champs
// facultatifs le disent :
//
//   session : 'fall' (rentrée d'automne) | 'spring' (rentrée décalée)
//   rhythm  : 'initiale' | 'alternance' (colonne « Rythme » CLA / ALT d'OMNES)
//
// Les offres écrites avant ce chantier n'ont ni l'un ni l'autre : l'app déduit
// alors la session du mois de la rentrée.
//
// La règle d'or des imports qui passent par ici : une offre EXISTANTE n'est
// jamais réécrite, réordonnée ni « nettoyée ». On ajoute à la fin ce qui
// manque, et l'objet existant est recopié tel quel, clés inconnues comprises.
// ─────────────────────────────────────────────────────────────────────────────

export type OfferingSession = 'fall' | 'spring';
export type OfferingRhythm = 'initiale' | 'alternance';

export const OFFERING_SESSIONS: readonly OfferingSession[] = ['fall', 'spring'];
export const OFFERING_RHYTHMS: readonly OfferingRhythm[] = [
  'initiale',
  'alternance',
];

export type CampusOffering = {
  campus: string;
  tuitionUpfront: number | null;
  tuitionInstallments: number | null;
  intake: string | null;
  session?: OfferingSession;
  rhythm?: OfferingRhythm;
};

/// Rythme OMNES (colonne « Rythme / Rythm »). Table FERMÉE : une valeur
/// inconnue arrête l'import plutôt que d'écrire une offre sans rythme.
export const RHYTHM_BY_CODE: Record<string, OfferingRhythm> = {
  CLA: 'initiale',
  ALT: 'alternance',
};

/** Comparaison de campus insensible à la casse, aux accents et aux espaces. */
export function campusKey(campus: string): string {
  return campus
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Mois et année d'une rentrée écrite « jj/mm/aaaa » (OMNES) ou « mm/aaaa »
 * (IGENSIA). Nul pour tout le reste (« FALL 2027 », texte libre de l'admin).
 */
export function intakeMonthYear(
  intake: string | null | undefined,
): { month: number; year: number } | null {
  const m = /^(?:\d{1,2}\/)?(\d{1,2})\/(\d{4})$/.exec((intake ?? '').trim());
  if (!m) return null;
  const month = Number(m[1]);
  if (month < 1 || month > 12) return null;
  return { month, year: Number(m[2]) };
}

/**
 * Session déduite du mois : janvier à juin = rentrée décalée, juillet à
 * décembre = rentrée d'automne. Nul quand le mois est illisible.
 */
export function sessionFromIntake(
  intake: string | null | undefined,
): OfferingSession | null {
  const my = intakeMonthYear(intake);
  if (!my) return null;
  return my.month <= 6 ? 'spring' : 'fall';
}

/// Les rentrées qu'une offre existante annonce. Le seed d'automne joint
/// plusieurs dates d'un même campus par « · ».
function intakesOf(raw: unknown): string[] {
  if (typeof raw !== 'string') return [];
  return raw
    .split('·')
    .map((part) => part.trim())
    .filter(Boolean);
}

type ExistingOffering = Record<string, unknown>;

/** Les offres déjà en base, telles quelles. Nul si la colonne n'est pas une liste. */
export function readCampusOfferings(raw: unknown): ExistingOffering[] | null {
  if (!Array.isArray(raw)) return null;
  return raw.filter(
    (item): item is ExistingOffering =>
      item != null && typeof item === 'object' && !Array.isArray(item),
  );
}

/**
 * L'offre entrante est-elle déjà là ? Même campus, ET :
 *  - soit la même date de rentrée (une offre d'automne « 01/10/2026 · 15/09/2026 »
 *    couvre ses deux dates) ;
 *  - soit la même session ET le même rythme, déclarés des deux côtés : une date
 *    corrigée à la main dans l'admin ne doit pas faire revenir l'offre d'origine
 *    en doublon.
 */
export function offeringIsPresent(
  existing: readonly ExistingOffering[],
  incoming: CampusOffering,
): boolean {
  const campus = campusKey(incoming.campus);
  return existing.some((offer) => {
    if (typeof offer.campus !== 'string' || campusKey(offer.campus) !== campus) {
      return false;
    }
    if (incoming.intake && intakesOf(offer.intake).includes(incoming.intake)) {
      return true;
    }
    return (
      incoming.session != null &&
      offer.session === incoming.session &&
      (offer.rhythm ?? null) === (incoming.rhythm ?? null)
    );
  });
}

/**
 * Fusion additive : les offres existantes, recopiées à l'identique et dans leur
 * ordre, puis celles qui manquent. `added` est vide quand il n'y a rien à
 * écrire — c'est ce qui rend un import rejouable à zéro écriture.
 */
export function mergeCampusOfferings(
  existing: readonly ExistingOffering[],
  incoming: readonly CampusOffering[],
): { merged: unknown[]; added: CampusOffering[] } {
  const added: CampusOffering[] = [];
  for (const offer of incoming) {
    if (offeringIsPresent([...existing, ...added], offer)) continue;
    added.push(offer);
  }
  return { merged: [...existing, ...added], added };
}

/** Tri d'affichage et d'écriture des offres NEUVES : campus, puis date. */
export function compareOfferings(a: CampusOffering, b: CampusOffering): number {
  const byCampus = a.campus.localeCompare(b.campus, 'fr');
  if (byCampus !== 0) return byCampus;
  const ka = intakeMonthYear(a.intake);
  const kb = intakeMonthYear(b.intake);
  const va = ka ? ka.year * 100 + ka.month : 0;
  const vb = kb ? kb.year * 100 + kb.month : 0;
  return va - vb;
}
