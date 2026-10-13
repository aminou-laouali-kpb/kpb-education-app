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
 * `mastercard-foundation` n'est pas un niveau. Vocabulaire du catalogue
 * vérifié, plus les catégories que posent les collecteurs GreatYop et
 * MastereTn (`undergraduate`, `masters`, `phd`).
 */
const LEVEL_TAGS: ReadonlyMap<string, CanonicalStudyLevel> = new Map<
  string,
  CanonicalStudyLevel
>([
  ['secondary', 'secondary'],
  ['bachelor', 'bachelor'],
  ['undergraduate', 'bachelor'],
  ['master', 'master'],
  ['masters', 'master'],
  ['doctorate', 'doctorate'],
  ['phd', 'doctorate'],
]);

/**
 * Synonymes FR et EN d'un niveau dans un texte libre, cherchés comme MOTS sur
 * un texte en minuscules et sans accents : « Mastercard » n'est pas un master,
 * « post-secondaire » n'est pas le lycée, « post-doctorat » n'est pas un
 * doctorat.
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
    /(?<!post[\s-])\b(?:doctorats?|doctorates?|doctoral|ph\.?\s?d|dphil)\b/,
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
 * du catalogue vérifié ils reprennent exactement son `levels`. Un libellé ne
 * vaut pas mieux qu'eux — « Secondaire, Licence ou Master — pas de doctorat »
 * CITE le doctorat qu'il exclut.
 *
 * Sans tag de niveau (saisie admin, seed héritée), repli sur les DEUX libellés,
 * FR et EN : le résultat ne dépend jamais de la langue de la requête.
 */
export function scholarshipLevels(row: {
  tags: readonly string[];
  levelEligibleFr: string;
  levelEligibleEn: string;
}): Set<CanonicalStudyLevel> {
  const fromTags = new Set<CanonicalStudyLevel>();
  for (const tag of row.tags) {
    const level = LEVEL_TAGS.get(tag.trim().toLowerCase());
    if (level) fromTags.add(level);
  }
  if (fromTags.size > 0) return fromTags;
  return new Set([
    ...levelsInText(row.levelEligibleFr),
    ...levelsInText(row.levelEligibleEn),
  ]);
}
