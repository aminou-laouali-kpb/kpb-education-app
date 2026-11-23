import {
  Body,
  Controller,
  Logger,
  Post,
  Req,
  ServiceUnavailableException,
  UseGuards,
} from '@nestjs/common';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { AiConsentGuard } from '../ai/ai-consent.guard';
import {
  AiQuota,
  AiQuotaConsumption,
  AiQuotaGuard,
} from '../ai/ai-quota.guard';
import { AiQuotaService } from '../ai/ai-quota.service';
import {
  CvSummaryDto,
  InterviewFeedbackDto,
  InterviewQuestionsDto,
  LetterPersonalizeDto,
  ToolsService,
} from './tools.service';

type ToolsRequest = { aiQuotaConsumption?: AiQuotaConsumption };

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
  private readonly logger = new Logger(ToolsController.name);

  constructor(
    private readonly toolsService: ToolsService,
    private readonly quota: AiQuotaService,
  ) {}

  @Post('cv-summary')
  generateCvSummary(@Body() dto: CvSummaryDto, @Req() req: ToolsRequest) {
    return this.refundOnUnavailable(req, () =>
      this.toolsService.generateCvSummary(dto),
    );
  }

  @Post('personalize-letter')
  personalizeLetters(
    @Body() dto: LetterPersonalizeDto,
    @Req() req: ToolsRequest,
  ) {
    return this.refundOnUnavailable(req, () =>
      this.toolsService.personalizeLetters(dto),
    );
  }

  @Post('interview/questions')
  getInterviewQuestions(
    @Body() dto: InterviewQuestionsDto,
    @Req() req: ToolsRequest,
  ) {
    return this.refundOnUnavailable(req, () =>
      this.toolsService.getInterviewQuestions(dto),
    );
  }

  @Post('interview/feedback')
  evaluateInterviewAnswer(
    @Body() dto: InterviewFeedbackDto,
    @Req() req: ToolsRequest,
  ) {
    return this.refundOnUnavailable(req, () =>
      this.toolsService.evaluateInterviewAnswer(dto),
    );
  }

  /**
   * Le guard décompte AVANT l'appel au modèle. Quand l'outil répond 503 (IA
   * non configurée, panne du fournisseur, sortie inexploitable), l'élève n'a
   * rien reçu : on lui rend l'unité, comme le coach (audit 22/11/2026,
   * constat 16). Un échec du remboursement ne masque jamais la 503.
   */
  private async refundOnUnavailable<T>(
    req: ToolsRequest,
    run: () => Promise<T>,
  ): Promise<T> {
    try {
      return await run();
    } catch (error) {
      const consumption = req.aiQuotaConsumption;
      if (error instanceof ServiceUnavailableException && consumption) {
        try {
          await this.quota.refund({
            userId: consumption.userId,
            feature: consumption.feature,
            now: consumption.consumedAt,
          });
        } catch (refundError) {
          this.logger.warn(
            `Tools quota refund failed: ${refundError instanceof Error ? refundError.message : String(refundError)}`,
          );
        }
      }
      throw error;
    }
  }
}
