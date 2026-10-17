import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { isDisposableEmail } from '../referrals/campaigns/disposable-email-domains';
import { COMMUNITY_LIMITS } from './community.constants';
import { CommunityCatalogService, type ResolvedEntity } from './community-catalog.service';
import type { FilterFlag } from './community-content-filter';
import { CommunityErrors } from './community-errors';
import { CommunityFilterConfigService } from './community-filter-config.service';
import {
  canonicalizeMentionTokens,
  communitySearchText,
  extractHashtags,
  extractMentionRefs,
  mentionKey,
  type HashtagRef,
} from './community-text';

export interface PreparedContent {
  title: string | null;
  body: string;
  mentions: ResolvedEntity[];
  hashtags: HashtagRef[];
  flags: FilterFlag[];
  searchText: string;
}

export interface ContentStatusDecision {
  status: 'visible' | 'pending_review';
  statusReason: string | null;
}

/**
 * Statut de naissance d'un contenu de membre (§9.1) : un seul drapeau suffit
 * pour l'« attente de revue ». Le compte à e-mail jetable seul a son motif.
 */
export function statusForFlags(flags: readonly FilterFlag[]): ContentStatusDecision {
  if (!flags.length) return { status: 'visible', statusReason: null };
  if (flags.every((f) => f === 'disposable_email')) {
    return { status: 'pending_review', statusReason: 'new_account_review' };
  }
  return { status: 'pending_review', statusReason: 'auto_filter' };
}

/** Lignes `CommunityMention` à créer pour un contenu. */
export function mentionRows(mentions: readonly ResolvedEntity[]) {
  return mentions.map((m) => ({
    entityType: m.type,
    entityId: m.id,
    labelFr: m.labelFr,
    labelEn: m.labelEn,
    countryId: m.countryId,
    levels: m.levels,
  }));
}

/**
 * Prépare un contenu avant écriture : mentions validées contre le catalogue
 * public et libellés canoniques, hashtags (publications), filtre anti-arnaque
 * (membres seulement), texte cherchable.
 */
@Injectable()
export class CommunityComposerService {
  constructor(
    private readonly catalog: CommunityCatalogService,
    private readonly filterConfig: CommunityFilterConfigService,
  ) {}

  async prepare(input: {
    title?: string | null;
    body: string;
    isPost: boolean;
    /** Contenu de membre : passe le filtre. L'équipe n'est jamais filtrée. */
    authorEmail: string | null;
    now?: Date;
  }): Promise<PreparedContent> {
    const now = input.now ?? new Date();
    const title = input.title?.trim() ?? null;
    const rawBody = input.body.trim();

    const refs = extractMentionRefs(rawBody);
    if (refs.length > COMMUNITY_LIMITS.mentionsPerContent) {
      throw CommunityErrors.tooManyMentions(COMMUNITY_LIMITS.mentionsPerContent);
    }
    const resolved = await this.catalog.resolveEntities(refs, now);
    for (const ref of refs) {
      if (!resolved.has(mentionKey(ref.type, ref.id))) throw CommunityErrors.invalidMention(ref.type, ref.id);
    }
    const mentions = refs.map((r) => resolved.get(mentionKey(r.type, r.id))!);
    const body = canonicalizeMentionTokens(
      rawBody,
      new Map(mentions.map((m) => [mentionKey(m.type, m.id), m.labelFr])),
    );

    const hashtags = input.isPost ? extractHashtags(`${title ?? ''}\n${body}`) : [];
    if (hashtags.length > COMMUNITY_LIMITS.hashtagsPerPost) {
      throw CommunityErrors.tooManyHashtags(COMMUNITY_LIMITS.hashtagsPerPost);
    }

    let flags: FilterFlag[] = [];
    if (input.authorEmail !== null) {
      flags = await this.filterConfig.scan(`${title ?? ''}\n${body}`, now);
      if (isDisposableEmail(input.authorEmail)) flags = [...flags, 'disposable_email'];
    }

    return {
      title,
      body,
      mentions,
      hashtags,
      flags,
      searchText: input.isPost
        ? communitySearchText({ title: title ?? '', body, hashtags, mentionLabels: mentions })
        : '',
    };
  }

  /** Écrit les hashtags d'une publication (création des étiquettes au besoin). */
  async writeHashtags(
    tx: Prisma.TransactionClient,
    postId: string,
    hashtags: readonly HashtagRef[],
  ): Promise<void> {
    await tx.communityPostHashtag.deleteMany({ where: { postId } });
    for (const h of hashtags) {
      const tag = await tx.communityHashtag.upsert({
        where: { tag: h.tag },
        create: { tag: h.tag, display: h.display },
        update: {},
      });
      await tx.communityPostHashtag.create({ data: { postId, hashtagId: tag.id } });
    }
  }
}
