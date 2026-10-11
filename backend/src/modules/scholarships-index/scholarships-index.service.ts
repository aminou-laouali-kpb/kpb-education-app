import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import {
  publicScholarshipWhere,
  servedCycleStatus,
} from '../../common/public-scholarship-where';
import type { AdminSessionUser } from '../auth/auth.service';
import {
  ScrapedScholarship,
  ScholarshipScraper,
} from './scholarship-source.interface';
import { ScholarshipContentQualityService } from './scholarship-content-quality.service';
import { GreatYopScraper } from './scrapers/greatyop.scraper';
import { MastereTnScraper } from './scrapers/mastereTn.scraper';

export type RefreshResult = {
  startedAt: Date;
  finishedAt: Date;
  sources: Array<{
    prefix: string;
    name: string;
    fetched: number;
    upserted: number;
    deactivated: number;
    merged: number;
    error: string | null;
  }>;
  totalFetched: number;
  totalUpserted: number;
  totalDeactivated: number;
  totalMerged: number;
};

type ScholarshipReadRow = Prisma.ScholarshipGetPayload<{
  include: {
    applicationSteps: true;
    cycles: true;
    videos: true;
  };
}>;

/**
 * Scholarship-index refresh — every 48 hours.
 *
 * Responsibilities:
 *   1. Iterate scrapers (GreatYop + MastereTn), collecting scraped rows.
 *   2. Deduplicate across sources: when the same scholarship appears in both
 *      sites (detected by normalized title similarity), keep the record with
 *      the highest `contentScore` and merge missing fields from the other.
 *   3. Upsert each row into the Scholarship table (sourceKey as the stable ID).
 *   4. After each scraper run, deactivate any row with this scraper's prefix
 *      that wasn't seen in the current run (expired / removed listings).
 */
@Injectable()
export class ScholarshipsIndexService {
  private readonly logger = new Logger(ScholarshipsIndexService.name);
  private readonly scrapers: ScholarshipScraper[];

  /**
   * The automated 48h scrape is OFF by default and activated by a DEDICATED
   * flag, decoupled from the global `KPB_MVP_ONLY` lock — flipping that lock to
   * enable the refresh would also unlock other MVP-gated surfaces (MvpGuard).
   * Set `KPB_SCHOLARSHIP_REFRESH_ENABLED=true` to activate; only the vetted
   * sources (GreatYop, MastereTn) are wired. The admin "Refresh now" endpoint
   * stays available on demand regardless of this flag.
   */
  private readonly scheduledRefreshEnabled =
      process.env.KPB_SCHOLARSHIP_REFRESH_ENABLED === 'true';

  constructor(
    private readonly prismaService: PrismaService,
    greatYop: GreatYopScraper,
    mastereTn: MastereTnScraper,
    private readonly contentQuality: ScholarshipContentQualityService,
  ) {
    this.scrapers = [greatYop, mastereTn];
  }

  /** Cron tick — every 48 hours (midnight every other day). */
  @Cron('0 0 */2 * *')
  async scheduledRefresh(): Promise<void> {
    if (!this.scheduledRefreshEnabled) {
      this.logger.log(
        'Scheduled scholarship-index refresh disabled (set KPB_SCHOLARSHIP_REFRESH_ENABLED=true to activate). Admin "Refresh now" remains available on demand.',
      );
      return;
    }
    this.logger.log('Starting 48h scholarship-index refresh');
    try {
      const result = await this.refresh();
      this.logger.log(
        `Refresh complete: ${result.totalUpserted} upserted, ${result.totalDeactivated} deactivated, ${result.totalMerged} merged across ${result.sources.length} sources`,
      );
    } catch (error) {
      this.logger.error(
        `48h refresh failed: ${error instanceof Error ? error.message : 'unknown'}`,
        error instanceof Error ? error.stack : undefined,
      );
    }
  }

  /** True while a refresh runs: two runs in parallel doubled the load on the
   *  sources and raced on the same upserts/deactivations. */
  private refreshInProgress = false;

