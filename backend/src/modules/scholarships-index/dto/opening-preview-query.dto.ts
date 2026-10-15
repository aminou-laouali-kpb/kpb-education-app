import { IsDateString, IsOptional, IsString, Matches } from 'class-validator';

import {
  ACADEMIC_YEAR_PATTERN,
  IsAcademicYear,
} from '../../../common/academic-year';

/**
 * `GET /admin/scholarships/:id/opening-preview` — tout est facultatif. Sans
 * `academicYear`, le serveur choisit l'année (`defaultOpeningAcademicYear`) ;
 * les dates saisies dans le formulaire remplacent celles du cycle pour la
 * vérification de complétude et la copie du message.
 */
export class OpeningPreviewQueryDto {
  @IsOptional()
  @IsString()
  @Matches(ACADEMIC_YEAR_PATTERN, {
    message: 'academicYear must look like 2026 or 2026-2027',
  })
  @IsAcademicYear()
  academicYear?: string;

  @IsOptional()
  @IsDateString()
  opensAt?: string;

  @IsOptional()
  @IsDateString()
  closesAt?: string;
}
