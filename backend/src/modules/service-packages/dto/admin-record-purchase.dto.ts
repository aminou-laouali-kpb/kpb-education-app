import {
  IsBoolean,
  IsEmail,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

/** Vente saisie par l'équipe (élève passé par WhatsApp sans l'app). */
export class AdminRecordPurchaseDto {
  /** L'e-mail du compte KPB de l'élève. */
  @IsEmail()
  @MaxLength(320)
  email!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  packageCode!: string;

  /** `paid` si le reçu est déjà vérifié ; `pending_payment` sinon. */
  @IsOptional()
  @IsIn(['pending_payment', 'paid'])
  status?: 'pending_payment' | 'paid';

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;

  /**
   * Confirmé après l'alerte de doublon : un élève peut réellement acheter deux
   * fois le même service. Absent ou faux, une vente ouverte bloque (409).
   */
  @IsOptional()
  @IsBoolean()
  allowDuplicate?: boolean;
}
