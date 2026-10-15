import {
  Body,
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

import type { AdminSessionUser } from '../auth/auth.service';
import { resolveRequestId } from '../../common/request-id';
import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { DailyScholarshipService } from './daily-scholarship.service';
import { ActivateScholarshipDto } from './dto/activate-scholarship.dto';
import { ForecastScholarshipDto } from './dto/forecast-scholarship.dto';
import { ScholarshipContentQualityService } from './scholarship-content-quality.service';
import { ScholarshipLifecycleService } from './scholarship-lifecycle.service';
import { ScholarshipsIndexService } from './scholarships-index.service';

type AdminRequest = {
  adminUser?: AdminSessionUser;
  headers: IncomingHttpHeaders;
};

/**
 * Admin: manual refresh trigger.
 * Public (student): profile-aware scholarship listing.
 */
@Controller('admin/scholarships')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.ContentManager)
export class AdminScholarshipsController {
  constructor(
    private readonly scholarshipsIndexService: ScholarshipsIndexService,
    private readonly scholarshipLifecycle: ScholarshipLifecycleService,
    private readonly scholarshipQuality: ScholarshipContentQualityService,
  ) {}

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh() {
    return this.scholarshipsIndexService.refresh();
  }

  // ── Moderation queue (Sprint 3) ───────────────────────────────────────────
  /// List scholarships by moderation status (default: pending review).
  @Get('moderation')
  listForModeration(@Query('status') status?: string) {
    const s =
      status === 'approved' || status === 'rejected' ? status : 'pending';
    return this.scholarshipsIndexService.listForModeration(s);
  }

  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  approve(@Param('id') id: string, @Req() req: AdminRequest) {
    // L'approbation horodate `lastVerifiedAt` : la clause publique exige une
    // date de vérification, et c'est l'humain qui approuve qui la fournit.
    return this.scholarshipsIndexService.setModeration(
      id,
      'approved',
      req.adminUser,
    );
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  reject(@Param('id') id: string) {
    return this.scholarshipsIndexService.setModeration(id, 'rejected');
  }

  @Get(':id/readiness')
  readiness(@Param('id') id: string) {
    return this.scholarshipQuality.getReadiness(id);
  }

  @Post(':id/validate')
  @HttpCode(HttpStatus.OK)
  validate(@Param('id') id: string) {
    return this.scholarshipQuality.getReadiness(id);
  }

  @Post(':id/activate')
  @HttpCode(HttpStatus.OK)
  activate(
    @Param('id') id: string,
    @Body() input: ActivateScholarshipDto,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    // L'identifiant est celui de la ligne d'audit : renvoyé en en-tête, il
    // relie l'événement à l'appel qui l'a écrit.
    const requestId = resolveRequestId(req.headers['x-request-id']);
    res.setHeader('X-Request-Id', requestId);
    if (!req.adminUser) throw new UnauthorizedException();
    return this.scholarshipLifecycle.activate(
      id,
      input,
      req.adminUser,
      requestId,
    );
  }

  @Post(':id/forecast')
  @HttpCode(HttpStatus.OK)
  forecast(
    @Param('id') id: string,
    @Body() input: ForecastScholarshipDto,
  ) {
    return this.scholarshipLifecycle.saveForecast(id, input);
  }
}

/**
 * Public endpoint — consumed by the mobile app. The live-scholarships index
 * is now a launch acquisition surface and remains authenticated so matching
 * and alert subscriptions are always scoped to the current student.
 */
@Controller('scholarships')
export class ScholarshipsController {
  constructor(
    private readonly scholarshipsIndexService: ScholarshipsIndexService,
    private readonly dailyScholarshipService: DailyScholarshipService,
  ) {}

  // Declared before `:id` so "daily" is never captured as a scholarship id.
  @Get('daily')
  @UseGuards(StudentAuthGuard)
  daily(
    @Req() req: { studentUser: { id: string } },
    @Query('lang') lang: string = 'fr',
  ) {
    return this.dailyScholarshipService.getDailyForProfile(
      req.studentUser.id,
      lang === 'en' ? 'en' : 'fr',
    );
  }

  @Get()
  @UseGuards(StudentAuthGuard)
  list(
    @Req() req: { studentUser: { id: string } },
    @Query('lang') lang: string = 'fr',
    @Query('level') level?: string,
    @Query('fields') fields?: string,
    @Query('countryId') countryId?: string,
    @Query('fundingType') fundingType?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    // Chantier I — OPTIONNELS (les builds en store ne les envoient pas) ;
    // validés par le service : une valeur inconnue → 400.
    @Query('q') q?: string,
    @Query('status') status?: string,
    @Query('sort') sort?: string,
  ) {
    return this.scholarshipsIndexService.listForProfile({
      lang: lang === 'en' ? 'en' : 'fr',
      userId: req.studentUser.id,
      level,
      fieldIds: fields ? fields.split(',') : undefined,
      countryId,
      fundingType,
      limit: limit ? parseInt(limit, 10) : 20,
      offset: offset ? parseInt(offset, 10) : 0,
      q,
      status,
      sort,
    });
  }

  @Get(':id')
  @UseGuards(StudentAuthGuard)
  detail(
    @Param('id') id: string,
    @Req() req: { studentUser: { id: string } },
    @Query('lang') lang: string = 'fr',
  ) {
    return this.scholarshipsIndexService.getForProfile(id, {
      lang: lang === 'en' ? 'en' : 'fr',
      userId: req.studentUser.id,
    });
  }
}
