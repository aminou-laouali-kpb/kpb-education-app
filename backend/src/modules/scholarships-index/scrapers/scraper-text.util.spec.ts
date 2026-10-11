import {
  countryFromName,
  detectCountry,
  detectFundingType,
  htmlToText,
  isArticleLink,
  parseDeadline,
} from './scraper-text.util';

describe('scraper text helpers', () => {
  describe('detectFundingType', () => {
    it('ignores the "100%" that WordPress CSS puts in every page', () => {
      const page =
        '<style>.wp-block{width:100%}</style><div class="entry-content"><p>The EPFL fellowship covers a monthly stipend.</p></div>';
      expect(detectFundingType('EPFL Excellence Fellowships 2027', htmlToText(page))).toBe(
        'unknown',
      );
    });

    it('detects fully and partially funded wording in the article text', () => {
      expect(detectFundingType('Chevening Scholarships', 'This is a fully funded award.')).toBe(
        'fully_funded',
      );
      expect(detectFundingType('Bourse X', 'Une bourse partielle est accordée.')).toBe(
        'partially_funded',
      );
    });
  });

  describe('detectCountry', () => {
    it('prefers the country named in the title', () => {
      const text = 'Apply now. Related: Study in Italy, Study in Italy guide.';
      expect(detectCountry('EPFL Excellence Fellowships in Switzerland', text)).toMatchObject({
        id: 'che',
      });
    });

    it('does not let a single stray body mention decide (EPFL was classed Italy)', () => {
      const text = 'EPFL offers fellowships. Read also: Study in Italy.';
      // "EPFL" is a Switzerland alias and appears in the title.
      expect(detectCountry('EPFL Excellence Master Fellowships', text).id).toBe('che');
      expect(detectCountry('Global Fellowship', 'Read also: Study in Italy.').id).toBe(
        'international',
      );
    });

    it('takes the most mentioned country in the body', () => {
      const text = 'Study in Germany. German universities. Germany is free. One link to France.';
      expect(detectCountry('DAAD Scholarship', text).id).toBe('deu');
    });

    it('maps display names to the alpha-3 Country.id', () => {
      expect(countryFromName('Royaume-Uni').id).toBe('gbr');
      expect(countryFromName('United States').id).toBe('usa');
      expect(countryFromName('Atlantis').id).toBe('international');
    });
  });

  describe('parseDeadline', () => {
    const now = new Date('2026-10-10T12:00:00Z');

    it('stores the end of the stated day, not midnight', () => {
      expect(parseDeadline('Deadline: March 15, 2027', now)?.toISOString()).toBe(
        '2027-03-15T23:59:59.000Z',
      );
      expect(parseDeadline('Date limite : 15 mars 2027', now)?.toISOString()).toBe(
        '2027-03-15T23:59:59.000Z',
      );
    });

    it('infers the year of a date given without one', () => {
      expect(parseDeadline('Deadline: December 15', now)?.toISOString()).toBe(
        '2026-12-15T23:59:59.000Z',
      );
      // Long past this year → next occurrence.
      expect(parseDeadline('Deadline: January 31', now)?.toISOString()).toBe(
        '2027-01-31T23:59:59.000Z',
      );
    });

    it('returns null without a date and rejects impossible days', () => {
      expect(parseDeadline('See the official website', now)).toBeNull();
      expect(parseDeadline('February 31, 2027', now)).toBeNull();
    });
  });

  describe('isArticleLink', () => {
    it('keeps articles and drops static pages', () => {
      expect(isArticleLink('https://greatyop.com/epfl-excellence-fellowships-2027/')).toBe(true);
      for (const url of [
        'https://greatyop.com/about-us/',
        'https://greatyop.com/contact/',
        'https://greatyop.com/privacy-policy/',
        'https://greatyop.com/wp-json/',
        'https://greatyop.com/category/scholarships/',
        'https://greatyop.com/',
      ]) {
        expect(isArticleLink(url)).toBe(false);
      }
    });
  });
});
