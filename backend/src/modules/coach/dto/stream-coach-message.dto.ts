import { Type } from 'class-transformer';
import {
  IsArray,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';

/**
 * Profil joint au message du coach. Tous les champs sont facultatifs : le
 * service ne garde de toute façon que des valeurs du bon type
 * (`sanitizeCoachProfile`) et ne transmet jamais le nom au modèle.
 */
export class CoachStreamProfileDto {
  @IsOptional()
  @IsString()
  fullName?: string;

  @IsOptional()
  @IsString()
  currentLevel?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  targetCountryIds?: string[];

  @IsOptional()
  @IsString()
  preferredLanguage?: string;

  @IsOptional()
  @IsNumber()
  annualTuitionBudgetEur?: number;

  @IsOptional()
  @IsNumber()
  monthlyBudgetEur?: number;
}

/**
 * Corps de `POST /coach/conversations/:id/messages/stream`.
 *
 * Le message libre de l'élève voyage dans le CORPS de la requête, jamais
 * dans l'URL : une query string finit dans les journaux d'accès des proxys,
 * du CDN et de l'hébergeur (audit 22/11/2026, constat 33).
 *
 * Pas de `@MaxLength` ici : un message vide ou trop long reçoit, comme sur la
 * route GET, l'événement SSE `invalid_message` que l'app sait afficher.
 */
export class StreamCoachMessageDto {
  @IsOptional()
  @IsString()
  message?: string;

  @IsOptional()
  @IsObject()
  @ValidateNested()
  @Type(() => CoachStreamProfileDto)
  profile?: CoachStreamProfileDto;
}
