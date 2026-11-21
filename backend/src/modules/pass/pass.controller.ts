import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { IncomingHttpHeaders } from 'node:http';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { resolveRequestId } from '../../common/request-id';
import type { AdminSessionUser } from '../auth/auth.service';
import { AdminPassGrantDto, PassWebhookGrantDto, RevokePassDto } from './dto/pass.dto';
import { PassWebhookGuard } from './pass-webhook.guard';
import { PassService } from './pass.service';

type HeaderRequest = { headers?: IncomingHttpHeaders };
type AdminRequest = HeaderRequest & { adminUser?: AdminSessionUser };
type StudentRequest = { studentUser: { id: string } };

/**
 * n8n → serveur : « tel compte a payé, ouvre le Pass ». Protégé par le secret
 * partagé (PassWebhookGuard), pas par une session : n8n n'a pas de compte.
 */
@Controller('integrations/pass')
@UseGuards(PassWebhookGuard)
export class PassWebhookController {
  constructor(private readonly pass: PassService) {}

  @Post('grant')
  @HttpCode(200)
  grant(@Req() req: HeaderRequest, @Body() input: PassWebhookGrantDto) {
    return this.pass.grant({
      email: input.email,
      durationDays: input.durationDays,
      paymentReference: input.paymentReference,
      amountXof: input.amountXof,
      note: input.note,
      source: 'webhook',
      grantedBy: input.salesAgent,
      actorAdminId: null,
      requestId: resolveRequestId(req.headers?.['x-request-id']),
    });
  }
}

/** L'app lit son statut ; elle ne peut ni acheter ni s'accorder un accès. */
@Controller('me/pass')
@UseGuards(StudentAuthGuard)
export class StudentPassController {
  constructor(private readonly pass: PassService) {}

  @Get()
  status(@Req() req: StudentRequest) {
    return this.pass.status(req.studentUser.id);
  }
}

/**
 * Console : la même action que le webhook (secours si n8n est en panne), la
 * liste et la révocation. Ouvert à l'équipe commerciale, qui encaisse.
 * Miroir côté console : `AdminCapability.ManagePassGrants`.
 */
@Controller('admin/pass')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.Commercial)
export class AdminPassController {
  constructor(private readonly pass: PassService) {}

  @Get('grants')
  list(@Query('q') q?: string) {
    return this.pass.list({ q });
  }

  @Post('grants')
  grant(@Req() req: AdminRequest, @Body() input: AdminPassGrantDto) {
    return this.pass.grant({
      email: input.email,
      durationDays: input.durationDays,
      paymentReference: input.paymentReference,
      amountXof: input.amountXof,
      note: input.note,
      source: 'admin',
      grantedBy: req.adminUser?.email ?? 'admin',
      actorAdminId: req.adminUser?.id ?? null,
      requestId: resolveRequestId(req.headers?.['x-request-id']),
    });
  }

  @Post('grants/:id/revoke')
  @HttpCode(200)
  revoke(@Req() req: AdminRequest, @Param('id') id: string, @Body() input: RevokePassDto) {
    return this.pass.revoke(id, {
      reason: input.reason,
      revokedBy: req.adminUser?.email ?? 'admin',
      actorAdminId: req.adminUser?.id ?? null,
      requestId: resolveRequestId(req.headers?.['x-request-id']),
    });
  }
}
