import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

import { COMMUNITY_LIMITS, COMMUNITY_PAGINATION } from '../community.constants';

// Les bornes de longueur fines (titre 8–120, corps 20–5 000…) sont vérifiées
// par le service sur le texte ÉPURÉ des espaces de bord ; ici, des plafonds
// larges qui empêchent seulement d'envoyer un mégaoctet.

export const POST_TYPES = ['question', 'experience', 'advice'] as const;
export const ENTITY_TYPES = ['scholarship', 'country', 'institution', 'program'] as const;
export const REPORT_TARGETS = ['post', 'reply', 'member'] as const;
export const REPORT_REASONS = [
  'scam',
  'harassment',
  'inappropriate',
  'spam',
  'personal_info',
  'misinformation',
  'other',
] as const;

class LangQuery {
  @IsOptional()
  @IsIn(['fr', 'en'])
  lang?: 'fr' | 'en';
}

export class LangQueryDto extends LangQuery {}

export class PageQueryDto extends LangQuery {
  @IsOptional()
  @IsString()
  @MaxLength(600)
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(COMMUNITY_PAGINATION.maxLimit)
  limit?: number;
}

export class RepliesQueryDto extends LangQuery {
  @IsOptional()
  @IsString()
  @MaxLength(600)
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(COMMUNITY_PAGINATION.repliesMaxLimit)
  limit?: number;
}

export class FeedQueryDto extends PageQueryDto {
  @IsIn(['for_you', 'recent', 'unanswered'])
  tab!: 'for_you' | 'recent' | 'unanswered';

  @IsOptional()
  @IsIn(POST_TYPES)
  type?: (typeof POST_TYPES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(41)
  hashtag?: string;
}

export class EntitySpaceQueryDto extends PageQueryDto {
  @IsOptional()
  @IsIn(['recent', 'unanswered'])
  sort?: 'recent' | 'unanswered';
}

export class EntityCountsQueryDto {
  @IsString()
  @MaxLength(4000)
  refs!: string;
}

export class SearchQueryDto extends PageQueryDto {
  @IsString()
  @MinLength(COMMUNITY_LIMITS.searchMin)
  @MaxLength(COMMUNITY_LIMITS.searchMax)
  q!: string;

  @IsOptional()
  @IsIn(POST_TYPES)
  type?: (typeof POST_TYPES)[number];
}

export class MentionSuggestQueryDto extends LangQuery {
  @IsString()
  @MinLength(1)
  @MaxLength(60)
  q!: string;

  @IsOptional()
  @IsString()
  @Matches(/^(scholarship|country|institution|program)(,(scholarship|country|institution|program))*$/)
  types?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(COMMUNITY_PAGINATION.suggestMaxLimit)
  limit?: number;
}

export class HashtagSuggestQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(41)
  q?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(COMMUNITY_PAGINATION.suggestMaxLimit)
  limit?: number;
}

export class AcceptCharterDto {
  @IsString()
  @MaxLength(40)
  version!: string;
}

export class CreatePostDto {
  @IsIn(POST_TYPES)
  type!: (typeof POST_TYPES)[number];

  @IsString()
  @MaxLength(COMMUNITY_LIMITS.titleMax + 200)
  title!: string;

  @IsString()
  @MaxLength(COMMUNITY_LIMITS.postBodyMax + 1000)
  body!: string;
}

export class UpdatePostDto {
  @IsOptional()
  @IsIn(POST_TYPES)
  type?: (typeof POST_TYPES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(COMMUNITY_LIMITS.titleMax + 200)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(COMMUNITY_LIMITS.postBodyMax + 1000)
  body?: string;
}

export class ReplyBodyDto {
  @IsString()
  @MaxLength(COMMUNITY_LIMITS.replyBodyMax + 1000)
  body!: string;
}

export class CreateReportDto {
  @IsIn(REPORT_TARGETS)
  targetType!: (typeof REPORT_TARGETS)[number];

