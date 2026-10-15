import { ValidationPipe, type ExecutionContext, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { ScholarshipsController } from './admin-scholarships.controller';
import { DailyScholarshipService } from './daily-scholarship.service';
import { ScholarshipsIndexService } from './scholarships-index.service';

/**
 * `GET /scholarships` en HTTP, avec le `ValidationPipe` global de `main.ts`
 * (`whitelist`, `forbidNonWhitelisted`, `transform`).
 *
 * Chantier I : la nouvelle app envoie `q`, `status` et `sort`. La route lit
 * ses paramètres un par un (`@Query('nom')`, pas de DTO de requête) : le pipe
 * ne valide pas une chaîne nue, et une clé non déclarée n'est jamais
 * extraite — elle ne peut donc pas déclencher le 400 `forbidNonWhitelisted`.
 * C'est ce qui permet à la nouvelle app de parler à un serveur plus ancien
 * (qui ignore ces clés et ne renvoie pas d'écho `query`).
 */
describe('GET /scholarships (HTTP, pipe global)', () => {
  let app: INestApplication;
  let base: string;
  const index = {
    listForProfile: jest.fn(async () => ({ items: [], total: 0, hasMore: false })),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [ScholarshipsController],
      providers: [
        { provide: ScholarshipsIndexService, useValue: index },
        { provide: DailyScholarshipService, useValue: {} },
      ],
    })
      .overrideGuard(StudentAuthGuard)
      .useValue({
        canActivate: (context: ExecutionContext) => {
          context.switchToHttp().getRequest().studentUser = { id: 'user-1' };
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
  beforeEach(() => jest.clearAllMocks());

  it('une clé inconnue de la route n’est pas un 400 (serveur plus ancien que l’app)', async () => {
    const response = await fetch(`${base}/scholarships?lang=fr&limit=20&offset=0&cursor=x&foo=bar`);
    expect(response.status).toBe(200);
    expect(index.listForProfile).toHaveBeenCalledWith(
      expect.not.objectContaining({ cursor: expect.anything() }),
    );
  });

  it('q, status et sort passent au service, valeurs inconnues comprises', async () => {
    const response = await fetch(
      `${base}/scholarships?lang=fr&q=eiffel&status=open,expired&sort=random`,
    );
    expect(response.status).toBe(200);
    expect(index.listForProfile).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        q: 'eiffel',
        status: 'open,expired',
        sort: 'random',
      }),
    );
  });

  it('une clé répétée arrive en tableau, sans 400', async () => {
    const response = await fetch(`${base}/scholarships?status=open&status=upcoming`);
    expect(response.status).toBe(200);
    expect(index.listForProfile).toHaveBeenCalledWith(
      expect.objectContaining({ status: ['open', 'upcoming'] }),
    );
  });
});
