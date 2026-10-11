import {
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateAppointmentDto {
  @IsString()
  @MaxLength(120)
  title!: string;

  // Non vide : `caseId: ""` sautait la vérification de propriété (test
  // `if (input.caseId)`) puis échouait en violation de clé étrangère.
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  caseId!: string;

  @IsISO8601()
  scheduledAt!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  contactMethod?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}
