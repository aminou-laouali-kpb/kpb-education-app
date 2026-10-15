import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Put,
  Query,
  Req,
  UseFilters,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { SCHOLARSHIP_MATCH_RUN_THROTTLE } from '../../common/throttler-options';
import { CreateMatchRunDto } from './dto/create-match-run.dto';
import { UpdateMatchAlertsDto } from './dto/update-match-alerts.dto';
import {
  ScholarshipMatchDisabledFilter,
  ScholarshipMatchEnabledGuard,
} from './scholarship-match.feature';
import { ScholarshipMatchService } from './scholarship-match.service';

type StudentRequest = { studentUser?: { id: string; accountType?: string } };

/**
 * « Mes 10 bourses » (chantier D).
 *
 * Chaque chemin a au moins deux segments (`match/state`, `match/runs`,
 * `match/alerts`) : le `GET /scholarships/:id` du catalogue ne peut pas les
 * capturer.
 *
 * Ordre des portes : drapeau (404 `{ disabled: true }`), puis jeton élève
 * (401), puis type de compte (403 pour un parent ou un partenaire — le test
 * est caché pour eux en v1, et ses réponses décrivent l'élève lui-même).
 */
@Controller('scholarships/match')
@UseFilters(ScholarshipMatchDisabledFilter)
@UseGuards(ScholarshipMatchEnabledGuard, StudentAuthGuard)
export class ScholarshipMatchController {
  constructor(private readonly scholarshipMatch: ScholarshipMatchService) {}

  private studentId(req: StudentRequest): string {
    const accountType = req.studentUser?.accountType;
    if (accountType && accountType !== 'student') {
      throw new ForbiddenException('Only student accounts can take the scholarship test.');
    }
    return req.studentUser!.id;
  }

  @Get('state')
  state(@Req() req: StudentRequest, @Query('lang') lang?: string) {
    return this.scholarshipMatch.state(this.studentId(req), lang);
  }

  @Post('runs')
  @HttpCode(HttpStatus.OK)
  @Throttle(SCHOLARSHIP_MATCH_RUN_THROTTLE)
  createRun(@Req() req: StudentRequest, @Body() body: CreateMatchRunDto) {
    return this.scholarshipMatch.createRun(this.studentId(req), body);
  }

  @Put('alerts')
  setAlerts(@Req() req: StudentRequest, @Body() body: UpdateMatchAlertsDto) {
    return this.scholarshipMatch.setAlerts(this.studentId(req), body.enabled);
  }
}
