import { GreatYopScraper } from './greatyop.scraper';
import { MastereTnScraper } from './mastereTn.scraper';

/**
 * Constat d'audit n° 9 : la fenêtre de crawl (pages et articles plafonnés,
 * articles sautés sur erreur) servait de liste exhaustive pour désactiver les
 * bourses absentes. Les scrapers doivent dire s'ils ont tout lu.
 */
type Harness = {
  scraper: GreatYopScraper | MastereTnScraper;
  articleLink: (slug: string) => string;
};

const harnesses: Array<[string, () => Harness]> = [
  [
    'GreatYopScraper',
    () => ({
      scraper: new GreatYopScraper(),
      articleLink: (slug) => `https://greatyop.com/${slug}/`,
    }),
  ],
  [
    'MastereTnScraper',
    () => ({
      scraper: new MastereTnScraper(),
      articleLink: (slug) => `https://www.mastere.tn/${slug}/`,
    }),
  ],
];

describe.each(harnesses)('%s — crawl completeness', (_name, build) => {
  /**
   * `listing[i]` = slugs de la page i+1 ; une page absente lève (HTTP 404).
   * Les articles dont le slug est dans `broken` lèvent à la lecture.
   */
  function run(listing: string[][], broken: string[] = []) {
    const { scraper, articleLink } = build();
    const s = scraper as unknown as Record<string, unknown>;
    s.sleep = async () => undefined;
    s.fetchHtml = async (url: string) => {
      const page = url.match(/\/page\/(\d+)\/$/);
      const isListing =
        page || /\/(category\/scholarships|bourses)\/$/.test(url);
      if (isListing) {
        const n = page ? Number(page[1]) : 1;
        const slugs = listing[n - 1];
        if (!slugs) throw new Error(`HTTP 404 for ${url}`);
        return slugs.map((sl) => `<a href="${articleLink(sl)}">x</a>`).join('');
      }
      throw new Error('unexpected fetch');
    };
    s.parseArticle = async (url: string) => {
      const slug = url.split('/').filter(Boolean).pop()!;
      if (broken.includes(slug)) throw new Error('timeout');
      return { sourceKey: `${scraper.prefix}-${slug}` };
    };
    return scraper.fetch();
  }

  const slugs = (prefix: string, n: number) =>
    Array.from({ length: n }, (_, i) => `${prefix}-bourse-${i + 1}`);

  it('is complete when the listing ends on an empty page and every article parsed', async () => {
    const result = await run([slugs('a', 3), []]);
    expect(result.complete).toBe(true);
    expect(result.rows).toHaveLength(3);
  });

  it('is partial when an article fails to parse', async () => {
    const result = await run([slugs('a', 3), []], ['a-bourse-2']);
    expect(result.complete).toBe(false);
    expect(result.rows).toHaveLength(2);
  });

  it('is partial when more articles are listed than the per-run cap', async () => {
    const result = await run([slugs('a', 30), slugs('b', 30), []]);
    expect(result.rows).toHaveLength(50);
    expect(result.complete).toBe(false);
  });

  it('is partial when the page cap is hit or a listing page errors', async () => {
    // Pages pleines jusqu'au plafond : la fin du listing n'a jamais été vue.
    const capped = await run(Array.from({ length: 6 }, (_, i) => [`p${i}-bourse-pleine`]));
    expect(capped.complete).toBe(false);
    // Page 2 en erreur (404/503) : on ne sait pas ce qui suit.
    const errored = await run([slugs('a', 2)]);
    expect(errored.complete).toBe(false);
  });
});
