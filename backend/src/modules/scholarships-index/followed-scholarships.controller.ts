import { Controller, UseGuards } from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { FollowedScholarshipsService } from './followed-scholarships.service';

/**
 * `GET /me/followed-scholarships` — les bourses que suit l'étudiant connecté
 * (favori ou alerte), closes comprises (chantier C). Un invité ne suit rien :
 * la route exige un compte, comme toutes les routes de suivi.
 *
 * Coquille posée par le lot « schema » ; la route arrive avec le lot
 * « student-api », qui possède ce fichier.
 */
@Controller('me/followed-scholarships')
@UseGuards(StudentAuthGuard)
export class FollowedScholarshipsController {
  constructor(private readonly followed: FollowedScholarshipsService) {}
}
