import { IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * Activation du mode ambassadeur. Le corps était un `Record` non validé : un
 * type non-string donnait une 500, et la taille n'avait pas de limite.
 */
export class ActivateAmbassadorDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  displayName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  campus?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  /** Numéro Wave / mobile money du versement. */
  @IsOptional()
  @IsString()
  @MaxLength(40)
  payoutAccount?: string;
}
