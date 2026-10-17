import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
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
import { CommunityModerationService, type ModerationActor } from './community-moderation.service';
import { pickLang } from './community-text';
import {
  AdminPostsQueryDto,
  ContentActionDto,
  CreateSanctionDto,
  FilterEntryDto,
  FilterTestDto,
  LangQueryDto,
  PageQueryDto,
  PinDto,
  QueueQueryDto,
  ReasonDto,
  SanctionsQueryDto,
  StatsQueryDto,
  TeamPostDto,
  TeamReplyDto,
  VerifiedDto,
} from './dto/community.dto';

type AdminRequest = { adminUser?: AdminSessionUser; headers: IncomingHttpHeaders };

/** R : lecture, actions sur contenu, réponses d'équipe, vérification, épinglage. */
const READ_ROLES = [
  InternalRole.Moderator,
  InternalRole.ContentManager,
  InternalRole.Admin,
  InternalRole.SuperAdmin,
] as const;
/** S : sanctions. */
const SANCTION_ROLES = [InternalRole.Moderator, InternalRole.Admin, InternalRole.SuperAdmin] as const;
/** C : configuration du filtre. */
const CONFIG_ROLES = [InternalRole.Admin, InternalRole.SuperAdmin] as const;

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
 * Communauté — routes de l'ÉQUIPE (§8 du contrat). Jamais coupées par le
 * drapeau `KPB_COMMUNITY_ENABLED`. Les réponses portent l'identité réelle des
 * membres (dont des mineurs) : `Cache-Control: private, no-store` partout.
 */
@Controller('admin/community')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(...READ_ROLES)
export class CommunityAdminController {
  constructor(private readonly moderation: CommunityModerationService) {}

  @Get('queue')
  @Header('Cache-Control', 'private, no-store')
  queue(@Query() q: QueueQueryDto, @Req() req: AdminRequest) {
    return this.moderation.queue(actor(req).role, q.kind ?? 'all', q.cursor, q.limit, pickLang(q.lang));
  }

  // Le conseiller (Counselor) LIT les discussions pour y répondre — jamais la
  // file de modération, les membres, les sanctions ni le filtre.
  @Get('posts')
  @Roles(...READ_ROLES, InternalRole.Counselor)
  @Header('Cache-Control', 'private, no-store')
  listPosts(@Query() q: AdminPostsQueryDto, @Req() req: AdminRequest) {
    return this.moderation.listPosts(
      actor(req).role,
      { status: q.status, type: q.type, q: q.q },
      q.cursor,
      q.limit,
      pickLang(q.lang),
    );
  }

  @Get('posts/:id')
  @Roles(...READ_ROLES, InternalRole.Counselor)
  @Header('Cache-Control', 'private, no-store')
  postDetail(@Param('id') id: string, @Query() q: LangQueryDto, @Req() req: AdminRequest) {
    return this.moderation.postDetail(actor(req).role, checkId(id), pickLang(q.lang));
  }

  @Get('members/:memberId')
  @Header('Cache-Control', 'private, no-store')
  memberDetail(@Param('memberId') memberId: string, @Query() q: LangQueryDto, @Req() req: AdminRequest) {
    return this.moderation.memberDetail(actor(req).role, checkId(memberId), pickLang(q.lang));
  }

  @Get('sanctions')
  @Header('Cache-Control', 'private, no-store')
  listSanctions(@Query() q: SanctionsQueryDto, @Req() req: AdminRequest) {
    return this.moderation.listSanctions(actor(req).role, q.status ?? 'active', q.cursor, q.limit);
  }

  @Get('moderation-log')
  @Header('Cache-Control', 'private, no-store')
  moderationLog(@Query() q: PageQueryDto) {
    return this.moderation.moderationLog(q.cursor, q.limit);
  }

  @Get('stats')
  @Header('Cache-Control', 'private, no-store')
  stats(@Query() q: StatsQueryDto) {
    return this.moderation.stats(q.days ?? 30);
  }

  // ── Actions sur un contenu (§8.4) ─────────────────────────────────────────

