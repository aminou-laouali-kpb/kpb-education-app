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
  Patch,
  Post,
  Put,
  Query,
  Req,
  Res,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Response } from 'express';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { COMMUNITY_WRITE_THROTTLE } from '../../common/throttler-options';
import { COMMUNITY_PAGINATION } from './community.constants';
import { CommunityAccessService, type CommunityViewer } from './community-access.service';
import { CommunityCatalogService } from './community-catalog.service';
import { CommunityModerationService } from './community-moderation.service';
import { CommunityPostsService } from './community-posts.service';
import { isEntityType, pickLang, type CommunityEntityTypeValue } from './community-text';
import { CommunityDisabledFilter, CommunityEnabledGuard } from './community.feature';
import {
  AcceptCharterDto,
  CreatePostDto,
  CreateReportDto,
  EntityCountsQueryDto,
  EntitySpaceQueryDto,
  FeedQueryDto,
  HashtagSuggestQueryDto,
  LangQueryDto,
  MentionSuggestQueryDto,
  PageQueryDto,
  RepliesQueryDto,
  ReplyBodyDto,
  SearchQueryDto,
  UpdatePostDto,
} from './dto/community.dto';

type StudentRequest = { studentUser?: { id: string; accountType?: string } };

const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

function checkId(id: string): string {
  if (!ID_PATTERN.test(id)) throw new BadRequestException('Invalid id.');
  return id;
}

function entityType(raw: string): CommunityEntityTypeValue {
  if (!isEntityType(raw)) throw new BadRequestException('Invalid entity type.');
  return raw;
}

/**
 * Communauté — routes ÉLÈVE (§7 du contrat docs/community-api-contract.md).
 *
 * Ordre des portes : drapeau `KPB_COMMUNITY_ENABLED` (404 `{ disabled: true }`,
 * avant toute authentification), jeton élève (401), compte élève (403
 * `community_students_only`) ; les écritures ajoutent charte, sanction et
 * quotas dans le service. Réponses personnelles : `private, no-store`.
 *
 * Les routes à segment fixe (`me/*`, `entities/counts`, `*\/suggest`) sont
 * déclarées avant les routes à paramètre de même préfixe.
 */
@Controller('community')
@UseFilters(CommunityDisabledFilter)
@UseGuards(CommunityEnabledGuard, StudentAuthGuard)
export class CommunityStudentController {
  constructor(
    private readonly access: CommunityAccessService,
    private readonly posts: CommunityPostsService,
    private readonly moderation: CommunityModerationService,
    private readonly catalog: CommunityCatalogService,
  ) {}

  private viewer(req: StudentRequest): Promise<CommunityViewer> {
    return this.access.resolveViewer(req.studentUser!.id, req.studentUser?.accountType);
  }

  // ── Membre et charte (§7.1) ───────────────────────────────────────────────

  @Get('me')
  @Header('Cache-Control', 'private, no-store')
  async me(@Req() req: StudentRequest, @Query() q: LangQueryDto) {
    return this.access.me(await this.viewer(req), pickLang(q.lang));
  }

  @Post('charter/accept')
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  async acceptCharter(@Req() req: StudentRequest, @Body() body: AcceptCharterDto) {
    return this.access.acceptCharter(await this.viewer(req), body.version);
  }

  @Get('me/posts')
  @Header('Cache-Control', 'private, no-store')
  async myPosts(@Req() req: StudentRequest, @Query() q: PageQueryDto) {
    return this.posts.myPosts(await this.viewer(req), q.cursor, q.limit, pickLang(q.lang));
  }

  @Get('me/following')
  @Header('Cache-Control', 'private, no-store')
  async myFollowing(@Req() req: StudentRequest, @Query() q: PageQueryDto) {
    return this.posts.myFollowing(await this.viewer(req), q.cursor, q.limit, pickLang(q.lang));
  }

  @Get('blocks')
  @Header('Cache-Control', 'private, no-store')
  async blocks(@Req() req: StudentRequest, @Query() q: PageQueryDto) {
    return this.access.listBlocks(await this.viewer(req), q.cursor, q.limit);
  }

