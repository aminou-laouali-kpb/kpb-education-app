import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import {
  compareAcademicYear,
  defaultOpeningAcademicYear,
  IsAcademicYear,
  isConsecutiveAcademicYear,
  nextAcademicYear,
  type OpeningYearCycle,
} from './academic-year';

const NOW = new Date('2026-10-15T12:00:00.000Z');

function cycle(overrides: Partial<OpeningYearCycle>): OpeningYearCycle {
  return {
    academicYear: '2026-2027',
    status: 'forecast',
    activatedAt: null,
    closesAt: null,
    estimatedCloseAt: null,
    ...overrides,
  };
}

describe('academic-year', () => {
  describe('isConsecutiveAcademicYear', () => {
    it.each(['2027', '2027-2028', '1999-2000'])('accepte %s', (value) => {
      expect(isConsecutiveAcademicYear(value)).toBe(true);
    });

    it.each([
      '2027-2029',
      '2028-2027',
      '2027-2027',
      '27-28',
      '2027/2028',
      ' 2027-2028',
      '',
      42,
      null,
      undefined,
    ])('refuse %j', (value) => {
      expect(isConsecutiveAcademicYear(value)).toBe(false);
    });
  });

  it('ordonne par année de début puis de fin, une valeur mal formée comme la plus ancienne', () => {
    const sorted = ['2027-2028', 'n/a', '2026-2027', '2027', '2028-2029'].sort(
      compareAcademicYear,
    );
    expect(sorted).toEqual(['n/a', '2026-2027', '2027', '2027-2028', '2028-2029']);
    // Un tri décroissant ne la prend donc jamais pour la plus récente.
    expect(['n/a', '2026-2027'].sort((a, b) => compareAcademicYear(b, a))[0]).toBe(
      '2026-2027',
    );
  });

  it('donne l’année suivante sous la même forme', () => {
    expect(nextAcademicYear('2027-2028')).toBe('2028-2029');
    expect(nextAcademicYear('2027')).toBe('2028');
    expect(() => nextAcademicYear('bientôt')).toThrow(RangeError);
  });

  describe('defaultOpeningAcademicYear', () => {
    it('sans cycle : année UTC courante et suivante', () => {
      expect(defaultOpeningAcademicYear([], NOW)).toBe('2026-2027');
      // 31/12 à 23h30 à Abidjan (UTC+0) est déjà le 1er janvier à UTC+1 : on
      // suit l'horloge UTC, la même pour tous.
      expect(
        defaultOpeningAcademicYear([], new Date('2026-12-31T23:30:00.000Z')),
      ).toBe('2026-2027');
    });

    it('le cycle le plus récent tant qu’il n’est pas activé', () => {
      expect(
        defaultOpeningAcademicYear(
          [
            cycle({ academicYear: '2026-2027', activatedAt: new Date('2025-10-01') }),
            cycle({ academicYear: '2027-2028', status: 'forecast' }),
          ],
          NOW,
        ),
      ).toBe('2027-2028');
    });

    it('le cycle activé encore servi ouvert', () => {
      expect(
        defaultOpeningAcademicYear(
          [
            cycle({
              academicYear: '2026-2027',
              status: 'open',
              activatedAt: new Date('2026-09-01'),
              closesAt: new Date('2026-11-05T23:59:59.999Z'),
            }),
          ],
          NOW,
        ),
      ).toBe('2026-2027');
    });

    it('l’année suivante quand le cycle activé est clos (même littéralement « open »)', () => {
      expect(
        defaultOpeningAcademicYear(
          [
            cycle({
              academicYear: '2026-2027',
              status: 'open',
              activatedAt: new Date('2026-01-01'),
              closesAt: new Date('2026-03-01T23:59:59.999Z'),
            }),
          ],
          NOW,
        ),
      ).toBe('2027-2028');
    });

    it('ignore un cycle dont l’année n’est pas consécutive', () => {
      expect(
        defaultOpeningAcademicYear(
          [
            cycle({ academicYear: '2027-2029' }),
            cycle({
              academicYear: '2026-2027',
              status: 'closed',
              activatedAt: new Date('2025-10-01'),
            }),
          ],
          NOW,
        ),
      ).toBe('2027-2028');
    });
  });

  describe('@IsAcademicYear', () => {
    class Probe {
      @IsAcademicYear()
      academicYear!: unknown;
    }

    it.each(['2027', '2027-2028'])('valide %s', async (academicYear) => {
      await expect(
        validate(plainToInstance(Probe, { academicYear })),
      ).resolves.toHaveLength(0);
    });

    it.each(['2027-2029', '2027 - 2028', 2027])('refuse %j', async (academicYear) => {
      const errors = await validate(plainToInstance(Probe, { academicYear }));
      expect(errors).toHaveLength(1);
      expect(errors[0].constraints).toHaveProperty('isAcademicYear');
    });
  });
});
