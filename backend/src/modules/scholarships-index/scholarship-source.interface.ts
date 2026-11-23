/**
 * Contract for a scholarship-index scraper.
 *
 * Scrapers are pure: they fetch/parse the source, return a typed list, and
 * never touch the database. The service does upsert + deactivation.
 */
export interface ScholarshipScraper {
  /** Stable identifier used as the sourceKey prefix for this scraper. */
  readonly prefix: string;

  /**
   * Human-readable name — used in logs and the admin-trigger response so the
   * operator can see which sources ran successfully.
   */
  readonly name: string;

  /**
   * Fetch + parse the upstream index. Returns [] on any parse error rather
   * than throwing — a single flaky source shouldn't break the whole 48h
   * refresh. The service logs partial failures.
   *
   * Un tableau nu vaut liste EXHAUSTIVE de la source : le service désactive
   * alors les fiches absentes. Un scraper qui ne lit qu'une fenêtre bornée
   * (pages plafonnées, articles plafonnés, articles sautés sur erreur) DOIT
   * renvoyer `{ rows, complete }` et ne poser `complete: true` que s'il a tout
   * lu : sinon une bourse sortie de la fenêtre serait retirée alors qu'elle est
   * toujours en ligne.
   */
  fetch(): Promise<ScrapedScholarship[] | ScraperFetchResult>;
}

/** Résultat d'un crawl qui sait dire s'il a couvert toute la source. */
export type ScraperFetchResult = {
  rows: ScrapedScholarship[];
  /**
   * `true` seulement si toutes les pages de listing ont été parcourues jusqu'à
   * leur fin ET tous les articles listés ont été lus sans erreur.
   */
  complete: boolean;
};

export type FundingType = 'fully_funded' | 'partially_funded' | 'unknown';

export type ScrapedScholarship = {
  /** MUST start with `${scraper.prefix}-` — enforced by the service. */
  sourceKey: string;
  nameFr: string;
  nameEn: string;
  /** ISO 3166-1 alpha-2 country code or a name fallback. Used to resolve Country.id. */
  countryId: string;
  countryNameFr: string;
  countryNameEn: string;
  /** Bilingual description paragraphs */
  descriptionFr: string;
  descriptionEn: string;
  /** List of benefits / advantages */
  advantagesFr: string[];
  advantagesEn: string[];
  /** Eligibility criteria */
  eligibilityFr: string[];
  eligibilityEn: string[];
  /** Funding classification */
  fundingType: FundingType;
  /** Null if the source doesn't publish an explicit deadline date. */
  deadlineAt: Date | null;
  deadlineLabelFr: string;
  deadlineLabelEn: string;
  /** Study levels: 'bachelor', 'master', 'phd', 'postdoc', 'research' */
  levelEligibleFr: string;
  levelEligibleEn: string;
  /** URL a student would visit to apply. */
  applicationUrl: string;
  /** Canonical source page for admins to verify the listing. */
  sourceUrl?: string;
  /** Freeform labels: ["masters", "fully-funded", "africa-priority", …]. */
  tags: string[];
  /**
   * Content quality score 0–100 used for duplicate merging.
   * Higher = this record should "win" when same scholarship appears in two sources.
   */
  contentScore?: number;
};
