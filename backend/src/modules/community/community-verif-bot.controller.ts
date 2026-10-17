import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
  Res,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import type { IncomingHttpHeaders } from 'node:http';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { resolveRequestId } from '../../common/request-id';
import type { AdminSessionUser } from '../auth/auth.service';
import type { ModerationActor } from './community-moderation.service';
import { pickLang } from './community-text';
import { CommunityVerifBotService } from './community-verif-bot.service';
import { BotDraftsQueryDto, BotPublishDto, LangQueryDto, ReasonDto, StatsQueryDto } from './dto/community.dto';

type AdminRequest = { adminUser?: AdminSessionUser; headers: IncomingHttpHeaders };

/** R (§8) : lecture et travail sur les brouillons — jamais le conseiller seul. */
const READ_ROLES = [
  InternalRole.Moderator,
  InternalRole.ContentManager,
  InternalRole.Admin,
  InternalRole.SuperAdmin,
] as const;

const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

function checkId(id: string): string {
  if (!ID_PATTERN.test(id)) throw new BadRequestException('Invalid id.');
  return id;
}

function actor(req: AdminRequest): ModerationActor {
  if (!req.adminUser) throw new UnauthorizedException();
  return { id: req.adminUser.id, fullName: req.adminUser.fullName, role: req.adminUser.role };
}

function requestIdOf(req: AdminRequest, res: Response): string {
  const id = resolveRequestId(req.headers['x-request-id']);
  res.setHeader('X-Request-Id', id);
  return id;
}

/**
 * Bot « Vérif » (C3) — la file des brouillons de l'équipe (§8.9 du contrat,
 * révision 2). Comme toutes les routes admin de la communauté : jamais coupées
 * par le drapeau, `private, no-store`, chaque écriture dans `AdminAuditEvent`.
 */
@Controller('admin/community/bot')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(...READ_ROLES)
export class CommunityVerifBotController {
  constructor(private readonly bot: CommunityVerifBotService) {}

  @Get('drafts')
  @Header('Cache-Control', 'private, no-store')
  list(@Query() q: BotDraftsQueryDto) {
    return this.bot.list(q.status ?? 'proposed', q.cursor, q.limit);
  }

  @Get('stats')
  @Header('Cache-Control', 'private, no-store')
  stats(@Query() q: StatsQueryDto) {
    return this.bot.stats(q.days ?? 30);
  }

  @Get('drafts/:id')
  @Header('Cache-Control', 'private, no-store')
  detail(@Param('id') id: string, @Query() q: LangQueryDto, @Req() req: AdminRequest) {
    return this.bot.detail(checkId(id), actor(req).role, pickLang(q.lang));
  }

  @Post('drafts/:id/publish')
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  publish(
    @Param('id') id: string,
    @Body() body: BotPublishDto,
    @Query() q: LangQueryDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.bot.publish(checkId(id), body, actor(req), requestIdOf(req, res), pickLang(q.lang));
  }

  @Post('drafts/:id/reject')
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  reject(
    @Param('id') id: string,
    @Body() body: ReasonDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.bot.reject(checkId(id), body.reason, actor(req), requestIdOf(req, res));
  }

  @Post('drafts/:id/regenerate')
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  regenerate(@Param('id') id: string, @Req() req: AdminRequest, @Res({ passthrough: true }) res: Response) {
    return this.bot.regenerate(checkId(id), actor(req), requestIdOf(req, res));
  }
}
