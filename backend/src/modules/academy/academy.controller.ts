import { Controller, Get, Param } from '@nestjs/common';

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
