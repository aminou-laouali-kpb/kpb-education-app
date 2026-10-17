// ─────────────────────────────────────────────────────────────────────────────
// Doublons du catalogue — noms normalisés et table de rapprochement OMNES.
//
// Deux formations d'une même école sont LA MÊME fiche quand leurs noms ne
// diffèrent que par la casse, les accents, les espaces, les tirets, le campus
// resté collé dans l'intitulé (« BCh- Bordeaux - B1 - … »), un segment répété
// (« M1 - M1 ») ou l'orthographe « Developpement / Development ».
// `programNameKey` est cette égalité ; le test-garde
// (catalog-duplicates.spec.ts) l'applique à tous les seeds et imports.
//
// Les identifiants OMNES (`omnes-p-<hash(école|nom)>`) sont dérivés du nom
// d'automne, tel que `normalizeFormationName` le nettoie, et sont EN
// PRODUCTION : changer cette normalisation les déplacerait. On ne la touche
// donc pas. Une variante d'écriture retombe sur l'id existant par la table
// EXPLICITE `OMNES_PROGRAM_ID_ALIASES` (alias → id canonique). L'id canonique
// est toujours un id du seed d'automne quand la formation y figure.
// ─────────────────────────────────────────────────────────────────────────────
import {
  type CampusOffering,
  mergeCampusOfferings,
  readCampusOfferings,
} from './campus-offerings';
import { normalizeFormationName, omnesProgramId } from './omnes-conventions';

