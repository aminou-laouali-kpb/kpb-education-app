import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  Req,
  RequestMethod,
  Sse,
  UseGuards,
  MessageEvent,
} from '@nestjs/common';
import { METHOD_METADATA } from '@nestjs/common/constants';
import { Observable } from 'rxjs';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { CoachService } from './coach.service';
import { StreamCoachMessageDto } from './dto/stream-coach-message.dto';

@Controller('coach')
@UseGuards(StudentAuthGuard)
export class CoachController {
  constructor(private readonly coachService: CoachService) {}

  @Get('quota')
  getQuota(@Req() req: any) {
    return this.coachService.getQuota(req.studentUser.id);
  }

  @Get('suggestions')
  getSuggestions(@Query('lang') lang = '') {
    return this.coachService.getSuggestions({
      fullName: 'Étudiant',
      preferredLanguage: lang,
    });
  }

  @Post('conversations')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  createConversation(@Body() body: Record<string, unknown>, @Req() req: any) {
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    return this.coachService.createConversation(req.studentUser.id, profile);
  }

  @Get('conversations/:id/messages')
  getMessages(@Param('id') id: string, @Req() req: any) {
    return this.coachService.getMessages(id, req.studentUser.id);
  }

  // Pas de plafond propre (pour les deux routes de flux ci-dessous) : la
  // route est authentifiée et déjà bornée à cinq messages par semaine et par
  // élève. Un plafond par IP y referait punir les élèves d'un même opérateur
  // mobile les uns par les autres.

  /**
   * Réponse du coach en flux SSE, message dans le CORPS de la requête.
   *
   * C'est la route de l'app depuis l'audit du 22/11/2026 (constat 33) : le
   * message libre de l'élève (jusqu'à 2000 caractères où il décrit ses notes,
   * ses finances, sa famille) ne passe plus dans l'URL, qui finit dans les
   * journaux d'accès des proxys, du CDN et de l'hébergeur — hors de la purge
   * RGPD de la base. Ni le message ni le profil ne sont journalisés ici.
   */
  @Sse('conversations/:id/messages/stream', {
    [METHOD_METADATA]: RequestMethod.POST,
  })
  // 200 comme le GET : c'est un flux de lecture, pas une création.
  @HttpCode(200)
  streamMessageFromBody(
    @Param('id') id: string,
    @Body() body: StreamCoachMessageDto,
    @Req() req: any,
  ): Observable<MessageEvent> {
    return this.coachService.streamReply({
      conversationId: id,
      userId: req.studentUser.id,
      message: body.message ?? '',
      profile: { ...(body.profile ?? {}) },
    });
  }

  /**
   * ANCIENNE route, CONSERVÉE pour la compatibilité : les versions de l'app
   * déjà installées chez les élèves (avant le constat 33 de l'audit du
   * 22/11/2026) envoient le message en query string sur ce GET. La retirer
   * casserait le coach pour elles jusqu'à leur mise à jour.
   *
   * Elle ne doit plus servir à rien d'autre : l'app actuelle utilise le POST
   * ci-dessus. À supprimer quand le suivi des builds
   * (`AppBuildInterceptor`) ne montre plus d'anciennes versions actives.
   * Le backend ne journalise jamais l'URL ni le message (ni ici, ni dans
   * `main.ts`, ni dans les intercepteurs) ; seuls les journaux d'accès de
   * l'infrastructure la voient encore pour ces anciennes versions.
   */
  @Sse('conversations/:id/messages/stream')
  streamMessage(
    @Param('id') id: string,
    @Req() req: any,
    @Query('message') message = '',
    @Query('fullName') fullName = 'Étudiant',
    @Query('currentLevel') currentLevel = '',
    @Query('targetCountryIds') targetCountryIds = '',
    @Query('lang') lang = '',
  ): Observable<MessageEvent> {
    return this.coachService.streamReply({
      conversationId: id,
      userId: req.studentUser.id,
      message,
      profile: {
        fullName,
        currentLevel,
        targetCountryIds: targetCountryIds
          ? targetCountryIds.split(',').filter(Boolean)
          : [],
        preferredLanguage: lang,
      },
    });
  }

  @Post('conversations/:id/messages')
  postMessage(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() body: Record<string, unknown>,
    @Req() req: any,
  ): Observable<MessageEvent> {
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    const message = String(body.message ?? '');
    return this.coachService.streamReply({
      conversationId: id,
      userId: req.studentUser.id,
      message,
      profile,
    });
  }
}
