import { Injectable } from '@nestjs/common';

import { notPendingEefInstitution, notPendingEefProgram } from '../../common/eef-provenance';
import { publicScholarshipWhere } from '../../common/public-scholarship-where';
import { normalizeSearchText } from '../etudes-en-france/catalog/eef-search-text';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeHost } from './community-content-filter';
import {
  COMMUNITY_ENTITY_TYPES,
  mentionKey,
  type CommunityEntityTypeValue,
} from './community-text';

export interface ResolvedEntity {
  type: CommunityEntityTypeValue;
  id: string;
  labelFr: string;
  labelEn: string;
  countryId: string | null;
  /** Niveaux d'éligibilité (bourses seulement), pour le score « Pour toi ». */
  levels: string[];
}

export interface EntitySuggestion {
  type: CommunityEntityTypeValue;
  id: string;
  label: string;
  subtitle: string | null;
  countryId: string | null;
}

const HOSTS_TTL_MS = 10 * 60 * 1000;

/**
 * Le catalogue vu par la communauté : résolution des mentions (entités
 * PUBLIQUES seulement — bourses : `publicScholarshipWhere` ; pays, écoles,
 * formations : actives et jamais une ligne de l'import « Études en France » en
 * attente de publication, `notPendingEef*`). Une école ou une formation publiée
 * de l'espace EEF reste mentionnable : elle a sa fiche dans l'app.
 * autocomplétion, et hôtes des liens officiels (liste blanche du filtre).
 */
@Injectable()
export class CommunityCatalogService {
  private hostsCache: { at: number; hosts: Set<string> } | null = null;

  constructor(private readonly prisma: PrismaService) {}

  async resolveEntities(
    refs: readonly { type: CommunityEntityTypeValue; id: string }[],
    now: Date = new Date(),
  ): Promise<Map<string, ResolvedEntity>> {
    const out = new Map<string, ResolvedEntity>();
    if (refs.length === 0) return out;
    const ids = (type: CommunityEntityTypeValue) =>
      [...new Set(refs.filter((r) => r.type === type).map((r) => r.id))];

    const scholarshipIds = ids('scholarship');
    const countryIds = ids('country');
    const institutionIds = ids('institution');
    const programIds = ids('program');

    await this.prisma.execute(async (db) => {
      if (scholarshipIds.length) {
        const rows = await db.scholarship.findMany({
          where: { AND: [publicScholarshipWhere(now), { id: { in: scholarshipIds } }] },
          select: { id: true, nameFr: true, nameEn: true, countryId: true, eligibleLevels: true },
        });
        for (const r of rows) {
          out.set(mentionKey('scholarship', r.id), {
            type: 'scholarship',
            id: r.id,
            labelFr: r.nameFr,
            labelEn: r.nameEn || r.nameFr,
            countryId: r.countryId || null,
            levels: r.eligibleLevels.map(String),
          });
        }
      }
      if (countryIds.length) {
        const rows = await db.country.findMany({
          where: { isActive: true, id: { in: countryIds } },
          select: { id: true, nameFr: true, nameEn: true },
        });
        for (const r of rows) {
          out.set(mentionKey('country', r.id), {
            type: 'country',
            id: r.id,
            labelFr: r.nameFr,
            labelEn: r.nameEn || r.nameFr,
            countryId: r.id,
            levels: [],
          });
        }
      }
      if (institutionIds.length) {
        const rows = await db.institution.findMany({
          where: { AND: [{ isActive: true, id: { in: institutionIds } }, notPendingEefInstitution()] },
          select: { id: true, nameFr: true, nameEn: true, countryId: true },
        });
        for (const r of rows) {
          out.set(mentionKey('institution', r.id), {
            type: 'institution',
            id: r.id,
            labelFr: r.nameFr,
            labelEn: r.nameEn || r.nameFr,
            countryId: r.countryId || null,
            levels: [],
          });
        }
      }
      if (programIds.length) {
        const rows = await db.program.findMany({
          where: { AND: [{ isActive: true, id: { in: programIds } }, notPendingEefProgram()] },
          select: { id: true, nameFr: true, nameEn: true, countryId: true },
        });
        for (const r of rows) {
          out.set(mentionKey('program', r.id), {
            type: 'program',
            id: r.id,
            labelFr: r.nameFr,
            labelEn: r.nameEn || r.nameFr,
            countryId: r.countryId || null,
            levels: [],
          });
        }
      }
    });
    return out;
  }

