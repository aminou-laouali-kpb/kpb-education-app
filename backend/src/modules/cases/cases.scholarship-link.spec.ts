import { BadRequestException, ValidationPipe, type ExecutionContext, type INestApplication } from '@nestjs/common';
import type { ModuleRef } from '@nestjs/core';
import { Test } from '@nestjs/testing';

import { InternalRole } from '../../common/enums/internal-role.enum';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import type { PushSenderService } from '../notifications/push-sender.service';
import type { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { CasesController } from './cases.controller';
import { CasesService } from './cases.service';
import { CreateCaseDto } from './dto/create-case.dto';

/**
 * « Être accompagné par KPB » depuis « Mes 10 bourses » (chantier D) :
 * - le dossier porte la bourse accompagnée, SEULEMENT si la fiche existe ;
 * - `GET /cases?scholarshipId=` (déduplication) reste dans les dossiers de
 *   l'appelant ;
 * - la bourse est relue par l'élève, le conseiller et l'admin ; son nom et ses
 *   liens officiels (relation, sans N+1) par les seules lectures staff.
 */

const NOW = new Date('2026-10-15T10:00:00.000Z');

function caseRow(overrides: Record<string, unknown> = {}) {
  return {
    id: 'case-1',
    userId: 'user-1',
    referenceCode: 'KPB-2026-001',
    type: 'scholarship_support',
    title: 'Candidature — Eiffel',
    status: 'submitted',
    description: 'd',
    contextLabel: 'c',
    preferredContactMethod: 'in_app',
    createdAt: NOW,
    updatedAt: NOW,
    scholarshipId: null,
    messages: [],
    timelineEvents: [],
    tasks: [],
    documents: [],
    internalNotes: [],
    ...overrides,
  };
}

function makeCreateService(existingScholarships: string[]) {
  const created: Array<Record<string, unknown>> = [];
  const lookedUp: string[] = [];
  const tx = {
    counsellor: { findMany: async () => [] },
    scholarship: {
      findUnique: async ({ where }: { where: { id: string } }) => {
        lookedUp.push(where.id);
        return existingScholarships.includes(where.id) ? { id: where.id } : null;
      },
    },
    case: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        created.push(data);
        return { id: 'case-1', seq: 1, createdAt: NOW };
      },
      update: async () => ({}),
      findUnique: async () => caseRow({ scholarshipId: created[0]?.scholarshipId ?? null }),
    },
    caseTimelineEvent: { create: async () => ({}) },
    caseMessage: { create: async () => ({}) },
    caseDocument: { create: async () => ({}) },
  };
  const prisma = {
    isEnabled: true,
    execute: async (fn: (client: unknown) => Promise<unknown>) =>
      fn({ $transaction: async (body: (t: typeof tx) => Promise<unknown>) => body(tx) }),
  } as unknown as PrismaService;
  const push = { sendToUser: async () => undefined } as unknown as PushSenderService;
  const moduleRef = {
    get: () => ({ creditReferrerForFirstCase: async () => undefined }),
  } as unknown as ModuleRef;
  return { service: new CasesService(prisma, moduleRef, push), created, lookedUp };
}

const BASE_INPUT = {
  type: 'scholarship_support',
  title: 'Candidature — Eiffel',
  description: 'Je veux être accompagné.',
  contextLabel: 'Mes 10 bourses',
} as unknown as CreateCaseDto;

describe('CasesService — dossier lié à une bourse', () => {
  it('garde la bourse quand la fiche existe, et la relit dans la réponse', async () => {
    const { service, created } = makeCreateService(['eiffel']);

    const result = await service.create({ ...BASE_INPUT, scholarshipId: 'eiffel' }, 'user-1');

    expect(created[0]).toMatchObject({ scholarshipId: 'eiffel', userId: 'user-1' });
    expect(result.scholarshipId).toBe('eiffel');
  });

  it('crée le dossier SANS lien quand la bourse est inconnue (jamais une erreur)', async () => {
    const { service, created, lookedUp } = makeCreateService([]);

    const result = await service.create({ ...BASE_INPUT, scholarshipId: 'retiree' }, 'user-1');

    expect(lookedUp).toEqual(['retiree']);
    expect(created[0]).toMatchObject({ scholarshipId: null });
    expect(result.scholarshipId).toBeNull();
  });

  it('sans scholarshipId : aucune lecture de fiche, lien nul (anciennes builds)', async () => {
    const { service, created, lookedUp } = makeCreateService(['eiffel']);

    await service.create(BASE_INPUT, 'user-1');

    expect(lookedUp).toEqual([]);
    expect(created[0]).toMatchObject({ scholarshipId: null });
  });
});

