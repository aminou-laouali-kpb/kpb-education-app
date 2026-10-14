import { Controller, UseGuards } from '@nestjs/common';

import { Roles } from '../../../common/decorators/roles.decorator';
import { InternalRole } from '../../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { ScholarshipOpeningAdminService } from './scholarship-opening-admin.service';

/**
 * Annonce d'ouverture d'une bourse — routes de l'équipe (chantier C) :
 * aperçu, annulation, arrêt des envois, rapport, « À faire », colonnes de la
 * liste. Contrats : `docs/api-contracts.md` et `scholarship-opening.contract.ts`.
 *
 * Même chemin, mêmes gardes et mêmes rôles que `AdminScholarshipsController` :
 * qui peut ouvrir un cycle peut en voir l'aperçu. La limite « au-delà du
 * seuil, administrateurs seulement » se joue dans `activate`, pas ici.
 *
 * Coquille posée par le lot « schema » pour que `app.module.ts` soit final ;
 * les routes arrivent avec le lot « fanout », qui possède ce fichier.
 */
@Controller('admin/scholarships')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.ContentManager)
export class AdminScholarshipOpeningController {
  constructor(private readonly opening: ScholarshipOpeningAdminService) {}
}
