import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { AiConsentGuard } from '../ai/ai-consent.guard';
import { AiQuota, AiQuotaGuard } from '../ai/ai-quota.guard';
import {
  CvSummaryDto,
  InterviewFeedbackDto,
  InterviewQuestionsDto,
  LetterPersonalizeDto,
  ToolsService,
} from './tools.service';

@Controller('tools')
@UseGuards(StudentAuthGuard, AiConsentGuard, AiQuotaGuard)
// Les 4 outils partagent un compteur quotidien par utilisateur.
@AiQuota({
  feature: 'student_tools',
  limitEnv: 'KPB_AI_DAILY_QUOTA_TOOLS',
  defaultDailyLimit: 30,
  maxBodyBytes: 32 * 1024,
})
export class ToolsController {
  constructor(private readonly toolsService: ToolsService) {}

  @Post('cv-summary')
  generateCvSummary(@Body() dto: CvSummaryDto) {
    return this.toolsService.generateCvSummary(dto);
  }

  @Post('personalize-letter')
  personalizeLetters(@Body() dto: LetterPersonalizeDto) {
    return this.toolsService.personalizeLetters(dto);
  }

  @Post('interview/questions')
  getInterviewQuestions(@Body() dto: InterviewQuestionsDto) {
    return this.toolsService.getInterviewQuestions(dto);
  }

  @Post('interview/feedback')
  evaluateInterviewAnswer(@Body() dto: InterviewFeedbackDto) {
    return this.toolsService.evaluateInterviewAnswer(dto);
  }
}