  /** Triggered from admin UI ("Refresh now" button) and by the cron. */
  async refresh(): Promise<RefreshResult> {
    if (this.refreshInProgress) {
      throw new ConflictException('A scholarship refresh is already running.');
    }
    this.refreshInProgress = true;
    try {
      return await this.runRefresh();
    } finally {
      this.refreshInProgress = false;
    }
  }

  private async runRefresh(): Promise<RefreshResult> {
    const startedAt = new Date();
    const allScraped: Array<{ prefix: string; rows: ScrapedScholarship[] }> = [];
    const sources: RefreshResult['sources'] = [];

    // ── Phase 1: Fetch from all scrapers ─────────────────────────────────────
    for (const scraper of this.scrapers) {
      const sourceResult = {
        prefix: scraper.prefix,
        name: scraper.name,
        fetched: 0,
        upserted: 0,
        deactivated: 0,
        merged: 0,
        error: null as string | null,
      };
      try {
        const rows = await scraper.fetch();
        const valid = rows.filter((r) => {
          if (!r.sourceKey.startsWith(`${scraper.prefix}-`)) {
            this.logger.warn(
              `[${scraper.prefix}] rejecting key "${r.sourceKey}" — bad prefix`,
            );
            return false;
          }
          return true;
        });
        sourceResult.fetched = valid.length;
        allScraped.push({ prefix: scraper.prefix, rows: valid });
      } catch (error) {
        sourceResult.error =
          error instanceof Error ? error.message : 'unknown error';
        this.logger.error(
          `[${scraper.prefix}] failed: ${sourceResult.error}`,
          error instanceof Error ? error.stack : undefined,
        );
        allScraped.push({ prefix: scraper.prefix, rows: [] });
      }
      sources.push(sourceResult);
    }

    // ── Phase 2: Cross-source deduplication ──────────────────────────────────
    const allRows = allScraped.flatMap((s) => s.rows);
    const { deduplicated, mergeCount } = this.deduplicateAcrossSources(allRows);

    // Update merge counts per source
    const mergesBySource = new Map<string, number>();
    for (const row of deduplicated) {
      const prefix = row.sourceKey.split('-')[0];
      mergesBySource.set(prefix, (mergesBySource.get(prefix) ?? 0));
    }
    sources.forEach((s) => {
      s.merged = mergeCount;
    });

    // ── Phase 3: Upsert all deduplicated rows ─────────────────────────────────
    for (const source of sources) {
      const rows = deduplicated.filter((r) =>
        r.sourceKey.startsWith(`${source.prefix}-`),
      );
      for (const row of rows) {
        const ok = await this.upsert(row);
        if (ok) source.upserted += 1;
      }
      // Une source en erreur ou vide n'est PAS la preuve que ses bourses ont
      // disparu : un 503 ou un challenge Cloudflare renvoie 0 ligne. Sans ce
      // garde-fou, `NOT IN []` désactivait toutes les fiches de la source.
      if (source.error || source.fetched === 0) {
        this.logger.warn(
          `[${source.prefix}] no rows fetched — skipping deactivation`,
        );
        continue;
      }
      // Les clés « vues » sont celles RÉCUPÉRÉES (avant déduplication) : une
      // fiche fusionnée dans le doublon d'une autre source est toujours en
      // ligne chez sa source, elle ne doit pas être désactivée pour autant.
      const seenKeys =
        allScraped
          .find((s) => s.prefix === source.prefix)
          ?.rows.map((r) => r.sourceKey) ?? [];
      source.deactivated = await this.deactivateMissing(source.prefix, seenKeys);
    }

    const finishedAt = new Date();
    return {
      startedAt,
      finishedAt,
      sources,
      totalFetched: sources.reduce((sum, s) => sum + s.fetched, 0),
      totalUpserted: sources.reduce((sum, s) => sum + s.upserted, 0),
      totalDeactivated: sources.reduce((sum, s) => sum + s.deactivated, 0),
      totalMerged: mergeCount,
    };
  }

