import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { ReadNotificationsByRefDto } from './dto/read-notifications-by-ref.dto';
import { UserNotificationsService } from './user-notifications.service';

type StudentRequest = { studentUser: { id: string } };

@Controller('me/notifications')
@UseGuards(StudentAuthGuard)
export class UserNotificationsController {
  constructor(private readonly notifications: UserNotificationsService) {}

  @Get()
  list(@Req() req: StudentRequest, @Query('lang') lang: string = 'fr') {
    return this.notifications.list(
      req.studentUser.id,
      lang === 'en' ? 'en' : 'fr',
    );
  }

  /** Le badge de la cloche, sans charger le fil. */
  @Get('unread-count')
  unreadCount(@Req() req: StudentRequest) {
    return this.notifications.unreadCount(req.studentUser.id);
  }

  @Patch(':id/read')
  markRead(@Param('id') id: string, @Req() req: StudentRequest) {
    return this.notifications.markRead(req.studentUser.id, id);
  }

  @Post('read-all')
  markAllRead(@Req() req: StudentRequest) {
    return this.notifications.markAllRead(req.studentUser.id);
  }

  /** Tap sur un push groupé : ses références (`refs`) sont marquées lues. */
  @Post('read-by-ref')
  @HttpCode(HttpStatus.OK)
  markReadByRefs(
    @Body() input: ReadNotificationsByRefDto,
    @Req() req: StudentRequest,
  ) {
    return this.notifications.markReadByRefs(req.studentUser.id, input.refs);
  }
}
