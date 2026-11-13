import { Type } from 'class-transformer';
import {
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

import { CaseStatus } from '../../../common/enums/case-status.enum';

/** Dossiers par page dans la liste de l'administration. */
export const ADMIN_CASES_PAGE_SIZE = 50;
export const ADMIN_CASES_MAX_PAGE_SIZE = 100;

/**
 * `GET /admin/cases` : une page de dossiers, filtrée par le serveur.
 *
 * Tout est facultatif : sans paramètre, la première page des dossiers les
 * plus récents. `cursor` est la valeur `nextCursor` de la page précédente,
 * jamais une valeur fabriquée par le client.
 */
export class ListAdminCasesQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(ADMIN_CASES_MAX_PAGE_SIZE)
  limit?: number;

  @IsOptional()
  @IsEnum(CaseStatus)
  status?: CaseStatus;

  /** Nom du conseiller, tel qu'il est affiché dans la liste. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  advisor?: string;

  /** `true` : seulement les dossiers sans conseiller. */
  @IsOptional()
  @IsIn(['true', 'false'])
  unassigned?: string;

  /** Recherche : référence, titre, nom ou e-mail de l'élève. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  q?: string;

  /** `true` : seulement les dossiers où l'élève attend une réponse. */
  @IsOptional()
  @IsIn(['true', 'false'])
  awaiting?: string;
}
