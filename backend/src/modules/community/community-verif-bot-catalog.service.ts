import { Injectable } from '@nestjs/common';

import { notPendingEefInstitution, notPendingEefProgram } from '../../common/eef-provenance';
import { publicScholarshipWhere } from '../../common/public-scholarship-where';
import { usVisaSuspensionConfig } from '../config/us-visa-suspension';
import { normalizeSearchText } from '../etudes-en-france/catalog/eef-search-text';
import { PrismaService } from '../prisma/prisma.service';
import {
  countryFacts,
  institutionFacts,
  programFacts,
  scholarshipFacts,
  usVisaFact,
  type EntityFacts,
  type EntityRef,
  type FactEntityType,
  type FactSet,
} from './community-verif-bot-facts';
import { VERIF_BOT_MAX_ENTITIES } from './community-verif-bot.config';

const INDEX_TTL_MS = 10 * 60 * 1000;

/** Mots génériques retirés d'un nom de bourse pour en garder le cœur (« Eiffel »). */
const GENERIC_WORDS = new Set([
  'bourse', 'bourses', 'programme', 'programmes', 'program', 'programme', 'scholarship', 'scholarships',
  'de', 'des', 'du', 'd', 'la', 'le', 'les', 'l', 'the', 'of', 'for', 'pour', 'et', 'and', 'excellence',
  'gouvernement', 'government', 'master', 'masters', 'doctorat', 'phd', 'etudes', 'study', 'studies',
  'international', 'internationale', 'internationales', 'fund', 'fellowship', 'fellowships', 'award',
  'awards', 'en', 'au', 'aux', 'a', 'in',
]);

interface IndexEntry {
  type: 'scholarship' | 'institution' | 'country';
  id: string;
  labelFr: string;
  labelEn: string;
  /** Formes normalisées acceptées (nom complet FR / EN, cœur du nom). */
  names: string[];
  /** Sigle exact (« UQAM »), comparé en majuscules sur le texte brut. */
  acronym: string | null;
  /** Une forme « cœur » exige le mot « bourse » / « scholarship » dans le texte. */
  coreNames: string[];
}

export type ResolveOutcome =
  | { kind: 'resolved'; refs: EntityRef[] }
  | { kind: 'none' }
  | { kind: 'ambiguous' };

/** Priorité d'affichage : la bourse d'abord, le pays en dernier. */
const TYPE_ORDER: Record<FactEntityType, number> = { scholarship: 0, program: 1, institution: 2, country: 3 };

function wholeWord(haystack: string, needle: string): boolean {
  if (!needle) return false;
  return ` ${haystack} `.includes(` ${needle} `);
}

/**
 * Le catalogue vu par le bot « Vérif » : lecture des faits (entités PUBLIQUES
 * seulement, mêmes portes que les mentions) et résolution d'une entité citée
 * en toutes lettres, sans jeton — avec un seuil STRICT : nom complet en mots
 * entiers, sigle exact, ou cœur d'un nom de bourse (≥ 5 lettres) quand le
 * texte parle de bourse ; un seul candidat par famille, sinon « ambigu ».
 */
@Injectable()
export class CommunityVerifBotCatalogService {
  private index: { at: number; entries: IndexEntry[] } | null = null;

  constructor(private readonly prisma: PrismaService) {}

  // ── Résolution par le texte ───────────────────────────────────────────────

