import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type {
  AcademyCourse,
  AcademyLesson,
  Prisma,
  PrismaClient,
  PublicationStatus,
} from '@prisma/client';

import { youtubeVideoUrls } from '../scholarships-index/youtube-video.util';
import { PrismaService } from '../prisma/prisma.service';
import { COURSE_ORDER_BY, LESSON_ORDER_BY } from './academy.service';
import {
  canonicalImportedVideo,
  canonicalLessonVideo,
  lessonThumbnailUrl,
  lessonYoutubeId,
} from './academy-video.util';
import type {
  CreateAcademyCourseDto,
  UpdateAcademyCourseDto,
} from './dto/academy-course.dto';
import type {
  CreateAcademyLessonDto,
  UpdateAcademyLessonDto,
} from './dto/academy-lesson.dto';
import type { ImportAcademyCourseDto } from './dto/import-academy-course.dto';

/** Un import de 500 leçons tient largement dedans ; le défaut (5 s) non. */
const IMPORT_TRANSACTION_OPTIONS = { maxWait: 10_000, timeout: 60_000 };

type LessonStats = Pick<AcademyLesson, 'status' | 'durationSeconds'>;

export interface AcademyAdminLesson extends AcademyLesson {
  youtubeVideoId: string | null;
  thumbnailUrl: string | null;
  watchUrl: string;
}

export interface AcademyAdminCourse extends AcademyCourse {
  lessonCount: number;
  publishedLessonCount: number;
  publishedDurationSeconds: number;
  purchaseCount: number;
  /** Ce que l'app affiche réellement : cours publié ET au moins une leçon publiée. */
  visibleInApp: boolean;
}

export interface AcademyImportReport {
  course: {
    id: string;
    slug: string;
    status: PublicationStatus;
    created: boolean;
    updated: boolean;
  };
  lessons: { created: number; updated: number; unchanged: number };
  /** Leçons du cours absentes du manifeste : laissées telles quelles, à trier. */
  notInManifest: Array<{
    id: string;
    titleFr: string;
    order: number;
    status: PublicationStatus;
  }>;
}

function adminCourse(
  course: AcademyCourse,
  lessons: LessonStats[],
  purchaseCount: number,
): AcademyAdminCourse {
  const published = lessons.filter((lesson) => lesson.status === 'published');
  return {
    id: course.id,
    slug: course.slug,
    titleFr: course.titleFr,
    titleEn: course.titleEn,
    descriptionFr: course.descriptionFr,
    descriptionEn: course.descriptionEn,
    coverImageUrl: course.coverImageUrl,
    priceXOF: course.priceXOF,
    priceEUR: course.priceEUR,
    status: course.status,
    displayOrder: course.displayOrder,
    requiresPass: course.requiresPass,
    createdAt: course.createdAt,
    updatedAt: course.updatedAt,
    lessonCount: lessons.length,
    publishedLessonCount: published.length,
    publishedDurationSeconds: published.reduce(
      (total, lesson) => total + lesson.durationSeconds,
      0,
    ),
    purchaseCount,
    visibleInApp: course.status === 'published' && published.length > 0,
  };
}

function adminLesson(lesson: AcademyLesson): AcademyAdminLesson {
  const youtubeVideoId = lessonYoutubeId(lesson.videoUrl);
  return {
    ...lesson,
    youtubeVideoId,
    thumbnailUrl: lessonThumbnailUrl(youtubeVideoId),
    watchUrl: youtubeVideoId
      ? youtubeVideoUrls(youtubeVideoId).watchUrl
      : lesson.videoUrl,
  };
}

/** Texte obligatoire : `@IsNotEmpty` laisse passer « ␣␣␣ ». */
function requireText(value: string, field: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new BadRequestException(`${field} must not be blank.`);
  }
  return trimmed;
}

