import {
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

import {
  ACADEMIC_YEAR_PATTERN,
  IsAcademicYear,
} from '../../../common/academic-year';

export class ActivateScholarshipDto {
  // La forme et son message sont le contrat des admins déjà déployés ;
  // `@IsAcademicYear` refuse en plus deux années non consécutives (« 2027-2029 »
  // créerait un second cycle, donc une seconde annonce aux mêmes étudiants).
  @IsString()
  @Matches(ACADEMIC_YEAR_PATTERN, {
    message: 'academicYear must look like 2026 or 2026-2027',
  })
  @IsAcademicYear()
  academicYear!: string;

  @IsDateString()
  opensAt!: string;

  @IsDateString()
  closesAt!: string;

  @IsOptional()
  @IsDateString()
  estimatedOpenAt?: string;

  @IsOptional()
  @IsDateString()
  estimatedCloseAt?: string;

  @IsOptional()
  @IsIn(['confirmed'])
  dateConfidence?: 'confirmed';

  @IsOptional()
  @IsUrl({ require_protocol: true })
  @MaxLength(2000)
  sourceUrl?: string;

  // ── Annonce d'ouverture (chantier C) ──────────────────────────────────────
  // Nouveaux champs : un backend plus ancien les REFUSE (`forbidNonWhitelisted`),
  // d'où l'ordre de déploiement, backend puis admin. Absents, le comportement
  // d'avant est gardé (annonce à la première activation seulement).

  /** `true` : annoncer ; `false` : « Enregistrer les dates sans prévenir ». */
  @IsOptional()
  @IsBoolean()
  notify?: boolean;

  /**
   * Le `toNotify` que l'équipe a vu à l'aperçu et confirmé. Exigé au-delà du
   * seuil ; une audience qui a trop grossi depuis est refusée (409).
   */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  expectedRecipients?: number;
}
