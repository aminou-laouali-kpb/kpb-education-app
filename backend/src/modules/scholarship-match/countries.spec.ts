import { ISO_COUNTRIES, isIsoCountryCode, resolveCountryCode } from '../../common/iso-countries';
import { SCHOLARSHIP_CATALOG_V1 } from '../scholarships-index/data/scholarship-catalog.v1';
import {
  countryName,
  countryOptions,
  normaliseCountryAnswer,
  PRIORITY_COUNTRY_CODES,
} from './countries';

describe('table ISO des pays', () => {
  it('249 pays ISO 3166-1, codes uniques, noms FR et EN', () => {
    expect(ISO_COUNTRIES).toHaveLength(249);
    expect(new Set(ISO_COUNTRIES.map((c) => c.code)).size).toBe(249);
    expect(new Set(ISO_COUNTRIES.map((c) => c.alpha2)).size).toBe(249);
    for (const country of ISO_COUNTRIES) {
      expect(country.code).toMatch(/^[a-z]{3}$/);
      expect(country.alpha2).toMatch(/^[A-Z]{2}$/);
      expect(country.nameFr.trim()).not.toBe('');
      expect(country.nameEn.trim()).not.toBe('');
    }
  });

  it('connaît chaque pays du catalogue vérifié (sauf `int`, multi-pays)', () => {
    const ids = new Set(
      SCHOLARSHIP_CATALOG_V1.records.map((record) => record.scholarship.countryId),
    );
    for (const id of ids) {
      if (id === 'int') continue;
      expect([id, isIsoCountryCode(id)]).toEqual([id, true]);
    }
  });

  it('résout codes, noms et alias sans jamais deviner', () => {
    expect(resolveCountryCode('NE')).toBe('ner');
    expect(resolveCountryCode('ner')).toBe('ner');
    expect(resolveCountryCode('République démocratique du Congo')).toBe('cod');
    expect(resolveCountryCode('Congo Brazzaville')).toBe('cog');
    expect(resolveCountryCode('le Sénégal')).toBe('sen');
    expect(resolveCountryCode('Turkey')).toBe('tur');
    expect(resolveCountryCode('Türkiye')).toBe('tur');
    expect(resolveCountryCode('Autre')).toBeNull();
    expect(resolveCountryCode('Atlantide')).toBeNull();
    expect(normaliseCountryAnswer('ata')).toBeNull();
    expect(normaliseCountryAnswer(42)).toBeNull();
  });
});

describe('liste des pays servie', () => {
  it('l’Afrique francophone en tête, y compris les pays oubliés par l’onboarding', () => {
    const options = countryOptions('fr');
    expect(options.slice(0, PRIORITY_COUNTRY_CODES.length).map((o) => o.code)).toEqual([
      ...PRIORITY_COUNTRY_CODES,
    ]);
    for (const code of ['tcd', 'gab', 'cog', 'cod', 'caf', 'mdg', 'com', 'dji']) {
      expect(PRIORITY_COUNTRY_CODES).toContain(code);
    }
    expect(options.every((o, i) => o.priority === i < PRIORITY_COUNTRY_CODES.length)).toBe(true);
  });

  it('chaque pays habité une fois, le reste trié dans la langue demandée', () => {
    for (const lang of ['fr', 'en'] as const) {
      const options = countryOptions(lang);
      expect(new Set(options.map((o) => o.code)).size).toBe(options.length);
      expect(options).toHaveLength(249 - 7);
      expect(options.map((o) => o.code)).not.toContain('ata');
      const tail = options.filter((o) => !o.priority).map((o) => o.name);
      const collator = new Intl.Collator(lang, { sensitivity: 'base' });
      expect(tail).toEqual([...tail].sort((a, b) => collator.compare(a, b)));
    }
    expect(countryName('civ', 'fr')).toBe('Côte d’Ivoire');
    expect(countryName('deu', 'en')).toBe('Germany');
  });
});
