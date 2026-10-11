import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { AmbassadorService } from './ambassador.service';
import { ActivateAmbassadorDto } from './dto/activate-ambassador.dto';

type AuthedReq = Request & { studentUser?: { id: string } };

// Ambassadeur program (App-engagement handoff · US-032→035). Path prefix stays
// under `/referrals` per API_CONTRACTS Module 15; the existing
// ReferralsController owns the other `/referrals/*` routes (no collision).
@Controller('referrals')
@UseGuards(StudentAuthGuard)
export class AmbassadorController {
  constructor(private readonly ambassadorService: AmbassadorService) {}

  /** Real-time ambassador dashboard (or the sample preview if not activated). */
  @Get('dashboard')
  dashboard(@Req() req: AuthedReq) {
    return this.ambassadorService.getDashboard(req.studentUser!.id);
  }

  /** Activate ambassador mode + mint a referral code. */
  @Post('ambassador/activate')
  activate(@Req() req: AuthedReq, @Body() body: ActivateAmbassadorDto) {
    return this.ambassadorService.activate(req.studentUser!.id, {
      displayName: body.displayName,
      campus: body.campus,
      city: body.city,
      payoutAccount: body.payoutAccount,
    });
  }

  /** Request a Wave payout of the FULL available balance (recorded, paid ≤48h). */
  @Post('withdraw')
  withdraw(@Req() req: AuthedReq) {
    return this.ambassadorService.requestWithdrawal(req.studentUser!.id);
  }

  @Get('withdrawals/history')
  history(@Req() req: AuthedReq) {
    return this.ambassadorService.getWithdrawalHistory(req.studentUser!.id);
  }
}