  /**
   * Profile-aware list for the mobile app.
   * Filters and scores by user profile (level, fields of interest, country).
   */
  async listForProfile(params: {
    lang: 'fr' | 'en';
    userId?: string;
    level?: string;
    fieldIds?: string[];
    countryId?: string;
    fundingType?: string;
    limit?: number;
    offset?: number;
  }) {
    const lang = params.lang;
    const limit = this.boundedInt(params.limit, 20, 1, 100);
    const offset = this.boundedInt(params.offset, 0, 0, 10000);
    const validFundingTypes = [
      'fully_funded',
      'partially_funded',
      'unknown',
    ];
    if (
      params.fundingType &&
      !validFundingTypes.includes(params.fundingType)
    ) {
      throw new BadRequestException('Invalid fundingType filter.');
    }

    // Filters the student did choose (funding, country) stay hard filters.
    // `fieldIds` does NOT belong here: the mobile client derives it from the
    // saved profile, not from a control the student can see or clear.
    const baseWhere = {
      ...publicScholarshipWhere(),
      ...(params.fundingType
        ? {
            fundingType: params.fundingType as
              | 'fully_funded'
              | 'partially_funded'
              | 'unknown',
          }
        : {}),
      ...(params.countryId ? { countryId: params.countryId } : {}),
    };
    // `fieldIds` n'apparaît DÉLIBÉRÉMENT pas dans le `where`.
    //
    // Il y était, en filtre dur (`relatedFieldIds: { hasSome: fieldIds }`), et
    // l'effet mesuré en production le 21/08/2026 était celui-ci : sur les 10
    // fiches publiées, UNE SEULE portait un `relatedFieldIds` non vide
    // (`up_mastercard_scholars_2027`). Les neuf autres, créées avec un tableau
    // VIDE par tous les chemins d'écriture (seed héritée, import du catalogue
    // vérifié, upsert du collecteur), ne peuvent par construction jamais
    // satisfaire `hasSome` : elles étaient donc invisibles pour tout étudiant
    // ayant renseigné ses centres d'intérêt. L'écran affirmait « Classées selon
    // ton profil » en masquant 90 % du catalogue.
    //
    // Le repli existant ne rattrapait rien, parce qu'il ne se déclenchait qu'à
    // ZÉRO résultat : avec une fiche qui passait, il ne s'armait pas, aucun
    // bandeau n'était posé, et l'étudiant n'apprenait rien.
    //
    // Les centres d'intérêt redeviennent donc ce que le commentaire d'origine
    // annonçait déjà — « une préférence de classement, pas une raison de ne
    // rien montrer » — et ce que `level` a TOUJOURS été ici : un terme de
    // `matchScore` (+10 par domaine commun, plus bas), jamais une exclusion.
    // « Classées » redevient vrai au sens propre : rien n'est caché, tout est
    // ordonné.
    //
    // Conséquence assumée : une curation de `relatedFieldIds` améliore le
    // CLASSEMENT au lieu de décider de la visibilité. C'est le bon levier — une
    // lacune de curation ne doit plus se lire comme une panne.

    // matchScore is computed in memory, so we must score the full candidate
    // set before sorting/paginating — fetching only `limit + offset` rows (as
    // before) meant higher-scoring scholarships past that window were never
    // ranked, and `total` was wrong. Cap the set to stay bounded.
    const MAX_CANDIDATES = 500;
    const findCandidates = (criteria: Prisma.ScholarshipWhereInput) =>
      this.prismaService.execute((prisma) =>
        prisma.scholarship.findMany({
          where: criteria,
          orderBy: [{ deadlineAt: 'asc' }, { createdAt: 'desc' }],
          take: MAX_CANDIDATES,
          include: {
            applicationSteps: { orderBy: { stepNumber: 'asc' } },
            cycles: { orderBy: { academicYear: 'desc' }, take: 5 },
            videos: {
              where: { status: 'published' },
              orderBy: [{ isFeatured: 'desc' }, { displayOrder: 'asc' }],
              take: 1,
            },
          },
        }),
      );

    const where: Prisma.ScholarshipWhereInput = baseWhere;
    const items = await findCandidates(where);

    // Toujours `false` désormais : plus rien n'est retiré de la liste au nom du
    // profil, donc il n'y a plus de relâchement à annoncer.
    //
    // Le champ reste sur le fil, mais pas parce qu'un client le lirait — vérifié,
    // AUCUN ne le lit : `fetchLiveScholarships` rend une `List` et jette
    // l'enveloppe (app_api_client.dart:1150), et le bandeau de l'app est piloté
    // par un `profileFiltersRelaxed` purement local. Il reste par stabilité de
    // contrat : retirer un champ d'une réponse publique est une rupture, et sa
    // valeur est maintenant simplement toujours fausse.
    const fieldFilterRelaxed = false;

    if (!items) {
      // Reached only when no DATABASE_URL is configured (PrismaService.execute
      // returns null). Flagged so an unconfigured deployment is not reported to
      // the client as a legitimately empty catalog.
      this.logger.warn(
        'listForProfile served an empty list: no database is configured.',
      );
      return {
        items: [],
        total: 0,
        limit,
        offset,
        hasMore: false,
        fieldFilterRelaxed: false,
        databaseUnavailable: true,
      };
    }
    if (items.length === MAX_CANDIDATES) {
      this.logger.warn(
        `listForProfile hit the ${MAX_CANDIDATES}-candidate cap; ` +
          'matchScore ranking may be incomplete for very large result sets.',
      );
    }

    const subscriptions = params.userId
      ? await this.prismaService.execute((prisma) =>
          prisma.scholarshipAlertSubscription.findMany({
            where: {
              userId: params.userId,
              scholarshipId: { in: items.map((item) => item.id) },
            },
            select: { scholarshipId: true },
          }),
        )
      : [];
    const subscribedIds = new Set(
      (subscriptions ?? []).map((row) => row.scholarshipId),
    );

    const mapped = items.map((s) => {
      // Profile-match score
      let matchScore = s.baseMatch;
      if (params.level) {
        const levelField = lang === 'fr' ? s.levelEligibleFr : s.levelEligibleEn;
        if (levelField.toLowerCase().includes(params.level.toLowerCase())) {
          matchScore += 30;
        }
      }
      if (params.fieldIds?.length) {
        const fieldOverlap = params.fieldIds.filter((f) =>
          s.relatedFieldIds.includes(f),
        ).length;
        matchScore += fieldOverlap * 10;
      }

      return {
        ...this.publicDto(s, lang),
        matchScore,
        isAlertEnabled: subscribedIds.has(s.id),
        featuredVideo: s.videos?.[0]
          ? this.publicVideoDto(s.videos[0], lang)
          : null,
      };
    });

    // Sort by matchScore desc, then by deadline asc
    mapped.sort((a, b) => {
      if (b.matchScore !== a.matchScore) return b.matchScore - a.matchScore;
      if (a.deadlineAt && b.deadlineAt) {
        return new Date(a.deadlineAt).getTime() - new Date(b.deadlineAt).getTime();
      }
      return 0;
    });

    // Real total of matching scholarships, independent of the candidate cap.
    const total =
      (await this.prismaService.execute((prisma) =>
        prisma.scholarship.count({ where }),
      )) ?? mapped.length;

    const page = mapped.slice(offset, offset + limit);
    return {
      items: page,
      total,
      limit,
      offset,
      hasMore: offset + page.length < total,
      // True when the student's profile fields matched nothing and the listing
      // fell back to the unfiltered catalog. The client must disclose it rather
      // than presenting the result as a profile-matched list.
      fieldFilterRelaxed,
      databaseUnavailable: false,
    };
  }

