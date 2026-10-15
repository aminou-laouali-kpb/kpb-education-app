import { Body, Controller, Get, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { MatchPreviewDto } from './dto/match-preview.dto';
import { ScholarshipEligibilityAdminService } from './scholarship-eligibility-admin.service';

/**
 * Éligibilité structurée, côté équipe (« Mes 10 bourses », chantier D4).
 *
 * Mêmes gardes et mêmes rôles que l'édition du contenu des bourses (Admin,
 * SuperAdmin, ContentManager). Les écritures (niveaux, critères, tampon
 * « Conditions vérifiées ») passent par `PATCH /admin/catalog/scholarships/:id`.
 *
 * Toutes ces routes ont un segment FIXE : le contrôleur est déclaré AVANT
 * `AdminScholarshipsController` dans `app.module.ts`, pour qu'aucune route en
 * `:id` (présente ou future) ne lise jamais `eligibility-coverage` comme un
 * identifiant de bourse.
 */
@Controller('admin/scholarships')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.ContentManager)
export class AdminScholarshipEligibilityController {
  constructor(private readonly service: ScholarshipEligibilityAdminService) {}

  /** Couverture des bourses publiques : la porte de lancement (90 %). */
  @Get('eligibility-coverage')
  coverage() {
    return this.service.coverage();
  }

  /** Pays ISO 3166-1 (FR/EN) et constantes de l'éditeur de critères. */
  @Get('eligibility-options')
  options() {
    return this.service.options();
  }

  /** « Tester un profil » : le moteur, sans rien persister. */
  @Post('match-preview')
  @HttpCode(HttpStatus.OK)
  matchPreview(@Body() input: MatchPreviewDto) {
    return this.service.matchPreview(input);
  }
}
