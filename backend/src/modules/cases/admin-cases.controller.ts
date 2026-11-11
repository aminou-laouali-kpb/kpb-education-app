import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CasesService } from './cases.service';
import { StorageService } from '../storage/storage.service';
import { AssignCaseDto } from './dto/assign-case.dto';
import { CreateCaseInternalNoteDto } from './dto/create-case-internal-note.dto';
import { CreateCaseMessageDto } from './dto/create-case-message.dto';
import { CreateCaseTaskDto } from './dto/create-case-task.dto';
import { CreateCaseTimelineEventDto } from './dto/create-case-timeline-event.dto';
import { ListAdminCasesQueryDto } from './dto/list-admin-cases.query.dto';
import { UpdateCaseDto } from './dto/update-case.dto';

@Controller('admin/cases')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(
  InternalRole.Counselor,
  InternalRole.Commercial,
  InternalRole.Admin,
  InternalRole.SuperAdmin,
)
export class AdminCasesController {
  constructor(
    private readonly casesService: CasesService,
    private readonly storageService: StorageService,
  ) {}

  /**
   * Une page de dossiers (50 par défaut) : `{ items, nextCursor }`. Filtres
   * `status`, `advisor`, `unassigned`, `awaiting` et recherche `q` appliqués
   * par le serveur ; `cursor` = le `nextCursor` de la page précédente. Les
   * éléments ne portent ni tâches, ni historique, ni pièces, ni notes : voir
   * `GET :id`. Un conseiller ne voit que ses dossiers.
   */
  @Get()
  findAll(@Req() req: any, @Query() query: ListAdminCasesQueryDto) {
    return this.casesService.findAllForAdmin(req.adminUser, {
      cursor: query.cursor,
      limit: query.limit,
      status: query.status,
      advisor: query.advisor,
      unassigned: query.unassigned === 'true',
      q: query.q,
      awaiting: query.awaiting === 'true',
    });
  }

  /**
   * Le compteur « réponses attendues » et les conseillers du filtre, sur
   * tous les dossiers de la portée. Déclarée AVANT `:id`.
   */
  @Get('summary')
  summary(@Req() req: any) {
    return this.casesService.adminCaseListSummary(req.adminUser);
  }

  /** Le dossier ouvert, avec ses tâches, pièces, notes et son historique. */
  @Get(':id')
  findOne(@Param('id') id: string, @Req() req: any) {
    return this.casesService.findOneForAdmin(id, req.adminUser);
  }

  /**
   * Le fil d'un dossier, page par page (50 messages, `before` = id du plus
   * ancien déjà affiché). Un conseiller ne lit que ses dossiers.
   */
  @Get(':id/messages')
  findMessages(
    @Param('id') id: string,
    @Req() req: any,
    @Query('before') before?: string,
    @Query('limit') limit?: string,
  ) {
    const parsed = limit === undefined ? undefined : Number(limit);
    return this.casesService.findMessagesForAdmin(id, req.adminUser, {
      before: before || undefined,
      limit: Number.isFinite(parsed) ? parsed : undefined,
    });
  }

  /**
   * Réponse de l'équipe : enregistrée au nom de l'agent connecté (rôle et nom
   * tirés de la session, jamais du corps), poussée à l'élève.
   */
  @Post(':id/messages')
  createMessage(
    @Param('id') id: string,
    @Body() input: CreateCaseMessageDto,
    @Req() req: any,
  ) {
    return this.casesService.createMessage(id, input, {
      userId: req.adminUser.id,
      role: req.adminUser.role,
      fullName: req.adminUser.fullName,
    });
  }

  @Get(':id/documents/:documentId/file')
  async downloadDocument(
    @Param('id') id: string,
    @Param('documentId') documentId: string,
    @Req() req: any,
    @Res() response: Response,
  ): Promise<void> {
    const document = await this.casesService.getInternalDocument(
      id,
      documentId,
      req.adminUser,
    );
    const key = this.storageService.keyFromUrl(document.fileUrl);
    if (!key) throw new NotFoundException('Document not found.');
    const object = await this.storageService.getObject(key);
    if (!object) throw new NotFoundException('Document not found.');

    response.setHeader('Content-Type', object.mimeType);
    response.setHeader('Content-Disposition', 'attachment');
    response.setHeader('Cache-Control', 'private, no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    if (object.sizeBytes !== undefined) {
      response.setHeader('Content-Length', object.sizeBytes.toString());
    }
    object.stream.on('error', () => {
      if (!response.headersSent) response.status(503).end();
      else response.destroy();
    });
    object.stream.pipe(response);
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() input: UpdateCaseDto,
    @Req() req: any,
  ) {
    await this.casesService.assertStaffCanAccessCase(id, req.adminUser);
    return this.casesService.update(id, input);
  }

  // Affecter un dossier est une décision d'équipe : un conseiller pouvait
  // s'attribuer n'importe quel dossier, puis en télécharger les pièces.
  @Post(':id/assign')
  @Roles(InternalRole.Commercial, InternalRole.Admin, InternalRole.SuperAdmin)
  assign(@Param('id') id: string, @Body() input: AssignCaseDto) {
    return this.casesService.assignCase(id, input);
  }

  @Post(':id/tasks')
  async createTask(
    @Param('id') id: string,
    @Body() input: CreateCaseTaskDto,
    @Req() req: any,
  ) {
    await this.casesService.assertStaffCanAccessCase(id, req.adminUser);
    return this.casesService.createTask(id, input);
  }

  @Post(':id/internal-notes')
  async createInternalNote(
    @Param('id') id: string,
    @Body() input: CreateCaseInternalNoteDto,
    @Req() req: any,
  ) {
    await this.casesService.assertStaffCanAccessCase(id, req.adminUser);
    return this.casesService.createInternalNote(id, input);
  }

  @Post(':id/timeline-events')
  async createTimelineEvent(
    @Param('id') id: string,
    @Body() input: CreateCaseTimelineEventDto,
    @Req() req: any,
  ) {
    await this.casesService.assertStaffCanAccessCase(id, req.adminUser);
    return this.casesService.createTimelineEvent(id, input);
  }
}
