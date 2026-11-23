import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { MvpGuard } from '../../common/guards/mvp.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { SupabaseAuthService } from '../auth/supabase-auth.service';
import { SalonService } from './salon.service';

type StudentReq = Request & { studentUser?: { id: string } };

/**
 * Public event + session listing. Salon is hidden in the MVP app
 * (AppConfig.mvpOnly) — gated to match (P0-C). Admin routes stay open so
 * events can be prepared before the flag flips.
 */
@Controller('salon')
@UseGuards(MvpGuard)
export class SalonController {
  constructor(
    private readonly salonService: SalonService,
    private readonly supabaseAuthService: SupabaseAuthService,
  ) {}

  @Get('events')
  listEvents() {
    return this.salonService.listEvents();
  }

  @Get('events/:slug')
  async getEvent(@Param('slug') slug: string, @Req() req: Request) {
    return this.salonService.getEventBySlug(slug, await this.viewerId(req));
  }

  @Get('sessions/:id')
  async getSession(@Param('id') id: string, @Req() req: Request) {
    return this.salonService.getSession(id, await this.viewerId(req));
  }

  /**
   * Authentification FACULTATIVE : ces routes restent publiques (programme
   * consultable sans compte), mais l'élève connecté — l'app envoie son jeton
   * sur toutes les requêtes — est reconnu pour recevoir le lien de visio des
   * sessions auxquelles il est inscrit. Jeton absent ou invalide : anonyme,
   * jamais d'erreur (un jeton expiré ne doit pas masquer le programme).
   */
  private async viewerId(req: Request): Promise<string | undefined> {
    const header = req.headers?.authorization;
    if (!header || !header.startsWith('Bearer ')) return undefined;
    try {
      const user = await this.supabaseAuthService.verifyAndResolve(
        header.slice(7),
      );
      return user.id;
    } catch {
      return undefined;
    }
  }
}

/** Authenticated student → RSVP flow. */
@Controller('me/salon')
@UseGuards(StudentAuthGuard)
export class MySalonController {
  constructor(private readonly salonService: SalonService) {}

  @Get('registrations')
  myRegistrations(@Req() req: StudentReq) {
    return this.salonService.listMyRegistrations(req.studentUser!.id);
  }

  @Post('sessions/:id/register')
  register(@Req() req: StudentReq, @Param('id') sessionId: string) {
    return this.salonService.register(req.studentUser!.id, sessionId);
  }

  @Delete('sessions/:id/register')
  cancel(@Req() req: StudentReq, @Param('id') sessionId: string) {
    return this.salonService.cancelRegistration(
      req.studentUser!.id,
      sessionId,
    );
  }
}

/** Admin — manage events, sessions, and inspect registrations. */
@Controller('admin/salon')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Admin,
  InternalRole.SuperAdmin,
  InternalRole.ContentManager,
)
export class AdminSalonController {
  constructor(private readonly salonService: SalonService) {}

  @Get('events')
  listEvents() {
    return this.salonService.listAdminEvents();
  }

  @Post('events')
  createEvent(@Body() body: Parameters<SalonService['createEvent']>[0]) {
    return this.salonService.createEvent(body);
  }

  @Patch('events/:id')
  updateEvent(
    @Param('id') id: string,
    @Body() body: Parameters<SalonService['updateEvent']>[1],
  ) {
    return this.salonService.updateEvent(id, body);
  }

  @Post('sessions')
  createSession(@Body() body: Parameters<SalonService['createSession']>[0]) {
    return this.salonService.createSession(body);
  }

  @Patch('sessions/:id')
  updateSession(
    @Param('id') id: string,
    @Body() body: Parameters<SalonService['updateSession']>[1],
  ) {
    return this.salonService.updateSession(id, body);
  }

  @Get('sessions/:id/registrations')
  sessionRegistrations(@Param('id') sessionId: string) {
    return this.salonService.listSessionRegistrations(sessionId);
  }
}
