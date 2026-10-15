import { IsBoolean } from 'class-validator';

/**
 * `PATCH /me/scholarship-alerts/:scholarshipId` (builds récentes).
 *
 * `false` met l'annonce d'ouverture de CETTE bourse en sourdine : elle reste
 * suivie (rappels de date limite, liste des bourses suivies). `true` vaut la
 * cloche allumée.
 */
export class UpdateScholarshipAlertDto {
  @IsBoolean()
  notifyOpening!: boolean;
}
