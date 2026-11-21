import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { createHash, timingSafeEqual } from 'node:crypto';

export const PASS_WEBHOOK_HEADER = 'x-kpb-webhook-secret';
const MIN_SECRET_LENGTH = 32;

function digest(value: string): Buffer {
  return createHash('sha256').update(value, 'utf8').digest();
}

/**
 * Webhook n8n → Pass Karatou. Le secret partagé voyage dans l'en-tête
 * `X-KPB-Webhook-Secret` (HTTPS uniquement en production). Sans secret
 * configuré côté serveur, la route est FERMÉE (503), jamais ouverte à tous.
 * La comparaison porte sur des empreintes de longueur fixe : ni la longueur
 * ni le contenu du secret ne fuient par le temps de réponse.
 */
@Injectable()
export class PassWebhookGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const expected = process.env.KPB_PASS_WEBHOOK_SECRET?.trim() ?? '';
    if (expected.length < MIN_SECRET_LENGTH) {
      throw new ServiceUnavailableException('Pass webhook is not configured.');
    }
    const request = context
      .switchToHttp()
      .getRequest<{ headers?: Record<string, string | string[] | undefined> }>();
    const raw = request.headers?.[PASS_WEBHOOK_HEADER];
    const provided = (Array.isArray(raw) ? raw[0] : raw)?.trim() ?? '';
    if (!provided || !timingSafeEqual(digest(provided), digest(expected))) {
      throw new UnauthorizedException('Invalid webhook secret.');
    }
    return true;
  }
}
