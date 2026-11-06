/**
 * Classement par filière des formations OMNES (audit build 57, n° 8).
 *
 * Un élève « Informatique & IA » recevait, comme « tes 3 écoles compatibles »,
 * ECE (informatique), mais aussi INSEEC « Marketing Comm en Digital » et Sup de
 * Pub « Communication, Marketing Digital » : « digital » et « data » suffisaient
 * à ranger une formation en Informatique, et « ia\b » attrapait « Média ».
 */
import { inferFieldId, planFieldReclassification } from './omnes-conventions';

const filiere = (programName: string, programFamily = 'MSc') =>
  inferFieldId({ programName, programFamily });

describe('inferFieldId — filière d’une formation OMNES', () => {
  it.each([
    ['Marketing Comm en Digital', 'd06'],
    ['Communication, Marketing Digital', 'd06'],
    ['Communication & Média', 'd06'],
    ['Journalisme', 'd06'],
  ])('« %s » n’est pas de l’informatique → %s', (nom, attendu) => {
    expect(filiere(nom)).toBe(attendu);
  });

  it.each([
    ['Computer Science - 100% English', 'd01'],
    ['Cybersécurité', 'd01'],
    ['Data Science & Intelligence Artificielle', 'd01'],
    ['MSc Big Data & Machine Learning', 'd01'],
    ['Ingénierie logicielle et IA', 'd01'],
    ['Software Engineering', 'd01'],
  ])('« %s » reste de l’informatique → %s', (nom, attendu) => {
    expect(filiere(nom)).toBe(attendu);
  });

  it.each([
    ['Digital Marketing & Business', 'd02'],
    ['Business Development', 'd02'],
    ['Luxury Brand Management', 'd02'],
  ])('« %s » relève du commerce → %s', (nom, attendu) => {
    expect(filiere(nom)).toBe(attendu);
  });

  it('l’ingénierie garde son rang', () => {
    expect(filiere('Ingénieur aéronautique', 'Programme Grande École')).toBe('d03');
  });
});

describe('planFieldReclassification — reprise des fiches existantes', () => {
  it('ne reclasse que les fiches dont la filière change', () => {
    const plan = planFieldReclassification([
      { id: 'omnes-p-a', nameFr: 'Marketing Comm en Digital', levelFr: 'MSc', fieldId: 'd01' },
      { id: 'omnes-p-b', nameFr: 'Computer Science - 100% English', levelFr: 'MSc', fieldId: 'd01' },
      { id: 'omnes-p-c', nameFr: 'Communication & Média', levelFr: 'Bachelor', fieldId: 'd01' },
    ]);
    expect(plan).toEqual([
      { id: 'omnes-p-a', nameFr: 'Marketing Comm en Digital', from: 'd01', to: 'd06' },
      { id: 'omnes-p-c', nameFr: 'Communication & Média', from: 'd01', to: 'd06' },
    ]);
  });
});
