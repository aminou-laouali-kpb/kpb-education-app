import type { VersionedScholarshipCatalog, VerifiedScholarshipCatalogRecord } from './scholarship-catalog.types';

/**
 * Le catalogue TEL QU'IL ÉTAIT à une date passée, pour les specs à horloge figée.
 *
 * Un cycle passe en `closed` le jour où sa clôture confirmée est échue
 * (procédure de relecture, règle 5). Un spec qui juge le catalogue réel au
 * 22/10 en empruntant l'état « ouvert » d'une fiche casse donc le jour où cette
 * fiche est, à raison, close — c'est arrivé avec McCall MacBain le 20/08 et avec
 * Open Doors Russie le 06/11. Ici, un cycle `closed` dont la clôture confirmée
 * est POSTÉRIEURE à `now` est rendu `open` : c'est l'état publié à cette date.
 * Rien d'autre ne change.
 */
export function recordAsOf(
  record: VerifiedScholarshipCatalogRecord,
  now: Date,
): VerifiedScholarshipCatalogRecord {
  const { cycle } = record;
  if (cycle.status !== 'closed' || !cycle.closesAt) return record;
  if (new Date(cycle.closesAt).getTime() <= now.getTime()) return record;
  return { ...record, cycle: { ...cycle, status: 'open' } };
}

export function catalogAsOf(
  catalog: VersionedScholarshipCatalog,
  now: Date,
): VersionedScholarshipCatalog {
  return { ...catalog, records: catalog.records.map((record) => recordAsOf(record, now)) };
}
