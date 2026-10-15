import { ArrayMaxSize, IsArray, IsString, MaxLength } from 'class-validator';

/**
 * `POST /me/scholarship-alerts` (« Suivre les N compatibles » de « Mes 10
 * bourses ») : la cloche allumée sur au plus dix bourses, en un appel.
 */
export class BulkScholarshipAlertsDto {
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  scholarshipIds!: string[];
}
