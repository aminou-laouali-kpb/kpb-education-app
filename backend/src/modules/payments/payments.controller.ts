import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { PaymentsService } from './payments.service';

type StudentReq = Request & { studentUser?: { id: string; email: string; fullName: string; phone: string } };

/** Student/parent-facing — create a checkout. */
@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Get('providers')
  listProviders() {
    return { providers: this.paymentsService.listAvailableProviders() };
  }

  @Post('intents')
  @UseGuards(StudentAuthGuard)
  create(
    @Req() req: StudentReq,
    @Body()
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    body: {
      provider: 'cinetpay' | 'paydunya' | 'stripe' | 'manual';
      amountMinor: number;
      currency?: string;
      caseId?: string;
      counsellorId?: string;
      description?: string;
      returnUrl: string;
      cancelUrl: string;
    },
  ) {
    if (!req.studentUser) {
      throw new Error('Student context missing.');
    }
    return this.paymentsService.createIntent({
      ...body,
      userId: req.studentUser.id,
      customer: {
        email: req.studentUser.email,
        phone: req.studentUser.phone,
        fullName: req.studentUser.fullName,
      },
    });
  }

  @Get('intents/:id')
  @UseGuards(StudentAuthGuard)
  get(@Param('id') id: string) {
    return this.paymentsService.getIntent(id);
  }

  /**
   * Provider webhooks. Public endpoint — adapters verify signatures
   * internally. Always returns 200 after we persist so providers stop
   * retrying successful notifications.
   */
  @Post('webhooks/:provider')
  @HttpCode(HttpStatus.OK)
  webhook(
    @Param('provider') provider: 'cinetpay' | 'paydunya' | 'stripe',
    @Req() req: Request,
  ) {
    return this.paymentsService.handleWebhook(provider, {
      body: req.body,
      headers: req.headers,
      rawBody: (req as { rawBody?: Buffer }).rawBody,
    });
  }
}

/** Admin — reconcile offline payments, view intents. */
@Controller('admin/payments')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.Commercial)
export class AdminPaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Patch('intents/:id/mark-paid')
  markPaid(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() body: { note?: string },
  ) {
    return this.paymentsService.markPaidManually(id, body.note);
  }
}