/** Texte facultatif : vide ou blanc vaut absent. */
function optionalText(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

function courseNotFound(id: string) {
  return new NotFoundException(`Academy course ${id} not found.`);
}

function lessonNotFound(courseId: string, lessonId: string) {
  return new NotFoundException(
    `Lesson ${lessonId} not found in academy course ${courseId}.`,
  );
}

function slugConflict(slug: string) {
  return new ConflictException(
    `Another academy course already uses the slug "${slug}".`,
  );
}

function duplicateLessonVideo() {
  return new ConflictException(
    'This YouTube video is already a lesson of this course.',
  );
}

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === 'P2002'
  );
}

/**
 * Écritures du back-office sur les cours Academy et leurs leçons.
 *
 * Les refus attendus (introuvable, slug pris, vidéo en double) sortent des
 * transactions comme des RÉSULTATS, pas comme des exceptions : une exception
 * levée dans `prismaService.execute` est journalisée comme une panne de base.
 */
@Injectable()
export class AcademyAdminService {
  constructor(private readonly prismaService: PrismaService) {}

  private async run<T>(
    operation: (prisma: PrismaClient) => Promise<T>,
  ): Promise<T> {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
    try {
      return (await this.prismaService.execute(operation)) as T;
    } catch (error) {
      // Filet pour une course : deux écritures simultanées du même slug.
      if (isUniqueViolation(error)) {
        throw new ConflictException(
          'Another academy course already uses this slug.',
        );
      }
      throw error;
    }
  }

  async listCourses(): Promise<{ items: AcademyAdminCourse[] }> {
    const courses = await this.run((prisma) =>
      prisma.academyCourse.findMany({
        orderBy: COURSE_ORDER_BY,
        include: {
          lessons: { select: { status: true, durationSeconds: true } },
          _count: { select: { purchases: true } },
        },
      }),
    );
    return {
      items: courses.map((course) =>
        adminCourse(course, course.lessons, course._count.purchases),
      ),
    };
  }

  async getCourse(
    id: string,
  ): Promise<AcademyAdminCourse & { lessons: AcademyAdminLesson[] }> {
    const course = await this.run((prisma) =>
      prisma.academyCourse.findUnique({
        where: { id },
        include: {
          lessons: { orderBy: LESSON_ORDER_BY },
          _count: { select: { purchases: true } },
        },
      }),
    );
    if (!course) throw courseNotFound(id);
    return {
      ...adminCourse(course, course.lessons, course._count.purchases),
      lessons: course.lessons.map(adminLesson),
    };
  }

  async createCourse(
    input: CreateAcademyCourseDto,
  ): Promise<AcademyAdminCourse & { lessons: AcademyAdminLesson[] }> {
    const titleFr = requireText(input.titleFr, 'titleFr');
    const descriptionFr = input.descriptionFr?.trim() ?? '';
    const data: Prisma.AcademyCourseCreateInput = {
      slug: input.slug,
      titleFr,
      titleEn: optionalText(input.titleEn) ?? titleFr,
      descriptionFr,
      descriptionEn: optionalText(input.descriptionEn) ?? descriptionFr,
      coverImageUrl: input.coverImageUrl || null,
      // Gratuit : voir l'en-tête de CreateAcademyCourseDto.
      priceXOF: 0,
      priceEUR: 0,
      status: input.status ?? 'draft',
      displayOrder: input.displayOrder ?? 0,
      requiresPass: input.requiresPass ?? false,
    };

    const result = await this.run((prisma) =>
      prisma.$transaction(async (tx) => {
        const taken = await tx.academyCourse.findUnique({
          where: { slug: input.slug },
          select: { id: true },
        });
        if (taken) return { kind: 'slug_taken' as const };
        const course = await tx.academyCourse.create({ data });
        return { kind: 'ok' as const, course };
      }),
    );
    if (result.kind === 'slug_taken') throw slugConflict(input.slug);
    return { ...adminCourse(result.course, [], 0), lessons: [] };
  }

