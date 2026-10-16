// ─────────────────────────────────────────────────────────────────────────────
// Catalogue Amérique du Nord (Canada, États-Unis) — la moitié pure de
// `import:north-america`.
//
// Demande du propriétaire (16/10/2026) : ajouter au catalogue des universités
// NON partenaires (`isPartner: false`) du Canada et des États-Unis, choisies
// pour les étudiants d'Afrique francophone. La sélection et ses critères sont
// justifiés dans docs/catalogue-amerique-du-nord.md ; chaque fait vient d'une
// page officielle consultée le 16/10/2026 (provenance, fait par fait, dans
// scripts/data/amerique-du-nord-2027.sources.md). Ce qui est resté introuvable
// est vide, jamais deviné.
//
// Données : scripts/data/amerique-du-nord-2027.json (versionné). Ce module ne
// lit aucun fichier : il valide le document, fabrique les lignes et décide
// quoi écrire. L'import est CRÉATION SEULE — une ligne déjà en base n'est
// jamais réécrite — et rejouable à 0 écriture.
// ─────────────────────────────────────────────────────────────────────────────
import { programSearchText } from '../etudes-en-france/catalog/eef-search-text';
import { type CampusOffering, type OfferingSession, compareOfferings } from './campus-offerings';
import { findHomonym, findProgramDuplicates, schoolNameKey } from './catalog-dedupe';
import { normalizeDegreeLevel } from './omnes-conventions';
import { detectCurrencies } from './tuition-eur';

export const NA_ID_PREFIX = 'na-';
export const NA_SEED_NAME = 'import:north-america';

/// Pays → (préfixe d'id, `countryId` canonique M5). Table FERMÉE.
export const NA_COUNTRIES: Record<string, { prefix: string; countryId: string }> = {
  can: { prefix: 'na-ca-', countryId: 'can' },
  usa: { prefix: 'na-us-', countryId: 'usa' },
};

/// Niveaux admis, déjà à la convention `normalizeDegreeLevel` (mêmes libellés
/// que l'app : lib/app/core/utils/study_level.dart).
export const NA_LEVELS = ['Bachelor', 'BBA', 'Master'] as const;

export const NA_FIELD_IDS = [
  'd01', 'd02', 'd03', 'd04', 'd05', 'd06', 'd07', 'd08', 'd09', 'd10', 'd11', 'd12',
] as const;

/// Langue d'enseignement d'une formation. Table FERMÉE.
export const NA_LANGUAGES: Record<string, { fr: string; en: string; codes: string[] }> = {
  en: { fr: 'Anglais', en: 'English', codes: ['en'] },
  fr: { fr: 'Français', en: 'French', codes: ['fr'] },
  bi: { fr: 'Français et anglais', en: 'French and English', codes: ['fr', 'en'] },
};

const ID_RE = /^na-(ca|us)-[a-z0-9]+(?:-[a-z0-9]+)*$/;
const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
/// « 01/2027 » (mois connu) ou « FALL 2027 » / « SPRING 2027 » (mois non
/// publié par la source) — les deux formats que l'app sait dater.
const INTAKE_RE = /^(?:(0[1-9]|1[0-2])\/(20\d{2})|(FALL|SPRING) (20\d{2}))$/;

export type NaMoney = { amount: number; currency: string };

export type NaOffering = { campus: string; intake: string; session: OfferingSession };

export type NaProgramSource = {
  slug: string;
  nameFr: string;
  nameEn: string;
  level: string;
  fieldId: string;
  language: string;
  durationFr: string;
  durationEn: string;
  tuitionFr: string;
  tuitionEn: string;
  tuitionAnnual: NaMoney | null;
  requirementsFr: string[];
  requirementsEn: string[];
  sourceUrl: string;
  offerings?: NaOffering[];
};

export type NaInstitutionSource = {
  id: string;
  countryId: string;
  nameFr: string;
  nameEn: string;
  acronym?: string | null;
  institutionType: string;
  locationFr: string;
  locationEn: string;
  websiteUrl: string;
  sourceUrl: string;
  overviewFr: string;
  overviewEn: string;
  languageRequirementsFr: string;
  languageRequirementsEn: string;
  applicationFee: NaMoney | null;
  applicationFeeFr: string;
  applicationFeeEn: string;
  tuitionLabelFr: string;
  tuitionLabelEn: string;
  intakePeriods: string[];
  teachingLanguages: string[];
  programs: NaProgramSource[];
};

