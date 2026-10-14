import {
  Controller,
  Get,
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

import { Roles } from '../../../common/decorators/roles.decorator';
import { InternalRole } from '../../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { resolveRequestId } from '../../../common/request-id';
import type { AdminSessionUser } from '../../auth/auth.service';
import { OpeningPreviewQueryDto } from '../dto/opening-preview-query.dto';
import { ScholarshipOpeningAdminService } from './scholarship-opening-admin.service';
import type {
  CancelOpeningResponse,
  OpeningOverviewResponse,
  OpeningPreviewResponse,
  OpeningReportResponse,
  OpeningTodoResponse,
  StopOpeningResponse,
} from './scholarship-opening.contract';

type AdminRequest = {
  adminUser?: AdminSessionUser;
  headers: IncomingHttpHeaders;
};

/**
 * Annonce d'ouverture d'une bourse — routes de l'équipe (chantier C) :
 * aperçu, annulation, arrêt des envois, rapport, « À faire », colonnes de la
 * liste. Contrats : `docs/api-contracts.md` et `scholarship-opening.contract.ts`.
 *
 * Même chemin, mêmes gardes et mêmes rôles que `AdminScholarshipsController` :
 * qui peut ouvrir un cycle peut en voir l'aperçu. La limite « au-delà du
 * seuil, administrateurs seulement » se joue dans `activate`, pas ici.
 *
 * Enregistré AVANT `AdminScholarshipsController` (`app.module.ts`) : les
 * segments fixes `opening-todo` et `opening-overview` ne sont jamais lus
 * comme un `:id`.
 */
@Controller('admin/scholarships')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.ContentManager)
export class AdminScholarshipOpeningController {
  constructor(private readonly opening: ScholarshipOpeningAdminService) {}

  @Get('opening-todo')
  todo(): Promise<OpeningTodoResponse> {
    return this.opening.todo();
  }

  @Get('opening-overview')
  overview(): Promise<OpeningOverviewResponse> {
    return this.opening.overview();
  }

  @Get(':id/opening-preview')
  preview(
    @Param('id') id: string,
    @Query() query: OpeningPreviewQueryDto,
    @Req() req: AdminRequest,
  ): Promise<OpeningPreviewResponse> {
    return this.opening.preview(id, query, this.actor(req));
  }

  @Post(':id/cycles/:cycleId/opening/cancel')
  @HttpCode(HttpStatus.OK)
  cancel(
    @Param('id') id: string,
    @Param('cycleId') cycleId: string,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ): Promise<CancelOpeningResponse> {
    const requestId = this.attachRequestId(req, res);
    return this.opening.cancel(id, cycleId, this.actor(req), requestId);
  }

  @Post(':id/cycles/:cycleId/opening/stop')
  @HttpCode(HttpStatus.OK)
  stop(
    @Param('id') id: string,
    @Param('cycleId') cycleId: string,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StopOpeningResponse> {
    const requestId = this.attachRequestId(req, res);
    return this.opening.stop(id, cycleId, this.actor(req), requestId);
  }

  @Get(':id/cycles/:cycleId/opening-report')
  report(
    @Param('id') id: string,
    @Param('cycleId') cycleId: string,
  ): Promise<OpeningReportResponse> {
    return this.opening.report(id, cycleId);
  }

  /** `adminUser` est optionnel dans le type : jamais de `!`, un 401 explicite. */
  private actor(req: AdminRequest): AdminSessionUser {
    if (!req.adminUser) throw new UnauthorizedException();
    return req.adminUser;
  }

  /** L'identifiant écrit à l'audit, renvoyé pour relier l'événement à l'appel. */
  private attachRequestId(req: AdminRequest, res: Response): string {
    const requestId = resolveRequestId(req.headers['x-request-id']);
    res.setHeader('X-Request-Id', requestId);
    return requestId;
  }
}
