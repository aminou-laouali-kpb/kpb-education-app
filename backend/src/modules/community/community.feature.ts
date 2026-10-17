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
 * Le drapeau de la communauté côté API : `KPB_COMMUNITY_ENABLED`, FERMÉ par
 * défaut (seule la valeur `true`, casse et espaces tolérés, l'ouvre) — la même
 * variable que `features.community` de `/config/app`.
 *
 * Coupé : toutes les routes ÉLÈVE `/community/*` du contrat répondent
 * `404 { disabled: true, code: "community_disabled" }`, AVANT
 * l'authentification. Les routes admin `/admin/community/*` ne passent jamais
 * par ce garde : l'équipe modère même quand la communauté est fermée.
 */
export function isCommunityEnabled(): boolean {
  return process.env.KPB_COMMUNITY_ENABLED?.trim().toLowerCase() === 'true';
}

export class CommunityDisabledException extends NotFoundException {
  constructor() {
    super({ message: 'Community is disabled.', code: 'community_disabled' });
  }
}

@Injectable()
export class CommunityEnabledGuard implements CanActivate {
  canActivate(): boolean {
    if (!isCommunityEnabled()) throw new CommunityDisabledException();
    return true;
  }
}

/** Sert la forme promise (`disabled: true` au premier niveau, §2.2). */
@Catch(CommunityDisabledException)
export class CommunityDisabledFilter implements ExceptionFilter {
  catch(_exception: CommunityDisabledException, host: ArgumentsHost): void {
    host
      .switchToHttp()
      .getResponse<Response>()
      .status(HttpStatus.NOT_FOUND)
      .json({
        statusCode: HttpStatus.NOT_FOUND,
        disabled: true,
        code: 'community_disabled',
        message: 'Community is disabled.',
      });
  }
}
