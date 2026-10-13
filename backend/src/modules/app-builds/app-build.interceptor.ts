import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';

import { AppBuildTrackerService } from './app-build-tracker.service';
import { IncomingHeaders, parseAppVersionHeaders } from './app-version-headers';

interface TrackedRequest {
  headers?: IncomingHeaders;
  studentUser?: { id?: unknown };
}

/**
 * Intercepteur global (APP_INTERCEPTOR) : pour une requête authentifiée par
 * `StudentAuthGuard`, note la build de l'app qui l'a émise.
 *
 * Il tourne APRÈS les gardes, donc `request.studentUser` est déjà résolu — ou
 * absent, et l'intercepteur ne fait rien : routes publiques, back-office,
 * WebSocket. Tous les comptes de l'app sont concernés (élève, parent,
 * partenaire) : le même écran de mise à jour forcée les bloquerait tous.
 *
 * Il ne modifie ni la requête ni la réponse, et rend la main immédiatement :
 * aucune build installée ne peut voir la différence.
 */
@Injectable()
export class AppBuildInterceptor implements NestInterceptor {
  private readonly logger = new Logger(AppBuildInterceptor.name);

  constructor(private readonly tracker: AppBuildTrackerService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    try {
      if (context.getType() === 'http') {
        const request = context.switchToHttp().getRequest<TrackedRequest>();
        const profileId = request?.studentUser?.id;
        if (typeof profileId === 'string' && profileId.length > 0) {
          this.tracker.record(
            profileId,
            parseAppVersionHeaders(request.headers),
          );
        }
      }
    } catch (error) {
      this.logger.debug(
        `Suivi de build ignoré (${error instanceof Error ? error.name : 'UNKNOWN'}).`,
      );
    }
    return next.handle();
  }
}