/** Minuscules, sans accents, tirets / apostrophes / espaces unifiés. */
export function foldName(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[‐-―−]/g, '-')
    .replace(/[‘’ʼ`´]/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

/// Variantes d'orthographe tenues pour identiques dans la clé (jamais dans le
/// nom affiché). Liste courte et FERMÉE : chaque entrée a été vue dans une
/// grille source.
const SPELLING: [RegExp, string][] = [[/developpement/g, 'development']];

/**
 * Les segments d'un intitulé « École - Type - Campus - Code - Spécialité » :
 * séparés par un tiret entouré d'au moins une espace (« Paris- B1 » compte,
 * « Start-up » non) ; une parenthèse finale est un segment
 * (« … (100% English) » = « … - 100% English »).
 */
function segments(folded: string): string[] {
  return folded
    .replace(/\(([^()]*)\)/g, ' - $1 - ')
    .split(/\s+-\s*|\s*-\s+/)
    .map((s) => s.trim())
    .filter(Boolean);
}

/**
 * Clé de comparaison d'une formation dans son école. Le campus, s'il est
 * donné, est retiré : segment entier ou dernier mot d'un segment
 * (« MSc CGE Paris »).
 */
export function programNameKey(name: string, campus?: string | null): string {
  let folded = foldName(name);
  for (const [re, to] of SPELLING) folded = folded.replace(re, to);
  const target = campus ? foldName(campus) : '';
  const out: string[] = [];
  for (let seg of segments(folded)) {
    if (target) {
      if (seg === target) continue;
      if (seg.endsWith(` ${target}`)) seg = seg.slice(0, -target.length - 1).trim();
    }
    const compact = seg.replace(/[^a-z0-9+%]+/g, '');
    if (!compact || out[out.length - 1] === compact) continue;
    out.push(compact);
  }
  return out.join('|');
}

/** Clé de comparaison d'une école (nom). */
export function schoolNameKey(name: string): string {
  return foldName(name).replace(/[^a-z0-9]+/g, '');
}

/**
 * L'intitulé AFFICHÉ d'une formation OMNES, sans campus. Plus strict que
 * `normalizeFormationName` (qui fait l'id) : retire aussi un campus collé à
 * son tiret (« BCh- Rennes - … », « Paris- ING4 »), un segment répété et
 * normalise les « - ». Ne sert JAMAIS à calculer un id.
 */
export function cleanOmnesFormationName(name: string, campus: string): string {
  const target = foldName(campus);
  const parts = name
    .replace(/\s+/g, ' ')
    .trim()
    .split(/\s+-\s*|\s*-\s+/)
    .map((s) => s.trim())
    .filter(Boolean);
  const out: string[] = [];
  for (const part of parts) {
    if (foldName(part) === target) continue;
    if (out.length && foldName(out[out.length - 1]) === foldName(part)) continue;
    out.push(part);
  }
  return out.join(' - ');
}

export type OmnesAlias = {
  /// L'id qui fait foi (celui du seed d'automne quand la formation y est).
  canonical: string;
  /// Ce qui distingue l'alias, pour la revue.
  reason: string;
};

/// Table de rapprochement EXPLICITE (audit du 16/10/2026, grilles
/// omnes_fall_26.xlsx et omnes_spring_27.csv). Clé = id qu'une variante
/// d'écriture produirait ; valeur = la fiche sur laquelle elle doit retomber.
/// Le test-garde vérifie qu'elle couvre tous les doublons des grilles, qu'elle
/// ne chaîne pas et qu'un id canonique n'est jamais lui-même un alias.
export const OMNES_PROGRAM_ID_ALIASES: Record<string, OmnesAlias> = {
  // ── ECE
  'omnes-p-9838cac07f49c259': {
    canonical: 'omnes-p-8a4646566f6f1da4',
    reason: 'automne : « Developpeur » sans accent (ECE - B3 - Développeur en intelligence artificielle)',
  },
  'omnes-p-b37a173f112e752e': {
    canonical: 'omnes-p-ccab8475c73fd758',
    reason: 'printemps : « ECE - MSc CGE Paris - M1 - Artificial Intelligence (100% English) » (campus et parenthèses)',
  },
  // ── ESCE
  'omnes-p-05f9231a3054fa1d': {
    canonical: 'omnes-p-5e6bbea7512aada8',
    reason: 'printemps : « ESCE - AN4 - International Business Development (100% English) », sans « PGE » (À VALIDER)',
  },
  // ── INSEEC — campus resté dans l'intitulé d'automne
  'omnes-p-6e6b2568f651ba68': {
    canonical: 'omnes-p-bf33379880d7cebf',
    reason: 'automne : « BCh - Chambéry- B1 - Banque Assurance » (campus dans le nom)',
  },
  'omnes-p-4f9563b0a1a1358f': {
    canonical: 'omnes-p-bf33379880d7cebf',
    reason: 'automne : « BCh- Rennes - B1 - Banque Assurance » (campus dans le nom)',
  },
  'omnes-p-5bb572807fecb972': {
    canonical: 'omnes-p-32433b0bbb7b35f0',
    reason: 'automne : « BCh -Toulouse - B1 - Finance d’entreprise » (campus dans le nom)',
  },
  'omnes-p-ef9fc39dcb44c37c': {
    canonical: 'omnes-p-32433b0bbb7b35f0',
    reason: 'printemps : « Finance d’Entreprise » (casse)',
  },
  'omnes-p-84b4a9fd28168e47': {
    canonical: 'omnes-p-9d5c27b600e81fd1',
    reason: 'automne : « BCh - Paris- B2 - Banque Assurance » (campus dans le nom)',
  },
  'omnes-p-63bdd97fde4cc807': {
    canonical: 'omnes-p-629a5637e4b5a9ce',
    reason: 'automne : « BCh - Chambéry- B2 - Finance d’entreprise » (campus dans le nom)',
  },
  'omnes-p-40daca93ef99e28f': {
    canonical: 'omnes-p-629a5637e4b5a9ce',
    reason: 'automne : « BCh - Marseille- B2 - Finance d’entreprise » (campus dans le nom)',
  },
  'omnes-p-a83acae0ea7187e8': {
    canonical: 'omnes-p-cbaa716e4def7b9b',
    reason: 'automne : « BCh- Marseille - B3 - Banque Assurance » (campus dans le nom)',
  },
  'omnes-p-af686e2ac75f59f8': {
    canonical: 'omnes-p-c9a108240d695bd0',
    reason: 'printemps : « BCh- Bordeaux - B1 - Luxe et services personnalisés – … » (campus dans le nom)',
  },
  // ── INSEEC — casse
  'omnes-p-1c48574683f79dde': {
    canonical: 'omnes-p-5b5225f2346bc062',
    reason: 'printemps : « Activités Commerciales » (casse)',
  },
  'omnes-p-0575da5a5ff411a5': {
    canonical: 'omnes-p-f4a077ed40f40f72',
    reason: 'printemps : « Activités Commerciales » (casse)',
  },
  'omnes-p-f7d36c24b0b8bf0d': {
    canonical: 'omnes-p-3f93679371081b4b',
    reason: 'automne (Chambéry) : « Ingénierie d’Affaires » (casse)',
  },
  'omnes-p-9e2a2d1878e76221': {
    canonical: 'omnes-p-c28831d091d53bf6',
    reason: 'printemps : « Expert en Management Immobilier » (casse)',
  },
  'omnes-p-1f4c24f009c13627': {
    canonical: 'omnes-p-c00a0a0d3224211e',
    reason: 'automne (Lyon) : « IMSc - M1 - M1 - Chef de Projet Marketing & IA » (segment répété)',
  },
  // ── INSEEC — « Gestionnaire patrimoine » (automne) / « de Patrimoine » (printemps)
  'omnes-p-db3e36e6f24d24d3': {
    canonical: 'omnes-p-63164ca26d9504b4',
    reason: 'printemps : « IMSc - M1 - Gestionnaire de Patrimoine » (À VALIDER)',
  },
  'omnes-p-19e47dac984fb52f': {
    canonical: 'omnes-p-91fdb796a0e291f3',
    reason: 'printemps : « IMSc - M2 - Gestionnaire de Patrimoine » (À VALIDER)',
  },
  // ── Sup de Pub
  'omnes-p-cc103388d47c1719': {
    canonical: 'omnes-p-678d9be173074390',
    reason: 'automne : « Stratégie Media » sans accent',
  },
  'omnes-p-50eb287ef2ade64f': {
    canonical: 'omnes-p-6ec7759d088905d6',
    reason: 'automne : « SP5 -Stratégie » (tiret collé)',
  },
};

/** L'id sur lequel une formation doit retomber. */
export function resolveOmnesProgramId(id: string): string {
  return OMNES_PROGRAM_ID_ALIASES[id]?.canonical ?? id;
}

/**
 * Identité d'une ligne de grille OMNES : l'id (historique, puis rapproché),
 * l'intitulé affiché (sans campus) et si la ligne est une variante (alias) —
 * le nom d'une fiche est pris sur une ligne canonique quand il y en a une.
 */
export function omnesFormationIdentity(
  school: string,
  programName: string,
  campus: string,
): { id: string; name: string; isAlias: boolean } {
  const legacy = omnesProgramId(school, normalizeFormationName(programName, campus));
  const id = resolveOmnesProgramId(legacy);
  return { id, name: cleanOmnesFormationName(programName, campus), isAlias: id !== legacy };
}

export type NamedRecord = {
  /// École (id) — les doublons ne se cherchent qu'à l'intérieur d'une école.
  school: string;
  id: string;
  name: string;
  level: string;
  campus?: string | null;
  source?: string;
};

/**
 * Les paires d'ids DISTINCTS d'une même école qui ont le même nom normalisé et
 * le même niveau. Vide = aucun doublon.
 */
export function findProgramDuplicates(records: readonly NamedRecord[]): {
  key: string;
  ids: string[];
  names: string[];
}[] {
  const groups = new Map<string, Map<string, string>>();
  for (const r of records) {
    const key = `${r.school}#${foldName(r.level)}#${programNameKey(r.name, r.campus)}`;
    const ids = groups.get(key) ?? new Map<string, string>();
    if (!ids.has(r.id)) ids.set(r.id, r.source ? `${r.source}: ${r.name}` : r.name);
    groups.set(key, ids);
  }
  return [...groups.entries()]
    .filter(([, ids]) => ids.size > 1)
    .map(([key, ids]) => ({ key, ids: [...ids.keys()], names: [...ids.values()] }));
}

