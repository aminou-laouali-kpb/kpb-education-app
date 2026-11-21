import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import type { PrismaService } from '../prisma/prisma.service';
import { AcademyAdminService } from './academy-admin.service';
import { AcademyService } from './academy.service';

/**
 * Règles qui se décident AVANT la base, ou sur ce qu'elle rend : les specs
 * Postgres (`academy.postgres.spec.ts`) prouvent le reste sur un vrai schéma.
 */

function lessonRow(overrides: Record<string, unknown> = {}) {
  return {
    id: 'lesson-1',
    courseId: 'course-1',
    titleFr: 'Salutations',
    titleEn: 'Greetings',
    videoUrl: 'https://www.youtube.com/watch?v=aaaaaaaaaaa',
    durationSeconds: 240,
    order: 1,
    status: 'published',
    createdAt: new Date('2026-11-01T00:00:00Z'),
    updatedAt: new Date('2026-11-01T00:00:00Z'),
    ...overrides,
  };
}

function serviceWith(client: Record<string, unknown>) {
  const tx = client;
  const full = {
    ...client,
    $transaction: async (fn: (value: unknown) => unknown) => fn(tx),
  };
  const prisma = {
    isEnabled: true,
    execute: async (fn: (value: unknown) => unknown) => fn(full),
  } as unknown as PrismaService;
  return new AcademyAdminService(prisma);
}

