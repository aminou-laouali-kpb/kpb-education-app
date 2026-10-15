import { IsBoolean } from 'class-validator';

/** `PUT /scholarships/match/alerts` : l'opt-in explicite au push hebdomadaire. */
export class UpdateMatchAlertsDto {
  @IsBoolean()
  enabled!: boolean;
}