  async getEntity(
    type: CommunityEntityTypeValue,
    id: string,
    now: Date = new Date(),
  ): Promise<ResolvedEntity | null> {
    const map = await this.resolveEntities([{ type, id }], now);
    return map.get(mentionKey(type, id)) ?? null;
  }

  /** Autocomplétion des mentions (§7.5). */
  async suggest(
    rawQuery: string,
    types: readonly CommunityEntityTypeValue[],
    limit: number,
    lang: 'fr' | 'en',
    now: Date = new Date(),
  ): Promise<EntitySuggestion[]> {
    const q = rawQuery.trim();
    const norm = normalizeSearchText(q);
    if (!norm) return [];
    const wanted = new Set(types.length ? types : COMMUNITY_ENTITY_TYPES);
    const take = Math.min(limit * 2, 40);
    const contains = { contains: q, mode: 'insensitive' as const };
    const label = (fr: string, en: string) => (lang === 'en' ? en || fr : fr);

    const rows = await this.prisma.execute(async (db) => {
      const out: (EntitySuggestion & { rank: string })[] = [];
      const countryNames = new Map<string, string>();
      const remember = async (countryIds: string[]) => {
        const missing = [...new Set(countryIds)].filter((id) => id && !countryNames.has(id));
        if (!missing.length) return;
        const countries = await db.country.findMany({
          where: { id: { in: missing } },
          select: { id: true, nameFr: true, nameEn: true },
        });
        for (const c of countries) countryNames.set(c.id, label(c.nameFr, c.nameEn));
      };

      if (wanted.has('scholarship')) {
        const list = await db.scholarship.findMany({
          where: {
            AND: [publicScholarshipWhere(now), { OR: [{ nameFr: contains }, { nameEn: contains }] }],
          },
          select: { id: true, nameFr: true, nameEn: true, countryId: true, countryNameFr: true, countryNameEn: true },
          orderBy: { nameFr: 'asc' },
          take,
        });
        for (const s of list) {
          out.push({
            type: 'scholarship',
            id: s.id,
            label: label(s.nameFr, s.nameEn),
            subtitle: label(s.countryNameFr, s.countryNameEn) || null,
            countryId: s.countryId || null,
            rank: label(s.nameFr, s.nameEn),
          });
        }
      }
      if (wanted.has('country')) {
        const list = await db.country.findMany({
          where: { isActive: true, OR: [{ nameFr: contains }, { nameEn: contains }, { code: { equals: q, mode: 'insensitive' } }] },
          select: { id: true, nameFr: true, nameEn: true },
          orderBy: { displayOrder: 'asc' },
          take,
        });
        for (const c of list) {
          out.push({ type: 'country', id: c.id, label: label(c.nameFr, c.nameEn), subtitle: null, countryId: c.id, rank: label(c.nameFr, c.nameEn) });
        }
      }
      if (wanted.has('institution')) {
        const list = await db.institution.findMany({
          where: {
            AND: [
              { isActive: true, OR: [{ nameFr: contains }, { nameEn: contains }, { acronym: contains }] },
              notPendingEefInstitution(),
            ],
          },
          select: { id: true, nameFr: true, nameEn: true, countryId: true, acronym: true },
          orderBy: { nameFr: 'asc' },
          take,
        });
        await remember(list.map((i) => i.countryId));
        for (const i of list) {
          out.push({
            type: 'institution',
            id: i.id,
            label: label(i.nameFr, i.nameEn),
            subtitle: countryNames.get(i.countryId) ?? null,
            countryId: i.countryId || null,
            rank: i.acronym && normalizeSearchText(i.acronym).startsWith(norm) ? i.acronym : label(i.nameFr, i.nameEn),
          });
        }
      }
      if (wanted.has('program')) {
        const list = await db.program.findMany({
          where: {
            AND: [
              { isActive: true, OR: [{ searchText: { contains: norm } }, { nameFr: contains }] },
              notPendingEefProgram(),
            ],
          },
          select: { id: true, nameFr: true, nameEn: true, countryId: true, institutionId: true },
          orderBy: { nameFr: 'asc' },
          take,
        });
        const institutions = await db.institution.findMany({
          where: { AND: [{ id: { in: [...new Set(list.map((p) => p.institutionId))] } }, notPendingEefInstitution()] },
          select: { id: true, nameFr: true, nameEn: true },
        });
        const instName = new Map(institutions.map((i) => [i.id, label(i.nameFr, i.nameEn)]));
        for (const p of list) {
          out.push({
            type: 'program',
            id: p.id,
            label: label(p.nameFr, p.nameEn),
            subtitle: instName.get(p.institutionId) ?? null,
            countryId: p.countryId || null,
            rank: label(p.nameFr, p.nameEn),
          });
        }
      }
      return out;
    });

    const typeOrder = new Map(COMMUNITY_ENTITY_TYPES.map((t, i) => [t, i]));
    return (rows ?? [])
      .map((row) => ({ row, prefix: normalizeSearchText(row.rank).startsWith(norm) ? 0 : 1 }))
      .sort(
        (a, b) =>
          a.prefix - b.prefix ||
          (typeOrder.get(a.row.type) ?? 9) - (typeOrder.get(b.row.type) ?? 9) ||
          a.row.label.length - b.row.label.length ||
          a.row.label.localeCompare(b.row.label, 'fr'),
      )
      .slice(0, limit)
      .map(({ row }) => ({
        type: row.type,
        id: row.id,
        label: row.label,
        subtitle: row.subtitle,
        countryId: row.countryId,
      }));
  }

