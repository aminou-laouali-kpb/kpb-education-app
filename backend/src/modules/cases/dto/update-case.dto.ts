import { IsEnum, IsISO8601, IsOptional, IsString, MaxLength } from 'class-validator';

import { CaseStatus } from '../../../common/enums/case-status.enum';

export class UpdateCaseDto {
  @IsOptional()
  @IsEnum(CaseStatus)
  status?: CaseStatus;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  nextStepTitle?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  nextStepDescription?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  assignedAdvisorName?: string;

  @IsOptional()
  @IsISO8601()
  scheduledAt?: string;
}