export type NaSource = {
  source: string;
  consultedAt: string;
  exchangeRates: { date: string; source: string; perEur: Record<string, number> };
  institutions: NaInstitutionSource[];
};

/** Date de consultation des sources : `lastVerifiedAt` de chaque ligne. */
export function naVerifiedAt(doc: Pick<NaSource, 'consultedAt'>): Date {
  return new Date(`${doc.consultedAt}T00:00:00.000Z`);
}

export function naProgramId(institutionId: string, slug: string): string {
  return `${institutionId}--${slug}`;
}

/**
 * Clé d'homonymie d'un établissement : le nom SANS le sigle final entre
 * parenthèses. Le sigle est ajouté au nom affiché (« Université du Québec à
 * Montréal (UQAM) ») parce que la recherche de l'app ne lit que le nom et la
 * ville — comme « American Business College (ABC) » ; il ne doit pas
 * empêcher de reconnaître une fiche « Université du Québec à Montréal » déjà
 * saisie.
 */
export function naSchoolKey(name: string): string {
  return schoolNameKey(name.replace(/\s*\([^()]*\)\s*$/, ''));
}

/// La ville affichée et cherchable : « Houston, Texas » → « Houston ».
export function naCity(location: string): string {
  return location.split(',')[0].trim();
}

/**
 * Montant en euros, ARRONDI, au taux BCE versionné dans le document. Nul
 * quand le montant ou le taux manque : on ne devine pas.
 */
export function naToEur(money: NaMoney | null, rates: Record<string, number>): number | null {
  if (!money) return null;
  if (money.currency === 'EUR') return Math.round(money.amount);
  const perEur = rates[money.currency];
  if (!perEur || !(perEur > 0)) return null;
  return Math.round(money.amount / perEur);
}

/**
 * Un libellé de frais doit être lisible par l'app (lib/app/core/utils/
 * tuition_reading.dart) : UNE devise écrite en code (jamais « $ », qui se lit
 * USD), pas de « 9.850 » ambigu, pas de décimale à virgule (« 1 464,73 » se
 * lirait 146 473).
 */
export function tuitionLabelProblems(label: string, currency: string | null): string[] {
  if (!label) return [];
  const out: string[] = [];
  if (label.includes('$')) out.push('« $ » interdit (l’app le lit USD) : écrire le code devise');
  if (/\d\.\d{3}\b/.test(label)) out.push('point de milliers ambigu');
  if (/\d,\d{1,2}\b/.test(label) && /[A-Z]{3}/.test(label)) {
    // Une décimale à virgule avant un code devise (« 140,16 CAD ») se lit mal.
    out.push('décimale à virgule (arrondir)');
  }
  const found = detectCurrencies(label);
  if (found.length !== 1) out.push(`devise illisible (${found.join(', ') || 'aucune'})`);
  else if (currency && found[0] !== currency) out.push(`devise ${found[0]} ≠ ${currency}`);
  return out;
}

