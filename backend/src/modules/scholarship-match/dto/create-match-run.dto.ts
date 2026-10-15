import { IsBoolean, IsObject, IsOptional, IsString } from 'class-validator';

/**
 * `POST /scholarships/match/runs`.
 *
 * TOLÉRANT par construction : chaque champ est facultatif, `lang` et `trigger`
 * sont normalisés par le service (valeur inconnue → défaut), et `answers` est
 * un simple objet lu par `parseMatchAnswers` — une clé ou un jeton inconnus y
 * sont abandonnés, jamais refusés. Un DTO imbriqué validerait `answers` sous
 * `forbidNonWhitelisted` et répondrait 400 à une clé qu'une app plus récente
 * connaît et que ce serveur ne connaît pas.
 *
 * Ces réponses ne voyagent JAMAIS dans le PATCH du profil complet : un 400 y
 * bloquerait la synchronisation du profil (voir update-profile.dto.ts).
 */
export class CreateMatchRunDto {
  @IsOptional()
  @IsString()
  lang?: string;

  @IsOptional()
  @IsString()
  trigger?: string;

  @IsOptional()
  @IsObject()
  answers?: Record<string, unknown>;

  @IsOptional()
  @IsBoolean()
  confirm?: boolean;
}
