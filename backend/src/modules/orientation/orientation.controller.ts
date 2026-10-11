import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { AiConsentGuard } from '../ai/ai-consent.guard';
import { AiQuota, AiQuotaGuard } from '../ai/ai-quota.guard';

const ORIENTATION_AI_QUOTA = AiQuota({
  feature: 'orientation',
  limitEnv: 'KPB_AI_DAILY_QUOTA_ORIENTATION',
  defaultDailyLimit: 10,
  maxBodyBytes: 16 * 1024,
});
import { OrientationService } from './orientation.service';

@Controller('orientation')
export class OrientationController {
  constructor(private readonly orientationService: OrientationService) {}

  // Public: static question catalogue, no LLM, no DB write.
  @Get('questions')
  getQuestions() {
    return this.orientationService.getQuestions();
  }

  // Authenticated: calls the LLM provider + writes OrientationSession. Without
  // the guard, an attacker could burn AI quota and spam the DB at the global rate-limit
  // (60 req/min/IP in prod = ~86 400 paid completions/day per IP).
  @Post('sessions')
  @UseGuards(StudentAuthGuard, AiConsentGuard, AiQuotaGuard)
  @ORIENTATION_AI_QUOTA
  createSession(@Body() body: Record<string, unknown>, @Req() req: any) {
    return this.orientationService.createSession(
      this._withAuthenticatedUserId(body, req),
    );
  }

  @Post('submit')
  @UseGuards(StudentAuthGuard, AiConsentGuard, AiQuotaGuard)
  @ORIENTATION_AI_QUOTA
  submit(@Body() body: Record<string, unknown>, @Req() req: any) {
    return this.orientationService.createSession(
      this._withAuthenticatedUserId(body, req),
    );
  }

  @Get('results/:id')
  @UseGuards(StudentAuthGuard)
  getResults(@Param('id') id: string, @Req() req: any) {
    return this.orientationService.getResults(id, req.studentUser.id);
  }

  /// Overrides any client-supplied userId / profile.id with the authenticated
  /// id so the persisted session can never be attributed to another user.
  private _withAuthenticatedUserId(
    body: Record<string, unknown>,
    req: any,
  ): Record<string, unknown> {
    const studentId = req.studentUser.id;
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    return {
      ...body,
      userId: studentId,
      profile: { ...profile, id: studentId },
    };
  }
}
