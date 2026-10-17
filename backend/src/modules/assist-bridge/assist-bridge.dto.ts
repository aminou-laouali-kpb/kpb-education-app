import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min } from 'class-validator';

import { COMMUNITY_PAGINATION } from '../community/community.constants';
import { ASSIST_NEED_IDS } from './assist-bridge.rules';
import { ASSIST_ACTIONS, ASSIST_LIST_STATUSES, ASSIST_SOURCES } from './assist-bridge.service';

/** `POST /me/assist-bridge/events/:id` — ce que l'élève a fait de la suggestion. */
export class AssistActionDto {
  @IsIn(ASSIST_ACTIONS)
  action!: (typeof ASSIST_ACTIONS)[number];
}

export class AssistStatsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(365)
  days?: number;
}

export class AssistEventsQueryDto {
  @IsOptional()
  @IsIn(ASSIST_LIST_STATUSES)
  status?: (typeof ASSIST_LIST_STATUSES)[number];

  @IsOptional()
  @IsIn(ASSIST_NEED_IDS)
  needId?: string;

  @IsOptional()
  @IsIn(ASSIST_SOURCES)
  source?: (typeof ASSIST_SOURCES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(600)
  @Matches(/^[A-Za-z0-9_-]+$/)
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(COMMUNITY_PAGINATION.maxLimit)
  limit?: number;
}
