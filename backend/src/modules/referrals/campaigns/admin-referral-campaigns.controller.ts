import {
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  Patch,
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
import { AmbassadorAdminService } from './ambassador-admin.service';
import {
  ActivateAmbassadorAdminDto,
  CampaignTransitionDto,
  CreateReferralCampaignDto,
  EnrollParticipantDto,
  ForfeitPrizeDto,
  RecordPayoutDto,
  ReferralDecisionDto,
  RevokeAmbassadorDto,
  UpdateParticipantDto,
  UpdateReferralCampaignDto,
} from './dto/referral-campaign.dto';
import { ReferralCampaignService } from './referral-campaign.service';

type AdminRequest = { adminUser?: AdminSessionUser; headers: IncomingHttpHeaders };

/** Écritures et exports : administrateurs seulement. */
const WRITE_ROLES = [InternalRole.Admin, InternalRole.SuperAdmin] as const;

function actor(req: AdminRequest): AdminSessionUser {
  if (!req.adminUser) throw new UnauthorizedException();
  return req.adminUser;
}

function requestIdOf(req: AdminRequest, res: Response): string {
  const id = resolveRequestId(req.headers['x-request-id']);
  res.setHeader('X-Request-Id', id);
  return id;
}

/**
 * Compétition ambassadeurs — routes de l'équipe.
 *
 * Lecture : Admin, SuperAdmin et Commercial (l'équipe qui recrute les
 * ambassadeurs suit le classement). Écritures, décisions, versements et export :
 * Admin et SuperAdmin. Les réponses portent des noms et des e-mails (dont ceux
 * de mineurs) : `Cache-Control: private, no-store` partout.
 */
@Controller('admin/referral-campaigns')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.Commercial)
export class AdminReferralCampaignsController {
  constructor(private readonly campaigns: ReferralCampaignService) {}

  @Get()
  @Header('Cache-Control', 'private, no-store')
  list() {
    return this.campaigns.list();
  }

  @Post()
  @Roles(...WRITE_ROLES)
  create(
    @Body() dto: CreateReferralCampaignDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.campaigns.create(dto, actor(req), requestIdOf(req, res));
  }

  @Get(':id')
  @Header('Cache-Control', 'private, no-store')
  get(@Param('id') id: string) {
    return this.campaigns.get(id);
  }

  @Patch(':id')
  @Roles(...WRITE_ROLES)
  update(
    @Param('id') id: string,
    @Body() dto: UpdateReferralCampaignDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.campaigns.update(id, dto, actor(req), requestIdOf(req, res));
  }

  /** launch | freeze | unfreeze | validate_podium | close */
  @Post(':id/transition')
  @Roles(...WRITE_ROLES)
  @HttpCode(HttpStatus.OK)
  transition(
    @Param('id') id: string,
    @Body() dto: CampaignTransitionDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.campaigns.transition(id, dto.action, actor(req), requestIdOf(req, res));
  }

  /** Recalcul à la demande (idempotent : rejouer n'écrit que les différences). */
  @Post(':id/recompute')
  @Roles(...WRITE_ROLES)
  @HttpCode(HttpStatus.OK)
  recompute(@Param('id') id: string) {
    return this.campaigns.recompute(id);
  }

  @Get(':id/leaderboard')
  @Header('Cache-Control', 'private, no-store')
  leaderboard(
    @Param('id') id: string,
    @Query('city') city?: string,
    @Query('country') country?: string,
  ) {
    return this.campaigns.adminLeaderboard(id, { city, country });
  }

  @Post(':id/participants')
  @Roles(...WRITE_ROLES)
  enroll(
    @Param('id') id: string,
    @Body() dto: EnrollParticipantDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.campaigns.enroll(id, dto, actor(req), requestIdOf(req, res));
  }

  @Patch(':id/participants/:participantId')
  @Roles(...WRITE_ROLES)
  updateParticipant(
    @Param('id') id: string,
    @Param('participantId') participantId: string,
    @Body() dto: UpdateParticipantDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.campaigns.updateParticipant(id, participantId, dto, actor(req), requestIdOf(req, res));
  }

  @Get(':id/participants/:participantId/referrals')
  @Header('Cache-Control', 'private, no-store')
  participantReferrals(@Param('id') id: string, @Param('participantId') participantId: string) {
    return this.campaigns.participantReferrals(id, participantId);
  }

  @Post(':id/referrals/:referralId/decision')
  @Roles(...WRITE_ROLES)
  @HttpCode(HttpStatus.OK)
  decide(
    @Param('id') id: string,
    @Param('referralId') referralId: string,
    @Body() dto: ReferralDecisionDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.campaigns.decide(id, referralId, dto.decision, dto.reason, actor(req), requestIdOf(req, res));
  }

  @Get(':id/prizes')
  @Header('Cache-Control', 'private, no-store')
  prizes(@Param('id') id: string) {
    return this.campaigns.prizes(id);
  }

  @Post(':id/prizes/:rank/payout')
  @Roles(...WRITE_ROLES)
  @HttpCode(HttpStatus.OK)
  payout(
    @Param('id') id: string,
    @Param('rank', ParseIntPipe) rank: number,
    @Body() dto: RecordPayoutDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.campaigns.recordPayout(id, rank, dto, actor(req), requestIdOf(req, res));
  }

  /**
   * « Déclarer le prix forfait et réattribuer » : le lauréat du rang `rank`
   * perd son prix (motif tracé), qui passe au suivant classable non primé.
   * Refusé si ce prix est déjà versé ; rejouer la même déclaration ne change
   * rien (idempotent).
   */
  @Post(':id/prizes/:rank/forfeit')
  @Roles(...WRITE_ROLES)
  @HttpCode(HttpStatus.OK)
  forfeit(
    @Param('id') id: string,
    @Param('rank', ParseIntPipe) rank: number,
    @Body() dto: ForfeitPrizeDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.campaigns.forfeitPrize(id, rank, dto, actor(req), requestIdOf(req, res));
  }

  /** `scope=leaderboard` (défaut) ou `scope=referrals`. */
  @Get(':id/export.csv')
  @Roles(...WRITE_ROLES)
  @Header('Cache-Control', 'private, no-store')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  async exportCsv(
    @Param('id') id: string,
    @Query('scope') scope: string | undefined,
    @Res({ passthrough: true }) res: Response,
  ) {
    const s = scope === 'referrals' ? 'referrals' : 'leaderboard';
    res.setHeader('Content-Disposition', `attachment; filename="campagne-${s}.csv"`);
    return this.campaigns.exportCsv(id, s);
  }
}

/** Ambassadeurs : activation par l'équipe (seule voie), retrait. */
@Controller('admin/ambassadors')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.Commercial)
export class AdminAmbassadorsController {
  constructor(private readonly ambassadors: AmbassadorAdminService) {}

  @Get()
  @Header('Cache-Control', 'private, no-store')
  list(@Query('search') search?: string, @Query('approved') approved?: string) {
    return this.ambassadors.list({
      search,
      approved: approved === 'yes' || approved === 'no' ? approved : undefined,
    });
  }

  @Post()
  @Roles(...WRITE_ROLES)
  activate(
    @Body() dto: ActivateAmbassadorAdminDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.ambassadors.activate(dto, actor(req), requestIdOf(req, res));
  }

  @Post(':id/revoke')
  @Roles(...WRITE_ROLES)
  @HttpCode(HttpStatus.OK)
  revoke(
    @Param('id') id: string,
    @Body() dto: RevokeAmbassadorDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.ambassadors.revoke(id, dto.reason, actor(req), requestIdOf(req, res));
  }
}