  private async loadIndex(now: Date): Promise<IndexEntry[]> {
    if (this.index && now.getTime() - this.index.at < INDEX_TTL_MS) return this.index.entries;
    const entries: IndexEntry[] = [];
    await this.prisma.execute(async (db) => {
      const [scholarships, institutions, countries] = await Promise.all([
        db.scholarship.findMany({ where: publicScholarshipWhere(now), select: { id: true, nameFr: true, nameEn: true } }),
        db.institution.findMany({
          where: { AND: [{ isActive: true }, notPendingEefInstitution()] },
          select: { id: true, nameFr: true, nameEn: true, acronym: true },
        }),
        db.country.findMany({ where: { isActive: true }, select: { id: true, nameFr: true, nameEn: true } }),
      ]);
      for (const s of scholarships) {
        const names = [...new Set([normalizeSearchText(s.nameFr), normalizeSearchText(s.nameEn)].filter((n) => n.length >= 6))];
        const coreNames = [
          ...new Set(
            names
              .map((n) => n.split(' ').filter((w) => !GENERIC_WORDS.has(w) && !/^\d+$/.test(w)).join(' '))
              .filter((core) => core.length >= 5),
          ),
        ];
        entries.push({ type: 'scholarship', id: s.id, labelFr: s.nameFr, labelEn: s.nameEn || s.nameFr, names, acronym: null, coreNames });
      }
      for (const i of institutions) {
        const names = [...new Set([normalizeSearchText(i.nameFr), normalizeSearchText(i.nameEn)].filter((n) => n.length >= 8))];
        const acronym = i.acronym && /^[A-Z][A-Za-z0-9&-]{2,11}$/.test(i.acronym.trim()) ? i.acronym.trim().toUpperCase() : null;
        entries.push({ type: 'institution', id: i.id, labelFr: i.nameFr, labelEn: i.nameEn || i.nameFr, names, acronym, coreNames: [] });
      }
      for (const c of countries) {
        const names = [...new Set([normalizeSearchText(c.nameFr), normalizeSearchText(c.nameEn)].filter((n) => n.length >= 3))];
        entries.push({ type: 'country', id: c.id, labelFr: c.nameFr, labelEn: c.nameEn || c.nameFr, names, acronym: null, coreNames: [] });
      }
      return null;
    });
    this.index = { at: now.getTime(), entries };
    return entries;
  }

  /**
   * Retrouve les entités citées en toutes lettres. Un seul candidat par
   * famille ; deux bourses (ou deux écoles) également plausibles = ambigu.
   */
  async resolveByText(text: string, now: Date = new Date()): Promise<ResolveOutcome> {
    const norm = normalizeSearchText(text);
    if (!norm) return { kind: 'none' };
    const rawWords = new Set(text.split(/[^A-Za-z0-9&-]+/).filter(Boolean));
    const talksScholarship = /\b(bourse|bourses|scholarship|scholarships)\b/.test(norm);
    const entries = await this.loadIndex(now);
    const found = new Map<IndexEntry['type'], { entry: IndexEntry; length: number }[]>();
    for (const entry of entries) {
      let length = 0;
      for (const name of entry.names) if (wholeWord(norm, name)) length = Math.max(length, name.length);
      if (!length && entry.acronym && rawWords.has(entry.acronym)) length = entry.acronym.length;
      if (!length && talksScholarship) {
        for (const core of entry.coreNames) if (wholeWord(norm, core)) length = Math.max(length, core.length);
      }
      if (!length) continue;
      const bucket = found.get(entry.type) ?? [];
      bucket.push({ entry, length });
      found.set(entry.type, bucket);
    }
    const refs: EntityRef[] = [];
    for (const [type, bucket] of found) {
      bucket.sort((a, b) => b.length - a.length);
      const [best, second] = bucket;
      // Un nom plus long qui CONTIENT l'autre (« Bourse Eiffel Excellence » vs
      // « Eiffel ») départage ; deux noms indépendants, non.
      if (second && second.length === best.length) {
        if (type === 'country') continue; // un pays ambigu n'empêche pas le reste
        return { kind: 'ambiguous' };
      }
      refs.push({ type, id: best.entry.id, labelFr: best.entry.labelFr, labelEn: best.entry.labelEn, resolvedBy: 'name' });
    }
    if (!refs.length) return { kind: 'none' };
    return { kind: 'resolved', refs };
  }

  // ── Faits ─────────────────────────────────────────────────────────────────

