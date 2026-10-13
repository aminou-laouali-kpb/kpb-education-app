import { Controller, Get, Header, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminAppBuildsService } from './admin-app-builds.service';

/**
 * Adoption des builds de l'app, pour décider quand relever `minVersion` ou
 * changer de fournisseur de push.
 *
 * Mêmes rôles que le tableau de bord (`AdminDashboardController`) et les
 * rapports : ce sont des comptages, sans donnée personnelle.
 */
@Controller('admin/app-builds')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Admin,
  InternalRole.SuperAdmin,
  InternalRole.Counselor,
  InternalRole.Commercial,
)
export class AdminAppBuildsController {
  constructor(private readonly adminAppBuildsService: AdminAppBuildsService) {}

  // Réponse d'une session d'administration : aucun cache partagé ne doit la
  // resservir à une requête sans cookie.
  @Get()
  @Header('Cache-Control', 'private, no-store')
  @Header('Vary', 'Cookie')
  getAdoption() {
    return this.adminAppBuildsService.getAdoption();
  }
}
