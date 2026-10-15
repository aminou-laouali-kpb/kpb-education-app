import {
  isWithinQuietHours,
  localHourFor,
  localWeekdayFor,
  utcOffsetHoursForCountry,
} from './country-timezone';

describe('country-timezone', () => {
  it('maps francophone residences to their offset, accent/format-insensitive', () => {
    expect(utcOffsetHoursForCountry('SN')).toBe(0); // Senegal
    expect(utcOffsetHoursForCountry('Sénégal')).toBe(0);
    expect(utcOffsetHoursForCountry('senegal')).toBe(0);
    expect(utcOffsetHoursForCountry('NE')).toBe(1); // Niger
    expect(utcOffsetHoursForCountry("Côte d'Ivoire")).toBe(0);
    expect(utcOffsetHoursForCountry('Cameroun')).toBe(1);
    expect(utcOffsetHoursForCountry('FRA')).toBe(1);
  });

  // Les alias de l'ancienne table groupée par fuseau, recopiés tels quels :
  // la résolution passe désormais par la table ISO partagée et ne doit
  // perdre aucune graphie que les profils existants portent peut-être.
  it.each<[number, string[]]>([
    [0, ['SN', 'SEN', 'Senegal', 'Sénégal', 'ML', 'MLI', 'Mali', 'CI', 'CIV', "Côte d'Ivoire", 'Cote d Ivoire', 'Ivory Coast', 'BF', 'BFA', 'Burkina Faso', 'GN', 'GIN', 'Guinea', 'Guinée', 'TG', 'TGO', 'Togo', 'MR', 'MRT', 'Mauritania', 'Mauritanie', 'GM', 'GMB', 'Gambia', 'GH', 'GHA', 'Ghana', 'GB', 'GBR', 'United Kingdom', 'Royaume-Uni', 'UK', 'PT', 'PRT', 'Portugal']],
    [1, ['NE', 'NER', 'Niger', 'NG', 'NGA', 'Nigeria', 'BJ', 'BEN', 'Benin', 'Bénin', 'CM', 'CMR', 'Cameroon', 'Cameroun', 'TD', 'TCD', 'Chad', 'Tchad', 'GA', 'GAB', 'Gabon', 'CG', 'COG', 'Congo', 'Republic of the Congo', 'CD', 'COD', 'DR Congo', 'RDC', 'République Démocratique du Congo', 'CF', 'CAF', 'Central African Republic', 'Centrafrique', 'DZ', 'DZA', 'Algeria', 'Algérie', 'TN', 'TUN', 'Tunisia', 'Tunisie', 'MA', 'MAR', 'Morocco', 'Maroc', 'FR', 'FRA', 'France', 'BE', 'BEL', 'Belgium', 'Belgique', 'DE', 'DEU', 'Germany', 'Allemagne', 'ES', 'ESP', 'Spain', 'Espagne', 'IT', 'ITA', 'Italy', 'Italie', 'CH', 'CHE', 'Switzerland', 'Suisse']],
    [2, ['EG', 'EGY', 'Egypt', 'Égypte', 'ZA', 'ZAF', 'South Africa', 'Afrique du Sud', 'RW', 'RWA', 'Rwanda', 'BI', 'BDI', 'Burundi']],
    [3, ['TR', 'TUR', 'Turkey', 'Turquie', 'Türkiye', 'MG', 'MDG', 'Madagascar', 'KE', 'KEN', 'Kenya', 'SA', 'SAU', 'Saudi Arabia', 'Arabie Saoudite', 'QA', 'QAT', 'Qatar']],
    [4, ['AE', 'ARE', 'United Arab Emirates', 'Émirats Arabes Unis', 'Emirats', 'UAE', 'MU', 'MUS', 'Mauritius', 'Maurice']],
    [8, ['CN', 'CHN', 'China', 'Chine']],
    [-5, ['CA', 'CAN', 'Canada', 'US', 'USA', 'United States', 'États-Unis', 'Etats Unis']],
  ])('garde chaque alias historique de UTC%+d', (offset, aliases) => {
    for (const alias of aliases) {
      expect([alias, utcOffsetHoursForCountry(alias)]).toEqual([alias, offset]);
    }
  });

  it('falls back to UTC+0 for unknown or empty residences', () => {
    expect(utcOffsetHoursForCountry(undefined)).toBe(0);
    expect(utcOffsetHoursForCountry('')).toBe(0);
    expect(utcOffsetHoursForCountry('Atlantis')).toBe(0);
  });

  it('computes the local hour from a UTC date + offset', () => {
    const utc = new Date('2026-07-23T23:00:00Z');
    expect(localHourFor(utc, 0)).toBe(23);
    expect(localHourFor(utc, 1)).toBe(0); // wraps past midnight
    expect(localHourFor(utc, 4)).toBe(3);
  });

  it('computes the local weekday, including day rollover from the offset', () => {
    // 2026-07-27 is a Monday (getUTCDay() === 1).
    const mondayMorning = new Date('2026-07-27T08:00:00Z');
    expect(localWeekdayFor(mondayMorning, 0)).toBe(1); // Monday
    expect(localWeekdayFor(mondayMorning, 1)).toBe(1); // still Monday

    // Late Sunday UTC becomes Monday for a positive offset.
    const sundayLate = new Date('2026-07-26T23:30:00Z');
    expect(localWeekdayFor(sundayLate, 0)).toBe(0); // Sunday
    expect(localWeekdayFor(sundayLate, 1)).toBe(1); // Monday locally

    // Early Monday UTC is still Sunday for a negative offset.
    const mondayEarly = new Date('2026-07-27T02:00:00Z');
    expect(localWeekdayFor(mondayEarly, -5)).toBe(0); // Sunday in Montréal
  });

  it('detects the midnight-wrapping quiet window (21:00–08:00)', () => {
    const at = (h: number) =>
      new Date(`2026-07-23T${String(h).padStart(2, '0')}:00:00Z`);
    expect(isWithinQuietHours(at(23), 0, 21, 8)).toBe(true);
    expect(isWithinQuietHours(at(3), 0, 21, 8)).toBe(true);
    expect(isWithinQuietHours(at(7), 0, 21, 8)).toBe(true);
    expect(isWithinQuietHours(at(8), 0, 21, 8)).toBe(false); // window end is exclusive
    expect(isWithinQuietHours(at(10), 0, 21, 8)).toBe(false);
    expect(isWithinQuietHours(at(20), 0, 21, 8)).toBe(false);
  });

  it('never marks everything quiet when the window is degenerate', () => {
    const noon = new Date('2026-07-23T12:00:00Z');
    expect(isWithinQuietHours(noon, 0, 8, 8)).toBe(false);
  });
});