  /**
   * Les faits des entités demandées, PUBLIQUES seulement (une entité devenue
   * non publique disparaît du jeu de faits). Ordre : bourse, formation,
   * école, pays ; trois entités au plus.
   */
  async loadFacts(refs: readonly EntityRef[], now: Date = new Date()): Promise<FactSet> {
    const wanted = [...refs]
      .sort((a, b) => TYPE_ORDER[a.type] - TYPE_ORDER[b.type])
      .slice(0, VERIF_BOT_MAX_ENTITIES);
    const ids = (type: FactEntityType) => wanted.filter((r) => r.type === type).map((r) => r.id);
    const byKey = new Map<string, EntityFacts>();
    await this.prisma.execute(async (db) => {
      const scholarshipIds = ids('scholarship');
      if (scholarshipIds.length) {
        const rows = await db.scholarship.findMany({
          where: { AND: [publicScholarshipWhere(now), { id: { in: scholarshipIds } }] },
          include: { cycles: { orderBy: { academicYear: 'desc' }, take: 5 } },
        });
        for (const r of rows) {
          const ref = wanted.find((w) => w.type === 'scholarship' && w.id === r.id)!;
          byKey.set(`scholarship:${r.id}`, scholarshipFacts(r, { ...ref, labelFr: r.nameFr, labelEn: r.nameEn || r.nameFr }, now));
        }
      }
      const programIds = ids('program');
      const programs = programIds.length
        ? await db.program.findMany({ where: { AND: [{ isActive: true, id: { in: programIds } }, notPendingEefProgram()] } })
        : [];
      const institutionIds = [...new Set([...ids('institution'), ...programs.map((p) => p.institutionId)])];
      const institutions = institutionIds.length
        ? await db.institution.findMany({
            where: { AND: [{ isActive: true, id: { in: institutionIds } }, notPendingEefInstitution()] },
          })
        : [];
      const institutionById = new Map(institutions.map((i) => [i.id, i]));
      for (const p of programs) {
        const ref = wanted.find((w) => w.type === 'program' && w.id === p.id)!;
        byKey.set(
          `program:${p.id}`,
          programFacts(p, institutionById.get(p.institutionId) ?? null, { ...ref, labelFr: p.nameFr, labelEn: p.nameEn || p.nameFr }, now),
        );
      }
      for (const id of ids('institution')) {
        const row = institutionById.get(id);
        if (!row) continue;
        const ref = wanted.find((w) => w.type === 'institution' && w.id === id)!;
        byKey.set(`institution:${id}`, institutionFacts(row, { ...ref, labelFr: row.nameFr, labelEn: row.nameEn || row.nameFr }, now));
      }
      const countryIds = ids('country');
      if (countryIds.length) {
        const rows = await db.country.findMany({ where: { isActive: true, id: { in: countryIds } } });
        for (const r of rows) {
          const ref = wanted.find((w) => w.type === 'country' && w.id === r.id)!;
          byKey.set(`country:${r.id}`, countryFacts(r, { ...ref, labelFr: r.nameFr, labelEn: r.nameEn || r.nameFr }, now));
        }
      }
      return null;
    });
    const entities = wanted
      .map((r) => byKey.get(`${r.type}:${r.id}`))
      .filter((e): e is EntityFacts => !!e);
    const needsVisa = entities.some((e) => e.kind !== 'scholarship' && e.isUs);
    return {
      version: 1,
      checkedAt: now.toISOString(),
      entities,
      usVisa: needsVisa
        ? usVisaFact(
            usVisaSuspensionConfig({
              countries: process.env.KPB_US_VISA_SUSPENDED_COUNTRIES,
              verifiedAt: process.env.KPB_US_VISA_SUSPENSION_VERIFIED_AT,
              sourceUrl: process.env.KPB_US_VISA_SUSPENSION_SOURCE_URL,
            }),
          )
        : null,
    };
  }
}
