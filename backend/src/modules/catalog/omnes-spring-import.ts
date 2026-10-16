// ─────────────────────────────────────────────────────────────────────────────
// Rentrée décalée OMNES (grille « SPRING 27 ») — la moitié pure de
// `import:omnes-spring`.
//
// La grille liste, ligne par ligne, les formations OMNES ouvertes en janvier –
// mars 2027 (ECE, ESCE, INSEEC). Le seed d'automne a déjà créé une fiche par
// formation (`omnes-p-<hash(école|nom sans campus)>`) avec ses offres par
// campus. Ce module calcule ce qu'il faut AJOUTER, et rien d'autre :
//
//  - formation déjà connue (même id) → les offres de printemps manquantes sont
//    ajoutées à la fin de `campusOfferings` ; le reste de la fiche, et les
//    offres déjà là, ne sont pas touchés ;
//  - formation inconnue → une fiche neuve, aux conventions du seed d'automne
//    (omnes-conventions.ts), rattachée à son école ;
//  - école → ses dates de rentrée et ses nouvelles formations sont AJOUTÉES à
//    `intakePeriods` / `programIds`.
//
// Le script (scripts/import-omnes-spring.ts) lit la base, appelle `planOmnesSpring`
// et écrit le plan ; c'est ici que vit tout ce qui décide, testé par
// omnes-spring-import.spec.ts.
// ─────────────────────────────────────────────────────────────────────────────
import {
  type CampusOffering,
  RHYTHM_BY_CODE,
  compareOfferings,
  intakeMonthYear,
  mergeCampusOfferings,
  readCampusOfferings,
} from './campus-offerings';
import {
  type OmnesRow,
  formatDuration,
  formatLevel,
  formatTuitionSummary,
  inferFieldId,
  normalizeFormationName,
  normalizeOmnesLanguage,
  omnesInstitutionId,
  omnesProgramId,
  toNumberOrNull,
} from './omnes-conventions';
import { parseCsv } from './partner-import';

export const FRANCE_COUNTRY_ID = 'fra';

/// Mêmes en-têtes que `omnes_fall_26.xlsx` (voir scripts/extract-catalog-sources.py).
export const OMNES_SPRING_COLUMNS = [
  'Ecole / School',
  'Type_Programme / Type of program',
  'Niveau_Etude_ / Level of studies',
  'Niveau Admission / Admission Level',
  'Langue / Language',
  'Rythme / Rythm',
  'Campus',
  'NOM / NAME',
  'Payment Comptant / Payment Upfront',
  'Paiement Echelonné / With installments (2)',
  'Date_de_Rentrée / Intake Date',
] as const;

/// Les écoles OMNES que le seed d'automne connaît. Liste FERMÉE : une ligne
/// d'une autre école arrête l'import au lieu de créer une école fantôme.
export const OMNES_SCHOOLS = ['ECE', 'ESCE', 'INSEEC', 'HEIP', 'Sup de Pub'];

/// Codes ISO-639-1 pour `Program.teachingLanguages` (même convention que
/// partner-import.ts : codes ici, libellé lisible dans `languageFr`).
export const TEACHING_LANGUAGES_BY_CODE: Record<string, string[]> = {
  FR: ['fr'],
  EN: ['en'],
  MX: ['fr', 'en'],
};

export type OmnesSpringRow = OmnesRow & {
  languageCode: string;
  rhythmCode: string;
};

/**
 * Lit le CSV extrait de la grille. Toute anomalie est une ERREUR, collectée
 * ligne par ligne : rien ne s'écrit sur une grille mal lue.
 */
