import { Controller, Get, Param, Req, UseGuards } from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { PassService } from '../pass/pass.service';
import { AcademyService } from './academy.service';

/**
 * Cours Academy servis à l'app (lecture seule, sans compte).
 *
 * Pas de `MvpGuard`, contrairement aux autres surfaces masquées au lancement :
 * ces routes ne servent que ce que l'équipe a explicitement publié, et rien ne
 * l'est par défaut (un cours naît en brouillon). La publication dans l'admin
 * est la vraie porte ; un drapeau global de plus forcerait à rouvrir aussi
 * l'alumni, le salon ou le blog pour montrer un seul cours.
 */
@Controller('academy')
export class AcademyController {
  constructor(private readonly academy: AcademyService) {}

  @Get('courses')
  listCourses() {
    return this.academy.listCourses();
  }

  @Get('courses/:idOrSlug')
  getCourse(@Param('idOrSlug') idOrSlug: string) {
    return this.academy.getCourse(idOrSlug);
  }
}

/**
 * Le même cours, pour un élève connecté : les leçons réservées au Pass ne
 * s'ouvrent que si son Pass Karatou est actif à l'instant de la requête.
 */
@Controller('me/academy')
@UseGuards(StudentAuthGuard)
export class MeAcademyController {
  constructor(
    private readonly academy: AcademyService,
    private readonly pass: PassService,
  ) {}

  @Get('courses/:idOrSlug')
  async getCourse(
    @Req() req: { studentUser: { id: string } },
    @Param('idOrSlug') idOrSlug: string,
  ) {
    const hasPass = await this.pass.hasActivePass(req.studentUser.id);
    return {
      ...(await this.academy.getCourse(idOrSlug, hasPass)),
      viewerHasPass: hasPass,
    };
  }
}
