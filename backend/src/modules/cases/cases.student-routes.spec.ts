import type { ExecutionContext, INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { StorageService } from '../storage/storage.service';
import { AdminCasesController } from './admin-cases.controller';
import { CasesController } from './cases.controller';
import { CasesService } from './cases.service';

// L'étudiant ne fixe pas l'état de son propre dossier.
//
// `PATCH /cases/:id` (côté étudiant) laissait le propriétaire écrire `status`,
// `assignedAdvisorName`, `nextStepTitle` et `nextStepDescription` — et le service
// journalisait sa saisie comme « mis à jour par un admin ou un conseiller ».
// Or « terminé » ouvre le droit de noter un conseiller : un état que
// l'intéressé se donne lui-même ne peut pas porter ce droit. Aucun client de
// l'app n'appelait cette route ; elle a été retirée plutôt que restreinte.

describe('routes étudiant des dossiers', () => {
  let app: INestApplication;
  let base: string;
  const casesService = { update: jest.fn(), findOne: jest.fn() };

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
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(() => app.close());
  beforeEach(() => jest.clearAllMocks());

  it.each([
    ['PATCH', { status: 'completed' }],
    ['PATCH', { assignedAdvisorName: 'Un conseiller inventé' }],
    ['PUT', { status: 'completed' }],
  ])('%s /cases/:id n’existe pas pour un étudiant (%j)', async (method, body) => {
    const response = await fetch(`${base}/cases/case-1`, {
      method,
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });

    expect(response.status).toBe(404);
    expect(casesService.update).not.toHaveBeenCalled();
  });

  it('garde la lecture de son propre dossier', async () => {
    casesService.findOne.mockResolvedValue({ id: 'case-1' });

    const response = await fetch(`${base}/cases/case-1`);

    expect(response.status).toBe(200);
    expect(casesService.findOne).toHaveBeenCalledWith('case-1', 'user-1');
  });

  it('ne laisse à l’équipe, seule, que `update` — et le service n’a plus de branche « propriétaire »', () => {
    // L'équipe change l'état par `PATCH /admin/cases/:id`.
    const adminRoutes = Object.getOwnPropertyNames(
      AdminCasesController.prototype,
    );
    expect(adminRoutes).toContain('update');
    // Un troisième argument `ownerUserId` rouvrirait la route étudiante sans que
    // personne s'en aperçoive : la signature ne l'accepte plus.
    expect(CasesService.prototype.update.length).toBe(2);
  });
});

describe('CasesController — document upload ownership', () => {
  it("checks case ownership before writing the file (no orphan files on someone else's case)", async () => {
    const { CasesController } = await import('./cases.controller');
    const { NotFoundException } = await import('@nestjs/common');
    const saved: unknown[] = [];
    const casesService = {
      findOne: async () => {
        throw new NotFoundException('Case not found.');
      },
      uploadDocument: async () => ({}),
    };
    const storage = {
      save: async (...args: unknown[]) => {
        saved.push(args);
        return { url: 'storage://x' };
      },
    };
    const controller = new (CasesController as any)(casesService, storage);
    await expect(
      controller.uploadDocument(
        'case-other',
        { title: 'Passport' },
        { buffer: Buffer.from('x'), originalname: 'p.pdf', mimetype: 'application/pdf' },
        { studentUser: { id: 'u1' } },
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(saved).toHaveLength(0);
  });
});
