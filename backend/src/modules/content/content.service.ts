import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { PrismaClient } from '@prisma/client';

import { PublicationStatus } from '../../common/enums/publication-status.enum';
import { mockAdminData } from '../../common/data/mock-admin';
import { PrismaService } from '../prisma/prisma.service';
// Same degraded-mode policy as the catalog incident fix (never fixtures in
// production, explicit 503 instead, opt-out flag outside production). The
// rules live in `common/degraded-mode.ts`; only the domain error code below is
// content-specific, so `/content/*` never has to re-derive the policy.
import {
  CATALOG_SOURCE_DATABASE,
  CATALOG_SOURCE_MOCK,
  degradedServiceUnavailable,
  isMockCatalogFallbackAllowed,
  type CatalogSource,
} from '../../common/degraded-mode';

type ServiceOfferRecord = (typeof mockAdminData.serviceOffers)[number];
type SupportDestinationRecord = (typeof mockAdminData.supportDestinations)[number];
type ArticleRecord = (typeof mockAdminData.articles)[number];

/**
 * Every `/content/*` (and `/admin/*` content) list response carries the
 * provenance of its rows, mirroring the `/catalog/*` envelope. `mock` means
 * the bundled `mock-admin.ts` fixtures — which include commercial PRICES
 * (`priceLabel`) — and is only ever possible outside production.
 */
export type ContentListResponse<T> = {
  items: T[];
  source: CatalogSource;
};

/** Prisma "record not found" (e.g. update on an unknown id). */
/**
 * 503 served instead of `mock-admin.ts` fixtures. Distinct from the catalog's
 * `CATALOG_UNAVAILABLE` so the app can tell "no programs/scholarships" from
 * "no service offers / destinations / articles", and so a reader of the logs
 * knows which surface went dark.
 */
function contentUnavailable(resource: string) {
  return degradedServiceUnavailable(
    'CONTENT_UNAVAILABLE',
    'Editorial content is temporarily unavailable.',
    resource,
  );
}

function isPrismaRecordNotFound(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === 'P2025'
  );
}

@Injectable()
export class ContentService {
  private readonly logger = new Logger(ContentService.name);

  constructor(private readonly prismaService: PrismaService) {}

  // In-memory stores backing the non-production degraded mode only. They start
  // as copies of the demo fixtures so the Flutter app and admin panel stay
  // usable without a local Postgres. Production never reads them: degrade()
  // throws 503 before any of these arrays is touched.
  private readonly serviceOffers = [...mockAdminData.serviceOffers];
  private readonly supportDestinations = [...mockAdminData.supportDestinations];
  private readonly articles = [...mockAdminData.articles];

