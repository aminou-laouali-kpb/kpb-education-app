import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
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
import { CreateCaseTaskDto } from './dto/create-case-task.dto';
import { CreateCaseTimelineEventDto } from './dto/create-case-timeline-event.dto';
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

  @Get()
  findAll(@Req() req: any) {
    return this.casesService.findAllForAdmin(req.adminUser);
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
