import {
  Catch,
  HttpStatus,
  Injectable,
  NotFoundException,
  type ArgumentsHost,
  type CanActivate,
  type ExceptionFilter,
} from '@nestjs/common';
import type { Response } from 'express';

/**
 * Le drapeau de « Mes 10 bourses » côté API : `KPB_SCHOLARSHIP_MATCH_ENABLED`,
 * FERMÉ par défaut (seule la valeur `true`, casse et espaces tolérés, l'ouvre) —
 * la même variable que `features.scholarshipMatch` de `/config/app`.
 *
 * Drapeau coupé : toutes les routes `/scholarships/match/*` répondent
 * `404 { disabled: true }`, AVANT l'authentification (aucun appel Supabase pour
 * une fonction éteinte). L'app masque alors la carte et garde ses runs en cache
 * cachés.
 */
export function isScholarshipMatchEnabled(): boolean {
  return process.env.KPB_SCHOLARSHIP_MATCH_ENABLED?.trim().toLowerCase() === 'true';
}

export class ScholarshipMatchDisabledException extends NotFoundException {
  constructor() {
    super({ message: 'Scholarship match is disabled.', code: 'scholarship_match_disabled' });
  }
}

@Injectable()
export class ScholarshipMatchEnabledGuard implements CanActivate {
  canActivate(): boolean {
    if (!isScholarshipMatchEnabled()) throw new ScholarshipMatchDisabledException();
    return true;
  }
}

/**
 * Le filtre global réécrit chaque erreur en `{ statusCode, message, … }` et
 * perdrait `disabled` : ce filtre, posé sur le seul contrôleur du test, sert la
 * forme promise à l'app (`disabled: true` au premier niveau).
 */
@Catch(ScholarshipMatchDisabledException)
export class ScholarshipMatchDisabledFilter implements ExceptionFilter {
  catch(_exception: ScholarshipMatchDisabledException, host: ArgumentsHost): void {
    host
      .switchToHttp()
      .getResponse<Response>()
      .status(HttpStatus.NOT_FOUND)
      .json({
        statusCode: HttpStatus.NOT_FOUND,
        disabled: true,
        code: 'scholarship_match_disabled',
        message: 'Scholarship match is disabled.',
      });
  }
}
