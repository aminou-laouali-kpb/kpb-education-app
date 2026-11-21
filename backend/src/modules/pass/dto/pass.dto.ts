import {
  IsEmail,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/** Référence de la transaction mobile money (Orange, Wave, Moov…). */
const REFERENCE_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._\-/ ]{2,119}$/;

class PassGrantFields {
  /** L'e-mail avec lequel l'élève s'est connecté à l'app. */
  @IsEmail()
  @MaxLength(320)
  email!: string;

  @IsInt()
  @Min(1)
  @Max(730)
  durationDays!: number;

  @IsString()
  @Matches(REFERENCE_PATTERN)
  paymentReference!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10_000_000)
  amountXof?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

/** Corps envoyé par n8n quand un commercial valide un paiement. */
export class PassWebhookGrantDto extends PassGrantFields {
  /** Nom ou e-mail du commercial qui a vérifié le paiement. */
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  salesAgent!: string;
}

/** Même geste depuis la console (secours si n8n est en panne). */
export class AdminPassGrantDto extends PassGrantFields {}

export class RevokePassDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason!: string;
}
