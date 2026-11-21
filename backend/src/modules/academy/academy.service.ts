import { Injectable, NotFoundException } from '@nestjs/common';
import type { AcademyCourse, AcademyLesson, Prisma } from '@prisma/client';

import {
  CATALOG_SOURCE_DATABASE,
  degradedServiceUnavailable,
  type CatalogSource,
} from '../../common/degraded-mode';
import { PrismaService } from '../prisma/prisma.service';
import { lessonThumbnailUrl, lessonYoutubeId } from './academy-video.util';

/**
 * Ce que l'app a le droit de voir : une leçon publiée, dans un cours publié
 * qui en contient au moins une. Un cours publié mais vide n'apparaît pas — il
 * ne mènerait qu'à un écran sans vidéo.
 */
export const PUBLIC_LESSON_WHERE = {
  status: 'published',
} satisfies Prisma.AcademyLessonWhereInput;

export const PUBLIC_COURSE_WHERE = {
  status: 'published',
  lessons: { some: PUBLIC_LESSON_WHERE },
} satisfies Prisma.AcademyCourseWhereInput;

/** `order` d'abord ; à égalité (réimport partiel), la plus ancienne. */
export const LESSON_ORDER_BY = [
  { order: 'asc' },
  { createdAt: 'asc' },
] satisfies Prisma.AcademyLessonOrderByWithRelationInput[];

export const COURSE_ORDER_BY = [
  { displayOrder: 'asc' },
  { createdAt: 'asc' },
] satisfies Prisma.AcademyCourseOrderByWithRelationInput[];

/**
 * Aucune donnée de démonstration n'existe pour l'Academy : sans base, la route
 * répond 503 partout (jamais une liste vide qu'on prendrait pour « aucun
 * cours »).
 */
function academyUnavailable(resource: string) {
  return degradedServiceUnavailable(
    'ACADEMY_UNAVAILABLE',
    'Academy courses are temporarily unavailable.',
    resource,
  );
}

type PublicLessonRow = Pick<
  AcademyLesson,
  'id' | 'titleFr' | 'titleEn' | 'videoUrl' | 'durationSeconds' | 'order'
>;

type PublicCourseRow = AcademyCourse & { lessons: PublicLessonRow[] };

export interface AcademyPublicLesson {
  id: string;
  title: { fr: string; en: string };
  videoUrl: string;
  youtubeVideoId: string | null;
  thumbnailUrl: string | null;
  durationSeconds: number;
  order: number;
}

export interface AcademyPublicCourse {
  id: string;
  slug: string | null;
  title: { fr: string; en: string };
  description: { fr: string; en: string };
  coverImageUrl: string | null;
  priceXOF: number;
  priceEUR: number;
  isFree: boolean;
  lessonCount: number;
  totalDurationSeconds: number;
}

const PUBLIC_LESSON_SELECT = {
  id: true,
  titleFr: true,
  titleEn: true,
  videoUrl: true,
  durationSeconds: true,
  order: true,
} satisfies Prisma.AcademyLessonSelect;

function publicLesson(lesson: PublicLessonRow): AcademyPublicLesson {
  const youtubeVideoId = lessonYoutubeId(lesson.videoUrl);
  return {
    id: lesson.id,
    title: { fr: lesson.titleFr, en: lesson.titleEn },
    videoUrl: lesson.videoUrl,
    youtubeVideoId,
    thumbnailUrl: lessonThumbnailUrl(youtubeVideoId),
    durationSeconds: lesson.durationSeconds,
    order: lesson.order,
  };
}

function publicCourse(course: PublicCourseRow): AcademyPublicCourse {
  const firstLessonVideo = course.lessons[0]
    ? lessonYoutubeId(course.lessons[0].videoUrl)
    : null;
  return {
    id: course.id,
    slug: course.slug,
    title: { fr: course.titleFr, en: course.titleEn },
    description: { fr: course.descriptionFr, en: course.descriptionEn },
    coverImageUrl: course.coverImageUrl ?? lessonThumbnailUrl(firstLessonVideo),
    priceXOF: course.priceXOF,
    priceEUR: course.priceEUR,
    isFree: course.priceXOF === 0 && course.priceEUR === 0,
    lessonCount: course.lessons.length,
    totalDurationSeconds: course.lessons.reduce(
      (total, lesson) => total + lesson.durationSeconds,
      0,
    ),
  };
}

/** Lectures publiques (app) des cours Academy. */
@Injectable()
export class AcademyService {
  constructor(private readonly prismaService: PrismaService) {}

  async listCourses(): Promise<{
    items: AcademyPublicCourse[];
    source: CatalogSource;
  }> {
    const courses = await this.prismaService.execute((prisma) =>
      prisma.academyCourse.findMany({
        where: PUBLIC_COURSE_WHERE,
        orderBy: COURSE_ORDER_BY,
        include: {
          lessons: {
            where: PUBLIC_LESSON_WHERE,
            orderBy: LESSON_ORDER_BY,
            select: PUBLIC_LESSON_SELECT,
          },
        },
      }),
    );
    if (courses === null) throw academyUnavailable('academy-courses');
    return {
      items: courses.map(publicCourse),
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  /** Par identifiant ou par slug (`/academy/courses/hsk-1`). */
  async getCourse(
    idOrSlug: string,
  ): Promise<AcademyPublicCourse & { lessons: AcademyPublicLesson[] }> {
    const key = idOrSlug.trim();
    const course = await this.prismaService.execute((prisma) =>
      prisma.academyCourse.findFirst({
        where: {
          ...PUBLIC_COURSE_WHERE,
          OR: [{ id: key }, { slug: key }],
        },
        include: {
          lessons: {
            where: PUBLIC_LESSON_WHERE,
            orderBy: LESSON_ORDER_BY,
            select: PUBLIC_LESSON_SELECT,
          },
        },
      }),
    );
    if (course === null) {
      if (!this.prismaService.isEnabled) {
        throw academyUnavailable('academy-course');
      }
      throw new NotFoundException(`Academy course ${key} not found.`);
    }
    return {
      ...publicCourse(course),
      lessons: course.lessons.map(publicLesson),
    };
  }
}
