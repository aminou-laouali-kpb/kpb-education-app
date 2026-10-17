import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CommunityCatalogService } from './community-catalog.service';
import {
  BUILTIN_ALLOWED_DOMAINS,
  foldText,
  hostMatchesRules,
  normalizeHost,
  scanContent,
  type FilterContext,
  type FilterFlag,
} from './community-content-filter';

const ENTRIES_TTL_MS = 60 * 1000;

/**
 * Le contexte du filtre : liste blanche (intégrée + catalogue + équipe) et
 * termes bloqués par l'équipe. Les ajouts de l'équipe sont relus au plus une
 * fois par minute, et immédiatement après une modification depuis l'admin.
 */
@Injectable()
export class CommunityFilterConfigService {
  private entriesCache: { at: number; domains: string[]; terms: string[] } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly catalog: CommunityCatalogService,
  ) {}

  invalidate(): void {
    this.entriesCache = null;
  }

  private async entries(now: Date): Promise<{ domains: string[]; terms: string[] }> {
    if (this.entriesCache && now.getTime() - this.entriesCache.at < ENTRIES_TTL_MS) {
      return this.entriesCache;
    }
    const rows =
      (await this.prisma.tryExecute((db) =>
        db.communityFilterEntry.findMany({ select: { kind: true, value: true } }),
      )) ?? [];
    const domains = rows.filter((r) => r.kind === 'allowed_domain').map((r) => r.value);
    const terms = rows.filter((r) => r.kind === 'blocked_term').map((r) => foldText(r.value));
    this.entriesCache = { at: now.getTime(), domains, terms };
    return this.entriesCache;
  }

  async context(now: Date = new Date()): Promise<FilterContext> {
    const [{ domains, terms }, catalogHosts] = await Promise.all([
      this.entries(now),
      this.catalog.officialHosts(now),
    ]);
    const rules = [...BUILTIN_ALLOWED_DOMAINS, ...domains];
    return {
      isAllowedHost: (host: string) => {
        const h = normalizeHost(host);
        return catalogHosts.has(h) || hostMatchesRules(h, rules);
      },
      blockedTerms: terms,
    };
  }

  async scan(text: string, now: Date = new Date()): Promise<FilterFlag[]> {
    return scanContent(text, await this.context(now));
  }

  async catalogHostsCount(now: Date = new Date()): Promise<number> {
    return (await this.catalog.officialHosts(now)).size;
  }
}
