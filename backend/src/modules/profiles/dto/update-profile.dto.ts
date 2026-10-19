import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Validate,
} from 'class-validator';

import { MinimumAccountAgeConstraint } from '../profile-age.policy';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  fullName?: string;

  // Accepté puis IGNORÉ : l'email du profil est l'identité d'authentification
  // (Supabase), `updateMe` ne l'écrit jamais. Il était validé `@IsEmail()`,
  // or les apps déjà publiées envoient `email: ''` (profil créé par « Passer »
  // l'onboarding) ou ce que l'étudiant a tapé à la main (« x@gmail ») : le
  // PATCH entier partait en 400, l'app gardait le patch en attente et sautait
  // indéfiniment le rapatriement du profil serveur — l'email restait vide,
  // « Email » restait dans les manques à 100 %, et plus aucune modification
  // du profil n'atteignait le serveur. Un champ ignoré ne doit pas pouvoir
  // faire échouer la requête.
  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsString()
  whatsApp?: string;

  @IsOptional()
  @IsString()
  countryOfResidence?: string;

  @IsOptional()
  @IsString()
  preferredLanguage?: string;

  @IsOptional()
  @IsString()
  currentLevel?: string;

  @IsOptional()
  @IsString()
  targetLevel?: string;

  @IsOptional()
  @IsString()
  languageLevel?: string;

  @IsOptional()
  @IsArray()
  fieldIds?: string[];

  @IsOptional()
  @IsArray()
  targetCountryIds?: string[];

  @IsOptional()
  @IsString()
  gradeRange?: string;

  // `null` est une valeur ACCEPTÉE et signifiante : elle demande l'effacement
  // de la série du bac (l'étudiant est passé à un niveau qui n'en a pas).
  // `@IsOptional()` laisse passer `null` comme `undefined` ; c'est le service
  // qui distingue les deux, et le type le dit pour que ce ne soit pas un
  // accident.
  @IsOptional()
  @IsString()
  bacSeries?: string | null;

  @IsOptional()
  @IsInt()
  monthlyBudgetEur?: number;

  @IsOptional()
  @IsInt()
  annualTuitionBudgetEur?: number;

  @IsOptional()
  @IsString()
  preferredCurrency?: string;

  @IsOptional()
  @IsBoolean()
  wantsScholarshipSupport?: boolean;

  // Scholarship-newsletter (Mautic) opt-in. The server stamps
  // newsletterConsentedAt on the false→true transition (GDPR proof) — clients
  // only send the desired boolean.
  @IsOptional()
  @IsBoolean()
  scholarshipNewsletterOptIn?: boolean;

  // « Recevoir par e-mail les nouvelles et offres de KPB » (correctifs 57,
  // XC-06) — distinct de la newsletter bourses. Le serveur horodate
  // promotionsEmailConsentedAt au passage false→true.
  @IsOptional()
  @IsBoolean()
  promotionsEmailOptIn?: boolean;

  // KPB-169: canonical per-type notification opt-outs. Unknown keys are
  // dropped server-side rather than rejected, so a newer client that knows one
  // extra type can still save the types this server does understand.
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  disabledNotificationTypes?: string[];

  // DEPRECATED (KPB-169) — folded into disabledNotificationTypes on write and
  // derived on read. Accepted for clients built before the array existed.
  @IsOptional()
  @IsBoolean()
  dailyScholarshipOptOut?: boolean;

  @IsOptional()
  @IsBoolean()
  weeklyDigestOptOut?: boolean;

  @IsOptional()
  @IsArray()
  availableDocuments?: string[];

  // ISO timestamp when the user granted explicit consent to third-party AI
  // (Groq) processing. Set once the user opts into the AI coach.
  @IsOptional()
  @IsDateString()
  aiConsentedAt?: string;

  // Age gate + self-attested guardian consent for declared minors (<18).
  @IsOptional()
  @IsDateString()
  @Validate(MinimumAccountAgeConstraint)
  birthDate?: string;

  @IsOptional()
  @IsString()
  guardianName?: string;

  @IsOptional()
  @IsString()
  guardianContact?: string;

  @IsOptional()
  @IsDateString()
  guardianConsentedAt?: string;
}