/**
 * Une fiche homonyme (même école, même nom normalisé, même niveau) DÉJÀ en
 * base sous un autre id — fiche créée à la main dans l'admin, par exemple.
 * Un import ne crée pas une telle formation : il la signale.
 */
export function findHomonym(
  candidate: { id: string; institutionId: string; nameFr: string; levelFr: string },
  existing: readonly { id: string; institutionId: string; nameFr: string; levelFr: string }[],
): string | null {
  const key = programNameKey(candidate.nameFr);
  const level = foldName(candidate.levelFr);
  const hit = existing.find(
    (p) =>
      p.id !== candidate.id &&
      p.institutionId === candidate.institutionId &&
      foldName(p.levelFr) === level &&
      programNameKey(p.nameFr) === key,
  );
  return hit?.id ?? null;
}

// ── Fusion des doublons déjà en base (`dedupe:omnes`) ───────────────────────

export type DedupeProgramState = {
  id: string;
  nameFr: string;
  nameEn: string;
  campusOfferings: unknown;
  isActive: boolean;
  updatedAt: Date;
};

export type OmnesDedupePlan = {
  /// Fiche canonique : offres de ses alias ajoutées à la fin, intitulé
  /// nettoyé du campus quand il en porte un.
  canonicalUpdates: {
    id: string;
    expectedUpdatedAt: Date;
    merged: unknown[] | null;
    added: number;
    rename: { nameFr: string; nameEn: string } | null;
  }[];
  /// Alias encore actifs : mis hors ligne (`isActive = false`), jamais effacés.
  deactivations: { id: string; canonical: string; expectedUpdatedAt: Date; reason: string }[];
  /// Alias dont la fiche canonique est absente : laissés tels quels.
  orphans: { id: string; canonical: string }[];
};