  async getForProfile(
    id: string,
    params: { lang: 'fr' | 'en'; userId: string },
  ) {
    const scholarship = await this.prismaService.execute((prisma) =>
      prisma.scholarship.findFirst({
        // Même clause que les listes : sinon un lien profond, une alerte ou un
        // favori continue d'ouvrir la fiche d'une campagne close, qui affiche
        // son `deadlineLabel` figé « Ouvert — clôture le … ».
        where: { id, ...publicScholarshipWhere() },
        include: {
          applicationSteps: { orderBy: { stepNumber: 'asc' } },
          cycles: { orderBy: { academicYear: 'desc' } },
          videos: {
            where: { status: 'published' },
            orderBy: [{ isFeatured: 'desc' }, { displayOrder: 'asc' }],
          },
        },
      }),
    );
    if (!scholarship) {
      throw new NotFoundException(`Scholarship ${id} not found.`);
    }
    const subscription = await this.prismaService.execute((prisma) =>
      prisma.scholarshipAlertSubscription.findUnique({
        where: {
          userId_scholarshipId: {
            userId: params.userId,
            scholarshipId: id,
          },
        },
        select: { pushEnabled: true, inAppEnabled: true },
      }),
    );
    return {
      ...this.publicDto(scholarship, params.lang),
      cycles: scholarship.cycles.map((cycle) => this.publicCycleDto(cycle)),
      videos: scholarship.videos.map((video) =>
        this.publicVideoDto(video, params.lang),
      ),
      alert: {
        subscribed: Boolean(subscription),
        pushEnabled: subscription?.pushEnabled ?? false,
        inAppEnabled: subscription?.inAppEnabled ?? false,
      },
    };
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /**
   * Detect scholarships appearing in multiple sources by normalizing their
   * English titles (strip year, punctuation, lowercase). When a match is
   * found, merge into the record with the highest `contentScore`, filling
   * missing fields from the lower-score record.
   */
  private deduplicateAcrossSources(rows: ScrapedScholarship[]): {
    deduplicated: ScrapedScholarship[];
    mergeCount: number;
  } {
    const normalized = (title: string) =>
      title
        .toLowerCase()
        .replace(/\d{4}[-/]\d{4}|\d{4}/g, '')
        .replace(/[^a-z\s]/g, '')
        .replace(/\s+/g, ' ')
        .trim();

    const groups = new Map<string, ScrapedScholarship[]>();
    for (const row of rows) {
      const key = normalized(row.nameEn || row.nameFr);
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key)!.push(row);
    }

    const deduplicated: ScrapedScholarship[] = [];
    let mergeCount = 0;

    for (const [, group] of groups) {
      if (group.length === 1) {
        deduplicated.push(group[0]);
        continue;
      }
      // Sort by contentScore desc — winner is the best record
      group.sort((a, b) => (b.contentScore ?? 0) - (a.contentScore ?? 0));
      const winner = { ...group[0] };
      mergeCount += group.length - 1;

      // Fill empty fields from secondary records
      for (const other of group.slice(1)) {
        if (!winner.descriptionFr && other.descriptionFr) winner.descriptionFr = other.descriptionFr;
        if (!winner.descriptionEn && other.descriptionEn) winner.descriptionEn = other.descriptionEn;
        if (!winner.advantagesFr.length && other.advantagesFr.length) winner.advantagesFr = other.advantagesFr;
        if (!winner.advantagesEn.length && other.advantagesEn.length) winner.advantagesEn = other.advantagesEn;
        if (!winner.eligibilityFr.length && other.eligibilityFr.length) winner.eligibilityFr = other.eligibilityFr;
        if (!winner.eligibilityEn.length && other.eligibilityEn.length) winner.eligibilityEn = other.eligibilityEn;
        if (!winner.deadlineAt && other.deadlineAt) winner.deadlineAt = other.deadlineAt;
        if (winner.fundingType === 'unknown' && other.fundingType !== 'unknown') winner.fundingType = other.fundingType;
        // Merge tags
        winner.tags = [...new Set([...winner.tags, ...other.tags])];
      }

      deduplicated.push(winner);
    }

    return { deduplicated, mergeCount };
  }

