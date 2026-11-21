import {
  ArrayMaxSize,
  ArrayNotEmpty,
  ArrayUnique,
  IsArray,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUrl,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

import { PublicationStatus } from '../../../common/enums/publication-status.enum';

/**
 * Ajout d'une leçon : elle se place à la fin du cours. L'ordre se change
 * ensuite avec `PUT …/lessons/order`, qui renumérote tout le cours d'un coup.
 */
export class CreateAcademyLessonDto {
  /** Toute forme YouTube (watch, youtu.be, embed, shorts, live) en HTTPS. */
  @IsUrl({ require_protocol: true, protocols: ['https'] })
  @IsNotEmpty()
  @MaxLength(2000)
  youtubeUrl!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  titleFr!: string;

  /** Vide ou absent : le titre français est repris. */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  titleEn?: string;

  @IsInt()
  @Min(1)
  @Max(86400)
  durationSeconds!: number;

  /** `published` par défaut : le statut du cours suffit à tout retenir. */
  @IsOptional()
  @IsEnum(PublicationStatus)
  status?: PublicationStatus;
}

export class UpdateAcademyLessonDto {
  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['https'] })
  @IsNotEmpty()
  @MaxLength(2000)
  youtubeUrl?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  titleFr?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  titleEn?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(86400)
  durationSeconds?: number;

  @IsOptional()
  @IsEnum(PublicationStatus)
  status?: PublicationStatus;
}

/**
 * Nouvel ordre complet des leçons d'un cours : EXACTEMENT les identifiants du
 * cours, chacun une fois. Une liste partielle serait ambiguë (où vont les
 * absentes ?) : le serveur la refuse au lieu de deviner.
 */
export class ReorderAcademyLessonsDto {
  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(500)
  @ArrayUnique()
  @IsString({ each: true })
  lessonIds!: string[];
}