  async listServiceOffers(
    opts: { publicOnly?: boolean } = {},
  ): Promise<ContentListResponse<unknown>> {
    const items = await this.execOrDegrade('service-offers', (prisma) =>
      prisma.serviceOffer.findMany({
        // Route publique : jamais de brouillon, d'archive ni d'élément masqué
        // (l'app filtrait côté client, mais l'API les servait quand même).
        ...(opts.publicOnly
          ? { where: { status: 'published' } }
          : {}),
        orderBy: { createdAt: 'desc' },
      }),
    );

    if (items === null) return this.mockList(this.serviceOffers);

    return {
      items: items.map((item) => ({
        id: item.id,
        name: { fr: item.nameFr, en: item.nameEn },
        offerType: item.offerType,
        destinationIds: item.destinationIds,
        studyLevels: item.studyLevels,
        priceLabel: { fr: item.priceLabelFr, en: item.priceLabelEn },
        benefits: { fr: item.benefitsFr, en: item.benefitsEn },
        ctaLabel: { fr: item.ctaLabelFr, en: item.ctaLabelEn },
        status: item.status,
      })),
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async createServiceOffer(input: Record<string, unknown>) {
    const record: ServiceOfferRecord = {
      id: `offer-${Date.now()}`,
      name:
        (input['name'] as ServiceOfferRecord['name'] | undefined) ??
        { fr: 'Nouvelle offre', en: 'New offer' },
      offerType: (input['offerType'] as string | undefined) ?? 'consultation',
      destinationIds:
        (input['destinationIds'] as string[] | undefined) ?? [],
      studyLevels: (input['studyLevels'] as string[] | undefined) ?? [],
      priceLabel:
        (input['priceLabel'] as ServiceOfferRecord['priceLabel'] | undefined) ??
        { fr: 'Sur devis', en: 'Quoted on request' },
      benefits:
        (input['benefits'] as ServiceOfferRecord['benefits'] | undefined) ??
        { fr: [], en: [] },
      ctaLabel:
        (input['ctaLabel'] as ServiceOfferRecord['ctaLabel'] | undefined) ??
        { fr: 'En savoir plus', en: 'Learn more' },
      status:
        (input['status'] as PublicationStatus | undefined) ??
        PublicationStatus.Draft,
    };

    const created = await this.execOrDegrade('service-offers', (prisma) =>
      prisma.serviceOffer.create({
        data: {
          nameFr: record.name.fr,
          nameEn: record.name.en,
          offerType: record.offerType,
          destinationIds: record.destinationIds,
          studyLevels: record.studyLevels,
          priceLabelFr: record.priceLabel.fr,
          priceLabelEn: record.priceLabel.en,
          benefitsFr: record.benefits.fr,
          benefitsEn: record.benefits.en,
          ctaLabelFr: record.ctaLabel.fr,
          ctaLabelEn: record.ctaLabel.en,
          status: record.status,
        },
      }),
    );

    if (created === null) {
      this.serviceOffers.unshift(record);
      return { ...record, source: CATALOG_SOURCE_MOCK };
    }

    return {
      id: created.id,
      name: { fr: created.nameFr, en: created.nameEn },
      offerType: created.offerType,
      destinationIds: created.destinationIds,
      studyLevels: created.studyLevels,
      priceLabel: { fr: created.priceLabelFr, en: created.priceLabelEn },
      benefits: { fr: created.benefitsFr, en: created.benefitsEn },
      ctaLabel: { fr: created.ctaLabelFr, en: created.ctaLabelEn },
      status: created.status,
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async updateServiceOffer(id: string, input: Record<string, unknown>) {
    const updated = await this.execOrDegrade(
      'service-offers',
      (prisma) =>
        prisma.serviceOffer.update({
          where: { id },
          data: {
            ...(input['name']
              ? {
                  nameFr: (input['name'] as ServiceOfferRecord['name']).fr,
                  nameEn: (input['name'] as ServiceOfferRecord['name']).en,
                }
              : {}),
            ...(input['offerType']
              ? { offerType: input['offerType'] as string }
              : {}),
            ...(input['destinationIds']
              ? { destinationIds: input['destinationIds'] as string[] }
              : {}),
            ...(input['studyLevels']
              ? { studyLevels: input['studyLevels'] as string[] }
              : {}),
            ...(input['priceLabel']
              ? {
                  priceLabelFr: (input['priceLabel'] as ServiceOfferRecord['priceLabel']).fr,
                  priceLabelEn: (input['priceLabel'] as ServiceOfferRecord['priceLabel']).en,
                }
              : {}),
            ...(input['benefits']
              ? {
                  benefitsFr: (input['benefits'] as ServiceOfferRecord['benefits']).fr,
                  benefitsEn: (input['benefits'] as ServiceOfferRecord['benefits']).en,
                }
              : {}),
            ...(input['ctaLabel']
              ? {
                  ctaLabelFr: (input['ctaLabel'] as ServiceOfferRecord['ctaLabel']).fr,
                  ctaLabelEn: (input['ctaLabel'] as ServiceOfferRecord['ctaLabel']).en,
                }
              : {}),
            ...(input['status']
              ? { status: input['status'] as PublicationStatus }
              : {}),
          },
        }),
      { notFoundMessage: `Service offer ${id} not found.` },
    );

    if (updated === null) {
      const index = this.serviceOffers.findIndex((item) => item.id === id);
      if (index < 0) {
        throw new NotFoundException(`Service offer ${id} not found.`);
      }
      this.serviceOffers[index] = {
        ...this.serviceOffers[index],
        ...input,
      } as ServiceOfferRecord;
      return { ...this.serviceOffers[index], source: CATALOG_SOURCE_MOCK };
    }

    return {
      id: updated.id,
      name: { fr: updated.nameFr, en: updated.nameEn },
      offerType: updated.offerType,
      destinationIds: updated.destinationIds,
      studyLevels: updated.studyLevels,
      priceLabel: { fr: updated.priceLabelFr, en: updated.priceLabelEn },
      benefits: { fr: updated.benefitsFr, en: updated.benefitsEn },
      ctaLabel: { fr: updated.ctaLabelFr, en: updated.ctaLabelEn },
      status: updated.status,
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async listSupportDestinations(
    opts: { publicOnly?: boolean } = {},
  ): Promise<ContentListResponse<unknown>> {
    const items = await this.execOrDegrade('support-destinations', (prisma) =>
      prisma.supportDestination.findMany({
        // Route publique : jamais de brouillon, d'archive ni d'élément masqué
        // (l'app filtrait côté client, mais l'API les servait quand même).
        ...(opts.publicOnly
          ? { where: { status: 'published', isVisible: true } }
          : {}),
        orderBy: { createdAt: 'desc' },
      }),
    );

    if (items === null) return this.mockList(this.supportDestinations);

    return {
      items: items.map((item) => ({
        id: item.id,
        countryId: item.countryId,
        countryName: { fr: item.countryNameFr, en: item.countryNameEn },
        supportLanguages: item.supportLanguages,
        availableServiceTypes: item.availableServiceTypes,
        conditions: { fr: item.conditionsFr, en: item.conditionsEn },
        counselorNames: item.counselorNames,
        isVisible: item.isVisible,
        status: item.status,
      })),
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async createSupportDestination(input: Record<string, unknown>) {
    const record: SupportDestinationRecord = {
      id: `support-${Date.now()}`,
      countryId: (input['countryId'] as string | undefined) ?? 'new-country',
      countryName:
        (input['countryName'] as SupportDestinationRecord['countryName'] | undefined) ??
        { fr: 'Nouveau pays', en: 'New country' },
      supportLanguages:
        (input['supportLanguages'] as string[] | undefined) ?? ['fr'],
      availableServiceTypes:
        (input['availableServiceTypes'] as string[] | undefined) ??
        ['consultation'],
      conditions:
        (input['conditions'] as SupportDestinationRecord['conditions'] | undefined) ??
        { fr: [], en: [] },
      counselorNames:
        (input['counselorNames'] as string[] | undefined) ?? [],
      isVisible: (input['isVisible'] as boolean | undefined) ?? true,
      status:
        (input['status'] as PublicationStatus | undefined) ??
        PublicationStatus.Draft,
    };

    const created = await this.execOrDegrade('support-destinations', (prisma) =>
      prisma.supportDestination.create({
        data: {
          countryId: record.countryId,
          countryNameFr: record.countryName.fr,
          countryNameEn: record.countryName.en,
          supportLanguages: record.supportLanguages,
          availableServiceTypes: record.availableServiceTypes,
          conditionsFr: record.conditions.fr,
          conditionsEn: record.conditions.en,
          counselorNames: record.counselorNames,
          isVisible: record.isVisible,
          status: record.status,
        },
      }),
    );

    if (created === null) {
      this.supportDestinations.unshift(record);
      return { ...record, source: CATALOG_SOURCE_MOCK };
    }

    return {
      id: created.id,
      countryId: created.countryId,
      countryName: { fr: created.countryNameFr, en: created.countryNameEn },
      supportLanguages: created.supportLanguages,
      availableServiceTypes: created.availableServiceTypes,
      conditions: { fr: created.conditionsFr, en: created.conditionsEn },
      counselorNames: created.counselorNames,
      isVisible: created.isVisible,
      status: created.status,
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async updateSupportDestination(id: string, input: Record<string, unknown>) {
    const updated = await this.execOrDegrade(
      'support-destinations',
      (prisma) =>
        prisma.supportDestination.update({
          where: { id },
          data: {
            ...(input['countryId']
              ? { countryId: input['countryId'] as string }
              : {}),
            ...(input['countryName']
              ? {
                  countryNameFr:
                    (input['countryName'] as SupportDestinationRecord['countryName']).fr,
                  countryNameEn:
                    (input['countryName'] as SupportDestinationRecord['countryName']).en,
                }
              : {}),
            ...(input['supportLanguages']
              ? { supportLanguages: input['supportLanguages'] as string[] }
              : {}),
            ...(input['availableServiceTypes']
              ? {
                  availableServiceTypes:
                    input['availableServiceTypes'] as string[],
                }
              : {}),
            ...(input['conditions']
              ? {
                  conditionsFr:
                    (input['conditions'] as SupportDestinationRecord['conditions']).fr,
                  conditionsEn:
                    (input['conditions'] as SupportDestinationRecord['conditions']).en,
                }
              : {}),
            ...(input['counselorNames']
              ? { counselorNames: input['counselorNames'] as string[] }
              : {}),
            ...(input['isVisible'] !== undefined
              ? { isVisible: input['isVisible'] as boolean }
              : {}),
            ...(input['status']
              ? { status: input['status'] as PublicationStatus }
              : {}),
          },
        }),
      { notFoundMessage: `Support destination ${id} not found.` },
    );

    if (updated === null) {
      const index = this.supportDestinations.findIndex((item) => item.id === id);
      if (index < 0) {
        throw new NotFoundException(`Support destination ${id} not found.`);
      }
      this.supportDestinations[index] = {
        ...this.supportDestinations[index],
        ...input,
      } as SupportDestinationRecord;
      return { ...this.supportDestinations[index], source: CATALOG_SOURCE_MOCK };
    }

    return {
      id: updated.id,
      countryId: updated.countryId,
      countryName: { fr: updated.countryNameFr, en: updated.countryNameEn },
      supportLanguages: updated.supportLanguages,
      availableServiceTypes: updated.availableServiceTypes,
      conditions: { fr: updated.conditionsFr, en: updated.conditionsEn },
      counselorNames: updated.counselorNames,
      isVisible: updated.isVisible,
      status: updated.status,
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async listArticles(
    opts: { publicOnly?: boolean } = {},
  ): Promise<ContentListResponse<unknown>> {
    const items = await this.execOrDegrade('articles', (prisma) =>
      prisma.article.findMany({
        // Route publique : jamais de brouillon, d'archive ni d'élément masqué
        // (l'app filtrait côté client, mais l'API les servait quand même).
        ...(opts.publicOnly
          ? { where: { status: 'published' } }
          : {}),
        orderBy: { createdAt: 'desc' },
      }),
    );

    if (items === null) return this.mockList(this.articles);

    return {
      items: items.map((item) => ({
        id: item.id,
        slug: item.slug,
        category: item.category,
        title: { fr: item.titleFr, en: item.titleEn },
        summary: { fr: item.summaryFr, en: item.summaryEn },
        content: { fr: item.contentFr, en: item.contentEn },
        tags: item.tags,
        authorName: item.authorName,
        status: item.status,
        publishedAt: item.publishedAt?.toISOString() ?? null,
      })),
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async createArticle(input: Record<string, unknown>) {
    const record: ArticleRecord = {
      id: `article-${Date.now()}`,
      slug: (input['slug'] as string | undefined) ?? `article-${Date.now()}`,
      category: (input['category'] as string | undefined) ?? 'guides',
      title:
        (input['title'] as ArticleRecord['title'] | undefined) ??
        { fr: 'Nouvel article', en: 'New article' },
      summary:
        (input['summary'] as ArticleRecord['summary'] | undefined) ??
        { fr: '', en: '' },
      content:
        (input['content'] as ArticleRecord['content'] | undefined) ??
        { fr: '', en: '' },
      tags: (input['tags'] as string[] | undefined) ?? [],
      authorName: (input['authorName'] as string | undefined) ?? 'KPB Editorial',
      status:
        (input['status'] as PublicationStatus | undefined) ??
        PublicationStatus.Draft,
      publishedAt: (input['publishedAt'] as string | null | undefined) ?? null,
    };

    const created = await this.execOrDegrade('articles', (prisma) =>
      prisma.article.create({
        data: {
          slug: record.slug,
          category: record.category,
          titleFr: record.title.fr,
          titleEn: record.title.en,
          summaryFr: record.summary.fr,
          summaryEn: record.summary.en,
          contentFr: record.content.fr,
          contentEn: record.content.en,
          tags: record.tags,
          authorName: record.authorName,
          status: record.status,
          publishedAt: record.publishedAt ? new Date(record.publishedAt) : null,
        },
      }),
    );

    if (created === null) {
      this.articles.unshift(record);
      return { ...record, source: CATALOG_SOURCE_MOCK };
    }

    return {
      id: created.id,
      slug: created.slug,
      category: created.category,
      title: { fr: created.titleFr, en: created.titleEn },
      summary: { fr: created.summaryFr, en: created.summaryEn },
      content: { fr: created.contentFr, en: created.contentEn },
      tags: created.tags,
      authorName: created.authorName,
      status: created.status,
      publishedAt: created.publishedAt?.toISOString() ?? null,
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async updateArticle(id: string, input: Record<string, unknown>) {
    const updated = await this.execOrDegrade(
      'articles',
      (prisma) =>
        prisma.article.update({
          where: { id },
          data: {
            ...(input['slug'] ? { slug: input['slug'] as string } : {}),
            ...(input['category']
              ? { category: input['category'] as string }
              : {}),
            ...(input['title']
              ? {
                  titleFr: (input['title'] as ArticleRecord['title']).fr,
                  titleEn: (input['title'] as ArticleRecord['title']).en,
                }
              : {}),
            ...(input['summary']
              ? {
                  summaryFr: (input['summary'] as ArticleRecord['summary']).fr,
                  summaryEn: (input['summary'] as ArticleRecord['summary']).en,
                }
              : {}),
            ...(input['content']
              ? {
                  contentFr: (input['content'] as ArticleRecord['content']).fr,
                  contentEn: (input['content'] as ArticleRecord['content']).en,
                }
              : {}),
            ...(input['tags'] ? { tags: input['tags'] as string[] } : {}),
            ...(input['authorName']
              ? { authorName: input['authorName'] as string }
              : {}),
            ...(input['status']
              ? { status: input['status'] as PublicationStatus }
              : {}),
            ...(input['publishedAt'] !== undefined
              ? {
                  publishedAt: input['publishedAt']
                    ? new Date(input['publishedAt'] as string)
                    : null,
                }
              : {}),
          },
        }),
      { notFoundMessage: `Article ${id} not found.` },
    );

    if (updated === null) {
      const index = this.articles.findIndex((item) => item.id === id);
      if (index < 0) {
        throw new NotFoundException(`Article ${id} not found.`);
      }
      this.articles[index] = {
        ...this.articles[index],
        ...input,
      } as ArticleRecord;
      return { ...this.articles[index], source: CATALOG_SOURCE_MOCK };
    }

    return {
      id: updated.id,
      slug: updated.slug,
      category: updated.category,
      title: { fr: updated.titleFr, en: updated.titleEn },
      summary: { fr: updated.summaryFr, en: updated.summaryEn },
      content: { fr: updated.contentFr, en: updated.contentEn },
      tags: updated.tags,
      authorName: updated.authorName,
      status: updated.status,
      publishedAt: updated.publishedAt?.toISOString() ?? null,
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  /**
   * Runs an operation against Postgres and returns its result, or `null` when
   * the caller should fall back to the in-memory `mock-admin.ts` store.
   *
   * `null` is only ever returned outside production. In production a missing
   * or failing database throws 503 `CONTENT_UNAVAILABLE` (same envelope shape
   * as the catalog module), so a client can tell "nothing published yet" (200 with
   * `items: []`, `source: "database"`) from "the content service is down"
   * (503) — and never receives a fixture, and in particular never a fixture
   * PRICE, dressed up as a real row.
   *
   * An empty table is NOT a degradation: `findMany` resolves `[]`, which flows
   * through the database branch untouched.
   *
   * `options.notFoundMessage` maps Prisma P2025 (record not found on update)
   * to a 404 instead of misreporting a client error as an outage.
   */
  private async execOrDegrade<T>(
    resource: string,
    operation: (prisma: PrismaClient) => Promise<T>,
    options: { notFoundMessage?: string } = {},
  ): Promise<T | null> {
    if (!this.prismaService.isEnabled) {
      return this.degrade(resource, 'DATABASE_NOT_CONFIGURED');
    }
    try {
      const result = await this.prismaService.execute(operation);
      // `execute()` only returns null when no client is configured, which the
      // guard above already covered; treat it as a degradation regardless.
      if (result === null) {
        return this.degrade(resource, 'DATABASE_NOT_CONFIGURED');
      }
      return result;
    } catch (error) {
      if (options.notFoundMessage && isPrismaRecordNotFound(error)) {
        throw new NotFoundException(options.notFoundMessage);
      }
      // PrismaService.execute() already logged the bounded, PII-free error
      // code at `error` level before rethrowing.
      return this.degrade(resource, 'DATABASE_ERROR');
    }
  }

  /** Decides what a database outage means for this process. Never silent. */
  private degrade(resource: string, reason: string): null {
    if (!isMockCatalogFallbackAllowed()) {
      this.logger.error(
        `Content "${resource}" is unavailable (${reason}). Refusing to serve ` +
          'mock-admin fixtures (they contain prices); answering 503 ' +
          'CONTENT_UNAVAILABLE.',
      );
      throw contentUnavailable(resource);
    }
    this.logger.warn(
      `Content "${resource}" is unavailable (${reason}). Serving mock-admin ` +
        'fixtures tagged source="mock" (non-production only).',
    );
    return null;
  }

  private mockList<T>(rows: T[]): ContentListResponse<T> {
    return { items: [...rows], source: CATALOG_SOURCE_MOCK };
  }
}
