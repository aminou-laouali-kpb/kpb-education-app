import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { FollowedScholarshipsService } from './followed-scholarships.service';

type StudentRequest = { studentUser: { id: string } };

/**
 * `GET /me/followed-scholarships` — les bourses que suit l'étudiant connecté
 * (favori ou alerte), closes comprises (chantier C). Un invité ne suit rien :
 * la route exige un compte, comme toutes les routes de suivi.
 */
@Controller('me/followed-scholarships')
@UseGuards(StudentAuthGuard)
export class FollowedScholarshipsController {
  constructor(private readonly followed: FollowedScholarshipsService) {}

  @Get()
  list(@Req() req: StudentRequest, @Query('lang') lang: string = 'fr') {
    return this.followed.list(req.studentUser.id, lang === 'en' ? 'en' : 'fr');
  }
}