  /// Admin moderation: approve / reject / reset a scholarship's visibility.
  /// moderationStatus is intentionally NOT touched by the refresh upsert, so an
  /// admin decision survives subsequent scraper runs.
  /**
   * Contrepartie obligatoire de `lastVerifiedAt: { not: null }` dans la clause
   * publique : approuver EST un acte de vérification humaine, donc l'approbation
   * horodate. Sans cela, la seule interface d'ajout de bourse de l'équipe
   * produirait des fiches approuvées mais impubliables — et le filtre censé
   * protéger l'étudiant casserait l'outil de travail.
   *
   * Le rejet et la remise en attente n'effacent PAS la date : la fiche a bien été
   * relue, et l'effacer ferait perdre la trace de qui l'a regardée.
   */
  async setModeration(
    id: string,
    status: 'approved' | 'rejected' | 'pending',
    verifier?: AdminSessionUser,
  ) {
    if (status === 'approved') {
      await this.contentQuality.assertReady(id);
    }
    return this.prismaService.execute((prisma) =>
      prisma.scholarship.update({
        where: { id },
        data: {
          moderationStatus: status,
          ...(status === 'approved'
            ? {
                lastVerifiedAt: new Date(),
                verifiedById: verifier?.id ?? 'admin-moderation',
                verifiedByName:
                  verifier?.fullName ??
                  verifier?.email ??
                  'Admin moderation queue',
              }
            : {}),
        },
      }),
    );
  }

