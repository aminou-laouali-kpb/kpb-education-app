import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
  PayloadTooLargeException,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { AiQuotaService } from './ai-quota.service';

export type AiQuotaOptions = {
  /** Clé du compteur, partagée par toutes les routes d'une même famille. */
  feature: string;
  /** Variable d'environnement qui surcharge la limite quotidienne. */
  limitEnv: string;
  /** Limite quotidienne par défaut. */
  defaultDailyLimit: number;
  /** Taille maximale du body JSON sérialisé (octets). */
  maxBodyBytes: number;
};

export const AI_QUOTA_KEY = 'kpb:ai-quota';

/**
 * Borne le coût d'une route LLM : taille du body puis quota quotidien par
 * utilisateur. À poser APRÈS `StudentAuthGuard` et `AiConsentGuard`.
 */
export const AiQuota = (options: AiQuotaOptions) =>
  SetMetadata(AI_QUOTA_KEY, options);

export function resolveAiDailyLimit(options: AiQuotaOptions): number {
  const raw = Number(process.env[options.limitEnv]);
  return Number.isSafeInteger(raw) && raw > 0 ? raw : options.defaultDailyLimit;
}

@Injectable()
export class AiQuotaGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly quota: AiQuotaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const options = this.reflector.getAllAndOverride<AiQuotaOptions | undefined>(
      AI_QUOTA_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!options) return true;

    const request = context.switchToHttp().getRequest<{
      studentUser?: { id?: string };
      body?: unknown;
    }>();
    const userId = request.studentUser?.id;
    if (!userId) {
      throw new UnauthorizedException('Missing authenticated student.');
    }

    const bodyBytes = Buffer.byteLength(JSON.stringify(request.body ?? {}));
    if (bodyBytes > options.maxBodyBytes) {
      throw new PayloadTooLargeException({
        code: 'ai_input_too_large',
        message: `Texte trop long (${options.maxBodyBytes} octets max).`,
      });
    }

    const decision = await this.quota.consume({
      userId,
      feature: options.feature,
      limit: resolveAiDailyLimit(options),
    });
    if (!decision.allowed) {
      throw new HttpException(
        {
          code: 'ai_daily_quota_reached',
          message:
            "Limite quotidienne d'utilisation de l'IA atteinte. Réessaie demain.",
          resetsAt: decision.resetsAt.toISOString(),
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    return true;
  }
}
