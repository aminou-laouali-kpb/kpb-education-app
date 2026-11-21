import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';

import { Roles } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AcademyAdminService } from './academy-admin.service';
import {
  CreateAcademyCourseDto,
  UpdateAcademyCourseDto,
} from './dto/academy-course.dto';
import {
  CreateAcademyLessonDto,
  ReorderAcademyLessonsDto,
  UpdateAcademyLessonDto,
} from './dto/academy-lesson.dto';
import { ImportAcademyCourseDto } from './dto/import-academy-course.dto';

/**
 * Back-office des cours Academy. Mêmes rôles que l'écriture du catalogue
 * (`AdminCatalogController`) : l'équipe contenu prépare et publie les cours.
 * Miroir côté console : `AdminCapability.ManageAcademyCourses`.
 */
@Controller('admin/academy')
@UseGuards(AdminAuthGuard, RolesGuard)
@Roles(InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.ContentManager)
export class AdminAcademyController {
  constructor(private readonly service: AcademyAdminService) {}

  @Get('courses')
  listCourses() {
    return this.service.listCourses();
  }

  @Post('courses')
  createCourse(@Body() input: CreateAcademyCourseDto) {
    return this.service.createCourse(input);
  }

  /** Un module de manifeste (HyperFrames) → un cours, idempotent. */
  @Post('courses/import')
  importCourse(@Body() input: ImportAcademyCourseDto) {
    return this.service.importCourse(input);
  }

  @Get('courses/:id')
  getCourse(@Param('id') id: string) {
    return this.service.getCourse(id);
  }

  @Patch('courses/:id')
  updateCourse(@Param('id') id: string, @Body() input: UpdateAcademyCourseDto) {
    return this.service.updateCourse(id, input);
  }

  @Delete('courses/:id')
  deleteCourse(@Param('id') id: string) {
    return this.service.deleteCourse(id);
  }

  @Post('courses/:id/lessons')
  createLesson(
    @Param('id') id: string,
    @Body() input: CreateAcademyLessonDto,
  ) {
    return this.service.createLesson(id, input);
  }

  @Put('courses/:id/lessons/order')
  reorderLessons(
    @Param('id') id: string,
    @Body() input: ReorderAcademyLessonsDto,
  ) {
    return this.service.reorderLessons(id, input.lessonIds);
  }

  @Patch('courses/:id/lessons/:lessonId')
  updateLesson(
    @Param('id') id: string,
    @Param('lessonId') lessonId: string,
    @Body() input: UpdateAcademyLessonDto,
  ) {
    return this.service.updateLesson(id, lessonId, input);
  }

  @Delete('courses/:id/lessons/:lessonId')
  deleteLesson(
    @Param('id') id: string,
    @Param('lessonId') lessonId: string,
  ) {
    return this.service.deleteLesson(id, lessonId);
  }
}
