import { describe, expect, it } from 'vitest';

import { linkedScholarshipView } from './case-scholarship';

describe('bourse liée à un dossier', () => {
  it('rien quand le dossier n’a pas de bourse (ou un backend antérieur)', () => {
    expect(linkedScholarshipView({}, 'fr', true)).toBeNull();
    expect(linkedScholarshipView({ scholarshipId: null, scholarship: null }, 'fr', true)).toBeNull();
    expect(linkedScholarshipView({ scholarshipId: '  ' }, 'fr', true)).toBeNull();
  });

  it('nom dans la langue de l’admin, lien vers la fiche pour un éditeur', () => {
    const item = {
      scholarshipId: 'sch-eiffel',
      scholarship: { id: 'sch-eiffel', nameFr: 'Bourse Eiffel', nameEn: 'Eiffel Scholarship' },
    };
    expect(linkedScholarshipView(item, 'fr', true)).toEqual({
      id: 'sch-eiffel',
      label: 'Bourse Eiffel',
      nameMissing: false,
      href: '/scholarships?scholarshipId=sch-eiffel',
      external: false,
    });
    expect(linkedScholarshipView(item, 'en', true)?.label).toBe('Eiffel Scholarship');
  });

  it('se rabat sur l’autre langue, puis sur l’identifiant', () => {
    expect(
      linkedScholarshipView({ scholarshipId: 'sch-1', scholarship: { nameFr: 'Bourse X', nameEn: '' } }, 'en', true)
        ?.label,
    ).toBe('Bourse X');
    expect(linkedScholarshipView({ scholarshipId: 'sch-1' }, 'fr', true)).toMatchObject({
      label: 'sch-1',
      nameMissing: true,
    });
  });

  it('un conseiller suit la page officielle (http seulement), sinon pas de lien', () => {
    expect(
      linkedScholarshipView(
        { scholarshipId: 'sch-1', scholarship: { nameFr: 'X', sourceUrl: 'https://campusfrance.org/eiffel' } },
        'fr',
        false,
      ),
    ).toMatchObject({ href: 'https://campusfrance.org/eiffel', external: true });
    expect(
      linkedScholarshipView(
        { scholarshipId: 'sch-1', scholarship: { nameFr: 'X', sourceUrl: 'javascript:alert(1)' } },
        'fr',
        false,
      ),
    ).toMatchObject({ href: null, external: false });
  });

  it('lit l’identifiant du résumé quand `scholarshipId` manque', () => {
    expect(linkedScholarshipView({ scholarship: { id: 'sch-9', nameFr: 'Y' } }, 'fr', true)?.id).toBe('sch-9');
  });
});