  // ── Fils, espaces, recherche (§7.2 – §7.5) ────────────────────────────────

  @Get('feed')
  @Header('Cache-Control', 'private, no-store')
  async feed(@Req() req: StudentRequest, @Query() q: FeedQueryDto) {
    return this.posts.feed(
      await this.viewer(req),
      { tab: q.tab, type: q.type, hashtag: q.hashtag, cursor: q.cursor, limit: q.limit },
      pickLang(q.lang),
    );
  }

  @Get('entities/counts')
  @Header('Cache-Control', 'private, no-store')
  async entityCounts(@Req() req: StudentRequest, @Query() q: EntityCountsQueryDto) {
    await this.viewer(req);
    return this.posts.entityCounts(q.refs);
  }

  @Get('entities/:type/:id/count')
  @Header('Cache-Control', 'private, no-store')
  async entityCount(@Req() req: StudentRequest, @Param('type') type: string, @Param('id') id: string) {
    await this.viewer(req);
    return this.posts.entityCount(entityType(type), checkId(id));
  }

  @Get('entities/:type/:id')
  @Header('Cache-Control', 'private, no-store')
  async entitySpace(
    @Req() req: StudentRequest,
    @Param('type') type: string,
    @Param('id') id: string,
    @Query() q: EntitySpaceQueryDto,
  ) {
    return this.posts.entitySpace(
      await this.viewer(req),
      entityType(type),
      checkId(id),
      q.sort ?? 'recent',
      q.cursor,
      q.limit,
      pickLang(q.lang),
    );
  }

  @Get('search')
  @Header('Cache-Control', 'private, no-store')
  async search(@Req() req: StudentRequest, @Query() q: SearchQueryDto) {
    return this.posts.search(await this.viewer(req), q.q, q.type, q.cursor, q.limit, pickLang(q.lang));
  }

  @Get('mentions/suggest')
  @Header('Cache-Control', 'private, no-store')
  async suggestMentions(@Req() req: StudentRequest, @Query() q: MentionSuggestQueryDto) {
    await this.viewer(req);
    const types = (q.types ?? '').split(',').filter(isEntityType);
    const items = await this.catalog.suggest(
      q.q,
      types,
      q.limit ?? COMMUNITY_PAGINATION.suggestDefaultLimit,
      pickLang(q.lang),
    );
    return { items };
  }

  @Get('hashtags/suggest')
  @Header('Cache-Control', 'private, no-store')
  async suggestHashtags(@Req() req: StudentRequest, @Query() q: HashtagSuggestQueryDto) {
    await this.viewer(req);
    return this.posts.suggestHashtags(q.q, q.limit);
  }

  // ── Publications (§7.6) ───────────────────────────────────────────────────

  @Post('posts')
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  @Header('Cache-Control', 'private, no-store')
  async createPost(@Req() req: StudentRequest, @Body() body: CreatePostDto, @Query() q: LangQueryDto) {
    return this.posts.createPost(await this.viewer(req), body, pickLang(q.lang));
  }

  @Get('posts/:id')
  @Header('Cache-Control', 'private, no-store')
  async getPost(@Req() req: StudentRequest, @Param('id') id: string, @Query() q: LangQueryDto) {
    return this.posts.getPost(await this.viewer(req), checkId(id), pickLang(q.lang));
  }

  @Get('posts/:id/replies')
  @Header('Cache-Control', 'private, no-store')
  async listReplies(@Req() req: StudentRequest, @Param('id') id: string, @Query() q: RepliesQueryDto) {
    return this.posts.listReplies(await this.viewer(req), checkId(id), q.cursor, q.limit, pickLang(q.lang));
  }

  @Patch('posts/:id')
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  @Header('Cache-Control', 'private, no-store')
  async updatePost(
    @Req() req: StudentRequest,
    @Param('id') id: string,
    @Body() body: UpdatePostDto,
    @Query() q: LangQueryDto,
  ) {
    return this.posts.updatePost(await this.viewer(req), checkId(id), body, pickLang(q.lang));
  }

  @Delete('posts/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  async deletePost(@Req() req: StudentRequest, @Param('id') id: string): Promise<void> {
    await this.posts.deletePost(await this.viewer(req), checkId(id));
  }

