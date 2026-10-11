import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { ServicePackagesService } from './service-packages.service';

// The student access-token payload only carries id/email/role; fullName and
// phone are resolved from the stored profile in the service layer.
type AuthedReq = Request & { studentUser?: { id: string; email: string } };

/**
 * Public catalog — no auth. Parents browsing the app before login still
 * need to see the "Dossier prêt" pricing so they can decide to create
 * an account.
 */
@Controller('service-packages')
export class ServicePackagesController {
  constructor(
    private readonly servicePackagesService: ServicePackagesService,
  ) {}

  @Get()
  list(@Query('category') category?: string) {
    return this.servicePackagesService.listPublic({ category });
  }

  @Get(':code')
  get(@Param('code') code: string) {
    return this.servicePackagesService.getPublic(code);
  }
}

/**
 * Authenticated student endpoints — purchase flow and history.
 */
@Controller('me/purchases')
@UseGuards(StudentAuthGuard)
export class MyPurchasesController {
  constructor(
    private readonly servicePackagesService: ServicePackagesService,
  ) {}

  @Post()
  purchase(
    @Req() req: AuthedReq,
    @Body()
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    body: {
      packageCode: string;
      provider?: 'cinetpay' | 'paydunya' | 'manual';
      caseId?: string;
      returnUrl: string;
      cancelUrl: string;
    },
  ) {
    const user = req.studentUser!;
    return this.servicePackagesService.purchase({
      userId: user.id,
      packageCode: body.packageCode,
      provider: body.provider,
      caseId: body.caseId,
      returnUrl: body.returnUrl,
      cancelUrl: body.cancelUrl,
      // phone/fullName are resolved from the profile inside the service.
      customer: { email: user.email },
    });
  }

  @Post('whatsapp')
  createWhatsAppPurchase(
    @Req() req: AuthedReq,
    @Body()
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    body: {
      packageCode: string;
      caseId?: string;
      source?: string;
    },
  ) {
    return this.servicePackagesService.createWhatsAppPurchase({
      userId: req.studentUser!.id,
      packageCode: body.packageCode,
      caseId: body.caseId,
      source: body.source,
    });
  }

  @Get()
  list(@Req() req: AuthedReq) {
    return this.servicePackagesService.listForUser(req.studentUser!.id);
  }

  @Get(':id')
  get(@Req() req: AuthedReq, @Param('id') id: string) {
    return this.servicePackagesService.getForUser(req.studentUser!.id, id);
  }
}

/**
 * Admin — CRUD for the catalog + delivery workflow for purchases.
 */
@Controller('admin/service-packages')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Admin,
  InternalRole.SuperAdmin,
  InternalRole.ContentManager,
  InternalRole.Commercial,
)
export class AdminServicePackagesController {
  constructor(
    private readonly servicePackagesService: ServicePackagesService,
  ) {}

  @Get()
  list() {
    return this.servicePackagesService.listAdmin();
  }

  @Post()
  create(@Body() body: Parameters<ServicePackagesService['createPackage']>[0]) {
    return this.servicePackagesService.createPackage(body);
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body() body: Parameters<ServicePackagesService['updatePackage']>[1],
  ) {
    return this.servicePackagesService.updatePackage(id, body);
  }

  @Get('purchases/list')
  listPurchases(@Query('status') status?: string) {
    return this.servicePackagesService.listPurchasesAdmin(status);
  }

  @Patch('purchases/:id')
  updatePurchase(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() body: { status: string; internalNotes?: string },
  ) {
    return this.servicePackagesService.updatePurchaseStatus(
      id,
      body.status,
      body.internalNotes,
    );
  }
}