describe('AcademyAdminService', () => {
  it('répond 503 sans base, au lieu de faire semblant d’écrire', async () => {
    const service = new AcademyAdminService({
      isEnabled: false,
      execute: async () => null,
    } as unknown as PrismaService);
    await expect(service.listCourses()).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('stocke l’URL YouTube canonique et place la leçon en dernier', async () => {
    const create = jest.fn(async ({ data }: { data: Record<string, unknown> }) =>
      lessonRow({ id: 'lesson-3', ...data }),
    );
    const service = serviceWith({
      academyCourse: { findUnique: async () => ({ id: 'course-1' }) },
      academyLesson: {
        findMany: async () => [
          { videoUrl: 'https://www.youtube.com/watch?v=aaaaaaaaaaa', order: 1 },
          { videoUrl: 'https://www.youtube.com/watch?v=bbbbbbbbbbb', order: 4 },
        ],
        create,
      },
    });

    const lesson = await service.createLesson('course-1', {
      youtubeUrl: 'https://youtu.be/ccccccccccc?si=partage',
      titleFr: '  Les tons  ',
      titleEn: '   ',
      durationSeconds: 300,
    });

    expect(create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        courseId: 'course-1',
        videoUrl: 'https://www.youtube.com/watch?v=ccccccccccc',
        titleFr: 'Les tons',
        // Anglais laissé blanc : le français est repris, comme pour les vidéos de bourse.
        titleEn: 'Les tons',
        order: 5,
        status: 'published',
      }),
    });
    expect(lesson).toMatchObject({
      youtubeVideoId: 'ccccccccccc',
      thumbnailUrl: 'https://img.youtube.com/vi/ccccccccccc/hqdefault.jpg',
    });
  });

  it('refuse la même vidéo deux fois dans un cours, quelle que soit la forme du lien', async () => {
    const create = jest.fn();
    const service = serviceWith({
      academyCourse: { findUnique: async () => ({ id: 'course-1' }) },
      academyLesson: {
        findMany: async () => [
          { videoUrl: 'https://www.youtube.com/watch?v=aaaaaaaaaaa', order: 1 },
        ],
        create,
      },
    });

    await expect(
      service.createLesson('course-1', {
        youtubeUrl: 'https://www.youtube.com/shorts/aaaaaaaaaaa',
        titleFr: 'Doublon',
        durationSeconds: 60,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(create).not.toHaveBeenCalled();
  });

  it('refuse un lien qui n’est pas YouTube avant de toucher la base', async () => {
    const findUnique = jest.fn();
    const service = serviceWith({ academyCourse: { findUnique } });
    await expect(
      service.createLesson('course-1', {
        youtubeUrl: 'https://vimeo.com/123456',
        titleFr: 'Hors YouTube',
        durationSeconds: 60,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(findUnique).not.toHaveBeenCalled();
  });

  it('refuse un titre blanc, que @IsNotEmpty laisse passer', async () => {
    const service = serviceWith({});
    await expect(
      service.createCourse({ slug: 'hsk-1', titleFr: '   ' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('crée un cours gratuit, en brouillon, avec l’anglais repris du français', async () => {
    const create = jest.fn(async ({ data }: { data: Record<string, unknown> }) => ({
      id: 'course-1',
      createdAt: new Date(),
      updatedAt: new Date(),
      ...data,
    }));
    const service = serviceWith({
      academyCourse: { findUnique: async () => null, create },
    });

    const course = await service.createCourse({
      slug: 'hsk-1',
      titleFr: 'Préparation HSK 1',
      descriptionFr: 'Les 150 premiers mots.',
    });

    expect(create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        slug: 'hsk-1',
        titleEn: 'Préparation HSK 1',
        descriptionEn: 'Les 150 premiers mots.',
        priceXOF: 0,
        priceEUR: 0,
        status: 'draft',
      }),
    });
    expect(course).toMatchObject({
      lessonCount: 0,
      visibleInApp: false,
      lessons: [],
    });
  });

  it('refuse un slug déjà pris par un autre cours (409)', async () => {
    const create = jest.fn();
    const service = serviceWith({
      academyCourse: { findUnique: async () => ({ id: 'other' }), create },
    });
    await expect(
      service.createCourse({ slug: 'hsk-1', titleFr: 'Doublon' }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(create).not.toHaveBeenCalled();
  });

  it('refuse de supprimer un cours qui a des achats', async () => {
    const deleteMany = jest.fn();
    const service = serviceWith({
      academyCourse: {
        findUnique: async () => ({ _count: { purchases: 2 } }),
      },
      academyLesson: { deleteMany },
    });
    await expect(service.deleteCourse('course-1')).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(deleteMany).not.toHaveBeenCalled();
  });

  it('refuse un réordonnancement qui ne liste pas toutes les leçons', async () => {
    const update = jest.fn();
    const service = serviceWith({
      academyCourse: { findUnique: async () => ({ id: 'course-1' }) },
      academyLesson: {
        findMany: async () => [
          { id: 'l1', order: 1 },
          { id: 'l2', order: 2 },
        ],
        update,
      },
    });
    await expect(
      service.reorderLessons('course-1', ['l2']),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      service.reorderLessons('course-1', ['l2', 'intrus']),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(update).not.toHaveBeenCalled();
  });

  it('ne réécrit que les leçons dont la position change', async () => {
    const update = jest.fn(async () => ({}));
    const service = serviceWith({
      academyCourse: {
        findUnique: async (args: { include?: unknown }) =>
          args.include
            ? {
                id: 'course-1',
                slug: 'hsk-1',
                titleFr: 'HSK 1',
                titleEn: 'HSK 1',
                descriptionFr: '',
                descriptionEn: '',
                coverImageUrl: null,
                priceXOF: 0,
                priceEUR: 0,
                status: 'draft',
                displayOrder: 0,
                createdAt: new Date(),
                updatedAt: new Date(),
                lessons: [],
                _count: { purchases: 0 },
              }
            : { id: 'course-1' },
      },
      academyLesson: {
        findMany: async () => [
          { id: 'l1', order: 1 },
          { id: 'l2', order: 2 },
          { id: 'l3', order: 3 },
        ],
        update,
      },
    });

    await service.reorderLessons('course-1', ['l1', 'l3', 'l2']);

    expect(update).toHaveBeenCalledTimes(2);
    expect(update).toHaveBeenCalledWith({ where: { id: 'l3' }, data: { order: 2 } });
    expect(update).toHaveBeenCalledWith({ where: { id: 'l2' }, data: { order: 3 } });
  });

  describe('import de manifeste', () => {
    const base = {
      slug: 'hsk-1',
      titleFr: 'Préparation HSK 1',
      lessons: [
        {
          order: 1,
          youtubeUrl: 'https://youtu.be/aaaaaaaaaaa',
          titleFr: 'Salutations',
          durationSeconds: 240,
        },
      ],
    };

    it('refuse deux leçons à la même position, avant toute écriture', async () => {
      const execute = jest.fn();
      const service = new AcademyAdminService({
        isEnabled: true,
        execute,
      } as unknown as PrismaService);
      await expect(
        service.importCourse({
          ...base,
          lessons: [
            base.lessons[0],
            { ...base.lessons[0], youtubeUrl: 'https://youtu.be/bbbbbbbbbbb' },
          ],
        }),
      ).rejects.toThrow('Lesson #1 appears twice in the manifest.');
      expect(execute).not.toHaveBeenCalled();
    });

    it('refuse la même vidéo à deux positions', async () => {
      const service = serviceWith({});
      await expect(
        service.importCourse({
          ...base,
          lessons: [
            base.lessons[0],
            {
              ...base.lessons[0],
              order: 2,
              youtubeUrl: 'https://www.youtube.com/watch?v=aaaaaaaaaaa',
            },
          ],
        }),
      ).rejects.toThrow('Lessons #1 and #2 use the same YouTube video.');
    });

    it('nomme la leçon dont le lien est invalide', async () => {
      const service = serviceWith({});
      await expect(
        service.importCourse({
          ...base,
          lessons: [
            { ...base.lessons[0], order: 7, youtubeUrl: 'https://example.org/video' },
          ],
        }),
      ).rejects.toThrow(/^Lesson #7: /);
    });
  });
});

describe('AcademyService (lectures publiques)', () => {
  it('répond 503 sans base — jamais une liste vide prise pour « aucun cours »', async () => {
    const service = new AcademyService({
      isEnabled: false,
      execute: async () => null,
    } as unknown as PrismaService);
    await expect(service.listCourses()).rejects.toMatchObject({
      status: 503,
      response: expect.objectContaining({ code: 'ACADEMY_UNAVAILABLE' }),
    });
    await expect(service.getCourse('hsk-1')).rejects.toMatchObject({
      status: 503,
    });
  });

  it('404 pour un cours introuvable quand la base répond', async () => {
    const service = new AcademyService({
      isEnabled: true,
      execute: async () => null,
    } as unknown as PrismaService);
    await expect(service.getCourse('inconnu')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('prend la miniature de la première leçon quand le cours n’a pas de couverture', async () => {
    const course = {
      id: 'course-1',
      slug: 'hsk-1',
      titleFr: 'HSK 1',
      titleEn: 'HSK 1',
      descriptionFr: 'FR',
      descriptionEn: 'EN',
      coverImageUrl: null,
      priceXOF: 0,
      priceEUR: 0,
      status: 'published',
      displayOrder: 0,
      createdAt: new Date(),
      updatedAt: new Date(),
      lessons: [
        lessonRow({ id: 'l1', durationSeconds: 200 }),
        lessonRow({
          id: 'l2',
          order: 2,
          durationSeconds: 100,
          videoUrl: 'https://www.youtube.com/watch?v=bbbbbbbbbbb',
        }),
      ],
    };
    const service = new AcademyService({
      isEnabled: true,
      execute: async () => [course],
    } as unknown as PrismaService);

    const { items, source } = await service.listCourses();

    expect(source).toBe('database');
    expect(items).toEqual([
      expect.objectContaining({
        slug: 'hsk-1',
        title: { fr: 'HSK 1', en: 'HSK 1' },
        coverImageUrl: 'https://img.youtube.com/vi/aaaaaaaaaaa/hqdefault.jpg',
        isFree: true,
        lessonCount: 2,
        totalDurationSeconds: 300,
      }),
    ]);
  });
});
