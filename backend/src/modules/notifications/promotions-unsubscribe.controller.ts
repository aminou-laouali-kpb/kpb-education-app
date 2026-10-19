import {
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Logger,
  Post,
  Query,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { PUBLIC_LEADERBOARD_THROTTLE } from '../../common/throttler-options';
import { PrismaService } from '../prisma/prisma.service';
import { verifyPromotionsUnsubscribeToken } from './promotions-unsubscribe';

const PAGE_STYLE =
  'body{font-family:system-ui,sans-serif;max-width:32rem;margin:3rem auto;padding:0 1rem;color:#0f172a}' +
  'button{font:inherit;padding:.75rem 1.25rem;border-radius:.75rem;border:0;background:#1d4ed8;color:#fff}';

function page(title: string, body: string): string {
  return (
    '<!doctype html><html lang="fr"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<meta name="robots" content="noindex">' +
    `<title>${title}</title><style>${PAGE_STYLE}</style></head>` +
    `<body><h1>${title}</h1>${body}</body></html>`
  );
}

const INVALID = page(
  'Lien invalide',
  '<p>Ce lien de désinscription est incomplet ou abîmé. Tu peux aussi te désinscrire ' +
    'dans l\'app : Profil → Préférences.</p>' +
    '<p lang="en">This unsubscribe link is invalid. You can also unsubscribe in the app: Profile → Preferences.</p>',
);

const DONE = page(
  'Désinscription faite',
  '<p>Tu ne recevras plus d\'e-mails de nouvelles et d\'offres de KPB Education. ' +
    'Les e-mails liés à ton compte et à tes dossiers continuent.</p>' +
    '<p lang="en">You will no longer receive news and offers emails from KPB Education. ' +
    'Emails about your account and your applications continue.</p>',
);

/**
 * Désinscription des e-mails promotionnels — SANS authentification, par lien
 * signé (`promotions-unsubscribe.ts`).
 *
 * - `GET` affiche une page avec un bouton : un lien ouvert par un antivirus de
 *   messagerie ne doit pas désinscrire à lui seul ;
 * - `POST` désinscrit (le bouton de la page, et le « un clic » des messageries,
 *   RFC 8058 `List-Unsubscribe-Post`). Idempotent : rejouer ne change rien.
 *
 * La page n'affiche AUCUNE donnée du compte : un lien transféré ne révèle rien.
 */
@Controller('public/promotions')
export class PromotionsUnsubscribeController {
  private readonly logger = new Logger(PromotionsUnsubscribeController.name);

  constructor(private readonly prismaService: PrismaService) {}

  @Get('unsubscribe')
  @Throttle(PUBLIC_LEADERBOARD_THROTTLE)
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  confirm(@Query('u') userId?: string, @Query('t') token?: string): string {
    if (!verifyPromotionsUnsubscribeToken(userId, token)) return INVALID;
    const action =
      `?u=${encodeURIComponent(userId!)}&t=${encodeURIComponent(token!)}`;
    return page(
      'Se désinscrire',
      '<p>Ne plus recevoir par e-mail les nouvelles et offres de KPB Education ?</p>' +
        `<form method="post" action="unsubscribe${action}">` +
        '<button type="submit">Me désinscrire / Unsubscribe</button></form>',
    );
  }

  @Post('unsubscribe')
  @HttpCode(HttpStatus.OK)
  @Throttle(PUBLIC_LEADERBOARD_THROTTLE)
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  async unsubscribe(
    @Query('u') userId?: string,
    @Query('t') token?: string,
  ): Promise<string> {
    if (!verifyPromotionsUnsubscribeToken(userId, token)) return INVALID;
    // `updateMany` : un compte supprimé depuis l'envoi ne fait pas d'erreur.
    await this.prismaService.execute((prisma) =>
      prisma.userProfile.updateMany({
        where: { id: userId!, promotionsEmailOptIn: true },
        data: { promotionsEmailOptIn: false },
      }),
    );
    this.logger.log('Promotions email unsubscribe via signed link.');
    return DONE;
  }
}
