import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

import {
  READ_BY_REF_MAX_LENGTH,
  READ_BY_REF_MAX_REFS,
  READ_BY_REF_PATTERN,
} from '../opening/scholarship-opening.contract';

/**
 * `POST /me/notifications/read-by-ref` : marque lues les entrées d'inbox
 * qu'un push groupé a annoncées. Une référence est une `dedupeKey` sans son
 * suffixe `:<userId>` (ex. `scholarship-opened:<cycleId>`) ; le serveur
 * rajoute l'identifiant de l'étudiant connecté, jamais celui d'un autre.
 */
export class ReadNotificationsByRefDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(READ_BY_REF_MAX_REFS)
  @IsString({ each: true })
  @MaxLength(READ_BY_REF_MAX_LENGTH, { each: true })
  @Matches(READ_BY_REF_PATTERN, { each: true })
  refs!: string[];
}