  /**
   * Hôtes des liens OFFICIELS du catalogue publié : pages sources et de
   * candidature des bourses publiques, sites des écoles, sources des pays et
   * formations. Un lien vers la page officielle d'une bourse n'est pas une
   * arnaque — l'équipe n'a pas à le saisir à la main. Rechargés toutes les 10 min.
   */
  async officialHosts(now: Date = new Date()): Promise<Set<string>> {
    if (this.hostsCache && now.getTime() - this.hostsCache.at < HOSTS_TTL_MS) {
      return this.hostsCache.hosts;
    }
    const hosts = new Set<string>();
    const add = (url: string | null | undefined) => {
      if (!url) return;
      try {
        const parsed = new URL(url);
        if (parsed.protocol === 'https:' || parsed.protocol === 'http:') {
          hosts.add(normalizeHost(parsed.hostname));
        }
      } catch {
        /* lien illisible : ignoré */
      }
    };
    await this.prisma.tryExecute(async (db) => {
      const [scholarships, institutions, countries] = await Promise.all([
        db.scholarship.findMany({
          where: publicScholarshipWhere(now),
          select: { sourceUrl: true, applicationUrl: true },
        }),
        db.institution.findMany({
          where: { AND: [{ isActive: true }, notPendingEefInstitution()] },
          select: { websiteUrl: true, sourceUrl: true },
        }),
        db.country.findMany({ where: { isActive: true }, select: { sourceUrl: true } }),
      ]);
      for (const s of scholarships) {
        add(s.sourceUrl);
        add(s.applicationUrl);
      }
      for (const i of institutions) {
        add(i.websiteUrl);
        add(i.sourceUrl);
      }
      for (const c of countries) add(c.sourceUrl);
      return null;
    });
    this.hostsCache = { at: now.getTime(), hosts };
    return hosts;
  }
}