  @IsString()
  @Matches(/^[A-Za-z0-9_-]{1,64}$/)
  targetId!: string;

  @IsIn(REPORT_REASONS)
  reason!: (typeof REPORT_REASONS)[number];

  @IsOptional()
  @IsString()
  @MaxLength(COMMUNITY_LIMITS.reportDetailsMax)
  details?: string;
}

// ── Admin ───────────────────────────────────────────────────────────────────

export class QueueQueryDto extends PageQueryDto {
  @IsOptional()
  @IsIn(['all', 'auto_hidden', 'reported', 'members'])
  kind?: 'all' | 'auto_hidden' | 'reported' | 'members';
}

export class AdminPostsQueryDto extends PageQueryDto {
  @IsOptional()
  @IsIn(['visible', 'pending_review', 'hidden', 'deleted'])
  status?: 'visible' | 'pending_review' | 'hidden' | 'deleted';

  @IsOptional()
  @IsIn(POST_TYPES)
  type?: (typeof POST_TYPES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(COMMUNITY_LIMITS.searchMax)
  q?: string;
}

export class SanctionsQueryDto extends PageQueryDto {
  @IsOptional()
  @IsIn(['active', 'all'])
  status?: 'active' | 'all';
}

export class StatsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  days?: number;
}

export class ContentActionDto {
  @IsIn(['restore', 'hide', 'delete', 'dismiss_reports'])
  action!: 'restore' | 'hide' | 'delete' | 'dismiss_reports';

  @IsString()
  @MinLength(COMMUNITY_LIMITS.adminReasonMin)
  @MaxLength(COMMUNITY_LIMITS.adminReasonMax)
  reason!: string;

  @IsOptional()
  @IsBoolean()
  notifyAuthor?: boolean;
}

export class CreateSanctionDto {
  @IsIn(['warning', 'read_only', 'ban'])
  kind!: 'warning' | 'read_only' | 'ban';

  @IsString()
  @MinLength(COMMUNITY_LIMITS.adminReasonMin)
  @MaxLength(COMMUNITY_LIMITS.adminReasonMax)
  reason!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(365)
  durationDays?: number;

  @IsOptional()
  @IsBoolean()
  hideContent?: boolean;
}

export class ReasonDto {
  @IsString()
  @MinLength(COMMUNITY_LIMITS.adminReasonMin)
  @MaxLength(COMMUNITY_LIMITS.adminReasonMax)
  reason!: string;
}

export class TeamReplyDto {
  @IsString()
  @MaxLength(COMMUNITY_LIMITS.replyBodyMax + 1000)
  body!: string;

  @IsIn(['kpb_team', 'kpb_advisor'])
  as!: 'kpb_team' | 'kpb_advisor';

  @IsOptional()
  @IsBoolean()
  verified?: boolean;
}

export class TeamPostDto {
  @IsIn(POST_TYPES)
  type!: (typeof POST_TYPES)[number];

  @IsString()
  @MaxLength(COMMUNITY_LIMITS.titleMax + 200)
  title!: string;

  @IsString()
  @MaxLength(COMMUNITY_LIMITS.postBodyMax + 1000)
  body!: string;

  @IsIn(['kpb_team', 'kpb_advisor'])
  as!: 'kpb_team' | 'kpb_advisor';

  @IsOptional()
  @IsBoolean()
  pinned?: boolean;
}

export class VerifiedDto {
  @IsBoolean()
  verified!: boolean;
}

export class PinDto {
  @IsBoolean()
  pinned!: boolean;
}

export class FilterEntryDto {
  @IsIn(['allowed_domain', 'blocked_term'])
  kind!: 'allowed_domain' | 'blocked_term';

  @IsString()
  @MaxLength(260)
  value!: string;
}

export class FilterTestDto {
  @IsString()
  @MaxLength(COMMUNITY_LIMITS.postBodyMax)
  text!: string;
}
