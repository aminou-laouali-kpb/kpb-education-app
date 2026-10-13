import { HttpException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';

import { CatalogService } from './catalog.service';
import { PrismaService } from '../prisma/prisma.service';
import { mockCatalog } from '../../common/data/mock-catalog';
import { isMockCatalogFallbackAllowed } from './catalog-degraded-mode';

const mockPrismaService = {
  isEnabled: true,
  execute: jest.fn(),
};

const countryRow = {
  id: 'france',
  code: 'FR',
  flagEmoji: '🇫🇷',
  nameFr: 'France',
  nameEn: 'France',
  taglineFr: 'Étudier en France',
  taglineEn: 'Study in France',
  nextIntakeLabelFr: 'Septembre',
  nextIntakeLabelEn: 'September',
  mainLanguageFr: 'Français',
  mainLanguageEn: 'French',
  whyStudyFr: 'Qualité académique',
  whyStudyEn: 'Academic quality',
  marketingDescriptionFr: 'Description',
  marketingDescriptionEn: 'Description',
  whyStudyBulletsFr: ['Bon réseau'],
  whyStudyBulletsEn: ['Strong network'],
  howItWorksFr: 'Processus',
  howItWorksEn: 'Process',
  costsOverviewFr: 'Coûts',
  costsOverviewEn: 'Costs',
  languageSectionFr: 'Langue',
  languageSectionEn: 'Language',
  partnerSchoolsFr: 'Écoles',
  partnerSchoolsEn: 'Schools',
  scholarshipsSectionFr: 'Bourses',
  scholarshipsSectionEn: 'Scholarships',
  whatsAppPrefillFr: 'Bonjour',
  whatsAppPrefillEn: 'Hello',
  mvpNoteFr: 'Note',
  mvpNoteEn: 'Note',
  tuitionRangeFr: '3 000 - 8 000 €',
  tuitionRangeEn: '€3,000 - €8,000',
  livingCostRangeFr: '700 - 1 000 €',
  livingCostRangeEn: '€700 - €1,000',
  visaOverviewFr: 'Visa étudiant',
  visaOverviewEn: 'Student visa',
  admissionDifficultyFr: 'Moyenne',
  admissionDifficultyEn: 'Medium',
  popularFieldIds: ['d01'],
  displayOrder: 1,
  isActive: true,
};

describe('CatalogService', () => {
  let service: CatalogService;
  const previousNodeEnv = process.env.NODE_ENV;
  const previousFallbackFlag = process.env.KPB_CATALOG_MOCK_FALLBACK;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CatalogService,
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
      ],
    }).compile();

    service = module.get<CatalogService>(CatalogService);
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

  describe('real catalog', () => {
    it('returns database countries tagged source="database"', async () => {
      mockPrismaService.execute.mockResolvedValueOnce([countryRow]);

      const result = await service.getCountries();

      expect(result.source).toBe('database');
      expect(result.items).toHaveLength(1);
      expect(result.items[0]).toMatchObject({
        id: 'france',
        code: 'FR',
        flagEmoji: '🇫🇷',
        name: { fr: 'France', en: 'France' },
        tagline: { fr: 'Étudier en France', en: 'Study in France' },
        popularFieldIds: ['d01'],
        displayOrder: 1,
        isActive: true,
      });
    });

    it('serves scholarships with a baseMatch capped below the app "good" tier', async () => {
      // Installed builds show `baseMatch` as is when the student has no
      // profile ("Très bon match" from 70, "78 %" on 2.2.0). The stored value
      // is untouched; only what the public endpoint serves is capped.
      mockPrismaService.execute.mockResolvedValueOnce([
        {
          id: 'mastercard-test',
          nameFr: 'Bourse test',
          nameEn: 'Test scholarship',
          countryId: 'can',
          relatedFieldIds: [],
          baseMatch: 78,
          cycles: [],
        },
      ]);

      const result = await service.getScholarships();

      expect(result.source).toBe('database');
      expect(result.items[0]).toMatchObject({
        id: 'mastercard-test',
        baseMatch: 40,
      });
    });
  });

  describe('empty catalog is not a degradation', () => {
    it('returns an empty database list rather than fixtures', async () => {
      process.env.NODE_ENV = 'production';
      mockPrismaService.execute.mockResolvedValueOnce([]);

      const result = await service.getScholarships();

      expect(result.items).toEqual([]);
      expect(result.source).toBe('database');
    });
  });

  describe('production refuses fixtures', () => {
    beforeEach(() => {
      process.env.NODE_ENV = 'production';
    });

    it('throws 503 CATALOG_UNAVAILABLE when the database errors', async () => {
      mockPrismaService.execute.mockRejectedValueOnce(
        new Error('connection refused'),
      );

      await expect(service.getScholarships()).rejects.toBeInstanceOf(
        HttpException,
      );
    });

    it('never leaks a mock scholarship name in the 503 payload', async () => {
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      const error = await service.getScholarships().catch((e) => e as unknown);

      expect(error).toBeInstanceOf(HttpException);
      const httpError = error as HttpException;
      expect(httpError.getStatus()).toBe(503);
      expect(httpError.getResponse()).toMatchObject({
        code: 'CATALOG_UNAVAILABLE',
        details: { resource: 'scholarships' },
      });
      expect(JSON.stringify(httpError.getResponse())).not.toContain('McCall');
    });

    it('logs the outage at error level instead of swallowing it', async () => {
      const errorSpy = jest
        .spyOn(service['logger'], 'error')
        .mockImplementation(() => undefined);
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      await expect(service.getFields()).rejects.toBeInstanceOf(HttpException);

      expect(errorSpy).toHaveBeenCalledTimes(1);
      expect(errorSpy.mock.calls[0][0]).toContain('CATALOG_UNAVAILABLE');
    });

    it('refuses fixtures when no database is configured at all', async () => {
      mockPrismaService.isEnabled = false;

      await expect(service.getPrograms()).rejects.toBeInstanceOf(HttpException);
      expect(mockPrismaService.execute).not.toHaveBeenCalled();
    });

    it.each([
      ['fields', () => service.getFields()],
      ['countries', () => service.getCountries()],
      ['institutions', () => service.getInstitutions()],
      ['programs', () => service.getPrograms()],
      ['scholarships', () => service.getScholarships()],
    ])('covers the %s endpoint too', async (_resource, call) => {
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      await expect(call()).rejects.toBeInstanceOf(HttpException);
    });
  });

  describe('non-production degraded mode stays available but honest', () => {
    it('serves mock fields tagged source="mock"', async () => {
      mockPrismaService.execute.mockResolvedValueOnce(null);

      const result = await service.getFields();

      expect(result.items).toEqual(mockCatalog.fields);
      expect(result.source).toBe('mock');
    });

    it('serves mock scholarships tagged source="mock" and warns', async () => {
      const warnSpy = jest
        .spyOn(service['logger'], 'warn')
        .mockImplementation(() => undefined);
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      const result = await service.getScholarships();

      expect(result.items).toEqual(mockCatalog.scholarships);
      expect(result.source).toBe('mock');
      expect(warnSpy).toHaveBeenCalledTimes(1);
    });

    it('keeps the programs envelope shape when degraded', async () => {
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      const result = await service.getPrograms({ limit: 10, offset: 0 });

      expect(result.source).toBe('mock');
      expect(result.total).toBe(mockCatalog.programs.length);
      expect(result.limit).toBe(10);
      expect(result.offset).toBe(0);
    });

    it('can be switched off with KPB_CATALOG_MOCK_FALLBACK=0', async () => {
      process.env.KPB_CATALOG_MOCK_FALLBACK = '0';
      mockPrismaService.execute.mockRejectedValueOnce(new Error('boom'));

      await expect(service.getScholarships()).rejects.toBeInstanceOf(
        HttpException,
      );
    });
  });
});

describe('isMockCatalogFallbackAllowed', () => {
  it('is never allowed in production, even with an explicit opt-in', () => {
    expect(
      isMockCatalogFallbackAllowed({
        NODE_ENV: 'production',
        KPB_CATALOG_MOCK_FALLBACK: 'true',
      }),
    ).toBe(false);
  });

  it('is allowed by default outside production', () => {
    expect(isMockCatalogFallbackAllowed({ NODE_ENV: 'development' })).toBe(true);
    expect(isMockCatalogFallbackAllowed({})).toBe(true);
  });

  it.each(['0', 'false', 'off', 'no', 'FALSE'])(
    'honours KPB_CATALOG_MOCK_FALLBACK=%s outside production',
    (value) => {
      expect(
        isMockCatalogFallbackAllowed({
          NODE_ENV: 'development',
          KPB_CATALOG_MOCK_FALLBACK: value,
        }),
      ).toBe(false);
    },
  );
});
