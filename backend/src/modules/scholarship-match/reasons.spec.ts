import {
  ALL_MATCH_CODES,
  EXCLUSION_CODES,
  EXCLUSION_GROUP,
  isHonestLabel,
  REASON_CODES,
  renderPoint,
  TO_VERIFY_CODES,
  topReasons,
  type MatchPointParams,
} from './reasons';

/** Des paramètres pour chaque forme de libellé. */
const PARAM_SAMPLES: MatchPointParams[] = [
  {},
  {
    level: 'master',
    levels: ['bachelor', 'master'],
    countries: ['ner'],
    age: 24,
    min: 16,
    max: 29,
    maxInclusive: true,
    asOfDate: '2027-08-01',
    minMonths: 24,
    lang: 'en',
    minCefr: 'b2',
    tests: ['ielts 6.5', 'toefl_ibt 90'],
    minOn20: 12,
    waivable: true,
  },
  {
    level: 'doctorate',
    levels: ['secondary'],
    countries: ['sen', 'mli', 'bfa', 'civ', 'gin'],
    max: 30,
    maxInclusive: false,
    minMonths: 36,
    lang: 'de',
    minOn20: 14.5,
  },
  { min: 16, lang: 'fr', minCefr: 'c1', countries: [] },
];

describe('reasons — libellés rendus côté serveur', () => {
  it('chaque code appartient à une seule famille', () => {
    expect(new Set(ALL_MATCH_CODES).size).toBe(
      REASON_CODES.length + TO_VERIFY_CODES.length + EXCLUSION_CODES.length,
    );
  });

  it.each(ALL_MATCH_CODES.map((code) => [code]))('%s : parité FR/EN, aucun trou', (code) => {
    for (const params of PARAM_SAMPLES) {
      const fr = renderPoint({ code, params }, 'fr');
      const en = renderPoint({ code, params }, 'en');
      for (const text of [fr, en]) {
        expect(text.trim().length).toBeGreaterThan(0);
        expect(text).not.toMatch(/undefined|NaN|null|\[object/);
      }
    }
    // Sans paramètre du tout (un ancien run relu après une évolution).
    expect(renderPoint({ code }, 'fr').length).toBeGreaterThan(0);
    expect(renderPoint({ code }, 'en').length).toBeGreaterThan(0);
  });

  it.each(ALL_MATCH_CODES.map((code) => [code]))(
    '%s : ni « % » ni « chance » dans un libellé KPB',
    (code) => {
      for (const params of PARAM_SAMPLES) {
        for (const lang of ['fr', 'en'] as const) {
          const text = renderPoint({ code, params }, lang);
          expect([code, lang, isHonestLabel(text)]).toEqual([code, lang, true]);
        }
      }
    },
  );

  it('isHonestLabel attrape « % » et « chance(s) », toutes casses', () => {
    expect(isHonestLabel('70 % de réussite')).toBe(false);
    expect(isHonestLabel('Tes Chances sont bonnes')).toBe(false);
    expect(isHonestLabel('Good chance')).toBe(false);
    expect(isHonestLabel('Niveau Master accepté')).toBe(true);
  });

  it('chaque motif d’exclusion a un groupe pour le résumé', () => {
    for (const code of EXCLUSION_CODES) expect(EXCLUSION_GROUP[code]).toBeDefined();
  });

  it('exemples du parcours, mot pour mot', () => {
    expect(renderPoint({ code: 'level_accepted', params: { level: 'master' } }, 'fr')).toBe(
      'Niveau Master accepté',
    );
    expect(
      renderPoint(
        {
          code: 'age_within_limit',
          params: { age: 24, max: 29, maxInclusive: true, asOfDate: '2027-08-01' },
        },
        'fr',
      ),
    ).toBe('Tu as 24 ans — limite 29 ans au 1er août 2027');
    expect(
      renderPoint(
        { code: 'language_missing', params: { lang: 'en', tests: ['ielts 6.5'] } },
        'fr',
      ),
    ).toBe('IELTS 6.5 en anglais demandé — tu n’as pas indiqué de score');
    expect(
      renderPoint({ code: 'nationality_accepted', params: { countries: ['ner'] } }, 'fr'),
    ).toBe('Ouverte à ta nationalité (Niger)');
    expect(
      renderPoint({ code: 'age_too_old', params: { max: 30, maxInclusive: false } }, 'en'),
    ).toBe('Age required: under 30');
  });

  it('au plus trois pays nommés, puis « … »', () => {
    expect(
      renderPoint(
        { code: 'nationality_not_listed', params: { countries: ['sen', 'mli', 'bfa', 'civ'] } },
        'fr',
      ),
    ).toBe('Réservée à d’autres nationalités (Sénégal, Mali, Burkina Faso…)');
  });

  it('topReasons : au plus 3, les plus parlantes d’abord', () => {
    const top = topReasons([
      { code: 'fields_all' },
      { code: 'age_within_limit' },
      { code: 'level_accepted' },
      { code: 'nationality_accepted' },
      { code: 'destination_wanted' },
    ]);
    expect(top.map((point) => point.code)).toEqual([
      'nationality_accepted',
      'level_accepted',
      'age_within_limit',
    ]);
  });
});
