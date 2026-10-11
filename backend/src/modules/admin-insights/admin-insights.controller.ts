import { Controller, Get, Query, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminInsightsService } from './admin-insights.service';

@Controller('admin/insights')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin)
export class AdminInsightsController {
  constructor(private readonly insights: AdminInsightsService) {}

  /** `from` / `to` : AAAA-MM-JJ (UTC, inclus). Défaut : 30 derniers jours. */
  @Get()
  get(@Query('from') from?: string, @Query('to') to?: string) {
    return this.insights.getInsights(from, to);
  }
}
