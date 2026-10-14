import {
  buildBundleCopy,
  buildOpeningCopy,
  formatDateUtc,
  openingLanguage,
} from './scholarship-opening.copy';

describe('scholarship-opening.copy', () => {
  const names = { fr: 'Bourse Chevening', en: 'Chevening Scholarship' };
  const now = new Date('2026-10-15T12:00:00.000Z');

  it('« 1er » en français, le jour nu ensuite ; anglais sans ordinal', () => {
    expect(formatDateUtc(new Date('2026-11-01T00:00:00Z'), 'fr')).toBe(
      '1er novembre',
    );
    expect(formatDateUtc(new Date('2026-11-05T00:00:00Z'), 'fr')).toBe(
      '5 novembre',
    );
    expect(formatDateUtc(new Date('2026-11-01T00:00:00Z'), 'en')).toBe(
      '1 November',
    );
  });

  // L'admin enregistre la clôture à 23:59:59.999Z : lue dans un fuseau à
  // l'ouest de Greenwich, ce serait la veille ; à l'est, le lendemain.
  it('lit la date en UTC (T23:59:59.999Z reste le même jour)', () => {
    const close = new Date('2026-11-30T23:59:59.999Z');
    expect(formatDateUtc(close, 'fr')).toBe('30 novembre');
    expect(formatDateUtc(close, 'en')).toBe('30 November');
  });

  it('langue : en* → anglais, tout le reste → français', () => {
    expect(openingLanguage('en')).toBe('en');
    expect(openingLanguage('EN-gb')).toBe('en');
    expect(openingLanguage('fr')).toBe('fr');
    expect(openingLanguage('')).toBe('fr');
    expect(openingLanguage(null)).toBe('fr');
  });

  it('ouverte : variantes alerte et favori, nom dans le corps, tutoiement', () => {
    const copy = buildOpeningCopy(
      names,
      new Date('2026-10-01T00:00:00Z'),
      new Date('2026-11-05T23:59:59.999Z'),
      now,
    );
    expect(copy.variant).toBe('opened');
    expect(copy.fr.alert).toEqual({
      title: "C'est ouvert",
      body: "Bourse Chevening : candidatures jusqu'au 5 novembre. Ouvre la fiche pour voir les étapes.",
    });
    expect(copy.fr.favorite).toEqual({
      title: 'Une bourse que tu suis est ouverte',
      body: "Bourse Chevening : candidatures jusqu'au 5 novembre. Tu l'avais mise en favori.",
    });
    expect(copy.en.alert).toEqual({
      title: 'Applications are open',
      body: 'Chevening Scholarship: apply by 5 November. Open the page to see the steps.',
    });
    expect(copy.en.favorite).toEqual({
      title: 'A scholarship you follow is open',
      body: 'Chevening Scholarship: apply by 5 November. You saved it as a favourite.',
    });
  });

  // Jamais « ouverte » avant l'ouverture.
  it('ouverture à venir à l’instant de l’envoi → « Dates confirmées »', () => {
    const copy = buildOpeningCopy(
      names,
      new Date('2026-11-01T00:00:00Z'),
      new Date('2026-11-30T23:59:59.999Z'),
      now,
    );
    expect(copy.variant).toBe('dates_confirmed');
    expect(copy.fr.dates_confirmed).toEqual({
      title: 'Dates confirmées',
      body: 'Bourse Chevening : candidatures du 1er novembre au 30 novembre.',
    });
    expect(copy.en.dates_confirmed).toEqual({
      title: 'Dates confirmed',
      body: 'Chevening Scholarship: applications open 1 November and close 30 November.',
    });
    // La même instant d'ouverture, passé : « ouverte ».
    expect(
      buildOpeningCopy(names, new Date('2026-11-01T00:00:00Z'), null, new Date('2026-11-01T00:00:01Z'))
        .variant,
    ).toBe('opened');
  });

  it('sans date de clôture, ne fabrique pas de date', () => {
    const copy = buildOpeningCopy(names, null, null, now);
    expect(copy.fr.alert.body).toBe(
      'Bourse Chevening : les candidatures sont ouvertes. Ouvre la fiche pour voir les étapes.',
    );
    expect(copy.en.favorite.body).toBe(
      'Chevening Scholarship: applications are open. You saved it as a favourite.',
    );
  });

  describe('push groupé', () => {
    it.each([
      [
        ['Chevening', 'Eiffel'],
        '2 bourses que tu suis sont ouvertes',
        'Chevening et Eiffel. Regarde les dates limites.',
        '2 scholarships you follow are open',
        'Chevening and Eiffel. Check the deadlines.',
      ],
      [
        ['Chevening', 'Eiffel', 'MEXT'],
        '3 bourses que tu suis sont ouvertes',
        'Chevening, Eiffel et 1 autre. Regarde les dates limites.',
        '3 scholarships you follow are open',
        'Chevening, Eiffel and 1 more. Check the deadlines.',
      ],
      [
        ['Chevening', 'Eiffel', 'MEXT', 'DAAD'],
        '4 bourses que tu suis sont ouvertes',
        'Chevening, Eiffel et 2 autres. Regarde les dates limites.',
        '4 scholarships you follow are open',
        'Chevening, Eiffel and 2 more. Check the deadlines.',
      ],
    ])('n = %#', (list, frTitle, frBody, enTitle, enBody) => {
      expect(buildBundleCopy(list, 'fr', 'opened')).toEqual({ title: frTitle, body: frBody });
      expect(buildBundleCopy(list, 'en', 'opened')).toEqual({ title: enTitle, body: enBody });
    });

    it('n’écrit jamais « 0 autre »', () => {
      expect(buildBundleCopy(['A', 'B'], 'fr', 'opened').body).not.toContain('autre');
    });

    it('une ligne « Dates confirmées » dans le groupé : jamais « ouvertes »', () => {
      expect(buildBundleCopy(['Chevening', 'Eiffel'], 'fr', 'dates_confirmed')).toEqual({
        title: '2 bourses que tu suis ont du nouveau',
        body: 'Chevening et Eiffel. Regarde les dates.',
      });
      expect(
        buildBundleCopy(['Chevening', 'Eiffel', 'MEXT', 'DAAD'], 'en', 'dates_confirmed'),
      ).toEqual({
        title: '4 scholarships you follow have updates',
        body: 'Chevening, Eiffel and 2 more. Check the dates.',
      });
      for (const lang of ['fr', 'en'] as const) {
        const copy = buildBundleCopy(['A', 'B', 'C'], lang, 'dates_confirmed');
        expect(`${copy.title} ${copy.body}`).not.toMatch(/ouvert|open|limite|deadline/i);
      }
    });
  });
});
