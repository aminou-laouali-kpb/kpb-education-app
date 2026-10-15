import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

/**
 * Profil saisi par l'admin dans « Tester un profil » : les mêmes champs que
 * les réponses du test « Mes 10 bourses ».
 *
 * Validation TOLÉRANTE sur les jetons, comme le test côté élève : chaque
 * valeur est une chaîne libre que le moteur normalise ; un jeton inconnu est
 * abandonné (et signalé dans `dropped`), jamais refusé par une 400. Seule la
 * forme (chaîne, tableau, booléen, date AAAA-MM-JJ) est contrôlée ici.
 */
export class MatchPreviewDto {
  @IsOptional()
  @IsIn(['fr', 'en'])
  lang?: 'fr' | 'en';

  @IsOptional()
  @IsString()
  @MaxLength(64)
  nationalityCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  secondNationalityCode?: string;

  /** Pays de résidence : code ISO3 ou texte libre (« Sénégal », « RDC »…). */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  countryOfResidence?: string;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'birthDate : AAAA-MM-JJ.' })
  birthDate?: string;

  @IsOptional()
  @IsBoolean()
  guardianConsented?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  highestDiploma?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  scholarshipTargetLevel?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  fieldIds?: string[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(30)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  targetCountryIds?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(32)
  gradeBandOn20?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  englishLevel?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  frenchLevel?: string;

  /** [{ type, score, takenAt? }] — lu par la garde du moteur, pas ici. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  languageTests?: unknown[];

  @IsOptional()
  @IsString()
  @MaxLength(32)
  workExperienceBand?: string;

  /**
   * Profil confirmé par l'élève (défaut : oui). Faux : aucune valeur n'exclut,
   * comme pour un élève qui n'a pas validé son récapitulatif.
   */
  @IsOptional()
  @IsBoolean()
  confirmed?: boolean;

  /**
   * Une bourse à évaluer en plus, publique ou NON (la fiche en cours
   * d'édition) : rendue à part dans `focus`, jamais mêlée aux résultats.
   */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  focusScholarshipId?: string;
}
