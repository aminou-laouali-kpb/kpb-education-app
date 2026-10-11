import { Injectable, Logger } from '@nestjs/common';

import {
  FundingType,
  ScrapedScholarship,
  ScholarshipScraper,
} from '../scholarship-source.interface';
import {
  detectCountry,
  detectFundingType,
  fetchPageHtml,
  htmlToText,
  isArticleLink,
  parseDeadline,
} from './scraper-text.util';

/**
 * Greatyop.com — English (primary) + French mirror scraper.
 *
 * Source:  https://greatyop.com/category/scholarships/
 * French:  https://greatyop.com/accueil/ (French slugs linked inline in EN posts)
 *
 * Strategy:
 *  1. Crawl the listing page (up to 3 pages) collecting article URLs.
 *  2. For each article, fetch the EN detail page and parse the structured
 *     H2/H3 sections (Program Details, Benefits, Eligibility, Documents, How to Apply).
 *  3. Detect the French mirror URL from the hreflang or the nav link in the page.
 *  4. Fetch the FR mirror and extract the same sections.
 *  5. Return one ScrapedScholarship per listing.
 */
@Injectable()
export class GreatYopScraper implements ScholarshipScraper {
  readonly prefix = 'greatyop';
  readonly name = 'GreatYop.com (EN+FR)';
  private readonly logger = new Logger(GreatYopScraper.name);

  private readonly BASE_EN = 'https://greatyop.com';
  private readonly LISTING_URL = 'https://greatyop.com/category/scholarships/';
  private readonly HEADERS = {
    'User-Agent':
      'KPB-Education-Bot/1.0 (kpbeducation.cloud; contact@kpbeducation.cloud)',
    Accept: 'text/html,application/xhtml+xml',
  };

  async fetch(): Promise<ScrapedScholarship[]> {
    const results: ScrapedScholarship[] = [];

    // ── Step 1: Collect article URLs from listing pages ──────────────────────
    const articleUrls = await this.collectArticleUrls();
    this.logger.log(`[${this.prefix}] Found ${articleUrls.length} articles`);

    // ── Step 2: Parse each article ───────────────────────────────────────────
    for (const url of articleUrls.slice(0, 50)) {
      // cap at 50 to avoid hammering
      try {
        const scholarship = await this.parseArticle(url);
        if (scholarship) results.push(scholarship);
        await this.sleep(600); // polite delay between requests
      } catch (error) {
        this.logger.warn(
          `[${this.prefix}] Failed to parse ${url}: ${error instanceof Error ? error.message : 'unknown'}`,
        );
      }
    }

    this.logger.log(`[${this.prefix}] Scraped ${results.length} scholarships`);
    return results;
  }

  private async collectArticleUrls(): Promise<string[]> {
    const urls = new Set<string>();
    // Paginate through up to 4 listing pages
    for (let page = 1; page <= 4; page++) {
      const listUrl =
        page === 1
          ? this.LISTING_URL
          : `${this.LISTING_URL}page/${page}/`;
      try {
        const html = await this.fetchHtml(listUrl);
        const matches = html.matchAll(
          /href="(https:\/\/greatyop\.com\/[a-z0-9-]+\/)"/g,
        );
        let found = 0;
        for (const m of matches) {
          const u = m[1];
          // Articles only: no category/author/tag pages, no static pages
          // (/about-us/, /privacy-policy/… were imported as scholarships).
          if (isArticleLink(u)) {
            urls.add(u);
            found++;
          }
        }
        if (found === 0) break; // No more pages
        await this.sleep(500);
      } catch (err) {
        this.logger.warn(`[${this.prefix}] Listing page ${page} failed: ${err instanceof Error ? err.message : err}`);
        break;
      }
    }
    return [...urls];
  }

