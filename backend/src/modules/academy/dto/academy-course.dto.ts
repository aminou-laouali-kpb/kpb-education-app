import {
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
} from 'class-validator';

import { PublicationStatus } from '../../../common/enums/publication-status.enum';

/** `hsk-1`, `preparation-csc` : minuscules, chiffres, tirets simples. */
export const ACADEMY_SLUG_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

/**
 * Création d'un cours. Pas de prix : l'app n'a aucun parcours d'achat (voir
 * `app.module.ts`, lancement « conseiller WhatsApp uniquement »). Un prix saisi
 * ici ne verrouillerait rien et ferait croire le contraire : les cours créés
 * par cette API sont gratuits (0 / 0).
 */
export class CreateAcademyCourseDto {
  @IsString()
  @Matches(ACADEMY_SLUG_PATTERN)
  @MaxLength(80)
  slug!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  titleFr!: string;

  /** Vide ou absent : le titre français est repris. */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  titleEn?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  descriptionFr?: string;

  /** Vide ou absent : la description française est reprise. */
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  descriptionEn?: string;

  /** Absente : l'app prend la miniature de la première leçon publiée. */
  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['https'] })
  @MaxLength(2000)
  coverImageUrl?: string | null;

  /** `draft` par défaut : publier est un geste explicite. */
  @IsOptional()
  @IsEnum(PublicationStatus)
  status?: PublicationStatus;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000)
  displayOrder?: number;

  /** Réservé au Pass Karatou : sans Pass, seules les leçons « aperçu » se lisent. */
  @IsOptional()
  @IsBoolean()
  requiresPass?: boolean;
}

export class UpdateAcademyCourseDto {
  @IsOptional()
  @IsString()
  @Matches(ACADEMY_SLUG_PATTERN)
  @MaxLength(80)
  slug?: string;

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
  @IsString()
  @MaxLength(4000)
  descriptionFr?: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  descriptionEn?: string;

  /** `null` retire la couverture. */
  @IsOptional()
  @IsUrl({ require_protocol: true, protocols: ['https'] })
  @MaxLength(2000)
  coverImageUrl?: string | null;

  @IsOptional()
  @IsEnum(PublicationStatus)
  status?: PublicationStatus;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1000)
  displayOrder?: number;

  /** Réservé au Pass Karatou : sans Pass, seules les leçons « aperçu » se lisent. */
  @IsOptional()
  @IsBoolean()
  requiresPass?: boolean;
}
