import { Body, Controller, Post, UseGuards } from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { AiConsentGuard } from '../ai/ai-consent.guard';
import { AiQuota, AiQuotaGuard } from '../ai/ai-quota.guard';
import {
  DocumentKind,
  DocumentReviewLanguage,
  DocumentReviewService,
} from './document-review.service';

@Controller('document-review')
@UseGuards(StudentAuthGuard, AiConsentGuard, AiQuotaGuard)
@AiQuota({
  feature: 'document_review',
  limitEnv: 'KPB_AI_DAILY_QUOTA_DOCUMENT_REVIEW',
  defaultDailyLimit: 10,
  maxBodyBytes: 48 * 1024,
})
export class DocumentReviewController {
  constructor(private readonly service: DocumentReviewService) {}

  /// Returns structured, on-rubric feedback for a pasted motivation letter / CV.
  @Post()
  review(@Body() body: { kind?: string; text?: string; language?: string }) {
    const kind: DocumentKind = body?.kind === 'cv' ? 'cv' : 'motivation';
    const language: DocumentReviewLanguage = String(body?.language ?? '')
      .toLowerCase()
      .startsWith('en')
      ? 'en'
      : 'fr';
    return this.service.review(kind, body?.text ?? '', language);
  }
}
