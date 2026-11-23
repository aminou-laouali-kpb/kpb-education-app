import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

/**
 * Partner directory (Phase 3 — credibility layer).
 *
 * Campus France, AUF, Moroccan / Tunisian unis, and West African banks
 * (UBA, Ecobank, Orabank) for student-loan referrals. The mobile app
 * renders `listFeatured()` as the "Ils nous font confiance" strip on
 * the landing screen — each logo is worth ~1000 cold users.
 */
@Injectable()
export class PartnersService {
  constructor(private readonly prismaService: PrismaService) {}

  async listPublic(params: { category?: string; country?: string } = {}) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.partner.findMany({
        where: {
          isActive: true,
          ...(params.category ? { category: params.category as never } : {}),
          ...(params.country
            ? { countryCode: params.country.toUpperCase() }
            : {}),
        },
        orderBy: [
          { isFeatured: 'desc' },
          { displayOrder: 'asc' },
          { nameFr: 'asc' },
        ],
        select: {
          id: true,
          slug: true,
          nameFr: true,
          nameEn: true,
          category: true,
          countryCode: true,
          taglineFr: true,
          taglineEn: true,
          descriptionFr: true,
          descriptionEn: true,
          logoUrl: true,
          websiteUrl: true,
          referralUrl: true,
          isFeatured: true,
        },
      }),
    );
    return { items: items ?? [] };
  }

  /** Homepage strip — featured partners only, capped so it fits the UI. */
  async listFeatured(limit = 12) {
    // `?limit=abc` ou `?limit=1e999` donnent NaN/Infinity : Prisma rejette
    // `take: NaN` (500). On retombe sur la valeur par défaut et on tronque.
    const safeLimit = Number.isFinite(limit) ? Math.trunc(limit) : 12;
    const items = await this.prismaService.execute((prisma) =>
      prisma.partner.findMany({
        where: { isActive: true, isFeatured: true },
        orderBy: { displayOrder: 'asc' },
        take: Math.min(Math.max(safeLimit, 1), 24),
        select: {
          id: true,
          slug: true,
          nameFr: true,
          nameEn: true,
          category: true,
          logoUrl: true,
          websiteUrl: true,
          taglineFr: true,
          taglineEn: true,
        },
      }),
    );
    return { items: items ?? [] };
  }

  async getPublic(slug: string) {
    const partner = await this.prismaService.execute((prisma) =>
      prisma.partner.findUnique({ where: { slug } }),
    );
    if (!partner || !partner.isActive) {
      throw new NotFoundException(`Partner ${slug} not found.`);
    }
    return partner;
  }

  // ── Admin CRUD ────────────────────────────────────────────────────────────

  async listAdmin() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.partner.findMany({
        orderBy: [{ displayOrder: 'asc' }, { createdAt: 'desc' }],
      }),
    );
    return { items: items ?? [] };
  }

  async create(data: {
    slug: string;
    nameFr: string;
    nameEn: string;
    category: string;
    countryCode?: string;
    taglineFr?: string;
    taglineEn?: string;
    descriptionFr?: string;
    descriptionEn?: string;
    logoUrl?: string;
    websiteUrl?: string;
    referralUrl?: string;
    isFeatured?: boolean;
    displayOrder?: number;
    isActive?: boolean;
  }) {
    if (!data.slug?.trim()) {
      throw new BadRequestException('slug is required.');
    }
    return this.prismaService.execute((prisma) =>
      prisma.partner.create({
        data: {
          ...data,
          category: data.category as never,
          countryCode: data.countryCode?.toUpperCase(),
        },
      }),
    );
  }

  async update(
    id: string,
    data: Partial<{
      nameFr: string;
      nameEn: string;
      category: string;
      countryCode: string;
      taglineFr: string;
      taglineEn: string;
      descriptionFr: string;
      descriptionEn: string;
      logoUrl: string;
      websiteUrl: string;
      referralUrl: string;
      isFeatured: boolean;
      displayOrder: number;
      isActive: boolean;
    }>,
  ) {
    return this.prismaService.execute((prisma) =>
      prisma.partner.update({
        where: { id },
        data: {
          ...data,
          category: data.category ? (data.category as never) : undefined,
          countryCode: data.countryCode
            ? data.countryCode.toUpperCase()
            : undefined,
        },
      }),
    );
  }
}