  async updateCourse(
    id: string,
    input: UpdateAcademyCourseDto,
  ): Promise<AcademyAdminCourse & { lessons: AcademyAdminLesson[] }> {
    const titleFr =
      input.titleFr !== undefined
        ? requireText(input.titleFr, 'titleFr')
        : undefined;

    const result = await this.run((prisma) =>
      prisma.$transaction(async (tx) => {
        const current = await tx.academyCourse.findUnique({ where: { id } });
        if (!current) return { kind: 'not_found' as const };
        if (input.slug !== undefined && input.slug !== current.slug) {
          const taken = await tx.academyCourse.findUnique({
            where: { slug: input.slug },
            select: { id: true },
          });
          if (taken) return { kind: 'slug_taken' as const };
        }
        const nextTitleFr = titleFr ?? current.titleFr;
        const nextDescriptionFr =
          input.descriptionFr !== undefined
            ? input.descriptionFr.trim()
            : current.descriptionFr;
        const data: Prisma.AcademyCourseUpdateInput = {
          ...(input.slug !== undefined ? { slug: input.slug } : {}),
          ...(titleFr !== undefined ? { titleFr } : {}),
          // Vider le titre anglais = reprendre le français, comme à la création.
          ...(input.titleEn !== undefined
            ? { titleEn: optionalText(input.titleEn) ?? nextTitleFr }
            : {}),
          ...(input.descriptionFr !== undefined
            ? { descriptionFr: nextDescriptionFr }
            : {}),
          ...(input.descriptionEn !== undefined
            ? {
                descriptionEn:
                  optionalText(input.descriptionEn) ?? nextDescriptionFr,
              }
            : {}),
          ...(input.coverImageUrl !== undefined
            ? { coverImageUrl: input.coverImageUrl || null }
            : {}),
          ...(input.status !== undefined ? { status: input.status } : {}),
          ...(input.displayOrder !== undefined
            ? { displayOrder: input.displayOrder }
            : {}),
          ...(input.requiresPass !== undefined
            ? { requiresPass: input.requiresPass }
            : {}),
        };
        await tx.academyCourse.update({ where: { id }, data });
        return { kind: 'ok' as const };
      }),
    );
    if (result.kind === 'not_found') throw courseNotFound(id);
    if (result.kind === 'slug_taken') throw slugConflict(input.slug ?? '');
    return this.getCourse(id);
  }

  /**
   * Supprime le cours et ses leçons. Refusé dès qu'un achat existe : l'achat
   * est une trace comptable, on archive le cours au lieu de l'effacer. Une
   * bourse liée au cours (`Scholarship.academyCourseId`) perd simplement son
   * lien (clé étrangère `ON DELETE SET NULL`).
   */
  async deleteCourse(
    id: string,
  ): Promise<{ id: string; deleted: true; deletedLessons: number }> {
    const result = await this.run((prisma) =>
      prisma.$transaction(async (tx) => {
        const course = await tx.academyCourse.findUnique({
          where: { id },
          select: { _count: { select: { purchases: true } } },
        });
        if (!course) return { kind: 'not_found' as const };
        if (course._count.purchases > 0) {
          return {
            kind: 'has_purchases' as const,
            purchases: course._count.purchases,
          };
        }
        const { count } = await tx.academyLesson.deleteMany({
          where: { courseId: id },
        });
        await tx.academyCourse.delete({ where: { id } });
        return { kind: 'ok' as const, deletedLessons: count };
      }),
    );
    if (result.kind === 'not_found') throw courseNotFound(id);
    if (result.kind === 'has_purchases') {
      throw new ConflictException(
        `This course has ${result.purchases} purchase(s): archive it instead of deleting it.`,
      );
    }
    return { id, deleted: true, deletedLessons: result.deletedLessons };
  }

