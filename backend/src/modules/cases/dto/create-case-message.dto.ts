import {
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

export const MAX_CASE_MESSAGE_LENGTH = 3000;

/// Identifiant client d'un message : court, sans espace ni caractère spécial
/// (l'app envoie l'id de sa bulle, `user-<microsecondes>`).
export const CLIENT_MESSAGE_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

// senderRole and senderName are intentionally absent: students must not choose
// their own role. The service defaults to 'student'. Staff messages arrive via
// the WebSocket gateway (CaseMessagingGateway) where the role is derived from
// the authenticated connection, not from the payload.
export class CreateCaseMessageDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/\S/)
  @MaxLength(MAX_CASE_MESSAGE_LENGTH)
  body!: string;

  /// Optionnel : un renvoi avec le même identifiant dans le même dossier rend
  /// le message déjà créé (idempotence). Les anciennes apps ne l'envoient pas.
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(CLIENT_MESSAGE_ID_PATTERN)
  clientMessageId?: string;
}
