import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

import { PublicationStatus } from '../../../common/enums/publication-status.enum';
import { ACADEMY_SLUG_PATTERN } from './academy-course.dto';

export class ImportAcademyLessonDto {
  /** Position dans le cours (1, 2, 3…), telle que le manifeste la donne. */
  @IsInt()
  @Min(1)
  @Max(1000)
  order!: number;

  @IsUrl({ require_protocol: true, protocols: ['https'] })
  @IsNotEmpty()
  @MaxLength(2000)
  youtubeUrl!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  titleFr!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  titleEn?: string;

  @IsInt()
  @Min(1)
  @Max(86400)
  durationSeconds!: number;

  /**
   * Absent (le cas du manifeste produit par HyperFrames) : une leçon créée est
   * `published`, une leçon existante GARDE son statut. Un réimport ne doit pas
   * republier une leçon qu'on a retenue à la main.
   */
  @IsOptional()
  @IsEnum(PublicationStatus)
  status?: PublicationStatus;

  /** Absent : `false` à la création, inchangé sur une leçon existante. */
  @IsOptional()
  @IsBoolean()
  isFreePreview?: boolean;
}

/**
 * Un module du manifeste = un cours, identifié par son `slug`.
 *
 * Idempotent : rejouer le même manifeste ne change rien. Pas de `status` de
 * cours : un cours créé par import naît en brouillon, un cours existant garde
 * le sien. Publier reste un geste fait dans l'admin, après relecture.
 */
export class ImportAcademyCourseDto {
  @IsString()
  @Matches(ACADEMY_SLUG_PATTERN)
  @MaxLength(80)
  slug!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  titleFr!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  titleEn?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  descriptionFr?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  descriptionEn?: string;

  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['https'] })
  @MaxLength(2000)
  coverImageUrl?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000)
  displayOrder?: number;

  /** Absent : `false` à la création, inchangé sur un cours existant. */
  @IsOptional()
  @IsBoolean()
  requiresPass?: boolean;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => ImportAcademyLessonDto)
  lessons!: ImportAcademyLessonDto[];
}