export function parseOmnesSpringCsv(text: string): {
  rows: OmnesSpringRow[];
  errors: string[];
} {
  const raw = parseCsv(text);
  const errors: string[] = [];
  if (raw.length === 0) return { rows: [], errors: ['Grille vide.'] };
  const missing = OMNES_SPRING_COLUMNS.filter((c) => !(c in raw[0]));
  if (missing.length) {
    return { rows: [], errors: [`Colonnes absentes : ${missing.join(', ')}`] };
  }

  const rows: OmnesSpringRow[] = [];
  raw.forEach((r, index) => {
    const line = index + 2; // + l'en-tête, numérotation à partir de 1
    const school = r['Ecole / School'];
    const programName = r['NOM / NAME'];
    const campus = r['Campus'];
    const languageCode = r['Langue / Language'].toUpperCase();
    const rhythmCode = r['Rythme / Rythm'].toUpperCase();
    const intakeDate = r['Date_de_Rentrée / Intake Date'];
    const upfront = toNumberOrNull(r['Payment Comptant / Payment Upfront']);
    const installments = toNumberOrNull(
      r['Paiement Echelonné / With installments (2)'],
    );
    const problems: string[] = [];
    if (!OMNES_SCHOOLS.includes(school)) problems.push(`école inconnue « ${school} »`);
    if (!programName) problems.push('formation sans nom');
    if (!campus) problems.push('campus vide');
    if (!TEACHING_LANGUAGES_BY_CODE[languageCode]) {
      problems.push(`langue inconnue « ${languageCode} »`);
    }
    if (!RHYTHM_BY_CODE[rhythmCode]) problems.push(`rythme inconnu « ${rhythmCode} »`);
    if (!intakeMonthYear(intakeDate)) problems.push(`date de rentrée illisible « ${intakeDate} »`);
    if (upfront == null) problems.push('prix comptant illisible');
    if (problems.length) {
      errors.push(`ligne ${line} : ${problems.join(', ')} — ${programName}`);
      return;
    }
    rows.push({
      school,
      campus,
      programName,
      programFamily: r['Type_Programme / Type of program'],
      degreeLevel: r['Niveau_Etude_ / Level of studies'],
      admissionLevel: r['Niveau Admission / Admission Level'],
      language: normalizeOmnesLanguage(languageCode),
      paymentUpfront: upfront,
      paymentInstallments: installments,
      intakeDate,
      languageCode,
      rhythmCode,
    });
  });
  return { rows, errors };
}

export type SpringFormation = {
  id: string;
  institutionId: string;
  school: string;
  name: string;
  fieldId: string;
  level: { fr: string; en: string };
  duration: { fr: string; en: string };
  languages: string[];
  teachingLanguages: string[];
  requirements: string[];
  offerings: CampusOffering[];
};

/** Regroupe les lignes par formation, comme le seed d'automne. */
export function groupSpringFormations(
  rows: readonly OmnesSpringRow[],
): SpringFormation[] {
  const byId = new Map<string, SpringFormation>();
  for (const row of rows) {
    const name = normalizeFormationName(row.programName, row.campus);
    const id = omnesProgramId(row.school, name);
    const formation = byId.get(id) ?? {
      id,
      institutionId: omnesInstitutionId(row.school),
      school: row.school,
      name,
      fieldId: inferFieldId(row),
      level: formatLevel(row),
      duration: formatDuration(row),
      languages: [],
      teachingLanguages: [],
      requirements: [],
      offerings: [],
    };
    if (row.language && !formation.languages.includes(row.language)) {
      formation.languages.push(row.language);
    }
    for (const code of TEACHING_LANGUAGES_BY_CODE[row.languageCode] ?? []) {
      if (!formation.teachingLanguages.includes(code)) {
        formation.teachingLanguages.push(code);
      }
    }
    if (row.admissionLevel && !formation.requirements.includes(row.admissionLevel)) {
      formation.requirements.push(row.admissionLevel);
    }
    formation.offerings.push({
      campus: row.campus,
      tuitionUpfront: row.paymentUpfront,
      tuitionInstallments: row.paymentInstallments,
      intake: row.intakeDate,
      session: 'spring',
      rhythm: RHYTHM_BY_CODE[row.rhythmCode],
    });
    byId.set(id, formation);
  }
  for (const formation of byId.values()) formation.offerings.sort(compareOfferings);
  return [...byId.values()];
}

/** La donnée d'une fiche neuve, aux conventions du seed d'automne. */
export function springProgramCreateData(formation: SpringFormation) {
  const tuition = formatTuitionSummary(formation.offerings);
  const prices = formation.offerings
    .map((o) => o.tuitionUpfront)
    .filter((p): p is number => typeof p === 'number');
  const language = formation.languages.join(' / ');
  return {
    id: formation.id,
    institutionId: formation.institutionId,
    countryId: FRANCE_COUNTRY_ID,
    fieldId: formation.fieldId,
    nameFr: formation.name,
    nameEn: formation.name,
    levelFr: formation.level.fr,
    levelEn: formation.level.en,
    durationFr: formation.duration.fr,
    durationEn: formation.duration.en,
    tuitionFr: tuition.fr,
    tuitionEn: tuition.en,
    languageFr: language,
    languageEn: language,
    requirementsFr: formation.requirements,
    requirementsEn: formation.requirements,
    teachingLanguages: formation.teachingLanguages,
    tuitionMinEur: prices.length ? Math.round(Math.min(...prices)) : null,
    campusOfferings: formation.offerings,
  };
}

