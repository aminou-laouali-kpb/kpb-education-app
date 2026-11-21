import {
  ValidationPipe,
  type ExecutionContext,
  type INestApplication,
} from '@nestjs/common';
import { PATH_METADATA } from '@nestjs/common/constants';
import { Reflector } from '@nestjs/core';
import { Test } from '@nestjs/testing';

import { AppModule } from '../../app.module';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminCatalogController } from '../admin-catalog/admin-catalog.controller';
import { AcademyAdminService } from './academy-admin.service';
import { AcademyController } from './academy.controller';
import { AcademyService } from './academy.service';
import { AdminAcademyController } from './admin-academy.controller';

describe('Academy — périmètre des routes', () => {
  const reflector = new Reflector();

  it('sert l’app sous /academy, sans garde : seule la publication ouvre l’accès', () => {
    expect(Reflect.getMetadata(PATH_METADATA, AcademyController)).toBe('academy');
    expect(Reflect.getMetadata('__guards__', AcademyController)).toBeUndefined();
    for (const handler of ['listCourses', 'getCourse'] as const) {
      expect(
        Reflect.getMetadata('__guards__', AcademyController.prototype[handler]),
      ).toBeUndefined();
    }
  });

  it('écrit sous /admin/academy, derrière une session puis un rôle', () => {
    expect(Reflect.getMetadata(PATH_METADATA, AdminAcademyController)).toBe(
      'admin/academy',
    );
    expect(Reflect.getMetadata('__guards__', AdminAcademyController)).toEqual([
      AdminAuthGuard,
      RolesGuard,
    ]);
  });

  it('ouvre chaque route aux rôles du catalogue, pas plus', () => {
    const catalogRoles = reflector.get<InternalRole[]>(
      ROLES_KEY,
      AdminCatalogController,
    );
    const handlers = Object.getOwnPropertyNames(
      AdminAcademyController.prototype,
    ).filter((name) => name !== 'constructor');
    expect(handlers.length).toBeGreaterThanOrEqual(10);
    for (const name of handlers) {
      const roles = reflector.getAllAndOverride<InternalRole[]>(ROLES_KEY, [
        (AdminAcademyController.prototype as unknown as Record<string, () => unknown>)[name],
        AdminAcademyController,
      ]);
      expect({ name, roles: [...roles].sort() }).toEqual({
        name,
        roles: [...catalogRoles].sort(),
      });
    }
  });

  it('est branché dans AppModule', () => {
    const controllers = (Reflect.getMetadata('controllers', AppModule) ?? []) as unknown[];
    const providers = (Reflect.getMetadata('providers', AppModule) ?? []) as unknown[];
    expect(controllers).toEqual(
      expect.arrayContaining([AcademyController, AdminAcademyController]),
    );
    expect(providers).toEqual(
      expect.arrayContaining([AcademyService, AcademyAdminService]),
    );
  });
});

/**
 * Les routes d'administration en HTTP, avec le `ValidationPipe` global de
 * `main.ts` et le VRAI `RolesGuard` : seule la session est simulée.
 */
describe('/admin/academy (HTTP, pipe global)', () => {
  let app: INestApplication;
  let base: string;
  let role: string = InternalRole.ContentManager;
  const service = {
    listCourses: jest.fn(async () => ({ items: [] })),
    createCourse: jest.fn(async () => ({ id: 'course-1' })),
    importCourse: jest.fn(async () => ({ course: { id: 'course-1' } })),
    reorderLessons: jest.fn(async () => ({ id: 'course-1' })),
    createLesson: jest.fn(async () => ({ id: 'lesson-1' })),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [AdminAcademyController],
      providers: [{ provide: AcademyAdminService, useValue: service }],
    })
      .overrideGuard(AdminAuthGuard)
      .useValue({
        canActivate: (context: ExecutionContext) => {
          context.switchToHttp().getRequest().adminUser = { id: 'admin-1', role };
          return true;
        },
      })
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(() => app.close());
  beforeEach(() => {
    jest.clearAllMocks();
    role = InternalRole.ContentManager;
  });

  const send = (method: string, path: string, body?: unknown) =>
    fetch(`${base}${path}`, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });

  const manifest = {
    slug: 'hsk-1',
    titleFr: 'Préparation HSK 1',
    titleEn: 'HSK 1 preparation',
    lessons: [
      {
        order: 1,
        youtubeUrl: 'https://youtu.be/aaaaaaaaaaa',
        titleFr: 'Salutations',
        titleEn: 'Greetings',
        durationSeconds: 245,
      },
    ],
  };

  it('refuse le modérateur et le conseiller (403)', async () => {
    for (const refused of [InternalRole.Moderator, InternalRole.Counselor]) {
      role = refused;
      const response = await send('GET', '/admin/academy/courses');
      expect(response.status).toBe(403);
    }
    expect(service.listCourses).not.toHaveBeenCalled();
  });

  it('accepte un module de manifeste valide', async () => {
    const response = await send('POST', '/admin/academy/courses/import', manifest);
    expect(response.status).toBe(201);
    expect(service.importCourse).toHaveBeenCalledWith(
      expect.objectContaining({ slug: 'hsk-1', lessons: [expect.objectContaining({ order: 1 })] }),
    );
  });

  it.each([
    ['un slug avec majuscules', { ...manifest, slug: 'HSK-1' }],
    ['un lien en http', {
      ...manifest,
      lessons: [{ ...manifest.lessons[0], youtubeUrl: 'http://youtu.be/aaaaaaaaaaa' }],
    }],
    ['une durée nulle', {
      ...manifest,
      lessons: [{ ...manifest.lessons[0], durationSeconds: 0 }],
    }],
    ['un manifeste sans leçon', { ...manifest, lessons: [] }],
    // Le manifeste brut d'HyperFrames porte `file`, `type`, `hskLevel` : la
    // console les retire avant l'envoi, le serveur ne les devine pas.
    ['un champ inconnu dans une leçon', {
      ...manifest,
      lessons: [{ ...manifest.lessons[0], file: 'out/hsk1/01.mp4' }],
    }],
    ['un statut de cours (publier n’est pas un import)', { ...manifest, status: 'published' }],
  ])('refuse %s (400)', async (_label, body) => {
    const response = await send('POST', '/admin/academy/courses/import', body);
    expect(response.status).toBe(400);
    expect(service.importCourse).not.toHaveBeenCalled();
  });

  it('refuse un ordre de leçons avec doublon (400)', async () => {
    const response = await send('PUT', '/admin/academy/courses/course-1/lessons/order', {
      lessonIds: ['l1', 'l1'],
    });
    expect(response.status).toBe(400);
    expect(service.reorderLessons).not.toHaveBeenCalled();
  });

  it('transmet le nouvel ordre au service', async () => {
    const response = await send('PUT', '/admin/academy/courses/course-1/lessons/order', {
      lessonIds: ['l2', 'l1'],
    });
    expect(response.status).toBe(200);
    expect(service.reorderLessons).toHaveBeenCalledWith('course-1', ['l2', 'l1']);
  });

  it('n’accepte pas de prix à la création : les cours sont gratuits', async () => {
    const response = await send('POST', '/admin/academy/courses', {
      slug: 'hsk-1',
      titleFr: 'HSK 1',
      priceXOF: 15000,
    });
    expect(response.status).toBe(400);
    expect(service.createCourse).not.toHaveBeenCalled();
  });
});