  /** Ajoute la leçon en dernière position du cours. */
  async createLesson(
    courseId: string,
    input: CreateAcademyLessonDto,
  ): Promise<AcademyAdminLesson> {
    const titleFr = requireText(input.titleFr, 'titleFr');
    const { youtubeVideoId, videoUrl } = canonicalLessonVideo(input.youtubeUrl);

    const result = await this.run((prisma) =>
      prisma.$transaction(async (tx) => {
        const course = await tx.academyCourse.findUnique({
          where: { id: courseId },
          select: { id: true },
        });
        if (!course) return { kind: 'not_found' as const };
        const siblings = await tx.academyLesson.findMany({
          where: { courseId },
          select: { videoUrl: true, order: true },
        });
        if (
          siblings.some(
            (lesson) => lessonYoutubeId(lesson.videoUrl) === youtubeVideoId,
          )
        ) {
          return { kind: 'duplicate' as const };
        }
        const order =
          siblings.reduce((max, lesson) => Math.max(max, lesson.order), 0) + 1;
        const lesson = await tx.academyLesson.create({
          data: {
            courseId,
            titleFr,
            titleEn: optionalText(input.titleEn) ?? titleFr,
            videoUrl,
            durationSeconds: input.durationSeconds,
            order,
            status: input.status ?? 'published',
            isFreePreview: input.isFreePreview ?? false,
          },
        });
        return { kind: 'ok' as const, lesson };
      }),
    );
    if (result.kind === 'not_found') throw courseNotFound(courseId);
    if (result.kind === 'duplicate') throw duplicateLessonVideo();
    return adminLesson(result.lesson);
  }

  async updateLesson(
    courseId: string,
    lessonId: string,
    input: UpdateAcademyLessonDto,
  ): Promise<AcademyAdminLesson> {
    const titleFr =
      input.titleFr !== undefined
        ? requireText(input.titleFr, 'titleFr')
        : undefined;
    const video =
      input.youtubeUrl !== undefined
        ? canonicalLessonVideo(input.youtubeUrl)
        : undefined;

    const result = await this.run((prisma) =>
      prisma.$transaction(async (tx) => {
        const lesson = await tx.academyLesson.findFirst({
          where: { id: lessonId, courseId },
        });
        if (!lesson) return { kind: 'not_found' as const };
        if (video) {
          const siblings = await tx.academyLesson.findMany({
            where: { courseId, id: { not: lessonId } },
            select: { videoUrl: true },
          });
          if (
            siblings.some(
              (sibling) =>
                lessonYoutubeId(sibling.videoUrl) === video.youtubeVideoId,
            )
          ) {
            return { kind: 'duplicate' as const };
          }
        }
        const updated = await tx.academyLesson.update({
          where: { id: lessonId },
          data: {
            ...(video ? { videoUrl: video.videoUrl } : {}),
            ...(titleFr !== undefined ? { titleFr } : {}),
            ...(input.titleEn !== undefined
              ? {
                  titleEn:
                    optionalText(input.titleEn) ?? titleFr ?? lesson.titleFr,
                }
              : {}),
            ...(input.durationSeconds !== undefined
              ? { durationSeconds: input.durationSeconds }
              : {}),
            ...(input.status !== undefined ? { status: input.status } : {}),
            ...(input.isFreePreview !== undefined
              ? { isFreePreview: input.isFreePreview }
              : {}),
          },
        });
        return { kind: 'ok' as const, lesson: updated };
      }),
    );
    if (result.kind === 'not_found') throw lessonNotFound(courseId, lessonId);
    if (result.kind === 'duplicate') throw duplicateLessonVideo();
    return adminLesson(result.lesson);
  }

  async deleteLesson(
    courseId: string,
    lessonId: string,
  ): Promise<{ id: string; deleted: true }> {
    const result = await this.run((prisma) =>
      prisma.academyLesson.deleteMany({ where: { id: lessonId, courseId } }),
    );
    if (!result.count) throw lessonNotFound(courseId, lessonId);
    return { id: lessonId, deleted: true };
  }

