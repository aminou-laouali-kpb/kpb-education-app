import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { MvpGuard } from '../../common/guards/mvp.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ContentService } from './content.service';

@Controller()
export class ContentController {
  constructor(private readonly contentService: ContentService) {}

  @Get('content/service-offers')
  listServiceOffers() {
    return this.contentService.listServiceOffers({ publicOnly: true });
  }

  @Get('content/support-destinations')
  listSupportDestinations() {
    return this.contentService.listSupportDestinations({ publicOnly: true });
  }

  // Blog/articles are hidden in the MVP app (AppConfig.mvpOnly) — gate to
  // match (P0-C). service-offers/support-destinations above stay open: the
  // MVP home screen consumes them.
  @Get('content/articles')
  @UseGuards(MvpGuard)
  listArticles() {
    return this.contentService.listArticles({ publicOnly: true });
  }

  @Get('admin/service-offers')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  adminListServiceOffers() {
    return this.contentService.listServiceOffers();
  }

  @Post('admin/service-offers')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  createServiceOffer(@Body() input: Record<string, unknown>) {
    return this.contentService.createServiceOffer(input);
  }

  @Patch('admin/service-offers/:id')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  updateServiceOffer(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() input: Record<string, unknown>,
  ) {
    return this.contentService.updateServiceOffer(id, input);
  }

  @Get('admin/support-destinations')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  adminListSupportDestinations() {
    return this.contentService.listSupportDestinations();
  }

  @Post('admin/support-destinations')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  createSupportDestination(@Body() input: Record<string, unknown>) {
    return this.contentService.createSupportDestination(input);
  }

  @Patch('admin/support-destinations/:id')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  updateSupportDestination(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() input: Record<string, unknown>,
  ) {
    return this.contentService.updateSupportDestination(id, input);
  }

  @Get('admin/articles')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  adminListArticles() {
    return this.contentService.listArticles();
  }

  @Post('admin/articles')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  createArticle(@Body() input: Record<string, unknown>) {
    return this.contentService.createArticle(input);
  }

  @Patch('admin/articles/:id')
  @UseGuards(AdminAuthGuard, RolesGuard)
  @Roles(
    InternalRole.ContentManager,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  )
  updateArticle(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() input: Record<string, unknown>,
  ) {
    return this.contentService.updateArticle(id, input);
  }
}
