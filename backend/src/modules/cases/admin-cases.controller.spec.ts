import {
  ExecutionContext,
  INestApplication,
  ValidationPipe,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { StorageService } from '../storage/storage.service';
import { AdminCasesController } from './admin-cases.controller';
import { CasesService } from './cases.service';

/**
 * Les routes de la liste des dossiers, par de vraies requêtes HTTP : la
 * validation des paramètres (la même que `main.ts`), l'ordre des routes
 * (`summary` ne doit pas être lu comme l'identifiant d'un dossier) et les
 * rôles. Le service est un double : ses requêtes sont prouvées ailleurs
 * (`cases.admin-list.spec.ts`, `cases-admin-list.postgres.spec.ts`).
 */
describe('AdminCasesController — HTTP', () => {
  let app: INestApplication;
  let base: string;
  let role: string = InternalRole.Admin;
  const service = {
    findAllForAdmin: jest.fn(),
    adminCaseListSummary: jest.fn(),
    findOneForAdmin: jest.fn(),
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [AdminCasesController],
      providers: [
        { provide: CasesService, useValue: service },
        { provide: StorageService, useValue: {} },
      ],
    })
      .overrideGuard(AdminAuthGuard)
      .useValue({
        canActivate: (context: ExecutionContext) => {
          context.switchToHttp().getRequest().adminUser = {
            id: 'adm-1',
            role,
            fullName: 'Awa KPB',
          };
          return true;
        },
      })
      .compile();
    app = moduleRef.createNestApplication();
    // La même validation que `main.ts` : un paramètre inconnu est refusé.
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(() => app.close());
  beforeEach(() => {
    jest.clearAllMocks();
    role = InternalRole.Admin;
    service.findAllForAdmin.mockResolvedValue({ items: [], nextCursor: null });
    service.adminCaseListSummary.mockResolvedValue({
      awaitingCount: 3,
      advisors: ['Awa KPB'],
    });
    service.findOneForAdmin.mockResolvedValue({ id: 'case-1', tasks: [] });
  });

  const get = (path: string) => fetch(`${base}/admin/cases${path}`);

  it('sans paramètre : la première page, aucun filtre', async () => {
    const response = await get('');

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ items: [], nextCursor: null });
    expect(service.findAllForAdmin).toHaveBeenCalledWith(
      { id: 'adm-1', role: 'admin', fullName: 'Awa KPB' },
      {
        cursor: undefined,
        limit: undefined,
        status: undefined,
        advisor: undefined,
        unassigned: false,
        q: undefined,
        awaiting: false,
      },
    );
  });

  it('transmet les filtres, la recherche et le curseur au service', async () => {
    const query = new URLSearchParams({
      status: 'under_review',
      advisor: 'Fatou & Cie',
      q: 'awa diallo',
      awaiting: 'true',
      unassigned: 'true',
      cursor: 'abc_-',
      limit: '25',
    });

    const response = await get(`?${query}`);

    expect(response.status).toBe(200);
    expect(service.findAllForAdmin.mock.calls[0][1]).toEqual({
      cursor: 'abc_-',
      limit: 25,
      status: 'under_review',
      advisor: 'Fatou & Cie',
      unassigned: true,
      q: 'awa diallo',
      awaiting: true,
    });
  });

  it.each([
    'status=inconnu',
    'limit=0',
    'limit=101',
    'limit=dix',
    'awaiting=oui',
    'unassigned=1',
    `q=${'x'.repeat(121)}`,
    'tout=true',
  ])('refuse « %s » (400) sans lire la base', async (query) => {
    const response = await get(`?${query}`);
    expect(response.status).toBe(400);
    expect(service.findAllForAdmin).not.toHaveBeenCalled();
  });

  it('`summary` est le résumé, pas un dossier nommé « summary »', async () => {
    const response = await get('/summary');

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      awaitingCount: 3,
      advisors: ['Awa KPB'],
    });
    expect(service.adminCaseListSummary).toHaveBeenCalledTimes(1);
    expect(service.findOneForAdmin).not.toHaveBeenCalled();
  });

  it('`:id` rend le dossier ouvert, pour l’agent connecté', async () => {
    const response = await get('/case-1');

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ id: 'case-1', tasks: [] });
    expect(service.findOneForAdmin).toHaveBeenCalledWith('case-1', {
      id: 'adm-1',
      role: 'admin',
      fullName: 'Awa KPB',
    });
  });

  it.each([
    InternalRole.Counselor,
    InternalRole.Commercial,
    InternalRole.Admin,
    InternalRole.SuperAdmin,
  ])('le rôle %s lit la liste, le résumé et un dossier', async (allowed) => {
    role = allowed;
    for (const path of ['', '/summary', '/case-1']) {
      expect((await get(path)).status).toBe(200);
    }
  });

  it('un rôle hors du suivi des dossiers est refusé partout (403)', async () => {
    role = InternalRole.ContentManager;
    for (const path of ['', '/summary', '/case-1']) {
      expect((await get(path)).status).toBe(403);
    }
    expect(service.findAllForAdmin).not.toHaveBeenCalled();
    expect(service.adminCaseListSummary).not.toHaveBeenCalled();
    expect(service.findOneForAdmin).not.toHaveBeenCalled();
  });
});
