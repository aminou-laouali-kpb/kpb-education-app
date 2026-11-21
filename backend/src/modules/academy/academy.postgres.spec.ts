import { randomUUID } from 'node:crypto';

import { ConflictException, NotFoundException } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

import { PublicationStatus } from '../../common/enums/publication-status.enum';
import type { PrismaService } from '../prisma/prisma.service';
import { AcademyAdminService } from './academy-admin.service';
import { AcademyService } from './academy.service';

/**
 * Cours Academy contre un vrai Postgres.
 *
 * Ce que l'app voit se décide dans des `where` Prisma (cours publié, leçon
 * publiée, au moins une leçon publiée) : seule une base réelle dit s'ils
 * filtrent. L'import, lui, doit pouvoir être rejoué autant de fois qu'on veut
 * sans dupliquer une leçon, republier une leçon retenue ni dépublier un cours.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

describePostgres('Academy — intégration PostgreSQL', () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID().slice(0, 8);
  const slug = (name: string) => `it-${name}-${suffix}`;

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
    tryExecute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;

  const publicReads = new AcademyService(prismaService);
  const admin = new AcademyAdminService(prismaService);

  const video = (letter: string) =>
    `https://www.youtube.com/watch?v=${letter.repeat(11)}`;

  async function cleanup() {
    const courses = await prisma.academyCourse.findMany({
      where: { slug: { endsWith: `-${suffix}` } },
      select: { id: true },
    });
    const ids = courses.map((course) => course.id);
    await prisma.academyLesson.deleteMany({ where: { courseId: { in: ids } } });
    await prisma.academyCourse.deleteMany({ where: { id: { in: ids } } });
  }

  beforeAll(cleanup);
  afterAll(async () => {
    await cleanup();
    await prisma.$disconnect();
  });

  describe('lectures publiques', () => {
    let visibleId: string;

    beforeAll(async () => {
      const base = {
        descriptionFr: 'FR',
        descriptionEn: 'EN',
        priceXOF: 0,
        priceEUR: 0,
      };
      const visible = await prisma.academyCourse.create({
        data: {
          ...base,
          slug: slug('visible'),
          titleFr: 'Visible',
          titleEn: 'Visible',
          status: 'published',
          displayOrder: 2,
          lessons: {
            create: [
              // Créées dans le désordre : l'ordre servi vient de `order`.
              { titleFr: 'Deux', titleEn: 'Two', videoUrl: video('b'), durationSeconds: 100, order: 2 },
              { titleFr: 'Retenue', titleEn: 'Held', videoUrl: video('c'), durationSeconds: 999, order: 3, status: 'draft' },
              { titleFr: 'Une', titleEn: 'One', videoUrl: video('a'), durationSeconds: 200, order: 1 },
            ],
          },
        },
      });
      visibleId = visible.id;
      await prisma.academyCourse.create({
        data: {
          ...base,
          slug: slug('first'),
          titleFr: 'Premier',
          titleEn: 'First',
          status: 'published',
          displayOrder: 1,
          lessons: {
            create: [{ titleFr: 'Seule', titleEn: 'Only', videoUrl: video('d'), durationSeconds: 60, order: 1 }],
          },
        },
      });
      // Publié, mais aucune leçon publiée : n'existe pas pour l'app.
      await prisma.academyCourse.create({
        data: {
          ...base,
          slug: slug('empty'),
          titleFr: 'Vide',
          titleEn: 'Empty',
          status: 'published',
          lessons: {
            create: [{ titleFr: 'Brouillon', titleEn: 'Draft', videoUrl: video('e'), durationSeconds: 60, order: 1, status: 'draft' }],
          },
        },
      });
      // Leçons publiées dans un cours en brouillon : rien ne sort.
      await prisma.academyCourse.create({
        data: {
          ...base,
          slug: slug('draft'),
          titleFr: 'Brouillon',
          titleEn: 'Draft',
          status: 'draft',
          lessons: {
            create: [{ titleFr: 'Publiée', titleEn: 'Published', videoUrl: video('f'), durationSeconds: 60, order: 1 }],
          },
        },
      });
    });

    it('ne liste que les cours publiés avec au moins une leçon publiée, dans l’ordre d’affichage', async () => {
      const { items, source } = await publicReads.listCourses();
      const ours = items.filter((course) => course.slug?.endsWith(`-${suffix}`));
      expect(source).toBe('database');
      expect(ours.map((course) => course.slug)).toEqual([slug('first'), slug('visible')]);
      expect(ours[1]).toMatchObject({
        lessonCount: 2,
        totalDurationSeconds: 300,
        coverImageUrl: 'https://img.youtube.com/vi/aaaaaaaaaaa/hqdefault.jpg',
      });
    });

    it('sert le détail par slug comme par identifiant, sans la leçon retenue', async () => {
      const bySlug = await publicReads.getCourse(slug('visible'));
      const byId = await publicReads.getCourse(visibleId);
      expect(byId).toEqual(bySlug);
      expect(bySlug.lessons.map((lesson) => lesson.title.fr)).toEqual(['Une', 'Deux']);
      expect(bySlug.lessons[0]).toMatchObject({
        videoUrl: video('a'),
        youtubeVideoId: 'aaaaaaaaaaa',
      });
    });

    it.each(['empty', 'draft'])('répond 404 pour le cours « %s »', async (name) => {
      await expect(publicReads.getCourse(slug(name))).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('import de manifeste', () => {
    const manifest = () => ({
      slug: slug('hsk'),
      titleFr: 'Préparation HSK 1',
      titleEn: 'HSK 1 preparation',
      descriptionFr: 'Les bases.',
      lessons: [
        { order: 1, youtubeUrl: 'https://youtu.be/hhhhhhhhhhh', titleFr: 'Salutations', titleEn: 'Greetings', durationSeconds: 240 },
        { order: 2, youtubeUrl: 'https://youtu.be/iiiiiiiiiii', titleFr: 'Les tons', titleEn: 'Tones', durationSeconds: 300 },
        { order: 3, youtubeUrl: 'https://youtu.be/jjjjjjjjjjj', titleFr: 'Les nombres', titleEn: 'Numbers', durationSeconds: 280 },
      ],
    });

    it('crée le cours en brouillon, puis ne change rien quand on rejoue', async () => {
      const first = await admin.importCourse(manifest());
      expect(first).toMatchObject({
        course: { status: 'draft', created: true, updated: false },
        lessons: { created: 3, updated: 0, unchanged: 0 },
        notInManifest: [],
      });

      const again = await admin.importCourse(manifest());
      expect(again).toMatchObject({
        course: { id: first.course.id, created: false, updated: false },
        lessons: { created: 0, updated: 0, unchanged: 3 },
      });

      const course = await admin.getCourse(first.course.id);
      expect(course.lessons.map((lesson) => lesson.videoUrl)).toEqual([
        video('h'),
        video('i'),
        video('j'),
      ]);
      expect(course.descriptionEn).toBe('Les bases.');
    });

    it('garde le statut du cours et celui d’une leçon retenue à la main', async () => {
      const { course } = await admin.importCourse(manifest());
      await admin.updateCourse(course.id, { status: PublicationStatus.Published });
      const detail = await admin.getCourse(course.id);
      const tones = detail.lessons.find((lesson) => lesson.order === 2)!;
      await admin.updateLesson(course.id, tones.id, { status: PublicationStatus.Draft });

      const report = await admin.importCourse(manifest());

      expect(report.course.status).toBe('published');
      const after = await admin.getCourse(course.id);
      expect(after.status).toBe('published');
      expect(after.lessons.find((lesson) => lesson.id === tones.id)?.status).toBe('draft');
      expect(after.visibleInApp).toBe(true);
      expect(after.publishedLessonCount).toBe(2);
    });

    it('réaligne positions et titres, ajoute la nouvelle leçon, signale l’absente sans la toucher', async () => {
      const next = manifest();
      // La leçon « nombres » passe en 1, une nouvelle vidéo arrive en 2,
      // « salutations » sort du manifeste.
      next.lessons = [
        { ...next.lessons[2], order: 1, titleFr: 'Compter jusqu’à 10' },
        { order: 2, youtubeUrl: 'https://youtu.be/kkkkkkkkkkk', titleFr: 'La famille', titleEn: 'Family', durationSeconds: 310 },
        { ...next.lessons[1], order: 3 },
      ];

      const report = await admin.importCourse(next);

      expect(report.lessons).toEqual({ created: 1, updated: 2, unchanged: 0 });
      expect(report.notInManifest).toEqual([
        expect.objectContaining({ titleFr: 'Salutations', order: 1 }),
      ]);
      const course = await admin.getCourse(report.course.id);
      expect(course.lessons).toHaveLength(4);
      const byVideo = Object.fromEntries(
        course.lessons.map((lesson) => [lesson.youtubeVideoId, lesson]),
      );
      expect(byVideo.jjjjjjjjjjj).toMatchObject({ order: 1, titleFr: 'Compter jusqu’à 10' });
      expect(byVideo.kkkkkkkkkkk).toMatchObject({ order: 2, status: 'published' });
      expect(byVideo.iiiiiiiiiii).toMatchObject({ order: 3 });
      expect(byVideo.hhhhhhhhhhh).toMatchObject({ order: 1, titleFr: 'Salutations' });
    });

    it('renumérote 1…n à la demande, puis supprime le cours et ses leçons', async () => {
      const { course } = await admin.importCourse(manifest());
      const before = await admin.getCourse(course.id);
      const reversed = [...before.lessons].reverse().map((lesson) => lesson.id);

      const after = await admin.reorderLessons(course.id, reversed);

      expect(after.lessons.map((lesson) => lesson.id)).toEqual(reversed);
      expect(after.lessons.map((lesson) => lesson.order)).toEqual(
        reversed.map((_, index) => index + 1),
      );

      const removed = await admin.deleteCourse(course.id);
      expect(removed).toEqual({ id: course.id, deleted: true, deletedLessons: 4 });
      expect(await prisma.academyLesson.count({ where: { courseId: course.id } })).toBe(0);
    });
  });

  it('refuse de donner à un cours le slug d’un autre (409)', async () => {
    const a = await admin.createCourse({ slug: slug('a'), titleFr: 'A' });
    await admin.createCourse({ slug: slug('b'), titleFr: 'B' });
    await expect(admin.updateCourse(a.id, { slug: slug('b') })).rejects.toBeInstanceOf(
      ConflictException,
    );
  });
});
