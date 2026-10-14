import { isWithinQuietHours, utcOffsetHoursForCountry } from './country-timezone';
import {
  localDayStart,
  nextLocalHour,
  readQuietHours,
  userJitterMs,
} from './push-quiet-hours';

describe('push-quiet-hours', () => {
  it('lit les mêmes variables et bornes que le dispatcher', () => {
    expect(readQuietHours({})).toEqual({ startHour: 21, endHour: 8 });
    expect(
      readQuietHours({ KPB_PUSH_QUIET_START: '', KPB_PUSH_QUIET_END: 'x' }),
    ).toEqual({ startHour: 21, endHour: 8 });
    expect(
      readQuietHours({ KPB_PUSH_QUIET_START: '30', KPB_PUSH_QUIET_END: '-2' }),
    ).toEqual({ startHour: 23, endHour: 0 });
    expect(
      readQuietHours({ KPB_PUSH_QUIET_START: '22', KPB_PUSH_QUIET_END: '7' }),
    ).toEqual({ startHour: 22, endHour: 7 });
  });

  describe('nextLocalHour', () => {
    it('Dakar (UTC+0) à 22 h → 8 h le lendemain', () => {
      expect(
        nextLocalHour(new Date('2026-10-15T22:00:00Z'), 0, 8).toISOString(),
      ).toBe('2026-10-16T08:00:00.000Z');
    });

    it('Douala (UTC+1) à 22 h 30 locales → 8 h locales = 7 h UTC', () => {
      expect(
        nextLocalHour(new Date('2026-10-15T21:30:00Z'), 1, 8).toISOString(),
      ).toBe('2026-10-16T07:00:00.000Z');
    });

    it('après minuit local → 8 h le jour même', () => {
      // 23 h 30 UTC = 0 h 30 à Douala, le 16.
      expect(
        nextLocalHour(new Date('2026-10-15T23:30:00Z'), 1, 8).toISOString(),
      ).toBe('2026-10-16T07:00:00.000Z');
    });

    it('strictement après : 8 h pile → 8 h le lendemain', () => {
      expect(
        nextLocalHour(new Date('2026-10-15T08:00:00Z'), 0, 8).toISOString(),
      ).toBe('2026-10-16T08:00:00.000Z');
    });

    it('décalage négatif (Montréal, UTC−5)', () => {
      // 3 h UTC = 22 h la veille à Montréal → 8 h locales = 13 h UTC.
      expect(
        nextLocalHour(new Date('2026-10-16T03:00:00Z'), -5, 8).toISOString(),
      ).toBe('2026-10-16T13:00:00.000Z');
    });

    it('l’instant rendu n’est plus dans les heures calmes', () => {
      for (const country of ['Sénégal', 'Cameroun', 'Canada', 'Kenya', '']) {
        const offset = utcOffsetHoursForCountry(country);
        for (let h = 0; h < 24; h += 1) {
          const now = new Date(Date.UTC(2026, 9, 15, h, 17));
          if (!isWithinQuietHours(now, offset, 21, 8)) continue;
          expect(isWithinQuietHours(nextLocalHour(now, offset, 8), offset, 21, 8)).toBe(
            false,
          );
        }
      }
    });
  });

  it('localDayStart : minuit local, en UTC', () => {
    expect(
      localDayStart(new Date('2026-10-15T22:00:00Z'), 0).toISOString(),
    ).toBe('2026-10-15T00:00:00.000Z');
    // 23 h 30 UTC = 0 h 30 le 16 à Douala : le jour local a commencé à 23 h UTC.
    expect(
      localDayStart(new Date('2026-10-15T23:30:00Z'), 1).toISOString(),
    ).toBe('2026-10-15T23:00:00.000Z');
    expect(
      localDayStart(new Date('2026-10-16T03:00:00Z'), -5).toISOString(),
    ).toBe('2026-10-15T05:00:00.000Z');
  });

  it('userJitterMs : stable par élève, dans [0, 20 min), à la seconde', () => {
    const a = userJitterMs('user-a');
    expect(userJitterMs('user-a')).toBe(a);
    const values = Array.from({ length: 500 }, (_, i) => userJitterMs(`u${i}`));
    for (const value of values) {
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThan(20 * 60 * 1000);
      expect(value % 1000).toBe(0);
    }
    // Étalé, pas tous à la même seconde.
    expect(new Set(values).size).toBeGreaterThan(300);
    expect(userJitterMs('user-a', 1)).toBeLessThan(60_000);
  });
});
