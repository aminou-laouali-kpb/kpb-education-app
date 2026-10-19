import {
  IsArray,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

import { AUDIENCE_TYPES } from '../campaign-audience';
import { CAMPAIGN_PURPOSES } from '../campaign-purpose';

export class CreateNotificationCampaignDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsString()
  templateId?: string | null;

  /**
   * Doit rester ALIGNÉ sur les branches de `CampaignExecutorService
   * .resolveRecipients` — un test le vérifie dans les deux sens.
   *
   * Trois audiences étaient implémentées et inatteignables : `account_type`,
   * `study_level` et `country_of_residence` existaient dans l'exécuteur mais
   * pas ici, donc les demander rendait 400. À l'inverse, une valeur acceptée
   * ici sans branche dans l'exécuteur produirait 0 destinataire en silence.
   */
  @IsOptional()
  @IsIn(AUDIENCE_TYPES)
  audienceType?: string;

  @IsOptional()
  @IsObject()
  filters?: Record<string, unknown>;

  /**
   * `informational` (message de service) ou `promotional` (offre, mise en
   * avant, annonce marketing). Absent ⇒ `promotional` : le défaut prudent
   * d'un texte libre (XC-06, `campaign-purpose.ts`).
   */
  @IsOptional()
  @IsIn(CAMPAIGN_PURPOSES)
  purpose?: 'informational' | 'promotional';

  @IsOptional()
  @IsArray()
  @IsIn(['push', 'in_app', 'email'], { each: true })
  channels?: ('push' | 'in_app' | 'email')[];

  @IsOptional()
  @IsString()
  scheduledFor?: string | null;

  @IsOptional()
  @IsString()
  linkedCaseId?: string | null;

  /**
   * Écran ouvert au tap, sous la forme d'une route interne de l'app
   * (`/scholarships/<id>`, `/parcours/<slug>`, `/etudes-en-france`…).
   *
   * Sans elle, une campagne « nouvelle bourse » ouvrait l'accueil : l'élève
   * devait retrouver seul la bourse annoncée. L'app normalise la route et
   * retombe sur l'accueil si elle n'est pas navigable.
   */
  @IsOptional()
  @IsString()
  @MaxLength(200)
  @Matches(/^\/[A-Za-z0-9\-_/]*$/, {
    message: 'route doit être une route interne commençant par « / ».',
  })
  route?: string | null;
}
