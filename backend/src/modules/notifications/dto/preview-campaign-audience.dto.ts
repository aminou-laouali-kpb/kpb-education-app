import { IsArray, IsIn, IsObject, IsOptional } from 'class-validator';

import { AUDIENCE_TYPES } from '../campaign-audience';
import { CAMPAIGN_PURPOSES } from '../campaign-purpose';

export class PreviewCampaignAudienceDto {
  @IsOptional()
  @IsIn(AUDIENCE_TYPES)
  audienceType?: string;

  @IsOptional()
  @IsObject()
  filters?: Record<string, unknown>;

  /** Absent ⇒ `promotional`, comme à la création. */
  @IsOptional()
  @IsIn(CAMPAIGN_PURPOSES)
  purpose?: 'informational' | 'promotional';

  /** Les canaux à compter ; absent ⇒ `push`, comme à la création. */
  @IsOptional()
  @IsArray()
  @IsIn(['push', 'in_app', 'email'], { each: true })
  channels?: ('push' | 'in_app' | 'email')[];
}
