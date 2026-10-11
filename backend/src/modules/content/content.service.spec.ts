import { HttpException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';

import { ContentService } from './content.service';
import { PrismaService } from '../prisma/prisma.service';
import { mockAdminData } from '../../common/data/mock-admin';

const mockPrismaService = {
  isEnabled: true,
  execute: jest.fn(),
};

const serviceOfferRow = {
  id: 'offer-db-1',
  nameFr: 'Pack visa',
  nameEn: 'Visa pack',
  offerType: 'application_support',
  destinationIds: ['fra'],
  studyLevels: ['Master'],
  priceLabelFr: '150 000 FCFA',
  priceLabelEn: '150,000 XOF',
  benefitsFr: ['Suivi complet'],
  benefitsEn: ['Full follow-up'],
  ctaLabelFr: 'Démarrer',
  ctaLabelEn: 'Start',
  status: 'published',
};

const articleRow = {
  id: 'article-db-1',
  slug: 'etudier-en-france',
  category: 'guides',
  titleFr: 'Étudier en France',
  titleEn: 'Study in France',
  summaryFr: 'Résumé',
  summaryEn: 'Summary',
  contentFr: 'Contenu',
  contentEn: 'Content',
  tags: ['france'],
  authorName: 'KPB Editorial',
  status: 'published',
  publishedAt: new Date('2026-01-01T00:00:00.000Z'),
};

describe('ContentService', () => {
  let service: ContentService;
  const previousNodeEnv = process.env.NODE_ENV;
  const previousFallbackFlag = process.env.KPB_CATALOG_MOCK_FALLBACK;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ContentService,
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
      ],
    }).compile();

    service = module.get<ContentService>(ContentService);
    jest.clearAllMocks();
    mockPrismaService.isEnabled = true;
    process.env.NODE_ENV = 'test';
    delete process.env.KPB_CATALOG_MOCK_FALLBACK;
  });

  afterAll(() => {
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousFallbackFlag === undefined) {
      delete process.env.KPB_CATALOG_MOCK_FALLBACK;
    } else {
      process.env.KPB_CATALOG_MOCK_FALLBACK = previousFallbackFlag;
    }
  });

  describe('real content', () => {
    it('returns database service offers tagged source="database"', async () => {
      mockPrismaService.execute.mockResolvedValueOnce([serviceOfferRow]);

      const result = await service.listServiceOffers();

      expect(result.source).toBe('database');
      expect(result.items).toHaveLength(1);
      expect(result.items[0]).toMatchObject({
        id: 'offer-db-1',
        name: { fr: 'Pack visa', en: 'Visa pack' },
        priceLabel: { fr: '150 000 FCFA', en: '150,000 XOF' },
        status: 'published',
      });
    });

    it('returns database articles tagged source="database"', async () => {
      mockPrismaService.execute.mockResolvedValueOnce([articleRow]);

      const result = await service.listArticles();

      expect(result.source).toBe('database');
      expect(result.items[0]).toMatchObject({
        id: 'article-db-1',
        slug: 'etudier-en-france',
        publishedAt: '2026-01-01T00:00:00.000Z',
      });
    });

    it('tags database mutations source="database"', async () => {
      mockPrismaService.execute.mockResolvedValueOnce(serviceOfferRow);

      const result = await service.createServiceOffer({});

      expect(result).toMatchObject({ id: 'offer-db-1', source: 'database' });
    });
  });

  describe('empty content is not a degradation', () => {
    it.each([
      ['service-offers', () => service.listServiceOffers()],
      ['support-destinations', () => service.listSupportDestinations()],
      ['articles', () => service.listArticles()],
    ])(
      'returns an honest empty %s list in production rather than fixtures',
      async (_resource, call) => {
        process.env.NODE_ENV = 'production';
        mockPrismaService.execute.mockResolvedValueOnce([]);

        const result = await call();

        expect(result.items).toEqual([]);
        expect(result.source).toBe('database');
      },
    );
  });

  describe('production refuses fixtures', () => {
    beforeEach(() => {
      process.env.NODE_ENV = 'production';
    });

    it('throws 503 when the database errors, never leaking a fixture price', async () => {
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      const error = await service
        .listServiceOffers()
        .catch((e) => e as unknown);

      expect(error).toBeInstanceOf(HttpException);
      const httpError = error as HttpException;
      expect(httpError.getStatus()).toBe(503);
      expect(httpError.getResponse()).toMatchObject({
        code: 'CONTENT_UNAVAILABLE',
        details: { resource: 'service-offers' },
      });
      const body = JSON.stringify(httpError.getResponse());
      // The mock offers carry commercial amounts ("À partir de 75 000 FCFA").
      expect(body).not.toContain('75 000');
      expect(body).not.toContain('FCFA');
      expect(body).not.toContain('offer-scholarship-boost');
    });

    it('refuses fixtures when no database is configured at all', async () => {
      mockPrismaService.isEnabled = false;

      await expect(service.listServiceOffers()).rejects.toBeInstanceOf(
        HttpException,
      );
      expect(mockPrismaService.execute).not.toHaveBeenCalled();
    });

    it('logs the outage at error level instead of swallowing it', async () => {
      const errorSpy = jest
        .spyOn(service['logger'], 'error')
        .mockImplementation(() => undefined);
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      await expect(service.listArticles()).rejects.toBeInstanceOf(
        HttpException,
      );

      expect(errorSpy).toHaveBeenCalledTimes(1);
      expect(errorSpy.mock.calls[0][0]).toContain('CONTENT_UNAVAILABLE');
    });

    it.each([
      ['service-offers list', () => service.listServiceOffers()],
      ['support-destinations list', () => service.listSupportDestinations()],
      ['articles list', () => service.listArticles()],
      ['service-offer create', () => service.createServiceOffer({})],
      ['support-destination create', () => service.createSupportDestination({})],
      ['article create', () => service.createArticle({})],
      ['service-offer update', () => service.updateServiceOffer('x', {})],
      [
        'support-destination update',
        () => service.updateSupportDestination('x', {}),
      ],
      ['article update', () => service.updateArticle('x', {})],
    ])('covers %s too', async (_name, call) => {
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      const error = await call().catch((e) => e as unknown);

      expect(error).toBeInstanceOf(HttpException);
      expect((error as HttpException).getStatus()).toBe(503);
    });

    // The fixture offers carry commercial amounts a KPB advisor would then have
    // to deny on WhatsApp. This sweep asserts the money never leaves the
    // process on ANY production entry point, whatever the failure mode.
    it.each([
      ['DATABASE_ERROR', () => mockPrismaService.execute.mockRejectedValue(new Error('boom'))],
      ['DATABASE_NOT_CONFIGURED', () => { mockPrismaService.isEnabled = false; }],
    ])(
      'never resolves a fixture price on any endpoint (%s)',
      async (_mode, arrange) => {
        arrange();
        const calls: Array<() => Promise<unknown>> = [
          () => service.listServiceOffers(),
          () => service.listSupportDestinations(),
          () => service.listArticles(),
          () => service.createServiceOffer({}),
          () => service.createSupportDestination({}),
          () => service.createArticle({}),
          () => service.updateServiceOffer('offer-scholarship-boost', {}),
          () => service.updateSupportDestination('support-canada', {}),
          () => service.updateArticle('article-1', {}),
        ];

        for (const call of calls) {
          const outcome = await call().then(
            (value) => ({ resolved: true, value }),
            (error: unknown) => ({ resolved: false, value: error }),
          );

          expect(outcome.resolved).toBe(false);
          expect(outcome.value).toBeInstanceOf(HttpException);
        }
      },
    );

    it('maps an unknown id on update to 404, not to a fake outage', async () => {
      mockPrismaService.execute.mockRejectedValueOnce({ code: 'P2025' });

      await expect(
        service.updateServiceOffer('missing-id', {}),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });

  describe('non-production degraded mode stays available but honest', () => {
    it('serves mock service offers tagged source="mock" and warns', async () => {
      const warnSpy = jest
        .spyOn(service['logger'], 'warn')
        .mockImplementation(() => undefined);
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      const result = await service.listServiceOffers();

      expect(result.items).toEqual(mockAdminData.serviceOffers);
      expect(result.source).toBe('mock');
      expect(warnSpy).toHaveBeenCalledTimes(1);
    });

    it('serves mock destinations and articles when the database is off', async () => {
      mockPrismaService.isEnabled = false;

      const destinations = await service.listSupportDestinations();
      const articles = await service.listArticles();

      expect(destinations.source).toBe('mock');
      expect(destinations.items).toEqual(mockAdminData.supportDestinations);
      expect(articles.source).toBe('mock');
      expect(articles.items).toEqual(mockAdminData.articles);
    });

    it('keeps in-memory mutations working, tagged source="mock"', async () => {
      mockPrismaService.isEnabled = false;

      const created = await service.createServiceOffer({
        name: { fr: 'Offre test', en: 'Test offer' },
      });
      expect(created).toMatchObject({
        name: { fr: 'Offre test', en: 'Test offer' },
        source: 'mock',
      });

      const listed = await service.listServiceOffers();
      expect(listed.items[0]).toMatchObject({
        name: { fr: 'Offre test', en: 'Test offer' },
      });
    });

    it('still 404s an unknown id on the in-memory store', async () => {
      mockPrismaService.isEnabled = false;

      await expect(
        service.updateArticle('missing-id', {}),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('can be switched off with KPB_CATALOG_MOCK_FALLBACK=0', async () => {
      process.env.KPB_CATALOG_MOCK_FALLBACK = '0';
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      await expect(service.listArticles()).rejects.toBeInstanceOf(
        HttpException,
      );
    });
  });

  describe('public reads', () => {
    it.each([
      ['listServiceOffers', 'serviceOffer', { status: 'published' }],
      ['listSupportDestinations', 'supportDestination', { status: 'published', isVisible: true }],
      ['listArticles', 'article', { status: 'published' }],
    ] as const)('%s({ publicOnly }) only queries published items', async (fn, model, where) => {
      const findMany = jest.fn().mockResolvedValue([]);
      mockPrismaService.execute.mockImplementation((op: any) => op({ [model]: { findMany } }));
      await (service as any)[fn]({ publicOnly: true });
      expect(findMany).toHaveBeenCalledWith(expect.objectContaining({ where }));
    });

    it('admin reads keep every status', async () => {
      const findMany = jest.fn().mockResolvedValue([]);
      mockPrismaService.execute.mockImplementation((op: any) => op({ article: { findMany } }));
      await service.listArticles();
      expect(findMany.mock.calls[0][0].where).toBeUndefined();
    });
  });
});