  private async parseArticle(url: string): Promise<ScrapedScholarship | null> {
    const html = await this.fetchHtml(url);

    // Title from <h1> or <title>
    const titleEn =
      this.extractMeta(html, 'og:title') ||
      this.extractTag(html, 'h1') ||
      '';
    if (!titleEn || titleEn.length < 5) return null;

    // Detect French mirror URL from hreflang or nav link
    const frUrlMatch =
      html.match(/hreflang="fr"[^>]*href="([^"]+)"/) ||
      html.match(/href="(https:\/\/greatyop\.com\/[^"]+\/)"[^>]*>\s*Français\s*<\/a>/);
    const frUrl = frUrlMatch ? frUrlMatch[1] : null;

    // Extract categories → derive tags and levels
    const categories = this.extractCategories(html);
    const tags = this.buildTags(titleEn, categories);
    const levelEn = this.deriveLevelEn(categories);
    const levelFr = this.deriveLevelFr(categories);
    // ── Parse structured sections from EN page ─────────────────────────────
    const body = this.extractArticleBody(html);
    const bodyText = htmlToText(body);
    // Sur le TEXTE de l'article : le HTML brut contient toujours « 100% »
    // (CSS WordPress), et tout sortait « fully_funded ».
    const fundingType = detectFundingType(titleEn, bodyText);
    const descriptionEn = this.extractDescription(body);
    const advantagesEn = this.extractSection(body, ['Benefits', 'Scholarship Benefits', 'What Does', 'Awards', 'Advantages']);
    const eligibilityEn = this.extractSection(body, ['Eligibility', 'Eligibility Criteria', 'Who Can Apply', 'Requirements', 'Eligible']);
    const deadlineInfo = this.extractDeadline(bodyText, titleEn);

    // Country: title first, then the most-mentioned in the article text.
    const country = detectCountry(titleEn, bodyText);
    const countryEn = country.en;
    const countryFr = country.fr;

    // Application URL
    const applyUrl = this.extractApplyUrl(html) || url;

    // ── Fetch French mirror ────────────────────────────────────────────────
    let titleFr = titleEn;
    let descriptionFr = '';
    let advantagesFr: string[] = [];
    let eligibilityFr: string[] = [];

    if (frUrl && frUrl !== url) {
      try {
        await this.sleep(400);
        const frHtml = await this.fetchHtml(frUrl);
        titleFr =
          this.extractMeta(frHtml, 'og:title') ||
          this.extractTag(frHtml, 'h1') ||
          titleEn;
        const frBody = this.extractArticleBody(frHtml);
        descriptionFr = this.extractDescription(frBody);
        advantagesFr = this.extractSection(frBody, ['Avantages', 'Bénéfices', 'Ce que', 'Allocation', 'Montant']);
        eligibilityFr = this.extractSection(frBody, ['Éligibilité', 'Critères', 'Conditions', 'Qui peut', 'Exigences']);
      } catch {
        // French page unavailable — fallback to English
        titleFr = titleEn;
      }
    }

    // ── Build sourceKey ──────────────────────────────────────────────────────
    const slug = url.replace(this.BASE_EN + '/', '').replace(/\/$/, '');
    const sourceKey = `${this.prefix}-${slug}`.slice(0, 200);

    const score = this.computeScore({
      descriptionEn,
      advantagesEn,
      eligibilityEn,
      descriptionFr,
      advantagesFr,
      eligibilityFr,
    });

    return {
      sourceKey,
      nameEn: titleEn.trim(),
      nameFr: titleFr.trim(),
      // `Country.id` est alpha-3 (fra, che…) : un slug ne matchait jamais le
      // filtre pays de /scholarships.
      countryId: country.id,
      countryNameEn: countryEn,
      countryNameFr: countryFr,
      descriptionEn,
      descriptionFr: descriptionFr || descriptionEn,
      advantagesEn,
      advantagesFr: advantagesFr.length ? advantagesFr : advantagesEn,
      eligibilityEn,
      eligibilityFr: eligibilityFr.length ? eligibilityFr : eligibilityEn,
      fundingType,
      deadlineAt: deadlineInfo.date,
      deadlineLabelEn: deadlineInfo.label,
      deadlineLabelFr: deadlineInfo.label,
      levelEligibleEn: levelEn,
      levelEligibleFr: levelFr,
      applicationUrl: applyUrl,
      sourceUrl: url,
      tags,
      contentScore: score,
    };
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  private fetchHtml(url: string): Promise<string> {
    return fetchPageHtml(url, this.HEADERS);
  }

  private extractMeta(html: string, property: string): string {
    const m = html.match(
      new RegExp(
        `<meta[^>]+property=["']${property}["'][^>]+content=["']([^"']+)["']`,
        'i',
      ),
    );
    return m ? m[1].trim() : '';
  }

  private extractTag(html: string, tag: string): string {
    const m = html.match(new RegExp(`<${tag}[^>]*>([^<]+)<\/${tag}>`, 'i'));
    return m ? m[1].trim() : '';
  }

  private extractCategories(html: string): string[] {
    const cats: string[] = [];
    const matches = html.matchAll(/\/category\/([a-z-]+)\//g);
    for (const m of matches) cats.push(m[1]);
    return [...new Set(cats)];
  }

  private buildTags(title: string, categories: string[]): string[] {
    const tags = [...categories];
    const lower = title.toLowerCase();
    if (lower.includes('fully funded')) tags.push('fully-funded');
    if (lower.includes('partial')) tags.push('partially-funded');
    if (lower.includes('africa')) tags.push('africa-priority');
    if (lower.includes('phd') || lower.includes('doctoral')) tags.push('phd');
    if (lower.includes('master')) tags.push('masters');
    if (lower.includes('bachelor') || lower.includes('undergraduate')) tags.push('undergraduate');
    return [...new Set(tags)];
  }

  private deriveLevelEn(categories: string[]): string {
    const levels = categories.filter(c =>
      ['undergraduate', 'masters', 'phd', 'postdoctoral', 'research'].includes(c),
    );
    return levels.join(', ') || 'All levels';
  }

  private deriveLevelFr(categories: string[]): string {
    const map: Record<string, string> = {
      undergraduate: 'Licence',
      masters: 'Master',
      phd: 'Doctorat',
      postdoctoral: 'Post-doctorat',
      research: 'Recherche',
    };
    const levels = categories
      .filter(c => map[c])
      .map(c => map[c]);
    return levels.join(', ') || 'Tous niveaux';
  }

  private extractArticleBody(html: string): string {
    // Extract content between entry-content div
    const m = html.match(/<div[^>]*class="[^"]*entry-content[^"]*"[^>]*>([\s\S]*?)<\/div>\s*<\/div>/i);
    if (m) return m[1];
    // Fallback: take everything between first h2 and comments section
    const start = html.indexOf('<h2');
    const end = html.indexOf('id="respond"');
    if (start > 0 && end > start) return html.slice(start, end);
    return html;
  }

  private extractDescription(body: string): string {
    // First paragraph(s) before any h2 heading
    const beforeH2 = body.split(/<h2/i)[0];
    const paras: string[] = [];
    const matches = beforeH2.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi);
    for (const m of matches) {
      const text = m[1].replace(/<[^>]+>/g, '').trim();
      if (text.length > 40) paras.push(text);
    }
    return paras.slice(0, 3).join(' ').trim();
  }

  private extractSection(body: string, headings: string[]): string[] {
    const items: string[] = [];
    for (const heading of headings) {
      const pattern = new RegExp(
        `<h[23][^>]*>[^<]*${heading}[^<]*<\/h[23]>([\s\S]*?)(?=<h[23]|$)`,
        'i',
      );
      const m = body.match(pattern);
      if (!m) continue;
      const sectionHtml = m[1];
      // Extract list items
      const liMatches = sectionHtml.matchAll(/<li[^>]*>([\s\S]*?)<\/li>/gi);
      for (const li of liMatches) {
        const text = li[1].replace(/<[^>]+>/g, '').trim();
        if (text.length > 5) items.push(text);
      }
      // If no list items, extract paragraphs
      if (items.length === 0) {
        const pMatches = sectionHtml.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/gi);
        for (const p of pMatches) {
          const text = p[1].replace(/<[^>]+>/g, '').trim();
          if (text.length > 10) items.push(text);
        }
      }
      if (items.length) break;
    }
    return items;
  }

  private extractDeadline(text: string, title: string): { date: Date | null; label: string } {
    // Prefer a date next to a deadline keyword; fall back to any date.
    const near = text.match(
      /(?:deadline|apply by|closing date|due date)[^.]{0,80}/i,
    );
    const date =
      (near ? parseDeadline(near[0]) : null) ?? parseDeadline(`${title} ${text}`);
    if (!date) return { date: null, label: 'See official website' };
    return {
      date,
      label: date.toLocaleDateString('en-GB', {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
        timeZone: 'UTC',
      }),
    };
  }

  private extractApplyUrl(html: string): string | null {
    // Look for [Apply] link or [Official page]
    const m =
      html.match(/href="([^"]+)"[^>]*>\s*Apply\s*<\/a>/i) ||
      html.match(/href="([^"]+)"[^>]*>\s*Official page\s*<\/a>/i);
    return m ? m[1] : null;
  }

  private computeScore(data: {
    descriptionEn: string;
    advantagesEn: string[];
    eligibilityEn: string[];
    descriptionFr: string;
    advantagesFr: string[];
    eligibilityFr: string[];
  }): number {
    let score = 0;
    if (data.descriptionEn.length > 100) score += 20;
    if (data.advantagesEn.length > 0) score += 20;
    if (data.eligibilityEn.length > 0) score += 20;
    if (data.descriptionFr.length > 100) score += 20;
    if (data.advantagesFr.length > 0) score += 10;
    if (data.eligibilityFr.length > 0) score += 10;
    return score;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((r) => setTimeout(r, ms));
  }
}