/// Un campus collé à son tiret dans un intitulé (« BCh- Rennes - B1 »).
function cleanNameAgainstCampuses(name: string, campuses: readonly string[]): string {
  return campuses.reduce((n, campus) => cleanOmnesFormationName(n, campus), name);
}

/**
 * Ce que la fusion doit écrire. Pur. Une offre existante n'est jamais
 * réécrite (fusion additive de campus-offerings.ts) ; un alias n'est jamais
 * supprimé, il passe hors ligne et reste dans l'admin.
 */
export function planOmnesDedupe(
  programs: ReadonlyMap<string, DedupeProgramState>,
  aliases: Record<string, OmnesAlias> = OMNES_PROGRAM_ID_ALIASES,
): OmnesDedupePlan {
  const plan: OmnesDedupePlan = { canonicalUpdates: [], deactivations: [], orphans: [] };
  const byCanonical = new Map<string, string[]>();
  for (const [alias, { canonical }] of Object.entries(aliases)) {
    const row = programs.get(alias);
    if (!row) continue;
    if (!programs.has(canonical)) {
      plan.orphans.push({ id: alias, canonical });
      continue;
    }
    const list = byCanonical.get(canonical) ?? [];
    list.push(alias);
    byCanonical.set(canonical, list);
  }
  const canonicals = new Set([...byCanonical.keys()]);
  // Une fiche canonique sans alias en base peut porter, elle aussi, un campus
  // dans son intitulé (« ECE - PGE - Paris- ING4 … ») : on la nettoie aussi.
  for (const [id] of programs) if (!aliases[id]) canonicals.add(id);

  for (const id of [...canonicals].sort()) {
    const row = programs.get(id)!;
    const current = readCampusOfferings(row.campusOfferings) ?? [];
    let merged: unknown[] | null = null;
    let added = 0;
    for (const alias of byCanonical.get(id) ?? []) {
      const aliasRow = programs.get(alias)!;
      if (!aliasRow.isActive) continue;
      const incoming = (readCampusOfferings(aliasRow.campusOfferings) ?? []).filter(
        (o): o is CampusOffering & Record<string, unknown> => typeof o.campus === 'string',
      );
      const base = (merged ?? current) as Record<string, unknown>[];
      const result = mergeCampusOfferings(base, incoming);
      if (result.added.length) {
        merged = result.merged;
        added += result.added.length;
      }
      plan.deactivations.push({
        id: alias,
        canonical: id,
        expectedUpdatedAt: aliasRow.updatedAt,
        reason: aliases[alias].reason,
      });
    }
    const campuses = [...current, ...((merged ?? []) as Record<string, unknown>[])]
      .map((o) => o.campus)
      .filter((c): c is string => typeof c === 'string');
    const cleanFr = cleanNameAgainstCampuses(row.nameFr, campuses);
    const cleanEn = cleanNameAgainstCampuses(row.nameEn, campuses);
    const rename =
      cleanFr !== row.nameFr || cleanEn !== row.nameEn ? { nameFr: cleanFr, nameEn: cleanEn } : null;
    if (merged || rename) {
      plan.canonicalUpdates.push({ id, expectedUpdatedAt: row.updatedAt, merged, added, rename });
    }
  }
  return plan;
}

export function omnesDedupeWriteCount(plan: OmnesDedupePlan): number {
  return plan.canonicalUpdates.length + plan.deactivations.length;
}