export type ExistingProgramState = {
  id: string;
  institutionId: string;
  campusOfferings: unknown;
  updatedAt: Date;
};

export type ExistingInstitutionState = {
  id: string;
  intakePeriods: string[];
  programIds: string[];
};

export type OfferingAddition = {
  id: string;
  name: string;
  institutionId: string;
  /// L'écriture est conditionnée à cette valeur : une fiche retouchée entre la
  /// lecture et l'écriture n'est pas écrasée (voir le script).
  expectedUpdatedAt: Date;
  merged: unknown[];
  added: CampusOffering[];
};

export type InstitutionAddition = {
  id: string;
  addIntakePeriods: string[];
  addProgramIds: string[];
};

export type OmnesSpringPlan = {
  additions: OfferingAddition[];
  creations: ReturnType<typeof springProgramCreateData>[];
  unchanged: string[];
  skipped: { id: string; name: string; reason: string }[];
  institutions: InstitutionAddition[];
  errors: string[];
};

/** Ordre chronologique de dates « jj/mm/aaaa ». */
function compareDates(a: string, b: string): number {
  const key = (d: string) => d.split('/').reverse().join('');
  return key(a).localeCompare(key(b));
}

/**
 * Ce qu'il faut écrire, et seulement cela. Pur : la base est passée en
 * argument, telle que le script l'a lue.
 */
export function planOmnesSpring(
  formations: readonly SpringFormation[],
  programs: ReadonlyMap<string, ExistingProgramState>,
  institutions: ReadonlyMap<string, ExistingInstitutionState>,
): OmnesSpringPlan {
  const plan: OmnesSpringPlan = {
    additions: [],
    creations: [],
    unchanged: [],
    skipped: [],
    institutions: [],
    errors: [],
  };

  const schoolIds = [...new Set(formations.map((f) => f.institutionId))].sort();
  for (const id of schoolIds) {
    if (!institutions.has(id)) {
      plan.errors.push(
        `École ${id} absente de la base : lancer d'abord le seed d'automne (npm run seed:omnes).`,
      );
    }
  }
  if (plan.errors.length) return plan;

  const createdBySchool = new Map<string, string[]>();
  const datesBySchool = new Map<string, Set<string>>();

  for (const formation of formations) {
    const dates = datesBySchool.get(formation.institutionId) ?? new Set<string>();
    for (const offer of formation.offerings) if (offer.intake) dates.add(offer.intake);
    datesBySchool.set(formation.institutionId, dates);

    const existing = programs.get(formation.id);
    if (!existing) {
      plan.creations.push(springProgramCreateData(formation));
      const list = createdBySchool.get(formation.institutionId) ?? [];
      list.push(formation.id);
      createdBySchool.set(formation.institutionId, list);
      continue;
    }
    const current = readCampusOfferings(existing.campusOfferings);
    if (current === null) {
      // Une fiche OMNES sans offres a été vidée à la main : y écrire les seules
      // offres de printemps effacerait, à l'écran, la rentrée d'automne.
      plan.skipped.push({
        id: formation.id,
        name: formation.name,
        reason: 'campusOfferings vide (fiche retouchée ?) — à vérifier dans l’admin',
      });
      continue;
    }
    const { merged, added } = mergeCampusOfferings(current, formation.offerings);
    if (added.length === 0) {
      plan.unchanged.push(formation.id);
      continue;
    }
    plan.additions.push({
      id: formation.id,
      name: formation.name,
      institutionId: existing.institutionId,
      expectedUpdatedAt: existing.updatedAt,
      merged,
      added,
    });
  }

  for (const id of schoolIds) {
    const inst = institutions.get(id)!;
    const addIntakePeriods = [...(datesBySchool.get(id) ?? [])]
      .filter((d) => !inst.intakePeriods.includes(d))
      .sort(compareDates);
    const addProgramIds = (createdBySchool.get(id) ?? []).filter(
      (p) => !inst.programIds.includes(p),
    );
    if (addIntakePeriods.length || addProgramIds.length) {
      plan.institutions.push({ id, addIntakePeriods, addProgramIds });
    }
  }
  return plan;
}

/** Nombre d'écritures d'un plan : zéro quand l'import a déjà été appliqué. */
export function planWriteCount(plan: OmnesSpringPlan): number {
  return plan.additions.length + plan.creations.length + plan.institutions.length;
}
