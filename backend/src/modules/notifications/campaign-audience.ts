import { CaseStatus } from '../../common/enums/case-status.enum';

/**
 * Les audiences de campagne, et le filtre que chacune EXIGE.
 *
 * Source unique : le DTO valide `audienceType` sur ces clés, l'exécuteur s'en
 * sert pour refuser de résoudre une audience dont le filtre manque, et un test
 * vérifie que l'exécuteur a bien une branche par clé.
 *
 * ── Pourquoi une valeur « exigée » ────────────────────────────────────────
 *
 * `resolveRecipients` construisait `where: filtre ? {…} : undefined` pour
 * `case_status`, `account_type` et `country_of_residence`. Or `where:
 * undefined` en Prisma ne veut pas dire « personne » : il veut dire « aucun
 * filtre », donc TOUS LES COMPTES. Un filtre oublié ou mal orthographié
 * transformait un envoi ciblé en diffusion à toute la base. `study_level`
 * retombait de même sur tous les étudiants.
 *
 * Le dépôt connaissait pourtant la règle — `country` porte depuis toujours le
 * commentaire « A missing filter must NOT fall through to "everyone" » et rend
 * un tableau vide, tout comme `single_user`. Elle n'était appliquée qu'à deux
 * audiences sur six.
 *
 * On échoue donc FERMÉ, partout : filtre absent ⇒ zéro destinataire. Envoyer à
 * personne est un incident qu'on constate et qu'on corrige ; envoyer à tout le
 * monde ne se rattrape pas.
 */
export const AUDIENCE_REQUIRED_FILTER: Readonly<Record<string, string | null>> =
  Object.freeze({
    // Diffusions assumées : leur nom DIT qu'elles visent tout le monde.
    all_users: null,
    all_students: null,
    // Les déclarants « Études en France » : l'ensemble est BORNÉ PAR LA TABLE
    // `EefInterest` (seuls ceux qui ont déclaré leur intérêt), pas par un filtre —
    // elle ne peut donc pas retomber sur « tout le monde ». `exceptCountries` est
    // OPTIONNEL : il retire les pays où la procédure est suspendue.
    eef_interest: null,
    // Audiences ciblées : sans leur filtre, elles ne visent personne.
    country: 'countryId',
    country_of_residence: 'countryCode',
    case_status: 'status',
    account_type: 'accountType',
    study_level: 'levels',
    // Tous les étudiants SAUF des pays donnés. Le filtre est exigé : une exclusion
    // vide serait « tous les étudiants », c'est-à-dire la diffusion que le nom de
    // cette audience prétend éviter.
    all_students_except_countries: 'exceptCountries',
    single_user: 'userId',
  });

export const AUDIENCE_TYPES = Object.keys(AUDIENCE_REQUIRED_FILTER);

/** Le filtre exigé par cette audience est-il présent et non vide ? */
export function audienceFilterMissing(
  audienceType: string,
  filters: Record<string, unknown>,
): boolean {
  const key = AUDIENCE_REQUIRED_FILTER[audienceType];
  if (!key) return false;
  const value = filters[key];
  if (value === undefined || value === null) return true;
  if (typeof value === 'string') return value.trim() === '';
  if (Array.isArray(value)) return value.length === 0;
  return false;
}

/**
 * Le jeton qui désigne « les pays où la procédure Études en France est
 * suspendue », lus dans `KPB_EEF_SUSPENDED_COUNTRIES` — la MÊME liste que celle
 * que `/config/app` sert à l'app.
 *
 * Écrire `["Niger","NE"]` à la main dans chaque campagne est ce qui fait oublier
 * un pays le jour où la liste change : une campagne « la campagne est ouverte »
 * partirait vers un pays dont l'État dit que les dossiers ne sont pas traités.
 * Avec ce jeton, la campagne suit la liste de l'exploitation.
 */
export const EEF_SUSPENDED_COUNTRIES_TOKEN = 'eef_suspended';

/**
 * Les pays à EXCLURE, depuis le filtre `exceptCountries` : une liste, une chaîne
 * séparée par des virgules, ou le jeton [EEF_SUSPENDED_COUNTRIES_TOKEN] (qui
 * peut aussi figurer DANS la liste, à côté d'autres pays).
 *
 * Dédoublonné et sans blancs. Vide quand rien n'est lisible : l'appelant décide
 * alors quoi en faire (`all_students_except_countries` échoue fermé, avant même
 * de venir ici ; `eef_interest` n'exclut simplement personne).
 */
export function resolveExcludedCountries(
  value: unknown,
  env: NodeJS.ProcessEnv = process.env,
): string[] {
  const raw: unknown[] = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(',')
      : [];

  const out = new Set<string>();
  for (const entry of raw) {
    if (typeof entry !== 'string') continue;
    const trimmed = entry.trim();
    if (!trimmed) continue;
    if (trimmed.toLowerCase() === EEF_SUSPENDED_COUNTRIES_TOKEN) {
      for (const country of (env.KPB_EEF_SUSPENDED_COUNTRIES ?? '').split(
        ',',
      )) {
        const name = country.trim();
        if (name) out.add(name);
      }
      continue;
    }
    out.add(trimmed);
  }
  return [...out];
}

/** Les audiences qui acceptent (ou exigent) `exceptCountries`. */
const EXCEPT_COUNTRIES_AUDIENCES = new Set([
  'eef_interest',
  'all_students_except_countries',
]);

/** Un jeton, pas un nom de pays : snake_case, au moins un `_`, aucun espace. */
const TOKEN_LIKE = /^[a-z0-9]+(?:_[a-z0-9]+)+$/i;

