import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { UpdateScholarshipAlertDto } from './dto/update-scholarship-alert.dto';
import { ScholarshipAlertsService } from './scholarship-alerts.service';

type StudentRequest = { studentUser: { id: string } };

@Controller('me/scholarship-alerts')
@UseGuards(StudentAuthGuard)
export class ScholarshipAlertsController {
  constructor(private readonly scholarshipAlerts: ScholarshipAlertsService) {}

  @Get()
  list(@Req() req: StudentRequest) {
    return this.scholarshipAlerts.list(req.studentUser.id);
  }

  @Post(':scholarshipId')
  subscribe(
    @Param('scholarshipId') scholarshipId: string,
    @Req() req: StudentRequest,
  ) {
    return this.scholarshipAlerts.subscribe(
      req.studentUser.id,
      scholarshipId,
    );
  }

  /** Builds récentes : l'annonce d'ouverture, sans toucher au favori. */
  @Patch(':scholarshipId')
  updatePreference(
    @Param('scholarshipId') scholarshipId: string,
    @Body() input: UpdateScholarshipAlertDto,
    @Req() req: StudentRequest,
  ) {
    return this.scholarshipAlerts.updatePreference(
      req.studentUser.id,
      scholarshipId,
      input.notifyOpening,
    );
  }

  @Delete(':scholarshipId')
  unsubscribe(
    @Param('scholarshipId') scholarshipId: string,
    @Req() req: StudentRequest,
  ) {
    return this.scholarshipAlerts.unsubscribe(
      req.studentUser.id,
      scholarshipId,
    );
  }
}
