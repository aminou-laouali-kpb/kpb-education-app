import {
  type CampusOffering,
  campusKey,
  intakeMonthYear,
  mergeCampusOfferings,
  offeringIsPresent,
  readCampusOfferings,
  sessionFromIntake,
} from './campus-offerings';

/**
 * La fusion des offres est le cœur de la promesse « additif » des imports de
 * rentrée décalée : ce qui est déjà en base ne bouge pas, au bit près.
 */
describe('campus-offerings', () => {
  const spring: CampusOffering = {
    campus: 'Paris',
    tuitionUpfront: 6690,
    tuitionInstallments: 7025,
    intake: '01/03/2027',
    session: 'spring',
    rhythm: 'initiale',
  };

  it('lit le mois d’une date jj/mm/aaaa ou mm/aaaa, rien d’autre', () => {
    expect(intakeMonthYear('01/03/2027')).toEqual({ month: 3, year: 2027 });
    expect(intakeMonthYear('09/2027')).toEqual({ month: 9, year: 2027 });
    expect(intakeMonthYear('FALL 2027')).toBeNull();
    expect(intakeMonthYear('01/13/2027')).toBeNull();
    expect(intakeMonthYear(null)).toBeNull();
  });

  it('déduit la session du mois : janvier–juin décalée, juillet–décembre automne', () => {
    expect(sessionFromIntake('04/01/2027')).toBe('spring');
    expect(sessionFromIntake('22/03/2027')).toBe('spring');
    expect(sessionFromIntake('15/09/2026')).toBe('fall');
    expect(sessionFromIntake('01/10/2026')).toBe('fall');
    expect(sessionFromIntake('Rentrée automne')).toBeNull();
  });

  it('compare les campus sans casse ni accents', () => {
    expect(campusKey(' Chambéry ')).toBe(campusKey('CHAMBERY'));
  });

  it('une offre d’automne sur le même campus ne masque pas la rentrée décalée', () => {
    const fall = { campus: 'Paris', tuitionUpfront: 8850, tuitionInstallments: 9293, intake: '01/10/2026' };
    expect(offeringIsPresent([fall], spring)).toBe(false);
  });

  it('reconnaît une offre déjà là par sa date, y compris dans « date · date »', () => {
    const joined = { campus: 'paris', intake: '15/09/2026 · 01/03/2027' };
    expect(offeringIsPresent([joined], spring)).toBe(true);
  });

  it('reconnaît une offre dont la date a été corrigée dans l’admin, par session et rythme', () => {
    const edited = { campus: 'Paris', intake: '08/03/2027', session: 'spring', rhythm: 'initiale' };
    expect(offeringIsPresent([edited], spring)).toBe(true);
    const otherRhythm = { ...edited, rhythm: 'alternance' };
    expect(offeringIsPresent([otherRhythm], spring)).toBe(false);
  });

  it('garde les offres existantes telles quelles — mêmes objets, même ordre, clés inconnues comprises', () => {
    const a = { campus: 'Lyon', tuitionUpfront: 1, tuitionInstallments: null, intake: '01/10/2026', noteAdmin: 'x' };
    const b = { campus: 'Paris', tuitionUpfront: 2, tuitionInstallments: null, intake: '01/10/2026' };
    const { merged, added } = mergeCampusOfferings([a, b], [spring]);
    expect(merged).toHaveLength(3);
    expect(merged[0]).toBe(a);
    expect(merged[1]).toBe(b);
    expect(merged[2]).toEqual(spring);
    expect(added).toEqual([spring]);
  });

  it('rejouer la fusion sur son propre résultat n’ajoute rien', () => {
    const first = mergeCampusOfferings([], [spring]);
    const second = mergeCampusOfferings(readCampusOfferings(first.merged)!, [spring]);
    expect(second.added).toEqual([]);
    expect(second.merged).toEqual(first.merged);
  });

  it('ne lit pas comme une liste ce qui n’en est pas une', () => {
    expect(readCampusOfferings(null)).toBeNull();
    expect(readCampusOfferings({ campus: 'Paris' })).toBeNull();
    expect(readCampusOfferings([{ campus: 'Paris' }, 3, null])).toEqual([{ campus: 'Paris' }]);
  });
});
