import {
  campaignDaysFromWindow,
  campaignPhase,
  campaignWindowFromDays,
  isValidLocalDate,
  isWithinWindow,
  localDateOf,
  zonedLocalToUtc,
} from './campaign-time';

/**
 * La fenêtre de la compétition de novembre 2026 : « du 1er au 10 novembre,
 * heure d'Afrique de l'Ouest (UTC+1) ». Les bornes sont des JOURS, converties en
 * instants UTC ; la borne de fin est exclusive.
 */
describe('campaign-time — fenêtre UTC+1', () => {
  const window = campaignWindowFromDays('2026-11-01', '2026-11-10', 'Africa/Lagos');

  it('calcule les instants UTC depuis Africa/Lagos (UTC+1, sans heure d’été)', () => {
    expect(window.startsAt.toISOString()).toBe('2026-10-31T23:00:00.000Z');
    expect(window.endsAt.toISOString()).toBe('2026-11-10T23:00:00.000Z');
  });

  it('compte le 10 novembre à 23 h 59 heure de Niamey, pas minuit pile', () => {
    expect(isWithinWindow(new Date('2026-11-10T22:59:59.999Z'), window)).toBe(true);
    expect(isWithinWindow(new Date('2026-11-10T23:00:00.000Z'), window)).toBe(false);
  });

  it('compte le 1er novembre à 00 h 00 locale (31 octobre 23 h UTC), pas avant', () => {
    expect(isWithinWindow(new Date('2026-10-31T23:00:00.000Z'), window)).toBe(true);
    expect(isWithinWindow(new Date('2026-10-31T22:59:59.999Z'), window)).toBe(false);
  });

  it('rend les jours inclusifs à l’affichage', () => {
    expect(campaignDaysFromWindow(window, 'Africa/Lagos')).toEqual({
      startDate: '2026-11-01',
      endDate: '2026-11-10',
    });
  });

  it('donne la phase de la campagne', () => {
    expect(campaignPhase(window, new Date('2026-10-20T12:00:00Z'))).toBe('upcoming');
    expect(campaignPhase(window, new Date('2026-11-05T12:00:00Z'))).toBe('running');
    expect(campaignPhase(window, new Date('2026-11-11T00:00:00Z'))).toBe('ended');
  });

  it('reste juste pour un fuseau à heure d’été (Europe/Paris, passage du 25/10)', () => {
    // 25/10/2026 : Paris passe de UTC+2 à UTC+1.
    expect(zonedLocalToUtc('2026-10-24T00:00', 'Europe/Paris').toISOString()).toBe(
      '2026-10-23T22:00:00.000Z',
    );
    expect(zonedLocalToUtc('2026-10-26T00:00', 'Europe/Paris').toISOString()).toBe(
      '2026-10-25T23:00:00.000Z',
    );
  });

  it('lit un jour local depuis un instant', () => {
    expect(localDateOf(new Date('2026-10-31T23:30:00Z'), 'Africa/Lagos')).toBe('2026-11-01');
    expect(localDateOf(new Date('2026-10-31T23:30:00Z'), 'UTC')).toBe('2026-10-31');
  });

  it('refuse des dates invalides ou inversées et un fuseau inconnu', () => {
    expect(isValidLocalDate('2026-02-30')).toBe(false);
    expect(() => campaignWindowFromDays('2026-11-10', '2026-11-01')).toThrow();
    expect(() => campaignWindowFromDays('2026-11-01', '2026-11-10', 'Mars/Olympus')).toThrow();
  });

  it('accepte une campagne d’un seul jour', () => {
    const one = campaignWindowFromDays('2026-11-01', '2026-11-01', 'Africa/Lagos');
    expect(one.endsAt.getTime() - one.startsAt.getTime()).toBe(24 * 3600 * 1000);
  });
});
