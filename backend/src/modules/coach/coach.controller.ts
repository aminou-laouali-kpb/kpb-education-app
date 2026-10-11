import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  Sse,
  UseGuards,
  MessageEvent,
} from '@nestjs/common';
import { Observable } from 'rxjs';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { CoachService } from './coach.service';

@Controller('coach')
@UseGuards(StudentAuthGuard)
export class CoachController {
  constructor(private readonly coachService: CoachService) {}

  @Get('quota')
  getQuota(@Req() req: any) {
    return this.coachService.getQuota(req.studentUser.id);
  }

  @Get('suggestions')
  getSuggestions(@Query('lang') lang = '') {
    return this.coachService.getSuggestions({
      fullName: 'Étudiant',
      preferredLanguage: lang,
    });
  }

  @Post('conversations')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  createConversation(@Body() body: Record<string, unknown>, @Req() req: any) {
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    return this.coachService.createConversation(req.studentUser.id, profile);
  }

  @Get('conversations/:id/messages')
  getMessages(@Param('id') id: string, @Req() req: any) {
    return this.coachService.getMessages(id, req.studentUser.id);
  }

  @Sse('conversations/:id/messages/stream')
  streamMessage(
    @Param('id') id: string,
    @Req() req: any,
    @Query('message') message = '',
    @Query('fullName') fullName = 'Étudiant',
    @Query('currentLevel') currentLevel = '',
    @Query('targetCountryIds') targetCountryIds = '',
    @Query('lang') lang = '',
  ): Observable<MessageEvent> {
    return this.coachService.streamReply({
      conversationId: id,
      userId: req.studentUser.id,
      message,
      profile: {
        fullName,
        currentLevel,
        targetCountryIds: targetCountryIds
          ? targetCountryIds.split(',').filter(Boolean)
          : [],
        preferredLanguage: lang,
      },
    });
  }

  @Post('conversations/:id/messages')
  postMessage(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() body: Record<string, unknown>,
    @Req() req: any,
  ): Observable<MessageEvent> {
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    const message = String(body.message ?? '');
    return this.coachService.streamReply({
      conversationId: id,
      userId: req.studentUser.id,
      message,
      profile,
    });
  }
}
