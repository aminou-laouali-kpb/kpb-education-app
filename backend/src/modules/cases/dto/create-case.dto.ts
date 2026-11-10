import { Transform } from 'class-transformer';
import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';

import { CaseType } from '../../../common/enums/case-type.enum';

export const CASE_TITLE_MAX = 120;
export const CASE_DESCRIPTION_MAX = 8000;
export const CASE_CONTEXT_LABEL_MAX = 160;

/**
 * Coupe un texte trop long au lieu de laisser la validation le refuser.
 *
 * Une demande d'accompagnement est le parcours de conversion de KPB. Avant,
 * un récit de plus de 2 000 caractères (la dictée vocale y arrive vite) ou un
 * intitulé de formation de plus de 120 recevait un 400 : l'app avait déjà
 * affiché « transmise à l'équipe », réessayait sans fin, et aucun conseiller
 * ne recevait rien (audit avant la 59). Un texte tronqué arrive ; un texte
 * refusé n'arrive jamais. Les apps déjà installées n'ont aucune limite de
 * saisie : c'est donc au serveur de ne plus refuser.
 *
 * La coupe ne laisse pas une moitié de paire de substitution (un émoji coupé
 * en deux) en fin de texte.
 */
export function clampCaseText(value: unknown, max: number): unknown {
  if (typeof value !== 'string' || value.length <= max) return value;
  let cut = value.slice(0, max);
  const last = cut.charCodeAt(cut.length - 1);
  if (last >= 0xd800 && last <= 0xdbff) cut = cut.slice(0, -1);
  return cut;
}

export class CreateCaseDto {
  @IsEnum(CaseType)
  type!: CaseType;

  @Transform(({ value }) => clampCaseText(value, CASE_TITLE_MAX))
  @IsString()
  @MaxLength(CASE_TITLE_MAX)
  title!: string;

  @Transform(({ value }) => clampCaseText(value, CASE_DESCRIPTION_MAX))
  @IsString()
  @MaxLength(CASE_DESCRIPTION_MAX)
  description!: string;

  @Transform(({ value }) => clampCaseText(value, CASE_CONTEXT_LABEL_MAX))
  @IsString()
  @MaxLength(CASE_CONTEXT_LABEL_MAX)
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