  private boundedInt(
    value: number | undefined,
    fallback: number,
    min: number,
    max: number,
  ): number {
    if (!Number.isFinite(value)) return fallback;
    return Math.min(Math.max(Math.trunc(value as number), min), max);
  }

  private publicDto(row: ScholarshipReadRow, lang: 'fr' | 'en') {
    const currentCycle = this.selectCurrentCycle(row.cycles ?? []);
    return {
      id: row.id,
      title: lang === 'fr' ? row.nameFr : row.nameEn,
      countryId: row.countryId,
      countryName: lang === 'fr' ? row.countryNameFr : row.countryNameEn,
      fundingType: row.fundingType,
      typeOfFunding:
        lang === 'fr' ? row.typeOfFundingFr : row.typeOfFundingEn,
      applicationRequirement: row.applicationRequirement,
      description: lang === 'fr' ? row.descriptionFr : row.descriptionEn,
      advantages: lang === 'fr' ? row.advantagesFr : row.advantagesEn,
      eligibility: lang === 'fr' ? row.eligibilityFr : row.eligibilityEn,
      keyRequirements:
        lang === 'fr' ? row.keyRequirementsFr : row.keyRequirementsEn,
      relatedFieldIds: row.relatedFieldIds,
      level: lang === 'fr' ? row.levelEligibleFr : row.levelEligibleEn,
      deadlineLabel:
        lang === 'fr' ? row.deadlineLabelFr : row.deadlineLabelEn,
      deadlineAt: row.deadlineAt?.toISOString() ?? null,
      applicationUrl: row.applicationUrl,
      sourceUrl: row.sourceUrl,
      lastVerifiedAt: row.lastVerifiedAt?.toISOString() ?? null,
      tags: row.tags,
      currentCycle: currentCycle
        ? this.publicCycleDto(currentCycle)
        : null,
      applicationSteps: row.applicationSteps.map((step) => ({
        id: step.id,
        stepNumber: step.stepNumber,
        title: lang === 'fr' ? step.titleFr : step.titleEn,
        description:
          lang === 'fr' ? step.descriptionFr : step.descriptionEn,
        estimatedDurationDays: step.estimatedDurationDays,
      })),
    };
  }

  private selectCurrentCycle(cycles: ScholarshipReadRow['cycles']) {
    return (
      cycles.find((cycle) => cycle.status === 'open') ??
      cycles.find((cycle) => cycle.status === 'forecast') ??
      cycles[0]
    );
  }

  private publicCycleDto(cycle: ScholarshipReadRow['cycles'][number]) {
    return {
      id: cycle.id,
      academicYear: cycle.academicYear,
      status: servedCycleStatus(
        cycle.status,
        cycle.closesAt,
        cycle.estimatedCloseAt,
      ),
      dateConfidence: cycle.dateConfidence,
      estimatedOpenAt: cycle.estimatedOpenAt?.toISOString() ?? null,
      estimatedCloseAt: cycle.estimatedCloseAt?.toISOString() ?? null,
      opensAt: cycle.opensAt?.toISOString() ?? null,
      closesAt: cycle.closesAt?.toISOString() ?? null,
      sourceUrl: cycle.sourceUrl,
      verifiedAt: cycle.verifiedAt?.toISOString() ?? null,
    };
  }

