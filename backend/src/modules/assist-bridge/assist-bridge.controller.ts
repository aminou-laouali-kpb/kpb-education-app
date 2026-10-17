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
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { AssistActionDto, AssistEventsQueryDto, AssistStatsQueryDto } from './assist-bridge.dto';
import { AssistBridgeService } from './assist-bridge.service';

/** R (§8 du contrat) : la console de modération — jamais le conseiller seul. */
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

/**
 * Bot « Passerelle » (C3 bis) — lecture pour l'équipe (§15.5 du contrat,
 * révision 3) : mode, statistiques par besoin, derniers événements (sans texte
 * pour la source coach), catalogue des besoins. Lecture seule : le bot
 * n'attend aucune validation humaine (il n'écrit rien de public).
 */
@Controller('admin/community/assist-bridge')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(...READ_ROLES)
export class AssistBridgeAdminController {
  constructor(private readonly bridge: AssistBridgeService) {}

  @Get('stats')
  @Header('Cache-Control', 'private, no-store')
  stats(@Query() q: AssistStatsQueryDto) {
    return this.bridge.stats(q.days ?? 30);
  }

  @Get('events')
  @Header('Cache-Control', 'private, no-store')
  events(@Query() q: AssistEventsQueryDto) {
    return this.bridge.list({ status: q.status, needId: q.needId, source: q.source }, q.cursor, q.limit);
  }

  @Get('catalog')
  @Header('Cache-Control', 'private, no-store')
  catalog() {
    return this.bridge.catalog();
  }
}

type StudentRequest = { studentUser?: { id: string } };

/**
 * Bot « Passerelle » — suivi des clics de l'élève sur la feuille ouverte par
 * la notification : `opened_feature`, `opened_whatsapp`, `dismissed`. Jamais
 * coupé par le mode : une notification déjà envoyée reste mesurable.
 */
@Controller('me/assist-bridge')
@UseGuards(StudentAuthGuard)
export class AssistBridgeStudentController {
  constructor(private readonly bridge: AssistBridgeService) {}

  @Post('events/:id')
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  action(@Param('id') id: string, @Body() body: AssistActionDto, @Req() req: StudentRequest) {
    if (!req.studentUser) throw new UnauthorizedException();
    return this.bridge.recordAction(req.studentUser.id, checkId(id), body.action);
  }
}
