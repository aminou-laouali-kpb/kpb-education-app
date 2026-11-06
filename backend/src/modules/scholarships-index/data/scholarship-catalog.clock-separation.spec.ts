// Deux verdicts, et l'alerte AVANT la clôture.
//
// ## Ce que ce fichier protège
//
// Le 20/08/2026, la date limite de McCall MacBain est passée pendant la nuit.
// Personne n'avait touché au dépôt, et la CI backend est devenue rouge sur
// TOUTE PR ouverte ce jour-là — dont #216, un correctif de fuite du nom civil
// vers un tiers américain. Un correctif de confidentialité bloqué par une
// bourse canadienne.
//
// Le plus instructif : `catalog-freshness.yml` promettait déjà, dans son
// en-tête, que ce pourrissement était « délibérément SÉPARÉ de la CI backend »,
// parce qu'« une campagne close est une ligne de littéral à rafraîchir, ce n'est
// pas une raison de bloquer une PR d'authentification ». La promesse était
// écrite ; elle n'était pas implémentée. `CATALOG_EXPIRED_CYCLE_CODES` — la
// constante qui nomme exactement ces codes — n'était branchée à RIEN, et son
// seul lecteur était son propre spec.
//
// Un commentaire n'exécute pas. C'est ce que ce fichier corrige.
//
// ## Les deux propriétés, et pourquoi elles doivent être testées séparément
//
// (1) `validIgnoringClock` ne doit tolérer QUE le passage du temps. Le risque
//     d'un second verdict plus permissif, c'est qu'il devienne une porte de
//     sortie : si un jour il ignorait aussi une anomalie structurelle, le
//     portail de fusion serait désarmé sans que personne ne le voie. Le test
//     l'attaque donc par les deux bouts — il exige la tolérance sur le code
//     daté, ET le refus sur tout le reste.
//
// (2) `closingSoon` doit voir venir. Une alerte qui se déclenche le jour du
//     basculement ne laisse plus le choix du moment ; c'est précisément ce qui
//     s'est passé.

import {
  CATALOG_EXPIRED_CYCLE_CODES,
  CATALOG_STALENESS_CODES,
  validateScholarshipCatalog,
  type ScholarshipCatalogValidationReport,
} from './scholarship-catalog.validator';
import { catalogAsOf } from './scholarship-catalog.as-of';
import { SCHOLARSHIP_CATALOG_V1 } from './scholarship-catalog.v1';

/** Le catalogue réel, jugé à une date choisie. Aucune maquette : une maquette
 * pourrait diverger de la structure que le portail juge vraiment. */
const at = (iso: string): ScholarshipCatalogValidationReport =>
  validateScholarshipCatalog(catalogAsOf(SCHOLARSHIP_CATALOG_V1, new Date(iso)), {
    includeVolumeTargets: false,
    now: new Date(iso),
  });

