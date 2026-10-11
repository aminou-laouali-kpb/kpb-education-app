import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import type { AdminSessionUser } from '../auth/auth.service';
import { CreateScholarshipVideoDto } from '../scholarships-index/dto/create-scholarship-video.dto';
import { UpdateScholarshipVideoDto } from '../scholarships-index/dto/update-scholarship-video.dto';
import { ScholarshipVideosService } from '../scholarships-index/scholarship-videos.service';
import { AdminCatalogService } from './admin-catalog.service';

type AdminRequest = { adminUser?: AdminSessionUser };

/// Catalogue write API for the back-office. Read access stays on the public
/// `/catalog/*` controller; these mutations are admin-only.
@Controller('admin/catalog')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.ContentManager)
export class AdminCatalogController {
  constructor(
    private readonly service: AdminCatalogService,
    private readonly scholarshipVideos: ScholarshipVideosService,
  ) {}

  private verifier(req: AdminRequest): AdminSessionUser {
    return (
      req.adminUser ?? {
        id: 'unknown-admin',
        fullName: 'Unknown admin',
        email: 'unknown-admin@kpb.education',
        role: InternalRole.Admin,
        languageScope: [],
      }
    );
  }

  // ── Verification (data-trust signal) ──────────────────────────────────────
  @Get('verification-due')
  listVerificationDue() {
    return this.service.listVerificationDue();
  }

  @Post('verify')
  setVerification(
    @Req() req: AdminRequest,
    @Body()
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    body: { entity: string; id: string; verified?: boolean; sourceUrl?: string },
  ) {
    return this.service.setVerification(
      body.entity,
      body.id,
      body.verified ?? true,
      body.sourceUrl,
      this.verifier(req),
    );
  }

  // ── Programs (formations) ─────────────────────────────────────────────────
  @Post('programs')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  createProgram(@Body() input: Record<string, unknown>) {
    return this.service.createProgram(input);
  }

  @Patch('programs/:id')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  updateProgram(@Param('id') id: string, @Body() input: Record<string, unknown>) {
    return this.service.updateProgram(id, input);
  }

  @Delete('programs/:id')
  deleteProgram(@Param('id') id: string) {
    return this.service.deleteProgram(id);
  }

  // ── Institutions (universités) ────────────────────────────────────────────
  @Post('institutions')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  createInstitution(@Body() input: Record<string, unknown>) {
    return this.service.createInstitution(input);
  }

  @Patch('institutions/:id')
  updateInstitution(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.updateInstitution(id, input);
  }

  @Delete('institutions/:id')
  deleteInstitution(@Param('id') id: string) {
    return this.service.deleteInstitution(id);
  }

  // ── Scholarships (bourses) ────────────────────────────────────────────────
  @Post('scholarships')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  createScholarship(@Body() input: Record<string, unknown>) {
    return this.service.createScholarship(input);
  }

  @Patch('scholarships/:id')
  updateScholarship(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.updateScholarship(id, input);
  }

  @Delete('scholarships/:id')
  deleteScholarship(@Param('id') id: string) {
    return this.service.deleteScholarship(id);
  }

  // ── Scholarship application steps ("comment postuler") ────────────────────
  @Get('scholarships/:id/steps')
  listApplicationSteps(@Param('id') id: string) {
    return this.service.listApplicationSteps(id);
  }

  @Post('scholarships/:id/steps')
  createApplicationStep(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.createApplicationStep(id, input);
  }

  @Patch('scholarships/:id/steps/:stepId')
  updateApplicationStep(
    @Param('id') id: string,
    @Param('stepId') stepId: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() input: Record<string, unknown>,
  ) {
    return this.service.updateApplicationStep(id, stepId, input);
  }

  @Delete('scholarships/:id/steps/:stepId')
  deleteApplicationStep(
    @Param('id') id: string,
    @Param('stepId') stepId: string,
  ) {
    return this.service.deleteApplicationStep(id, stepId);
  }

  // ── Scholarship YouTube explainers ──────────────────────────────────────
  @Get('scholarships/:id/videos')
  listScholarshipVideos(@Param('id') id: string) {
    return this.scholarshipVideos.list(id);
  }

  @Post('scholarships/:id/videos')
  createScholarshipVideo(
    @Param('id') id: string,
    @Body() input: CreateScholarshipVideoDto,
  ) {
    return this.scholarshipVideos.create(id, input);
  }

  @Patch('scholarships/:id/videos/:videoId')
  updateScholarshipVideo(
    @Param('id') id: string,
    @Param('videoId') videoId: string,
    @Body() input: UpdateScholarshipVideoDto,
  ) {
    return this.scholarshipVideos.update(id, videoId, input);
  }

  @Delete('scholarships/:id/videos/:videoId')
  deleteScholarshipVideo(
    @Param('id') id: string,
    @Param('videoId') videoId: string,
  ) {
    return this.scholarshipVideos.delete(id, videoId);
  }

  // ── Countries (pays) ──────────────────────────────────────────────────────
  @Post('countries')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  createCountry(@Body() input: Record<string, unknown>) {
    return this.service.createCountry(input);
  }

  @Patch('countries/:id')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  updateCountry(@Param('id') id: string, @Body() input: Record<string, unknown>) {
    return this.service.updateCountry(id, input);
  }

  @Delete('countries/:id')
  deleteCountry(@Param('id') id: string) {
    return this.service.deleteCountry(id);
  }

  // ── Fields (filières) ─────────────────────────────────────────────────────
  @Post('fields')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  createField(@Body() input: Record<string, unknown>) {
    return this.service.createField(input);
  }

  @Patch('fields/:id')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  updateField(@Param('id') id: string, @Body() input: Record<string, unknown>) {
    return this.service.updateField(id, input);
  }

  @Delete('fields/:id')
  deleteField(@Param('id') id: string) {
    return this.service.deleteField(id);
  }
}
