import { buildScholarshipCreateData } from '../modules/scholarships-index/data/scholarship-catalog.create-data';
import { SCHOLARSHIP_CATALOG_V1 } from '../modules/scholarships-index/data/scholarship-catalog.v1';
import {
  eligibilityCoverage,
  validateScholarshipCatalog,
} from '../modules/scholarships-index/data/scholarship-catalog.validator';

import {
  LEGACY_SEED_IDS,
  decidePublication,
  driftLine,
  issuesByRecordIndex,
  moderationDifferences,
  parseArgs,
  refuseSwitchReason,
} from './scholarships-catalog.cli';

/**
 * Fabrique la ligne Prisma telle qu'elle existera après `import`, à partir de la
 * fiche du catalogue. On teste donc la décision de publication sur la forme
 * réelle des données, pas sur une maquette qui pourrait diverger.
 */
function rowFromRecord(index: number) {
  const record = SCHOLARSHIP_CATALOG_V1.records[index];
  const data = buildScholarshipCreateData(
    record,
    SCHOLARSHIP_CATALOG_V1.catalogVersion,
  );
  const { applicationSteps, cycles, ...rest } = data;
  return {
    ...rest,
    applicationSteps: applicationSteps.create,
    cycles: [cycles.create],
  } as never;
}

describe('scholarships-catalog CLI', () => {
  describe('parseArgs', () => {
    it('refuses a run without exactly one mode', () => {
      expect(parseArgs(['publish'])).toBe(
        'Choose exactly one mode: --dry-run or --apply.',
      );
      expect(parseArgs(['publish', '--apply', '--dry-run'])).toBe(
        'Choose exactly one mode: --dry-run or --apply.',
      );
    });

    it('refuses an unknown command', () => {
      expect(parseArgs(['deploy', '--apply'])).toContain('Usage:');
    });

    it('refuses --confirmed-only on import, where it would mean nothing', () => {
      expect(parseArgs(['import', '--apply', '--confirmed-only'])).toContain(
        '--confirmed-only applies to publish and switch',
      );
    });

    it('accepts reconcile, and refuses --confirmed-only on it', () => {
      expect(parseArgs(['reconcile', '--dry-run'])).toEqual({
        command: 'reconcile',
        apply: false,
        confirmedOnly: false,
      });
      // `--confirmed-only` trie des fiches à PUBLIER. Réconcilier ne publie
      // rien : l'accepter ici laisserait croire qu'on ne réaligne que les
      // fiches confirmées, et donc qu'on peut le lancer sans conséquence sur
      // les autres.
      expect(parseArgs(['reconcile', '--apply', '--confirmed-only'])).toContain(
        'not to reconcile',
      );
    });

    it('accepts the switch command used for the production cutover', () => {
      expect(parseArgs(['switch', '--apply', '--confirmed-only'])).toEqual({
        command: 'switch',
        apply: true,
        confirmedOnly: true,
      });
    });
  });

  describe('issuesByRecordIndex', () => {
    // C'est le mécanisme qui remplace le refus global. Le refus global était la
    // falaise : une seule campagne close rendait les 33 autres fiches
    // inimportables.
    it('attributes each issue to the record it belongs to', () => {
      const map = issuesByRecordIndex({
        valid: false,
        validIgnoringClock: false,
        closingSoon: [],
        catalogVersion: '1.3.0',
        uniqueRecordCount: 0,
        uniqueRecordDeficit: 0,
        verifiedCounts: { secondary: 0, bachelor: 0, master: 0, doctorate: 0 },
        backlogCounts: { secondary: 0, bachelor: 0, master: 0, doctorate: 0 },
        volumeDeficits: { secondary: 0, bachelor: 0, master: 0, doctorate: 0 },
        backlogDeficits: { secondary: 0, bachelor: 0, master: 0, doctorate: 0 },
        warnings: [],
        eligibilityCoverage: eligibilityCoverage({
          ...SCHOLARSHIP_CATALOG_V1,
          records: [],
        }),
        issues: [
          {
            code: 'open_cycle_already_closed',
            path: 'records[16].cycle',
            message: 'x',
          },
          { code: 'missing_text', path: 'records[3].scholarship.nameFr', message: 'x' },
          { code: 'invalid_catalog_version', path: 'catalogVersion', message: 'x' },
        ],
      });

      expect(map.get(16)).toEqual(['open_cycle_already_closed']);
      expect(map.get(3)).toEqual(['missing_text']);
      expect(map.has(0)).toBe(false);
      // Une anomalie globale n'est rattachée à aucune fiche et ne doit donc
      // jamais faire écarter une fiche en particulier.
      expect([...map.keys()].sort((a, b) => a - b)).toEqual([3, 16]);
    });
  });

  describe('decidePublication', () => {
    // 25/08 et non plus 17/08 : le catalogue porte depuis le 24/08 une seconde
    // vague de vérification (re-lecture aux sources des 10 fiches publiées), et
    // une horloge antérieure placerait leur `verifiedAt` dans le futur — la
    // porte les écartait toutes, 30 tombait à 20 et 10 à 0. Aucune clôture ne
    // tombe entre les deux horloges (seule McCall clôt en août, le 19, et son
    // exclusion ne vient plus de l'horloge : son cycle est `closed` depuis la
    // correction du 20/08), donc les comptes attendus ne changent pas de sens.
    // 29/09 depuis la re-vérification aux sources du même jour (nouvelle vague
    // de `verifiedAt`, même raison que ci-dessus). Entre les deux horloges,
    // Schwarzman a clos (09/09) et sa fiche est passée `closed` : elle sort des
    // publiables comme McCall avant elle — d'où 29 et 11. Puis UP Mastercard,
    // close le 30/09 à 21:59 UTC et passée `closed` : 28 et 10. Puis Chevening
    // et Knight-Hennessy, clos le 06/10 : 26 et 8. Puis le 07/10 : Eiffel et
    // AUC passent `open` (26 et 10), et Gates Cambridge et CMU-Africa entrent
    // au catalogue, lus aux sources ce jour-là — l'horloge avance au 07/10
    // pour que leur `verifiedAt` ne soit pas dans le futur : 28 et 12.
    // 24/10 depuis la relecture mensuelle du même jour (nouvelle vague de
    // `verifiedAt`) : aucune clôture entre le 07/10 et le 24/10, les comptes
    // publiables ne bougent pas.
    const now = new Date('2026-10-24T18:00:00.000Z');

    // POURQUOI CES CHIFFRES ONT CHANGÉ LE 20/08/2026 — 31 → 30 et 11 → 10.
    //
    // Ce bloc était construit autour de McCall MacBain : `now` valait le 17 août
    // PARCE QUE cette fiche était encore ouverte à cette date, deux tests
    // exigeaient sa présence, et un troisième la refusait au 20 août. Sa clôture
    // réelle — 19 août 2026, 16 h ET — est arrivée, le contrôle de fraîcheur l'a
    // signalée, et la fiche est passée en `status: 'closed'`. Elle n'est donc
    // plus publiable à AUCUNE date, y compris le 17 août.
    //
    // La leçon est sur le harnais, pas sur les données : un test qui emprunte à
    // une donnée VIVANTE son état transitoire casse le jour où cette donnée est
    // correctement mise à jour. La contre-preuve est nette — le validateur, qui
    // lit l'horloge réelle, exigeait le changement pendant que ce spec, qui lit
    // une date gelée, exigeait l'inverse. Deux gardes du même dépôt en
    // désaccord sur le même fait.
    //
    // Le décor du troisième test est donc désormais FABRIQUÉ (voir plus bas) :
    // l'état dont il a besoin — cycle ouvert ET date passée — est précisément
    // celui que le validateur interdit maintenant dans les vraies données.
    //
    // La valeur numérique reste le critère : si quelqu'un annule la correction
    // de la porte de qualité, ce compte tombe à 25. « Les tests passent » ne
    // l'aurait pas montré.
    it('publishes exactly the 28 eligible records of catalog 1.3.0', () => {
      const decisions = SCHOLARSHIP_CATALOG_V1.records.map((_, index) =>
        decidePublication(rowFromRecord(index), now, false),
      );
      const published = decisions.filter((item) => item.publish).map((i) => i.id);

      expect(published).toHaveLength(28);
      expect(published).not.toContain('mccall_macbain_2027');
      expect(decisions.filter((item) => !item.publish).map((i) => i.id).sort()).toEqual([
        'chevening_2027',
        'daad_helmut_schmidt_2027',
        'knight_hennessy_2027',
        'mccall_macbain_2027',
        'rhodes_southern_africa_2027',
        'schwarzman_scholars_2027',
        'uct_international_refugee_2027',
        'up_mastercard_scholars_2027',
      ]);
    });

    // 12 et non plus 10 : la re-vérification du 24/08 a promu york_pise et
    // jj_wbgsp en dates confirmées (leurs sources publient désormais le cycle
    // 2027 ferme). 11 depuis le 29/09 : Schwarzman, confirmé, est clos ; 10
    // depuis le 30/09 : UP Mastercard, confirmée, est close ; 8 depuis le
    // 06/10 : Chevening et Knight-Hennessy, confirmés, sont clos ; 10 depuis
    // le 07/10 : Eiffel et AUC Excellence publient leurs dates 2027 (open) ;
    // 12 le même jour : Gates Cambridge et CMU-Africa entrent, dates confirmées ;
    // 13 depuis le 24/10 : le Swedish Institute publie ses dates 2027.
    it('publishes only the 13 confirmed-date records under --confirmed-only', () => {
      const published = SCHOLARSHIP_CATALOG_V1.records
        .map((_, index) => decidePublication(rowFromRecord(index), now, true))
        .filter((item) => item.publish);

      expect(published).toHaveLength(13);
      expect(published.every((item) => item.confidence === 'confirmed')).toBe(true);
      expect(published.map((item) => item.id)).not.toContain('mccall_macbain_2027');
    });

    it('refuses a record whose closing date has already passed', () => {
      // Décor FABRIQUÉ, et il doit l'être : un cycle « ouvert » dont la date de
      // clôture est passée est exactement ce que le validateur refuse
      // (`open_cycle_already_closed`). Emprunter cet état à une vraie fiche du
      // catalogue revenait à parier qu'une anomalie y subsiste — le pari a tenu
      // jusqu'au 20/08/2026, puis il a coûté trois tests rouges pour une
      // correction de données pourtant juste.
      const template = SCHOLARSHIP_CATALOG_V1.records.findIndex(
        (record) => record.scholarship.id === 'mccall_macbain_2027',
      );
      const row = rowFromRecord(template) as unknown as {
        cycles: Array<{
          status: string;
          closesAt: Date | string | null;
          verifiedAt: Date;
        }>;
        lastVerifiedAt: Date;
      };
      row.cycles[0].status = 'open';
      row.cycles[0].closesAt = new Date('2026-08-19T20:00:00.000Z');
      // Le décor a sa propre horloge (20/08) : la re-vérification RÉELLE de la
      // fiche empruntée date du 24/08, donc « du futur » pour lui, et la porte
      // recent_verification parlerait avant celle qu'on teste — elle lit
      // cycle.verifiedAt d'abord, lastVerifiedAt sinon
      // (scholarship-content-quality.service.ts). Un décor fabriqué se
      // fabrique en entier : les DEUX tampons sont épinglés dans son passé.
      row.lastVerifiedAt = new Date('2026-08-10T08:00:00.000Z');
      row.cycles[0].verifiedAt = new Date('2026-08-10T08:00:00.000Z');

      const decision = decidePublication(
        row as never,
        new Date('2026-08-20T00:00:00.000Z'),
        false,
      );

      expect(decision.publish).toBe(false);
      expect(decision.reason).toContain('passée');
    });

    it('refuses a closed cycle even before its closing date', () => {
      // Le pendant du test précédent, et ce qui manquait : la porte doit refuser
      // sur le STATUT, pas seulement sur la date. Sans cette assertion, remettre
      // McCall MacBain en `open` rendrait les deux comptes ci-dessus faux sans
      // qu'aucun test ne dise pourquoi.
      const index = SCHOLARSHIP_CATALOG_V1.records.findIndex(
        (record) => record.scholarship.id === 'mccall_macbain_2027',
      );
      const decision = decidePublication(
        rowFromRecord(index),
        new Date('2026-08-17T18:00:00.000Z'),
        false,
      );

      expect(decision.publish).toBe(false);
    });
  });

  describe('LEGACY_SEED_IDS', () => {
    it('names the 11 demonstration records served in production', () => {
      expect(LEGACY_SEED_IDS).toHaveLength(11);
      // Les identifiants legacy et ceux du catalogue vérifié ne se recouvrent
      // pas : dépublier les uns ne touche jamais les autres.
      const verified = new Set(
        SCHOLARSHIP_CATALOG_V1.records.map((record) => record.scholarship.id),
      );
      expect(LEGACY_SEED_IDS.filter((id) => verified.has(id))).toEqual([]);
      expect(LEGACY_SEED_IDS).toContain('mccall_macbain');
    });
  });


  describe('moderationDifferences', () => {
    // Le filet de `reconcile` : réaligner du contenu ne doit RIEN changer à
    // l'état de modération. On compare un instantané de TOUTE la table avant et
    // après, pas seulement les lignes du plan — un effet de bord ne se déclare
    // pas à l'avance. Onze fiches de démonstration sont devenues publiques sur
    // ce projet parce qu'un chemin d'écriture posait `isActive` sans le vouloir.
    it('ne voit aucune différence quand la modération est intacte', () => {
      const state = new Map([
        ['a_2027', 'true/approved'],
        ['b_2027', 'false/pending'],
      ]);
      expect(moderationDifferences(state, new Map(state))).toEqual([]);
    });

    it('attrape une publication, une dépublication, une apparition, une disparition', () => {
      const before = new Map([
        ['published_2027', 'true/approved'],
        ['pending_2027', 'false/pending'],
        ['gone_2027', 'false/pending'],
      ]);
      const after = new Map([
        ['published_2027', 'false/pending'],
        ['pending_2027', 'true/approved'],
        ['new_2027', 'true/approved'],
      ]);

      expect(moderationDifferences(before, after)).toEqual([
        'gone_2027 (disparue)',
        'new_2027 (apparue : true/approved)',
        'pending_2027 (false/pending → true/approved)',
        'published_2027 (true/approved → false/pending)',
      ]);
    });
  });

  describe('driftLine', () => {
    // « 2 fiches divergent » oblige à ouvrir psql pour savoir sur quoi. La ligne
    // doit porter le champ, la valeur servie et la valeur du dépôt.
    it('nomme le champ, la valeur en base et celle du catalogue', () => {
      expect(
        driftLine({
          scholarshipId: 'york_pise_2027_forecast',
          scope: 'cycle',
          field: 'dateConfidence',
          inDatabase: 'estimated',
          inCatalog: 'confirmed',
          reconciled: true,
        }),
      ).toBe('cycle.dateConfidence : estimated → confirmed');
    });

    it('dit explicitement quand une divergence est conservée en base', () => {
      expect(
        driftLine({
          scholarshipId: 'york_pise_2027_forecast',
          scope: 'cycle',
          field: 'status',
          inDatabase: 'open',
          inCatalog: 'forecast',
          reconciled: false,
          keptReason: 'cycle activé en base',
        }),
      ).toContain('[CONSERVÉ EN BASE — cycle activé en base]');
    });
  });

  describe('refuseSwitchReason', () => {
    // Reproduit l'incident du 14/08/2026 : `switch` lancé sans `import`, aucune
    // ligne portant le tag du catalogue, 0 fiche publiée, 11 fiches legacy
    // dépubliées quand même, 0 bourse servie aux utilisateurs.
    it('refuses a switch that would publish nothing and unpublish the legacy records', () => {
      const reason = refuseSwitchReason([], true);

      expect(reason).not.toBeNull();
      expect(reason).toContain("laisserait l'onglet Bourses vide");
      expect(reason).toContain('catalog:import --apply');
    });

    it('names the records it discarded when some were found but none eligible', () => {
      const reason = refuseSwitchReason(
        [
          { id: 'a_2027', publish: false, reason: 'clôture passée', confidence: 'confirmed' },
          { id: 'b_2027', publish: false, reason: 'porte de qualité', confidence: 'estimated' },
        ],
        true,
      );

      expect(reason).toContain('a_2027');
      expect(reason).toContain('clôture passée');
      expect(reason).toContain('b_2027');
    });

    it('lets a switch through as soon as one record is publishable', () => {
      expect(
        refuseSwitchReason(
          [
            { id: 'a_2027', publish: true, reason: 'éligible', confidence: 'confirmed' },
            { id: 'b_2027', publish: false, reason: 'écartée', confidence: 'estimated' },
          ],
          true,
        ),
      ).toBeNull();
    });

    // `publish` seul ne dépublie rien : publier 0 fiche est alors sans effet
    // visible, et refuser serait un faux positif.
    it('never blocks a publish-only run, which unpublishes nothing', () => {
      expect(refuseSwitchReason([], false)).toBeNull();
    });
  });
});