  /** Renumérote 1…n dans l'ordre donné. */
  async reorderLessons(
    courseId: string,
    lessonIds: string[],
  ): Promise<AcademyAdminCourse & { lessons: AcademyAdminLesson[] }> {
    const result = await this.run((prisma) =>
      prisma.$transaction(async (tx) => {
        const course = await tx.academyCourse.findUnique({
          where: { id: courseId },
          select: { id: true },
        });
        if (!course) return { kind: 'not_found' as const };
        const lessons = await tx.academyLesson.findMany({
          where: { courseId },
          select: { id: true, order: true },
        });
        const currentOrder = new Map(
          lessons.map((lesson) => [lesson.id, lesson.order]),
        );
        if (
          lessons.length !== lessonIds.length ||
          lessonIds.some((id) => !currentOrder.has(id))
        ) {
          return { kind: 'mismatch' as const };
        }
        for (const [index, id] of lessonIds.entries()) {
          if (currentOrder.get(id) !== index + 1) {
            await tx.academyLesson.update({
              where: { id },
              data: { order: index + 1 },
            });
          }
        }
        return { kind: 'ok' as const };
      }),
    );
    if (result.kind === 'not_found') throw courseNotFound(courseId);
    if (result.kind === 'mismatch') {
      throw new BadRequestException(
        'lessonIds must list every lesson of the course exactly once.',
      );
    }
    return this.getCourse(courseId);
  }