  private publicVideoDto(
    video: ScholarshipReadRow['videos'][number],
    lang: 'fr' | 'en',
  ) {
    return {
      id: video.id,
      youtubeVideoId: video.youtubeVideoId,
      title: lang === 'fr' ? video.titleFr : video.titleEn,
      description:
        lang === 'fr' ? video.descriptionFr : video.descriptionEn,
      thumbnailUrl: video.thumbnailUrl,
      durationSeconds: video.durationSeconds,
      languageCode: video.languageCode,
      isFeatured: video.isFeatured,
      displayOrder: video.displayOrder,
      watchUrl: `https://www.youtube.com/watch?v=${video.youtubeVideoId}`,
      shareUrl: `https://youtu.be/${video.youtubeVideoId}`,
    };
  }

  /// Admin moderation queue — scraped entries awaiting review (default pending).
  async listForModeration(
    status: 'approved' | 'rejected' | 'pending' = 'pending',
  ) {
    const rows = await this.prismaService.execute((prisma) =>
      prisma.scholarship.findMany({
        where: { moderationStatus: status },
        orderBy: { lastVerifiedAt: 'desc' },
        take: 200,
        include: {
          applicationSteps: { orderBy: { stepNumber: 'asc' } },
          cycles: { orderBy: { updatedAt: 'desc' }, take: 1 },
          videos: {
            orderBy: [{ isFeatured: 'desc' }, { displayOrder: 'asc' }],
          },
        },
      }),
    );
    return {
      items: (rows ?? []).map((r) => ({
        id: r.id,
        nameFr: r.nameFr,
        nameEn: r.nameEn,
        countryId: r.countryId,
        countryNameFr: r.countryNameFr,
        countryNameEn: r.countryNameEn,
        levelEligibleFr: r.levelEligibleFr,
        levelEligibleEn: r.levelEligibleEn,
        typeOfFundingFr: r.typeOfFundingFr,
        typeOfFundingEn: r.typeOfFundingEn,
        fundingType: r.fundingType,
        deadlineLabelFr: r.deadlineLabelFr,
        deadlineLabelEn: r.deadlineLabelEn,
        descriptionFr: r.descriptionFr,
        descriptionEn: r.descriptionEn,
        advantagesFr: r.advantagesFr,
        advantagesEn: r.advantagesEn,
        eligibilityFr: r.eligibilityFr,
        eligibilityEn: r.eligibilityEn,
        keyRequirementsFr: r.keyRequirementsFr,
        keyRequirementsEn: r.keyRequirementsEn,
        relatedFieldIds: r.relatedFieldIds,
        baseMatch: r.baseMatch,
        sourceUrl: r.sourceUrl,
        applicationUrl: r.applicationUrl,
        deadlineAt: r.deadlineAt,
        moderationStatus: r.moderationStatus,
        lastVerifiedAt: r.lastVerifiedAt,
        isActive: r.isActive,
        tags: r.tags,
        videos: (r.videos ?? []).map((video) => ({
          ...video,
          watchUrl: `https://www.youtube.com/watch?v=${video.youtubeVideoId}`,
          shareUrl: `https://youtu.be/${video.youtubeVideoId}`,
        })),
        currentCycle: r.cycles?.[0]
          ? {
              id: r.cycles[0].id,
              academicYear: r.cycles[0].academicYear,
              status: r.cycles[0].status,
              dateConfidence: r.cycles[0].dateConfidence,
              estimatedOpenAt: r.cycles[0].estimatedOpenAt,
              estimatedCloseAt: r.cycles[0].estimatedCloseAt,
              opensAt: r.cycles[0].opensAt,
              closesAt: r.cycles[0].closesAt,
            }
          : null,
        // Admin-editable enrichment (KPB scholarships module) — bilingual, not
        // localized here, so the moderation UI can edit both languages.
        applicationRequirement: r.applicationRequirement,
        applicationSteps: r.applicationSteps.map((step) => ({
          id: step.id,
          stepNumber: step.stepNumber,
          titleFr: step.titleFr,
          titleEn: step.titleEn,
          descriptionFr: step.descriptionFr,
          descriptionEn: step.descriptionEn,
          estimatedDurationDays: step.estimatedDurationDays,
        })),
      })),
    };
  }