describe('CasesService — déduplication par bourse, dans la portée de l’élève', () => {
  const LINKED = caseRow({
    scholarshipId: 'eiffel',
    scholarship: {
      id: 'eiffel',
      nameFr: 'Bourse Eiffel',
      nameEn: 'Eiffel Scholarship',
      sourceUrl: 'https://www.campusfrance.org/fr/eiffel',
      applicationUrl: null,
    },
  });

  function makeListService(rows: unknown[] = [LINKED]) {
    const wheres: unknown[] = [];
    const includes: unknown[] = [];
    const prisma = {
      isEnabled: true,
      execute: async (fn: (client: unknown) => Promise<unknown>) =>
        fn({
          case: {
            findMany: async ({ where, include }: { where: unknown; include: unknown }) => {
              wheres.push(where);
              includes.push(include);
              return rows;
            },
          },
        }),
    } as unknown as PrismaService;
    const service = new CasesService(
      prisma,
      { get: () => null } as unknown as ModuleRef,
      { sendToUser: async () => undefined } as unknown as PushSenderService,
    );
    return { service, wheres, includes };
  }

  it('filtre sur l’étudiant ET la bourse', async () => {
    const { service, wheres } = makeListService();

    const items = await service.findAll('user-1', { scholarshipId: 'eiffel' });

    expect(wheres).toEqual([{ userId: 'user-1', scholarshipId: 'eiffel' }]);
    expect(items[0]).toMatchObject({ scholarshipId: 'eiffel', internalNotes: [] });
  });

  it('sans filtre : la liste de l’élève, inchangée', async () => {
    const { service, wheres } = makeListService();
    await service.findAll('user-1');
    expect(wheres).toEqual([{ userId: 'user-1' }]);
  });

  it('la liste staff (admin, conseiller) relit aussi la bourse, avec son nom', async () => {
    const { service } = makeListService();
    const items = await service.findAll();
    expect(items[0].scholarshipId).toBe('eiffel');
    expect(items[0]).toMatchObject({
      scholarship: {
        id: 'eiffel',
        nameFr: 'Bourse Eiffel',
        nameEn: 'Eiffel Scholarship',
        sourceUrl: 'https://www.campusfrance.org/fr/eiffel',
        applicationUrl: null,
      },
    });
  });

  it('le nom est lu par la relation, dans la même requête (pas de N+1)', async () => {
    const { service, includes } = makeListService();
    await service.findAll();
    expect(includes[0]).toMatchObject({
      scholarship: {
        select: { id: true, nameFr: true, nameEn: true, sourceUrl: true, applicationUrl: true },
      },
    });
  });

  it('un conseiller lit le même résumé sur SES dossiers', async () => {
    const { service, wheres } = makeListService();
    const items = await service.findAllForAdmin({
      id: 'adm-1',
      role: InternalRole.Counselor,
      fullName: 'Awa Conseil',
    });
    expect(wheres[0]).toHaveProperty('OR');
    expect(items[0]).toMatchObject({ scholarship: { id: 'eiffel', nameFr: 'Bourse Eiffel' } });
  });

  it('la réponse élève ne porte que l’identifiant (pas de résumé)', async () => {
    const { service } = makeListService();
    const items = await service.findAll('user-1');
    expect(items[0].scholarshipId).toBe('eiffel');
    expect(items[0]).not.toHaveProperty('scholarship');
  });

  it('bourse supprimée (SET NULL) : ni identifiant ni résumé, sans erreur', async () => {
    const { service } = makeListService([caseRow({ scholarshipId: null, scholarship: null })]);
    const items = await service.findAll();
    expect(items[0]).toMatchObject({ scholarshipId: null, scholarship: null });
  });
});

describe('CreateCaseDto — scholarshipId', () => {
  const pipe = new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true });
  const validate = (value: unknown) => pipe.transform(value, { type: 'body', metatype: CreateCaseDto });
  const base = { type: 'scholarship_support', title: 't', description: 'd', contextLabel: 'c' };

  it('accepte un identifiant de bourse, et son absence', async () => {
    await expect(validate({ ...base, scholarshipId: 'eiffel_2027' })).resolves.toMatchObject({
      scholarshipId: 'eiffel_2027',
    });
    await expect(validate(base)).resolves.not.toHaveProperty('scholarshipId');
  });

  it.each([[{ scholarshipId: 'a'.repeat(65) }], [{ scholarshipId: 42 }]])('refuse %j', async (extra) => {
    await expect(validate({ ...base, ...extra })).rejects.toBeInstanceOf(BadRequestException);
  });
});

describe('GET /cases?scholarshipId= (route élève)', () => {
  let app: INestApplication;
  let base: string;
  const casesService = { findAll: jest.fn(async () => []) };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [CasesController],
      providers: [
        { provide: CasesService, useValue: casesService },
        { provide: StorageService, useValue: {} },
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
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(() => app.close());
  beforeEach(() => jest.clearAllMocks());

  it('passe le filtre avec l’étudiant du jeton, jamais un autre', async () => {
    const response = await fetch(`${base}/cases?scholarshipId=eiffel&userId=someone-else`);
    expect(response.status).toBe(200);
    expect(casesService.findAll).toHaveBeenCalledWith('user-1', { scholarshipId: 'eiffel' });
  });

  it('sans filtre, l’appel d’avant', async () => {
    await fetch(`${base}/cases`);
    expect(casesService.findAll).toHaveBeenCalledWith('user-1');
  });
});
