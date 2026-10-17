// ─────────────────────────────────────────────────────────────────────────────
// L'ordre et la pagination de `/catalog/programs`.
//
// ## Pourquoi un ordre « métier » plutôt que l'ordre alphabétique
//
// Décision du propriétaire du 17/10/2026 : aucun plafond de formations. Les
// builds récentes enchaînent les pages jusqu'à épuisement et voient TOUT. Les
// builds déjà installées, elles, envoient `limit=1000` sans `offset`, ne savent
// pas paginer et ne voient que la première page. Tant que le catalogue public
// dépassait 1 000 lignes, l'ordre alphabétique décidait seul de ce qu'elles
// perdaient : « Zoologie » d'une école partenaire disparaissait avant « Art »
// d'une université qu'aucun conseiller KPB ne connaît.
//
// La première page est donc composée par tranches disjointes, dans cet ordre :
//
//   1. les formations des établissements PARTENAIRES (publiés, hors import EEF
//      — la clause de `/catalog/institutions?partnerOnly=true`) ;
//   2. les autres formations dont la date limite de candidature est À VENIR
//      (`applicationDeadline >= aujourd'hui, 00:00 UTC`) ;
//   3. tout le reste (sans date limite, ou date passée).
//
// Chaque tranche est triée par `nameFr` puis `id` : un ordre total, donc des
// pages qui ne se chevauchent pas tant que le catalogue ne bouge pas. L'app ne
// dépend pas de l'ordre serveur : elle trie elle-même chaque liste affichée.
//
// Ce qui peut encore faire bouger une page d'un appel à l'autre — une écriture
// en base, ou une date limite qui passe à minuit UTC entre deux pages — est
// rattrapé côté app : elle dédoublonne par id et recommence si le total a
// changé en route (`lib/app/core/repositories/app_api_client/catalog.dart`).
// ─────────────────────────────────────────────────────────────────────────────
import type { Prisma } from '@prisma/client';

/**
 * La taille maximale d'UNE page. Ce n'est plus un plafond du catalogue : une
 * build récente demande la page suivante tant que `nextOffset` n'est pas nul.
 * 1 000 parce que c'est exactement ce que demandent les builds installées
 * (`limit=1000`) : elles gardent la même première page qu'avant, en volume.
 */
export const PROGRAM_PAGE_MAX = 1000;

/** Minuit UTC du jour de [now] : la borne de « date limite à venir ». */
export function startOfUtcDay(now: Date): Date {
  return new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
}

/**
 * Les trois tranches, chacune = [base] ET sa condition. Disjointes et
 * exhaustives : leur union est exactement [base].
 *
 * La condition est ajoutée dans `AND`, jamais par écrasement d'une clé : la
 * base peut déjà porter `institutionId` (filtre par établissement) ou `OR`
 * (recherche texte).
 */
export function programSnapshotSegments(
  base: Prisma.ProgramWhereInput,
  partnerInstitutionIds: readonly string[],
  todayUtc: Date,
): Prisma.ProgramWhereInput[] {
  const partnerIds = [...partnerInstitutionIds];
  const withClause = (
    clause: Prisma.ProgramWhereInput,
  ): Prisma.ProgramWhereInput => ({
    ...base,
    AND: [...asArray(base.AND), clause],
  });
  return [
    withClause({ institutionId: { in: partnerIds } }),
    withClause({
      institutionId: { notIn: partnerIds },
      applicationDeadline: { gte: todayUtc },
    }),
    withClause({
      institutionId: { notIn: partnerIds },
      OR: [{ applicationDeadline: null }, { applicationDeadline: { lt: todayUtc } }],
    }),
  ];
}

/** Une lecture à faire dans une tranche. */
export type ProgramPageSlice = { segment: number; skip: number; take: number };

/**
 * Découpe la fenêtre `[offset, offset + limit)` de la liste concaténée des
 * tranches (de tailles [counts]) en lectures par tranche. Aucune lecture pour
 * une tranche vide ou hors fenêtre.
 */
export function planProgramPage(
  counts: readonly number[],
  offset: number,
  limit: number,
): ProgramPageSlice[] {
  const slices: ProgramPageSlice[] = [];
  let start = Math.max(offset, 0);
  let remaining = Math.max(limit, 0);
  let before = 0;
  counts.forEach((count, segment) => {
    const size = Math.max(count, 0);
    const end = before + size;
    if (remaining > 0 && start < end) {
      const skip = start - before;
      const take = Math.min(size - skip, remaining);
      slices.push({ segment, skip, take });
      remaining -= take;
      start += take;
    }
    before = end;
  });
  return slices;
}

/**
 * L'inverse de [programSnapshotSegments] : la clause de base d'une tranche,
 * sans sa condition. Sert aux tests qui vérifient la clause publique envoyée à
 * Prisma (barrière relu / non relu, frontière EEF) quelle que soit la tranche.
 */
export function withoutSnapshotSegment(
  segment: Prisma.ProgramWhereInput,
): Prisma.ProgramWhereInput {
  const clauses = asArray(segment.AND);
  const { AND: _and, ...rest } = segment;
  void _and;
  const kept = clauses.slice(0, -1);
  return kept.length > 0 ? { ...rest, AND: kept } : rest;
}

function asArray(
  value: Prisma.ProgramWhereInput['AND'],
): Prisma.ProgramWhereInput[] {
  if (value === undefined) return [];
  return Array.isArray(value) ? value : [value];
}