  private async upsert(row: ScrapedScholarship): Promise<boolean> {
    const now = new Date();
    const existing = await this.prismaService.execute((prisma) =>
      prisma.scholarship.findUnique({
        where: { sourceKey: row.sourceKey },
        select: { moderationStatus: true },
      }),
    );
    // Une fiche approuvée appartient à l'équipe : le robot ne réécrit ni la
    // date (même par `null`), ni le contenu, ni `isActive` (une fiche
    // désactivée par un admin le reste), ni `lastVerifiedAt` (qui doit
    // continuer de dire « vérifiée par un humain »).
    if (existing?.moderationStatus === 'approved') {
      return true;
    }
    const isRejected = existing?.moderationStatus === 'rejected';
    const result = await this.prismaService.execute((prisma) =>
      prisma.scholarship.upsert({
        where: { sourceKey: row.sourceKey },
        create: {
          sourceKey: row.sourceKey,
          sourceUrl: row.sourceUrl,
          applicationUrl: row.applicationUrl,
          deadlineAt: row.deadlineAt,
          lastVerifiedAt: now,
          isActive: true,
          // Scraped entries are unpublished until an admin approves them.
          moderationStatus: 'pending',
          tags: row.tags,
          nameFr: row.nameFr,
          nameEn: row.nameEn,
          countryId: row.countryId,
          countryNameFr: row.countryNameFr,
          countryNameEn: row.countryNameEn,
          descriptionFr: row.descriptionFr,
          descriptionEn: row.descriptionEn,
          advantagesFr: row.advantagesFr,
          advantagesEn: row.advantagesEn,
          eligibilityFr: row.eligibilityFr,
          eligibilityEn: row.eligibilityEn,
          fundingType: row.fundingType,
          levelEligibleFr: row.levelEligibleFr,
          levelEligibleEn: row.levelEligibleEn,
          deadlineLabelFr: row.deadlineLabelFr,
          deadlineLabelEn: row.deadlineLabelEn,
          // Admin-curated fields (initialized empty)
          typeOfFundingFr: '',
          typeOfFundingEn: '',
          keyRequirementsFr: [],
          keyRequirementsEn: [],
          relatedFieldIds: [],
        },
        update: {
          // Refresh scraped fields. Admin-curated fields are NOT touched.
          sourceUrl: row.sourceUrl,
          applicationUrl: row.applicationUrl,
          deadlineAt: row.deadlineAt,
          lastVerifiedAt: now,
          // Une fiche rejetée par la modération n'est pas réactivée.
          ...(isRejected ? {} : { isActive: true }),
          tags: row.tags,
          // Update content fields if they now have better data
          ...(row.descriptionFr ? { descriptionFr: row.descriptionFr } : {}),
          ...(row.descriptionEn ? { descriptionEn: row.descriptionEn } : {}),
          ...(row.advantagesFr.length ? { advantagesFr: row.advantagesFr } : {}),
          ...(row.advantagesEn.length ? { advantagesEn: row.advantagesEn } : {}),
          ...(row.eligibilityFr.length ? { eligibilityFr: row.eligibilityFr } : {}),
          ...(row.eligibilityEn.length ? { eligibilityEn: row.eligibilityEn } : {}),
          ...(row.fundingType !== 'unknown' ? { fundingType: row.fundingType } : {}),
        },
      }),
    );
    return !!result;
  }

  private async deactivateMissing(prefix: string, seenKeys: string[]): Promise<number> {
    const result = await this.prismaService.execute((prisma) =>
      prisma.scholarship.updateMany({
        where: {
          sourceKey: { startsWith: `${prefix}-` },
          NOT: { sourceKey: { in: seenKeys } },
          isActive: true,
          // Les fiches approuvées ne sont jamais retirées par le robot : c'est
          // à l'équipe de constater une fermeture.
          moderationStatus: { not: 'approved' },
        },
        data: { isActive: false },
      }),
    );
    return result?.count ?? 0;
  }
}
