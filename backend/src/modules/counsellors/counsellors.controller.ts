import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import type { SupabaseTokenUser } from '../auth/supabase-auth.service';
import { CounsellorsService } from './counsellors.service';
import { CreateCounsellorReviewDto } from './dto/create-counsellor-review.dto';

/// `StudentAuthGuard` pose l'utilisateur vérifié ici. C'est LA source de
/// l'identité : rien de ce que le corps de la requête déclare n'en tient lieu.
type AuthedReq = Request & { studentUser?: SupabaseTokenUser };

/** Public (mobile) — browse the marketplace. */
@Controller('counsellors')
export class CounsellorsController {
  constructor(private readonly counsellorsService: CounsellorsService) {}

  @Get()
  list(
    @Query('country') country?: string,
    @Query('specialty') specialty?: string,
  ) {
    return this.counsellorsService.listPublic({
      countryOfResidence: country,
      specialty,
    });
  }

  @Get(':id')
  get(@Param('id') id: string) {
    return this.counsellorsService.getPublic(id);
  }

  /**
   * Authenticated students can leave a review after a completed case. The
   * review enters moderation (isPublished=false) — admin publishes it via
   * the admin endpoint below.
   *
   * L'AUTEUR est celui du jeton (`req.studentUser`), jamais un champ du corps :
   * le corps est un DTO validé qui ne peut pas en porter un, et le service
   * vérifie que le dossier noté appartient à l'appelant et a été traité par ce
   * conseiller. Auparavant le corps était un type en ligne, effacé à
   * l'exécution ; l'auteur manquait donc en base, et la suppression de compte
   * ne trouvait aucun avis.
   */
  @Post(':id/reviews')
  @UseGuards(StudentAuthGuard)
  createReview(
    @Param('id') id: string,
    @Body() body: CreateCounsellorReviewDto,
    @Req() req: AuthedReq,
  ) {
    return this.counsellorsService.createReview(id, body, req.studentUser!);
  }
}

/** Admin — KYC queue + CRUD. */
@Controller('admin/counsellors')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.Moderator)
export class AdminCounsellorsController {
  constructor(private readonly counsellorsService: CounsellorsService) {}

  @Get()
  list(@Query('kycStatus') kycStatus?: string) {
    return this.counsellorsService.listAdmin({ kycStatus });
  }

  @Post()
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  create(@Body() input: Record<string, unknown>) {
    return this.counsellorsService.create(input);
  }

  @Patch(':id')
  // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
  update(@Param('id') id: string, @Body() input: Record<string, unknown>) {
    return this.counsellorsService.update(id, input);
  }

  @Patch(':id/kyc')
  updateKyc(
    @Param('id') id: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() input: { kycStatus: string; kycNotes?: string | null },
  ) {
    return this.counsellorsService.updateKyc(
      id,
      input as Parameters<CounsellorsService['updateKyc']>[1],
    );
  }

  @Patch('reviews/:reviewId/publish')
  publishReview(
    @Param('reviewId') reviewId: string,
    // eslint-disable-next-line no-restricted-syntax -- corps hérité non validé, à migrer vers un DTO class-validator
    @Body() input: { isPublished: boolean },
  ) {
    return this.counsellorsService.setReviewPublished(
      reviewId,
      input.isPublished,
    );
  }
}