  /**
   * Import d'un module de manifeste (voir ImportAcademyCourseDto).
   *
   * - le cours est retrouvé par `slug`, sinon créé EN BROUILLON ;
   * - une leçon est retrouvée par sa vidéo YouTube : son titre, sa durée et sa
   *   position sont réalignés sur le manifeste, son statut n'est touché que si
   *   le manifeste en donne un ;
   * - une leçon du cours absente du manifeste n'est ni supprimée ni masquée :
   *   elle est listée dans `notInManifest`, à trier dans l'admin ;
   * - un champ absent du manifeste ne modifie rien sur un cours existant.
   *
   * Tout ou rien : une seule transaction.
   */
  async importCourse(input: ImportAcademyCourseDto): Promise<AcademyImportReport> {
    const titleFr = requireText(input.titleFr, 'titleFr');
    const titleEn = optionalText(input.titleEn);
    const descriptionFr =
      input.descriptionFr !== undefined ? input.descriptionFr.trim() : undefined;
    const descriptionEn = optionalText(input.descriptionEn);
    const coverImageUrl = optionalText(input.coverImageUrl);

    const seenOrders = new Set<number>();
    const seenVideos = new Map<string, number>();
    const lessons = input.lessons
      .map((lesson) => {
        if (seenOrders.has(lesson.order)) {
          throw new BadRequestException(
            `Lesson #${lesson.order} appears twice in the manifest.`,
          );
        }
        seenOrders.add(lesson.order);
        const video = canonicalImportedVideo(lesson.youtubeUrl, lesson.order);
        const twin = seenVideos.get(video.youtubeVideoId);
        if (twin !== undefined) {
          throw new BadRequestException(
            `Lessons #${twin} and #${lesson.order} use the same YouTube video.`,
          );
        }
        seenVideos.set(video.youtubeVideoId, lesson.order);
        return {
          order: lesson.order,
          titleFr: requireText(lesson.titleFr, `Lesson #${lesson.order} titleFr`),
          titleEn: optionalText(lesson.titleEn),
          durationSeconds: lesson.durationSeconds,
          status: lesson.status,
          isFreePreview: lesson.isFreePreview,
          ...video,
        };
      })
      .sort((a, b) => a.order - b.order);

    return this.run((prisma) =>
      prisma.$transaction(async (tx) => {
        const existing = await tx.academyCourse.findUnique({
          where: { slug: input.slug },
          include: { lessons: { orderBy: LESSON_ORDER_BY } },
        });

        let courseId: string;
        let courseStatus: PublicationStatus;
        let courseUpdated = false;
        if (!existing) {
          const created = await tx.academyCourse.create({
            data: {
              slug: input.slug,
              titleFr,
              titleEn: titleEn ?? titleFr,
              descriptionFr: descriptionFr ?? '',
              descriptionEn: descriptionEn ?? descriptionFr ?? '',
              coverImageUrl: coverImageUrl ?? null,
              priceXOF: 0,
              priceEUR: 0,
              status: 'draft',
              displayOrder: input.displayOrder ?? 0,
              requiresPass: input.requiresPass ?? false,
            },
          });
          courseId = created.id;
          courseStatus = created.status;
        } else {
          const patch: Prisma.AcademyCourseUpdateInput = {};
          if (existing.titleFr !== titleFr) patch.titleFr = titleFr;
          if (titleEn !== undefined && existing.titleEn !== titleEn) {
            patch.titleEn = titleEn;
          }
          if (
            descriptionFr !== undefined &&
            existing.descriptionFr !== descriptionFr
          ) {
            patch.descriptionFr = descriptionFr;
          }
          if (
            descriptionEn !== undefined &&
            existing.descriptionEn !== descriptionEn
          ) {
            patch.descriptionEn = descriptionEn;
          }
          if (
            coverImageUrl !== undefined &&
            existing.coverImageUrl !== coverImageUrl
          ) {
            patch.coverImageUrl = coverImageUrl;
          }
          if (
            input.displayOrder !== undefined &&
            existing.displayOrder !== input.displayOrder
          ) {
            patch.displayOrder = input.displayOrder;
          }
          if (
            input.requiresPass !== undefined &&
            existing.requiresPass !== input.requiresPass
          ) {
            patch.requiresPass = input.requiresPass;
          }
          if (Object.keys(patch).length > 0) {
            await tx.academyCourse.update({
              where: { id: existing.id },
              data: patch,
            });
            courseUpdated = true;
          }
          courseId = existing.id;
          courseStatus = existing.status;
        }

        const existingLessons = existing?.lessons ?? [];
        const byVideo = new Map<string, AcademyLesson>();
        for (const lesson of existingLessons) {
          const id = lessonYoutubeId(lesson.videoUrl);
          if (id && !byVideo.has(id)) byVideo.set(id, lesson);
        }

        const matched = new Set<string>();
        const counts = { created: 0, updated: 0, unchanged: 0 };
        for (const lesson of lessons) {
          const match = byVideo.get(lesson.youtubeVideoId);
          if (!match) {
            await tx.academyLesson.create({
              data: {
                courseId,
                titleFr: lesson.titleFr,
                titleEn: lesson.titleEn ?? lesson.titleFr,
                videoUrl: lesson.videoUrl,
                durationSeconds: lesson.durationSeconds,
                order: lesson.order,
                status: lesson.status ?? 'published',
                isFreePreview: lesson.isFreePreview ?? false,
              },
            });
            counts.created += 1;
            continue;
          }
          matched.add(match.id);
          const patch: Prisma.AcademyLessonUpdateInput = {};
          if (match.titleFr !== lesson.titleFr) patch.titleFr = lesson.titleFr;
          if (lesson.titleEn !== undefined && match.titleEn !== lesson.titleEn) {
            patch.titleEn = lesson.titleEn;
          }
          // Une ligne ancienne peut porter une URL non canonique.
          if (match.videoUrl !== lesson.videoUrl) patch.videoUrl = lesson.videoUrl;
          if (match.durationSeconds !== lesson.durationSeconds) {
            patch.durationSeconds = lesson.durationSeconds;
          }
          if (match.order !== lesson.order) patch.order = lesson.order;
          if (lesson.status !== undefined && match.status !== lesson.status) {
            patch.status = lesson.status;
          }
          if (
            lesson.isFreePreview !== undefined &&
            match.isFreePreview !== lesson.isFreePreview
          ) {
            patch.isFreePreview = lesson.isFreePreview;
          }
          if (Object.keys(patch).length > 0) {
            await tx.academyLesson.update({
              where: { id: match.id },
              data: patch,
            });
            counts.updated += 1;
          } else {
            counts.unchanged += 1;
          }
        }

        return {
          course: {
            id: courseId,
            slug: input.slug,
            status: courseStatus,
            created: !existing,
            updated: courseUpdated,
          },
          lessons: counts,
          notInManifest: existingLessons
            .filter((lesson) => !matched.has(lesson.id))
            .map((lesson) => ({
              id: lesson.id,
              titleFr: lesson.titleFr,
              order: lesson.order,
              status: lesson.status,
            })),
        };
      }, IMPORT_TRANSACTION_OPTIONS),
    );
  }
}