/**
 * Le filtre est-il MAL FORMÉ — c'est-à-dire présent mais incapable de faire ce
 * qu'il annonce ? Rend la raison, ou `null` s'il est exploitable.
 *
 * ## Pourquoi cette garde en plus de [audienceFilterMissing]
 *
 * `audienceFilterMissing` attrape l'exclusion ABSENTE ou VIDE. Elle laisse passer
 * le pire cas pour ces deux audiences : une exclusion NON VIDE qui ne désigne
 * personne. `["eef_suspendd"]` (faute de frappe sur le jeton) était lu comme un
 * nom de pays qu'aucun compte ne porte : l'envoi partait vers TOUS les étudiants,
 * Niger compris, avec un aperçu qui affichait simplement un nombre plus grand.
 * C'est exactement l'accident que l'exclusion existe pour empêcher — et il est
 * silencieux.
 *
 * Sont donc refusés, pour ces deux audiences seulement :
 *  - une clé de filtre inconnue (`exceptCountry`, `except`…) ;
 *  - `exceptCountries: null`, ni absent ni valeur ;
 *  - une entrée qui n'est pas du texte ;
 *  - une entrée en snake_case autre que le jeton connu (un nom de pays n'a pas de
 *    `_` collé : c'est un jeton mal écrit) ;
 *  - le jeton `eef_suspended` quand `KPB_EEF_SUSPENDED_COUNTRIES` est vide : il
 *    n'exclurait personne, et l'exploitant croirait le contraire.
 *
 * `case_status` a sa propre règle : le statut doit appartenir à l'enum
 * `CaseStatus` (voir [caseStatusFilterInvalid]).
 */
export function audienceFilterInvalid(
  audienceType: string,
  filters: Record<string, unknown>,
  env: NodeJS.ProcessEnv = process.env,
): string | null {
  if (audienceType === 'case_status') return caseStatusFilterInvalid(filters);
  if (!EXCEPT_COUNTRIES_AUDIENCES.has(audienceType)) return null;

  for (const key of Object.keys(filters)) {
    if (key !== 'exceptCountries') {
      return `filtre inconnu « ${key} » pour l'audience « ${audienceType} » (seul « exceptCountries » existe)`;
    }
  }
  if (!('exceptCountries' in filters)) return null;

  const value = filters['exceptCountries'];
  if (value === null || value === undefined) {
    return '« exceptCountries » est présent mais vide de sens (null)';
  }
  const entries: unknown[] = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(',')
      : [value];

  let usesToken = false;
  for (const entry of entries) {
    if (typeof entry !== 'string') {
      return '« exceptCountries » ne contient que du texte';
    }
    const trimmed = entry.trim();
    if (!trimmed) continue;
    if (trimmed.toLowerCase() === EEF_SUSPENDED_COUNTRIES_TOKEN) {
      usesToken = true;
      continue;
    }
    if (TOKEN_LIKE.test(trimmed)) {
      return `« ${trimmed} » ressemble à un jeton mais n'en est pas un (le seul jeton connu est « ${EEF_SUSPENDED_COUNTRIES_TOKEN} »)`;
    }
  }
  if (
    usesToken &&
    resolveExcludedCountries([EEF_SUSPENDED_COUNTRIES_TOKEN], env).length === 0
  ) {
    return `le jeton « ${EEF_SUSPENDED_COUNTRIES_TOKEN} » est vide : KPB_EEF_SUSPENDED_COUNTRIES ne désigne aucun pays, l'exclusion n'exclurait personne`;
  }
  return null;
}

/**
 * `case_status` : le statut doit être une valeur EXACTE de l'enum `CaseStatus`.
 * Avant, `"documents_requis"` ou `"Documents_Needed"` faisait échouer la requête
 * Prisma, l'erreur était avalée et la campagne se disait « terminée » à zéro
 * destinataire — aucun élève relancé, aucun message d'erreur.
 *
 * Un filtre absent ou vide reste du ressort de [audienceFilterMissing].
 */
function caseStatusFilterInvalid(
  filters: Record<string, unknown>,
): string | null {
  const value = filters['status'];
  if (value === undefined || value === null) return null;
  if (typeof value === 'string' && value.trim() === '') return null;
  const allowed: string[] = Object.values(CaseStatus);
  if (typeof value !== 'string' || !allowed.includes(value)) {
    return `statut de dossier inconnu « ${String(value)} » (valeurs admises : ${allowed.join(', ')})`;
  }
  return null;
}

const withoutAccents = (value: string) =>
  value.normalize('NFD').replace(/[\u0300-\u036f]/g, '');

/**
 * Les écritures d'un même pays que la base peut porter : tel quel, sans accents,
 * apostrophe droite ou typographique. L'app, elle, replie les accents et les
 * apostrophes avant de comparer (`EefCampaignWindow.normalizeCountry`) ; sans
 * ces variantes, exclure « Côte d'Ivoire » laisserait passer « Côte d’Ivoire ».
 */
export function countryVariants(country: string): string[] {
  const base = country.replace(/\s+/g, ' ').trim();
  const out = new Set<string>();
  for (const candidate of [base, withoutAccents(base)]) {
    out.add(candidate);
    out.add(candidate.replace(/\u2019/g, "'"));
    out.add(candidate.replace(/'/g, '\u2019'));
  }
  return [...out].filter(Boolean);
}

/**
 * Échappe un texte pour `ILIKE` : `%`, `_` et `\` sont des JOKERS en SQL.
 * Prisma passe `equals` + `mode: 'insensitive'` à `ILIKE` sans les échapper :
 * exclure « Mal_ » excluait « Mali », et exclure « % » excluait tout le monde.
 */
export function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (char) => `\\${char}`);
}