  @Post('posts/:id/actions')
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  postAction(
    @Param('id') id: string,
    @Body() body: ContentActionDto,
    @Query() q: LangQueryDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.moderation.contentAction('post', checkId(id), body, actor(req), requestIdOf(req, res), pickLang(q.lang));
  }

  @Post('replies/:id/actions')
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  replyAction(
    @Param('id') id: string,
    @Body() body: ContentActionDto,
    @Query() q: LangQueryDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.moderation.contentAction('reply', checkId(id), body, actor(req), requestIdOf(req, res), pickLang(q.lang));
  }

  // ── Sanctions (§8.5) ──────────────────────────────────────────────────────

  @Post('members/:memberId/sanctions')
  @Roles(...SANCTION_ROLES)
  @Header('Cache-Control', 'private, no-store')
  createSanction(
    @Param('memberId') memberId: string,
    @Body() body: CreateSanctionDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.moderation.createSanction(checkId(memberId), body, actor(req), requestIdOf(req, res));
  }

  @Post('members/:memberId/reports/dismiss')
  @Roles(...SANCTION_ROLES)
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  dismissMemberReports(
    @Param('memberId') memberId: string,
    @Body() body: ReasonDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.moderation.dismissMemberReports(checkId(memberId), body, actor(req), requestIdOf(req, res));
  }

  @Post('sanctions/:id/revoke')
  @Roles(...SANCTION_ROLES)
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  revokeSanction(
    @Param('id') id: string,
    @Body() body: ReasonDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.moderation.revokeSanction(checkId(id), body, actor(req), requestIdOf(req, res));
  }

  // ── Équipe KPB (§8.6) ─────────────────────────────────────────────────────

  @Post('posts/:id/replies')
  @Roles(...READ_ROLES, InternalRole.Counselor)
  @Header('Cache-Control', 'private, no-store')
  teamReply(
    @Param('id') id: string,
    @Body() body: TeamReplyDto,
    @Query() q: LangQueryDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.moderation.teamReply(checkId(id), body, actor(req), requestIdOf(req, res), pickLang(q.lang));
  }

  @Put('replies/:id/verified')
  @Header('Cache-Control', 'private, no-store')
  setVerified(
    @Param('id') id: string,
    @Body() body: VerifiedDto,
    @Query() q: LangQueryDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.moderation.setVerified(checkId(id), body.verified, actor(req), requestIdOf(req, res), pickLang(q.lang));
  }

  @Put('posts/:id/pin')
  @Header('Cache-Control', 'private, no-store')
  setPinned(
    @Param('id') id: string,
    @Body() body: PinDto,
    @Query() q: LangQueryDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.moderation.setPinned(checkId(id), body.pinned, actor(req), requestIdOf(req, res), pickLang(q.lang));
  }

  @Post('posts')
  @Header('Cache-Control', 'private, no-store')
  teamPost(
    @Body() body: TeamPostDto,
    @Query() q: LangQueryDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    return this.moderation.teamPost(body, actor(req), requestIdOf(req, res), pickLang(q.lang));
  }

  // ── Filtre (§8.8) ─────────────────────────────────────────────────────────

  @Get('filters')
  @Header('Cache-Control', 'private, no-store')
  filters() {
    return this.moderation.filters();
  }

  @Post('filters/test')
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  testFilter(@Body() body: FilterTestDto) {
    return this.moderation.testFilter(body.text);
  }

  @Post('filters')
  @Roles(...CONFIG_ROLES)
  @Header('Cache-Control', 'private, no-store')
  async addFilter(@Body() body: FilterEntryDto, @Req() req: AdminRequest, @Res({ passthrough: true }) res: Response) {
    const result = await this.moderation.addFilter(body, actor(req), requestIdOf(req, res));
    res.status(result.created ? HttpStatus.CREATED : HttpStatus.OK);
    return result.entry;
  }

  @Delete('filters/:id')
  @Roles(...CONFIG_ROLES)
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteFilter(@Param('id') id: string, @Req() req: AdminRequest, @Res({ passthrough: true }) res: Response) {
    await this.moderation.deleteFilter(checkId(id), actor(req), requestIdOf(req, res));
  }
}
