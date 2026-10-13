import type { ScholarshipStudyLevel } from './data/scholarship-catalog.types';

/**
 * Niveau d'études canonique, indépendant de la locale.
 *
 * C'est le vocabulaire du catalogue vérifié (`secondary`, `bachelor`,
 * `master`), plus `doctorate`, que l'app propose (« PhD ») sans que le
 * catalogue sache encore l'exprimer.
 */
export type CanonicalStudyLevel = ScholarshipStudyLevel | 'doctorate';

/**
 * Tags de niveau reconnus, comparés EXACTEMENT et non en sous-chaîne : le tag
 * `mastercard-foundation` n'est pas un niveau. Seulement le vocabulaire du
 * catalogue vérifié, plus `doctorate`.
 *
 * Les tags `undergraduate`, `masters` et `phd` des collecteurs ne sont PAS des
 * niveaux : GreatYop les déduit aussi du titre en sous-chaîne (« Mastercard… »
 * devient `masters`, « Postdoctoral… » devient `phd`), MastereTn les recopie
 * de son propre libellé. Une fiche collectée retombe donc sur ses libellés,
 * que GreatYop tire de ses seules catégories.
 */
const LEVEL_TAGS: ReadonlyMap<string, CanonicalStudyLevel> = new Map<
  string,
  CanonicalStudyLevel
>([
  ['secondary', 'secondary'],
  ['bachelor', 'bachelor'],
  ['master', 'master'],
  ['doctorate', 'doctorate'],
]);

/**
 * Synonymes FR et EN d'un niveau dans un texte libre, cherchés comme MOTS sur
 * un texte en minuscules et sans accents : « Mastercard » n'est pas un master,
 * « post-secondaire » n'est pas le lycée, « post-doctorat » n'est pas un
 * doctorat.
 *
 * Le doctorat ignore aussi une mention niée (« pas de doctorat », « no
 * doctorate ») : c'est le seul niveau qu'on lit dans un libellé même quand la
 * fiche a des tags de niveau (voir `scholarshipLevels`), et un libellé cite
 * volontiers le doctorat qu'il exclut.
 */
const LEVEL_PATTERNS: ReadonlyArray<readonly [CanonicalStudyLevel, RegExp]> = [
  [
    'secondary',
    /(?<!post[\s-])\b(?:secondary|secondaires?|lycees?|high[\s-]?schools?)\b/,
  ],
  ['bachelor', /\b(?:bachelors?|bacheliers?|licences?|undergraduates?)\b/],
  ['master', /\b(?:masters?|masteres?|msc|mba|mim)\b/],
  [
    'doctorate',
    /(?<!\b(?:no|not|pas de|sans|hors|excluding|except)\s)(?<!post[\s-])\b(?:doctorats?|doctorates?|doctoral|ph\.?\s?d|dphil)\b/,
  ],
];

function foldText(text: string): string {
  return text
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

/**
 * Niveaux canoniques cités dans un texte libre : un libellé `levelEligible*`,
 * ou le niveau cible envoyé par l'app (`Bachelor`, `Master`, `PhD`, ou un
 * libellé plus ancien comme « Licence »). Vide quand rien n'est reconnu.
 */
export function levelsInText(
  text: string | null | undefined,
): Set<CanonicalStudyLevel> {
  const levels = new Set<CanonicalStudyLevel>();
  if (!text) return levels;
  const folded = foldText(text);
  for (const [level, pattern] of LEVEL_PATTERNS) {
    if (pattern.test(folded)) levels.add(level);
  }
  return levels;
}

/**
 * Niveaux d'une bourse.
 *
 * Ses tags de niveau d'abord : c'est la donnée structurée, et sur chaque fiche
 * du catalogue vérifié ils reprennent exactement son `levels`. Pour le
 * secondaire, la Licence et le Master, un libellé ne vaut pas mieux qu'eux.
 *
 * Le doctorat fait exception : le vocabulaire du catalogue vérifié s'arrête au
 * master, donc ses tags ne le nomment jamais, et leur silence ne veut pas dire
 * « pas de doctorat ». Quand les tags ne le portent pas, on le lit dans les
 * libellés FR+EN : Gates Cambridge (tag `master`, « … ou doctorat ») accepte
 * bien un doctorant. Une mention niée (« pas de doctorat ») ne compte pas.
 *
 * Sans tag de niveau (fiche collectée, saisie admin, seed héritée), repli sur
 * les DEUX libellés, FR et EN, pour tous les niveaux : le résultat ne dépend
 * jamais de la langue de la requête.
 */
export function scholarshipLevels(row: {
  tags: readonly string[];
  levelEligibleFr: string;
  levelEligibleEn: string;
}): Set<CanonicalStudyLevel> {
  const fromLabels = new Set([
    ...levelsInText(row.levelEligibleFr),
    ...levelsInText(row.levelEligibleEn),
  ]);
  const fromTags = new Set<CanonicalStudyLevel>();
  for (const tag of row.tags) {
    const level = LEVEL_TAGS.get(tag.trim().toLowerCase());
    if (level) fromTags.add(level);
  }
  if (fromTags.size === 0) return fromLabels;
  if (fromLabels.has('doctorate')) fromTags.add('doctorate');
  return fromTags;
}
