import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import type { AdminSessionUser } from '../auth/auth.service';
import { CommercialService } from './commercial.service';

type AdminRequest = { adminUser?: AdminSessionUser };

@Controller('commercial')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin)
export class CommercialController {
  constructor(private readonly commercialService: CommercialService) {}

  private reviewerName(req: AdminRequest): string {
    return req.adminUser?.fullName?.trim() || 'Conseiller KPB';
  }

  @Get('leads')
  listLeads(
    @Query('email') email?: string,
    @Query('filter') filter?: string,
  ) {
    return this.commercialService.listLeads(email, filter);
  }

  @Patch('leads/:id')
  updateLead(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() body: { leadTag?: string; discussionMotive?: string },
  ) {
    return this.commercialService.updateLead(id, {
      leadTag: body.leadTag as never,
      discussionMotive: body.discussionMotive,
    });
  }

  // ── Per-document review (Feature D) ──────────────────────────────────────
  // The authed counsellor records a verdict on an uploaded case document.
  @Patch('documents/:id/review')
  reviewDocument(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() body: { status?: string },
    @Req() req: AdminRequest,
  ) {
    return this.commercialService.reviewDocument(
      id,
      body.status ?? '',
      this.reviewerName(req),
    );
  }

  @Get('stats')
  stats(@Query('email') email?: string) {
    return this.commercialService.stats(email);
  }

  // ── Admin only — performance overview for all counsellors ────────────────
  // Method-level @Roles overrides the class default (Reflector.getAllAndOverride).
  @Get('performance')
  @Roles(InternalRole.Admin, InternalRole.SuperAdmin)
  performance() {
    return this.commercialService.performance();
  }
}
