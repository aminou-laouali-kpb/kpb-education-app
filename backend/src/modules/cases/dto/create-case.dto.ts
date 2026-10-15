import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';

import { CaseType } from '../../../common/enums/case-type.enum';

export class CreateCaseDto {
  @IsEnum(CaseType)
  type!: CaseType;

  @IsString()
  @MaxLength(120)
  title!: string;

  @IsString()
  @MaxLength(2000)
  description!: string;

  @IsString()
  @MaxLength(160)
  contextLabel!: string;

  @IsOptional()
  @IsString()
  preferredContactMethod?: string;

  /**
   * « Être accompagné par KPB » depuis « Mes 10 bourses » : la bourse dont ce
   * dossier accompagne la candidature. Gardée seulement si la fiche existe
   * (sinon le dossier est créé sans lien, jamais refusé).
   */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  scholarshipId?: string;
}