describe('séparation de l’horloge et de la structure', () => {
  it('le catalogue est structurellement valide, et le reste dans le temps', () => {
    // Trois dates très écartées. Si `validIgnoringClock` dépendait d'autre
    // chose que la structure, il basculerait quelque part sur cet intervalle.
    for (const iso of [
      '2026-01-01T00:00:00.000Z',
      '2026-08-20T12:00:00.000Z',
      '2028-12-31T00:00:00.000Z',
    ]) {
      const report = at(iso);
      expect(report.validIgnoringClock).toBe(true);
      // Et la garde de la garde : si toutes les anomalies datées disparaissaient
      // du catalogue pour de bon, ce fichier ne mesurerait plus rien sans qu'on
      // le sache. On vérifie donc qu'à horizon lointain il y en a bien.
      if (iso.startsWith('2028')) {
        expect(report.valid).toBe(false);
        // Les DEUX familles datées : cycles clos ET vérifications périmées.
        // Ma première version n'en tolérait qu'une, et c'est ici que ça a cassé.
        const dated: readonly string[] = [
          ...CATALOG_EXPIRED_CYCLE_CODES,
          ...CATALOG_STALENESS_CODES,
        ];
        expect(report.issues.every((i) => dated.includes(i.code))).toBe(true);
      }
    }
  });

  it('une campagne close depuis hier ne bloque PAS le portail de fusion', () => {
    // 2028 : tous les cycles ouverts du catalogue ont clos depuis longtemps.
    const report = at('2028-12-31T00:00:00.000Z');
    expect(report.issues.length).toBeGreaterThan(0);
    expect(report.valid).toBe(false);
    expect(report.validIgnoringClock).toBe(true);
  });

  it('mais une anomalie STRUCTURELLE bloque les DEUX verdicts', () => {
    // Le point sensible du dispositif : le second verdict ne doit pas devenir
    // une porte de sortie. On injecte une faute qui n'a rien à voir avec le
    // temps — une version de schéma impossible — et les deux doivent tomber.
    const broken = {
      ...SCHOLARSHIP_CATALOG_V1,
      schemaVersion: 99 as unknown as 1,
    };
    const report = validateScholarshipCatalog(broken, {
      includeVolumeTargets: false,
      now: new Date('2026-08-20T12:00:00.000Z'),
    });
    expect(report.valid).toBe(false);
    expect(report.validIgnoringClock).toBe(false);
    expect(report.issues.map((i) => i.code)).toContain(
      'unsupported_schema_version',
    );
  });
});

describe('l’alerte avant clôture', () => {
  it('annonce Open Doors dans sa quinzaine, et pas avant', () => {
    // Open Doors clôt le 01/11/2026 (relu le 29/09/2026). Troisième exemple de
    // ce test : Schwarzman puis Chevening sont passés `closed` après leur
    // clôture (09/09, 06/10) — l'alerte ne concerne que des campagnes `open`.
    const ids = (iso: string) => at(iso).closingSoon.map((c) => c.scholarshipId);

    // Vingt jours avant : hors horizon, on ne crie pas pour rien.
    expect(ids('2026-10-12T12:00:00.000Z')).not.toContain('open_doors_russia_2027');
    // Dix jours avant : dans l'horizon.
    expect(ids('2026-10-22T12:00:00.000Z')).toContain('open_doors_russia_2027');
  });

  it('rend les jours restants et trie par urgence', () => {
    // Le 25/10 : Open Doors (01/11) et UofT Pearson (06/11) sont tous deux
    // dans l'horizon — deux entrées, donc un tri qui prouve quelque chose.
    const soon = at('2026-10-25T00:00:00.000Z').closingSoon;
    expect(soon.length).toBeGreaterThan(1);
    for (const entry of soon) {
      expect(entry.daysLeft).toBeGreaterThan(0);
      expect(entry.daysLeft).toBeLessThanOrEqual(14);
      expect(entry.scholarshipId).not.toHaveLength(0);
      expect(entry.closesAt).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    }
    const days = soon.map((s) => s.daysLeft);
    expect([...days].sort((a, b) => a - b)).toEqual(days);
  });

  it('ne compte JAMAIS une campagne déjà close comme « bientôt »', () => {
    // La confusion qu'il ne faut pas faire : une clôture passée est une
    // anomalie, pas un rendez-vous. Les deux listes doivent être disjointes,
    // sinon l'alerte se mettrait à répéter éternellement ce qui est déjà rouge.
    const report = at('2028-12-31T00:00:00.000Z');
    expect(report.closingSoon).toEqual([]);
    expect(report.issues.length).toBeGreaterThan(0);
  });

  it('l’horizon est réglable, et le défaut vaut bien quatorze jours', () => {
    const wide = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
      includeVolumeTargets: false,
      now: new Date('2026-10-12T12:00:00.000Z'),
      closingSoonHorizonDays: 60,
    });
    const byDefault = at('2026-10-12T12:00:00.000Z');
    expect(wide.closingSoon.length).toBeGreaterThan(byDefault.closingSoon.length);
    expect(byDefault.closingSoon.every((c) => c.daysLeft <= 14)).toBe(true);
  });
});