  // ── Réponses (§7.7) ───────────────────────────────────────────────────────

  @Post('posts/:id/replies')
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  @Header('Cache-Control', 'private, no-store')
  async createReply(
    @Req() req: StudentRequest,
    @Param('id') id: string,
    @Body() body: ReplyBodyDto,
    @Query() q: LangQueryDto,
  ) {
    return this.posts.createReply(await this.viewer(req), checkId(id), body, pickLang(q.lang));
  }

  @Patch('replies/:id')
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  @Header('Cache-Control', 'private, no-store')
  async updateReply(
    @Req() req: StudentRequest,
    @Param('id') id: string,
    @Body() body: ReplyBodyDto,
    @Query() q: LangQueryDto,
  ) {
    return this.posts.updateReply(await this.viewer(req), checkId(id), body, pickLang(q.lang));
  }

  @Delete('replies/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  async deleteReply(@Req() req: StudentRequest, @Param('id') id: string): Promise<void> {
    await this.posts.deleteReply(await this.viewer(req), checkId(id));
  }

  // ── « Utile » et suivi (§7.8, §7.9) ───────────────────────────────────────

  @Put('posts/:id/helpful')
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  @Header('Cache-Control', 'private, no-store')
  async markPostHelpful(@Req() req: StudentRequest, @Param('id') id: string) {
    return this.posts.setPostHelpful(await this.viewer(req), checkId(id), true);
  }

  @Delete('posts/:id/helpful')
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  @Header('Cache-Control', 'private, no-store')
  async unmarkPostHelpful(@Req() req: StudentRequest, @Param('id') id: string) {
    return this.posts.setPostHelpful(await this.viewer(req), checkId(id), false);
  }

  @Put('replies/:id/helpful')
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  @Header('Cache-Control', 'private, no-store')
  async markReplyHelpful(@Req() req: StudentRequest, @Param('id') id: string) {
    return this.posts.setReplyHelpful(await this.viewer(req), checkId(id), true);
  }

  @Delete('replies/:id/helpful')
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  @Header('Cache-Control', 'private, no-store')
  async unmarkReplyHelpful(@Req() req: StudentRequest, @Param('id') id: string) {
    return this.posts.setReplyHelpful(await this.viewer(req), checkId(id), false);
  }

  @Put('posts/:id/follow')
  @Header('Cache-Control', 'private, no-store')
  async follow(@Req() req: StudentRequest, @Param('id') id: string) {
    return this.posts.setFollow(await this.viewer(req), checkId(id), true);
  }

  @Delete('posts/:id/follow')
  @Header('Cache-Control', 'private, no-store')
  async unfollow(@Req() req: StudentRequest, @Param('id') id: string) {
    return this.posts.setFollow(await this.viewer(req), checkId(id), false);
  }

  // ── Signaler, bloquer, profil (§7.10 – §7.12) ─────────────────────────────

  @Post('reports')
  @Throttle(COMMUNITY_WRITE_THROTTLE)
  @Header('Cache-Control', 'private, no-store')
  async report(
    @Req() req: StudentRequest,
    @Body() body: CreateReportDto,
    @Res({ passthrough: true }) res: Response,
  ) {
    const result = await this.moderation.report(await this.viewer(req), body);
    res.status(result.created ? HttpStatus.CREATED : HttpStatus.OK);
    return result.report;
  }

  @Post('members/:memberId/block')
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'private, no-store')
  async block(@Req() req: StudentRequest, @Param('memberId') memberId: string) {
    return this.access.block(await this.viewer(req), checkId(memberId));
  }

  @Delete('members/:memberId/block')
  @Header('Cache-Control', 'private, no-store')
  async unblock(@Req() req: StudentRequest, @Param('memberId') memberId: string) {
    return this.access.unblock(await this.viewer(req), checkId(memberId));
  }

  @Get('members/:memberId')
  @Header('Cache-Control', 'private, no-store')
  async member(@Req() req: StudentRequest, @Param('memberId') memberId: string) {
    return this.access.memberProfile(await this.viewer(req), checkId(memberId));
  }
}
