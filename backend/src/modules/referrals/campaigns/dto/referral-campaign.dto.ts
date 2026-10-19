import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsEmail,
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  IsUrl,
  Length,
  Matches,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

/**
 * Corps des routes admin de la compétition ambassadeurs.
 *
 * Les prix (`prizes`) et la règle de qualification (`qualificationRule`) sont
 * des objets libres ici, validés et normalisés par le service
 * (`parsePrizes`, `parseQualificationRule`) : une seule source de vérité.
 */

const LOCAL_DATE = /^\d{4}-\d{2}-\d{2}$/;

export class CreateReferralCampaignDto {
  /** Identifiant d'URL : `kpbeducation.cloud/classement/?c=<slug>`. */
  @IsString()
  @Matches(/^[a-z0-9][a-z0-9-]{2,60}$/, {
    message: 'slug: lettres minuscules, chiffres et tirets (3 à 61 caractères).',
  })
  slug!: string;

  @IsString()
  @Length(1, 120)
  nameFr!: string;

  @IsString()
  @Length(1, 120)
  nameEn!: string;

  /** Premier jour, inclus (AAAA-MM-JJ, dans `timeZone`). */
  @IsString()
  @Matches(LOCAL_DATE)
  startDate!: string;

  /** Dernier jour, INCLUS (AAAA-MM-JJ, dans `timeZone`). */
  @IsString()
  @Matches(LOCAL_DATE)
  endDate!: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  timeZone?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  prizes?: unknown[];

  @IsOptional()
  @IsString()
  @MaxLength(20000)
  rulesText?: string;

  @IsOptional()
  @IsUrl({ protocols: ['https'], require_protocol: true })
  @MaxLength(500)
  rulesUrl?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @IsString({ each: true })
  @MaxLength(80, { each: true })
  eligibleCities?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(60)
  @IsString({ each: true })
  @MaxLength(80, { each: true })
  eligibleCountries?: string[];

  @IsOptional()
  @IsObject()
  qualificationRule?: Record<string, unknown>;
}

export class UpdateReferralCampaignDto {
  @IsOptional()
  @IsString()
  @Length(1, 120)
  nameFr?: string;

  @IsOptional()
  @IsString()
  @Length(1, 120)
  nameEn?: string;

  @IsOptional()
  @IsString()
  @Matches(LOCAL_DATE)
  startDate?: string;

  @IsOptional()
  @IsString()
  @Matches(LOCAL_DATE)
  endDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  timeZone?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  prizes?: unknown[];

  @IsOptional()
  @IsString()
  @MaxLength(20000)
  rulesText?: string;

  /** Chaîne vide = retirer le lien. */
  @IsOptional()
  @IsString()
  @MaxLength(500)
  rulesUrl?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @IsString({ each: true })
  @MaxLength(80, { each: true })
  eligibleCities?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(60)
  @IsString({ each: true })
  @MaxLength(80, { each: true })
  eligibleCountries?: string[];

  @IsOptional()
  @IsObject()
  qualificationRule?: Record<string, unknown>;
}

export class CampaignTransitionDto {
  @IsIn(['launch', 'freeze', 'unfreeze', 'validate_podium', 'close'])
  action!: 'launch' | 'freeze' | 'unfreeze' | 'validate_podium' | 'close';
}

export class EnrollParticipantDto {
  /** Ambassadeur déjà activé (`POST /admin/ambassadors`) : par id… */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  ambassadorId?: string;

  /** … ou par l'e-mail de son compte. */
  @IsOptional()
  @IsEmail()
  @MaxLength(254)
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  publicName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  country?: string;

  @IsOptional()
  @IsIn(['adult', 'minor', 'unknown'])
  minorStatus?: 'adult' | 'minor' | 'unknown';
}

export class UpdateParticipantDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  publicName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  country?: string;

  @IsOptional()
  @IsIn(['active', 'withdrawn', 'disqualified'])
  status?: 'active' | 'withdrawn' | 'disqualified';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  statusReason?: string;

  @IsOptional()
  @IsIn(['adult', 'minor', 'unknown'])
  minorStatus?: 'adult' | 'minor' | 'unknown';

  @IsOptional()
  @IsIn(['not_required', 'pending', 'verified', 'refused'])
  parentalAuthStatus?: 'not_required' | 'pending' | 'verified' | 'refused';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  parentalAuthNote?: string;
}

export class ReferralDecisionDto {
  /** `clear` retire la décision : la ligne retrouve son statut automatique. */
  @IsIn(['validated', 'excluded', 'clear'])
  decision!: 'validated' | 'excluded' | 'clear';

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class RecordPayoutDto {
  /** Référence de la transaction Wave (ou autre moyen). */
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  payoutReference!: string;

  @IsOptional()
  @IsDateString()
  paidAt?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  paidAmountFcfa?: number;

  @IsOptional()
  @IsIn(['ambassador', 'parent'])
  recipient?: 'ambassador' | 'parent';

  @IsOptional()
  @IsIn(['wave', 'orange_money', 'bank_transfer', 'cash', 'other'])
  payoutMethod?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

/**
 * « Déclarer le prix forfait et réattribuer » (correctifs 57). `participantId`
 * est le lauréat que l'équipe voit à l'écran : si le prix a changé de main
 * entre-temps, le serveur refuse au lieu de déclarer forfait quelqu'un d'autre.
 */
export class ForfeitPrizeDto {
  @IsString()
  @Length(1, 64)
  participantId!: string;

  /** Motif (ex. « injoignable 15 jours après la validation »), tracé. */
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

export class ActivateAmbassadorAdminDto {
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @IsString()
  @Length(1, 80)
  city!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  displayName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  campus?: string;
}

export class RevokeAmbassadorDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}