/** Contrôle du document entier. Vide = importable. */
export function validateNaSource(doc: NaSource): string[] {
  const errors: string[] = [];
  const rates = doc.exchangeRates?.perEur ?? {};
  if (!/^\d{4}-\d{2}-\d{2}$/.test(doc.consultedAt ?? '')) errors.push('consultedAt illisible');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(doc.exchangeRates?.date ?? '')) errors.push('exchangeRates.date illisible');
  const ids = new Set<string>();
  const names = new Map<string, string>();
  for (const inst of doc.institutions ?? []) {
    const where = inst.id ?? '(sans id)';
    const country = NA_COUNTRIES[inst.countryId];
    if (!country) errors.push(`${where} : pays inconnu « ${inst.countryId} »`);
    if (!ID_RE.test(inst.id ?? '')) errors.push(`${where} : id hors convention na-<pays>-<slug>`);
    else if (country && !inst.id.startsWith(country.prefix)) errors.push(`${where} : préfixe ≠ pays ${inst.countryId}`);
    if (ids.has(inst.id)) errors.push(`${where} : id en double`);
    ids.add(inst.id);
    for (const name of [inst.nameFr, inst.nameEn]) {
      const key = naSchoolKey(name ?? '');
      const other = names.get(key);
      if (other && other !== inst.id) errors.push(`${where} : même nom que ${other}`);
      names.set(key, inst.id);
    }
    for (const k of ['nameFr', 'nameEn', 'locationFr', 'locationEn', 'overviewFr', 'overviewEn', 'tuitionLabelFr', 'tuitionLabelEn'] as const) {
      if (!String(inst[k] ?? '').trim()) errors.push(`${where} : ${k} vide`);
    }
    for (const url of [inst.websiteUrl, inst.sourceUrl]) {
      if (!/^https:\/\//.test(url ?? '')) errors.push(`${where} : URL non https « ${url} »`);
    }
    if (!/\bKPB n'est pas partenaire\b/.test(inst.overviewFr) || !/\bKPB is not a partner\b/.test(inst.overviewEn)) {
      errors.push(`${where} : la présentation doit dire que KPB n'est pas partenaire`);
    }
    if (inst.applicationFee && !rates[inst.applicationFee.currency]) {
      errors.push(`${where} : pas de taux pour ${inst.applicationFee.currency}`);
    }
    if (inst.applicationFee && !inst.applicationFeeFr) errors.push(`${where} : applicationFeeFr vide`);
    for (const code of inst.teachingLanguages ?? []) {
      if (!['en', 'fr'].includes(code)) errors.push(`${where} : langue d'établissement inconnue « ${code} »`);
    }
    for (const label of [inst.tuitionLabelFr, inst.tuitionLabelEn]) {
      // Un libellé d'école sans montant (« fixés par le gouvernement du
      // Québec ») est permis ; dès qu'il cite une devise, il doit être lisible.
      if (label.includes('$') || detectCurrencies(label).length > 0) {
        for (const p of tuitionLabelProblems(label, null)) errors.push(`${where} : tuitionLabel — ${p}`);
      }
    }
    if (!(inst.programs ?? []).length) errors.push(`${where} : aucune formation`);
    const slugs = new Set<string>();
    for (const p of inst.programs ?? []) {
      const pw = `${where} / ${p.slug}`;
      if (!SLUG_RE.test(p.slug ?? '')) errors.push(`${pw} : slug invalide`);
      if (slugs.has(p.slug)) errors.push(`${pw} : slug en double`);
      slugs.add(p.slug);
      if (!(NA_LEVELS as readonly string[]).includes(p.level) || normalizeDegreeLevel(p.level) !== p.level) {
        errors.push(`${pw} : niveau hors convention « ${p.level} »`);
      }
      if (!(NA_FIELD_IDS as readonly string[]).includes(p.fieldId)) errors.push(`${pw} : domaine inconnu « ${p.fieldId} »`);
      if (!NA_LANGUAGES[p.language]) errors.push(`${pw} : langue inconnue « ${p.language} »`);
      if (!p.nameFr?.trim() || !p.nameEn?.trim()) errors.push(`${pw} : intitulé vide`);
      if (!/^https:\/\//.test(p.sourceUrl ?? '')) errors.push(`${pw} : sourceUrl non https`);
      if (Boolean(p.durationFr) !== Boolean(p.durationEn)) errors.push(`${pw} : durée FR/EN incohérente`);
      if ((p.requirementsFr ?? []).length !== (p.requirementsEn ?? []).length) {
        errors.push(`${pw} : conditions FR/EN de longueurs différentes`);
      }
      if (p.tuitionAnnual) {
        if (!rates[p.tuitionAnnual.currency]) errors.push(`${pw} : pas de taux pour ${p.tuitionAnnual.currency}`);
        if (!(p.tuitionAnnual.amount > 0)) errors.push(`${pw} : montant annuel invalide`);
        if (!p.tuitionFr || !p.tuitionEn) errors.push(`${pw} : libellé de frais vide malgré un montant`);
      }
      for (const label of [p.tuitionFr, p.tuitionEn]) {
        for (const pb of tuitionLabelProblems(label, p.tuitionAnnual?.currency ?? null)) errors.push(`${pw} : frais — ${pb}`);
      }
      for (const o of p.offerings ?? []) {
        if (!INTAKE_RE.test(o.intake)) errors.push(`${pw} : rentrée illisible « ${o.intake} »`);
        if (!['fall', 'spring'].includes(o.session)) errors.push(`${pw} : session inconnue « ${o.session} »`);
        if (!o.campus?.trim()) errors.push(`${pw} : campus vide`);
      }
      if ((p.offerings ?? []).length === 1) errors.push(`${pw} : une seule rentrée — pas de campusOfferings`);
    }
    const dups = findProgramDuplicates(
      (inst.programs ?? []).map((p) => ({ school: inst.id, id: naProgramId(inst.id, p.slug), name: p.nameFr, level: p.level })),
    );
    for (const d of dups) errors.push(`${where} : formations homonymes ${d.ids.join(', ')}`);
  }
  return errors;
}

/// Statut de l'établissement dans la fiche (`institutionType`) → libellé.
const TYPE_LABEL: Record<string, { fr: string; en: string }> = {
  universite_publique: { fr: 'université publique', en: 'public university' },
};

export function naInstitutionCreateData(inst: NaInstitutionSource, doc: NaSource) {
  const verifiedAt = naVerifiedAt(doc);
  return {
    id: inst.id,
    nameFr: inst.nameFr,
    nameEn: inst.nameEn,
    countryId: NA_COUNTRIES[inst.countryId].countryId,
    locationFr: inst.locationFr,
    locationEn: inst.locationEn,
    overviewFr: inst.overviewFr,
    overviewEn: inst.overviewEn,
    studyLevels: [...new Set(inst.programs.map((p) => p.level))],
    tuitionLabelFr: inst.tuitionLabelFr,
    tuitionLabelEn: inst.tuitionLabelEn,
    languageRequirementsFr: inst.languageRequirementsFr,
    languageRequirementsEn: inst.languageRequirementsEn,
    intakePeriods: [...inst.intakePeriods],
    programIds: inst.programs.map((p) => naProgramId(inst.id, p.slug)),
    // NON partenaire : ni badge, ni « S'inscrire via KPB » dans l'app.
    isPartner: false,
    institutionType: TYPE_LABEL[inst.institutionType] ? inst.institutionType : null,
    acronym: inst.acronym ?? null,
    websiteUrl: inst.websiteUrl,
    sourceUrl: inst.sourceUrl,
    lastVerifiedAt: verifiedAt,
    isActive: true,
  };
}

export function naOfferings(p: NaProgramSource): CampusOffering[] | null {
  if (!p.offerings || p.offerings.length < 2) return null;
  return p.offerings
    .map((o) => ({
      campus: o.campus,
      // Prix laissé vide : `tuitionUpfront` est lu comme des EUROS par l'app,
      // et les frais sont en USD / CAD. Le prix est dans `tuitionFr/En`.
      tuitionUpfront: null,
      tuitionInstallments: null,
      intake: o.intake,
      session: o.session,
    }))
    .sort(compareOfferings);
}

export function naProgramCreateData(p: NaProgramSource, inst: NaInstitutionSource, doc: NaSource) {
  const lang = NA_LANGUAGES[p.language];
  const city = naCity(inst.locationFr);
  const fee = naToEur(inst.applicationFee, doc.exchangeRates.perEur);
  const requirementsFr = [...p.requirementsFr];
  const requirementsEn = [...p.requirementsEn];
  return {
    id: naProgramId(inst.id, p.slug),
    institutionId: inst.id,
    countryId: NA_COUNTRIES[inst.countryId].countryId,
    fieldId: p.fieldId,
    nameFr: p.nameFr,
    nameEn: p.nameEn,
    levelFr: p.level,
    levelEn: p.level,
    durationFr: p.durationFr,
    durationEn: p.durationEn,
    // Sans montant publié pour la formation : le libellé de l'école.
    tuitionFr: p.tuitionFr || inst.tuitionLabelFr,
    tuitionEn: p.tuitionEn || inst.tuitionLabelEn,
    languageFr: lang.fr,
    languageEn: lang.en,
    teachingLanguages: [...lang.codes],
    requirementsFr,
    requirementsEn,
    // Candidature directe auprès de l'établissement : ni Études en France, ni
    // Parcoursup.
    procedureType: 'hors_eef',
    applicationFeeEur: fee,
    tuitionMinEur: naToEur(p.tuitionAnnual, doc.exchangeRates.perEur),
    campusOfferings: naOfferings(p),
    campusCity: city,
    searchText: programSearchText(p.nameFr, city),
    sourceUrl: p.sourceUrl,
    lastVerifiedAt: naVerifiedAt(doc),
    isActive: true,
  };
}

export type NaExistingInstitution = { id: string; nameFr: string; nameEn: string; programIds: string[] };
export type NaExistingProgram = { id: string; institutionId: string; nameFr: string; levelFr: string };

export type NaPlan = {
  /// Établissement absent : créé avec toutes ses formations.
  newInstitutions: {
    institution: ReturnType<typeof naInstitutionCreateData>;
    programs: ReturnType<typeof naProgramCreateData>[];
  }[];
  /// Établissement déjà là (même id) : formations manquantes créées, ids
  /// AJOUTÉS à `programIds`. Rien d'autre n'est réécrit.
  programAdditions: {
    institutionId: string;
    programs: ReturnType<typeof naProgramCreateData>[];
    addProgramIds: string[];
  }[];
  unchanged: string[];
  skipped: { id: string; name: string; reason: string }[];
};

/**
 * Le plan. `institutions` : TOUS les établissements en base (pour refuser un
 * homonyme saisi sous un autre id — l'Université d'Ottawa existe déjà sous
 * `uottawa`, par exemple). `programs` : les formations des établissements
 * visés (ids et homonymes).
 */
export function planNorthAmerica(
  doc: NaSource,
  institutions: readonly NaExistingInstitution[],
  programs: readonly NaExistingProgram[],
): NaPlan {
  const plan: NaPlan = { newInstitutions: [], programAdditions: [], unchanged: [], skipped: [] };
  const byId = new Map(institutions.map((i) => [i.id, i]));
  const programIds = new Set(programs.map((p) => p.id));
  for (const inst of doc.institutions) {
    const keys = new Set([naSchoolKey(inst.nameFr), naSchoolKey(inst.nameEn)]);
    const homonym = institutions.find(
      (i) => i.id !== inst.id && (keys.has(naSchoolKey(i.nameFr)) || keys.has(naSchoolKey(i.nameEn))),
    );
    if (homonym) {
      plan.skipped.push({
        id: inst.id,
        name: inst.nameFr,
        reason: `établissement homonyme déjà en base (${homonym.id}) — rien n'est créé, à rapprocher dans l'admin`,
      });
      continue;
    }
    const missing = inst.programs.filter((p) => {
      const id = naProgramId(inst.id, p.slug);
      if (programIds.has(id)) return false;
      const other = findHomonym({ id, institutionId: inst.id, nameFr: p.nameFr, levelFr: p.level }, programs);
      if (!other) return true;
      plan.skipped.push({
        id,
        name: p.nameFr,
        reason: `formation homonyme déjà en base (${other}) — rien n'est créé`,
      });
      return false;
    });
    const existing = byId.get(inst.id);
    if (!existing) {
      plan.newInstitutions.push({
        institution: naInstitutionCreateData(inst, doc),
        programs: missing.map((p) => naProgramCreateData(p, inst, doc)),
      });
      continue;
    }
    const addProgramIds = missing
      .map((p) => naProgramId(inst.id, p.slug))
      .filter((id) => !existing.programIds.includes(id));
    if (missing.length || addProgramIds.length) {
      plan.programAdditions.push({
        institutionId: inst.id,
        programs: missing.map((p) => naProgramCreateData(p, inst, doc)),
        addProgramIds,
      });
    } else {
      plan.unchanged.push(inst.id);
    }
  }
  return plan;
}

export function naPlanWriteCount(plan: NaPlan): number {
  return plan.newInstitutions.length + plan.programAdditions.length;
}
