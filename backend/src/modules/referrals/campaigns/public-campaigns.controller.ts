import {
  Controller,
  Get,
  Header,
  Param,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Request } from 'express';

import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import { PUBLIC_LEADERBOARD_THROTTLE } from '../../../common/throttler-options';
import { ReferralCampaignService } from './referral-campaign.service';

/**
 * Classement public d'une campagne — SANS authentification.
 *
 * Lu par la page statique `kpbeducation.cloud/classement/` (autre origine que
 * l'API) : la réponse porte `Access-Control-Allow-Origin: *`. C'est sans risque
 * ici et seulement ici — aucun cookie, aucune donnée personnelle au-delà du nom
 * public choisi par l'équipe (« Prénom I. »), de la ville et d'un nombre.
 * Cache court (30 s, partagé) et limite de 30 requêtes par minute et par IP.
 */
@Controller('public/campaigns')
export class PublicCampaignsController {
  constructor(private readonly campaigns: ReferralCampaignService) {}

  @Get(':slug/leaderboard')
  @Throttle(PUBLIC_LEADERBOARD_THROTTLE)
  @Header('Cache-Control', 'public, max-age=30')
  @Header('Access-Control-Allow-Origin', '*')
  leaderboard(@Param('slug') slug: string, @Query('city') city?: string) {
    return this.campaigns.publicLeaderboard(slug.slice(0, 80), city?.slice(0, 80) || undefined);
  }
}

type AuthedReq = Request & { studentUser?: { id: string } };

/**
 * Position de l'élève connecté dans la campagne en cours. Préparé pour l'écran
 * classement in-app de la build 57 ; l'app installée ne l'appelle pas.
 */
@Controller('referrals/campaigns')
@UseGuards(StudentAuthGuard)
export class StudentCampaignsController {
  constructor(private readonly campaigns: ReferralCampaignService) {}

  @Get('current')
  @Header('Cache-Control', 'private, no-store')
  current(@Req() req: AuthedReq) {
    return this.campaigns.myStanding(req.studentUser!.id);
  }
}
