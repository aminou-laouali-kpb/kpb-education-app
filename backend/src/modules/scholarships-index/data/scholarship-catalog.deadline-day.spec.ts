/**
 * Une date limite publiée SANS heure se lit le bon jour en Afrique (audit
 * build 57, n° 6).
 *
 * À 23:59:59Z, le téléphone d'un élève en UTC+1 convertissait la clôture au
 * lendemain : « Clôture proche · 2 nov. » pour une clôture le 1er novembre, au
 * Niger, au Cameroun, au Bénin, au Gabon, au Congo, en RDC ou au Maroc. Le
 * catalogue enregistre désormais ces dates à 20:59:59Z, qui tombe le même jour
 * calendaire de UTC−1 à UTC+3. Une heure PUBLIÉE par la source (Gates
 * Cambridge : « 23 h 59, heure du Royaume-Uni ») est gardée telle quelle.
 * Une clôture enregistrée à 00:00Z (début de journée) fermait la bourse dès le
 * matin du dernier jour : elle passe aussi à 20:59:59Z.
 */
import { DATE_ONLY_DEADLINE_UTC, endOfStatedDayUtc } from '../scrapers/scraper-text.util';
import { SCHOLARSHIP_CATALOG_V1 } from './scholarship-catalog.v1';

/**
 * Fiches dont la clôture porte une HEURE, gardée telle quelle :
 * - publiée par la source (Gates Cambridge : 23 h 59 heure du Royaume-Uni ;
 *   Rhodes Afrique australe : 23 h 59 SAST) ;
 * - fin de journée À L'HEURE DE L'ÉTABLISSEMENT, documentée dans la fiche
 *   (University of Pretoria, UCT : 23 h 59 SAST = 21:59Z).
 */
const HEURE_PUBLIEE = new Set([
  'gates_cambridge_2027',
  'rhodes_southern_africa_2027',
  'up_mastercard_scholars_2027',
  'uct_international_refugee_2027',
]);

const clotures = SCHOLARSHIP_CATALOG_V1.records.flatMap((record) =>
  (['closesAt', 'estimatedCloseAt'] as const)
    .map((champ) => ({ id: record.scholarship.id, champ, valeur: record.cycle[champ] }))
    .filter((c): c is { id: string; champ: typeof c.champ; valeur: string } => !!c.valeur),
);

/** Le jour calendaire local d'un instant, pour un décalage en heures. */
const jourLocal = (iso: string, decalage: number) =>
  new Date(new Date(iso).getTime() + decalage * 3_600_000).toISOString().slice(0, 10);

describe('dates limites sans heure — le bon jour de UTC−1 à UTC+3', () => {
  it('le catalogue a bien des clôtures à vérifier', () => {
    // Tiroir : sans lui, une lecture vide passerait tout au vert.
    expect(clotures.length).toBeGreaterThanOrEqual(15);
  });

  it.each(clotures.filter((c) => !HEURE_PUBLIEE.has(c.id)).map((c) => [`${c.id}.${c.champ}`, c] as const))(
    '%s tombe le même jour partout en Afrique',
    (_nom, c) => {
      const attendu = c.valeur.slice(0, 10);
      for (const decalage of [-1, 0, 1, 2, 3]) {
        expect(jourLocal(c.valeur, decalage)).toBe(attendu);
      }
    },
  );

  it('aucune date sans heure n’est enregistrée à 23:59:59Z', () => {
    const fautives = clotures
      .filter((c) => !HEURE_PUBLIEE.has(c.id) && c.valeur.endsWith('T23:59:59.000Z'))
      .map((c) => `${c.id}.${c.champ}`);
    expect(fautives).toEqual([]);
  });

  it('la règle d’import produit la même heure que le catalogue', () => {
    expect(endOfStatedDayUtc(2026, 10, 1).toISOString()).toBe('2026-11-01T20:59:59.000Z');
    expect(DATE_ONLY_DEADLINE_UTC).toEqual({ hour: 20, minute: 59, second: 59 });
  });
});
