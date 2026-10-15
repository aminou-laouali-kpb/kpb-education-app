import type { ExecutionContext, INestApplication } from '@nestjs/common';
import { ValidationPipe } from '@nestjs/common';
import { GUARDS_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { Reflector } from '@nestjs/core';
import { Test } from '@nestjs/testing';

import { AppModule } from '../../app.module';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { AdminScholarshipsController } from '../scholarships-index/admin-scholarships.controller';
import { ScholarshipContentQualityService } from '../scholarships-index/scholarship-content-quality.service';
import { ScholarshipLifecycleService } from '../scholarships-index/scholarship-lifecycle.service';
import { ScholarshipsIndexService } from '../scholarships-index/scholarships-index.service';
import { AdminCatalogController } from './admin-catalog.controller';
import { AdminScholarshipEligibilityController } from './admin-scholarship-eligibility.controller';
import { ScholarshipEligibilityAdminService } from './scholarship-eligibility-admin.service';

const CONTENT_EDITORS = [InternalRole.Admin, InternalRole.SuperAdmin, InternalRole.ContentManager];

describe('AdminScholarshipEligibilityController — périmètre', () => {
  const reflector = new Reflector();
  const handlers = Object.getOwnPropertyNames(AdminScholarshipEligibilityController.prototype).filter(
    (name) => name !== 'constructor',
  );
  const rolesFor = (controller: object, name: string): InternalRole[] =>
    reflector.getAllAndOverride<InternalRole[]>(ROLES_KEY, [
      (controller as { prototype: Record<string, () => unknown> }).prototype[name],
      controller as () => unknown,
    ]) ?? [];

  it('exige l’authentification admin ET la garde de rôles', () => {
    expect(Reflect.getMetadata(GUARDS_METADATA, AdminScholarshipEligibilityController)).toEqual([
      AdminAuthGuard,
      RolesGuard,
    ]);
  });

  it('n’expose que les trois routes prévues', () => {
    expect(handlers.sort()).toEqual(['coverage', 'matchPreview', 'options']);
  });

  it.each(['coverage', 'matchPreview', 'options'])(
    'la route %s est ouverte aux éditeurs de contenu (Admin, SuperAdmin, ContentManager), et à eux seuls',
    (name) => {
      const roles = rolesFor(AdminScholarshipEligibilityController, name);
      expect(roles.slice().sort()).toEqual(CONTENT_EDITORS.slice().sort());
      for (const excluded of [InternalRole.Counselor, InternalRole.Commercial, InternalRole.Moderator]) {
        expect(roles).not.toContain(excluded);
      }
    },
  );

  it('les écritures d’éligibilité (PATCH/POST du catalogue) ont les mêmes rôles', () => {
    for (const name of ['createScholarship', 'updateScholarship']) {
      expect(rolesFor(AdminCatalogController, name).slice().sort()).toEqual(
        CONTENT_EDITORS.slice().sort(),
      );
    }
  });

  it('partage le préfixe des routes de bourses et passe AVANT AdminScholarshipsController', () => {
    expect(Reflect.getMetadata(PATH_METADATA, AdminScholarshipEligibilityController)).toBe(
      Reflect.getMetadata(PATH_METADATA, AdminScholarshipsController),
    );
    const controllers = (Reflect.getMetadata('controllers', AppModule) ?? []) as unknown[];
    const providers = (Reflect.getMetadata('providers', AppModule) ?? []) as unknown[];
    const eligibility = controllers.indexOf(AdminScholarshipEligibilityController);
    expect(eligibility).toBeGreaterThanOrEqual(0);
    expect(eligibility).toBeLessThan(controllers.indexOf(AdminScholarshipsController));
    expect(providers).toContain(ScholarshipEligibilityAdminService);
  });
});

describe('AdminScholarshipEligibilityController — HTTP', () => {
  let app: INestApplication;
  let base: string;
  const service = {
    coverage: jest.fn(),
    options: jest.fn(),
    matchPreview: jest.fn(),
  };
  const quality = { getReadiness: jest.fn() };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      // Même ordre que app.module.ts.
      controllers: [AdminScholarshipEligibilityController, AdminScholarshipsController],
      providers: [
        { provide: ScholarshipEligibilityAdminService, useValue: service },
        { provide: ScholarshipsIndexService, useValue: {} },
        { provide: ScholarshipLifecycleService, useValue: {} },
        { provide: ScholarshipContentQualityService, useValue: quality },
      ],
    })
      .overrideGuard(AdminAuthGuard)
      .useValue({
        canActivate: (context: ExecutionContext) => {
          context.switchToHttp().getRequest().adminUser = { id: 'admin-1', role: 'admin' };
          return true;
        },
      })
      .overrideGuard(RolesGuard)
      .useValue({ canActivate: () => true })
      .compile();
    app = moduleRef.createNestApplication();
    // La même validation que `main.ts` : un champ inconnu est refusé.
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(() => app.close());
  beforeEach(() => {
    jest.clearAllMocks();
    service.coverage.mockResolvedValue({ total: 0 });
    service.options.mockReturnValue({ countries: [] });
    service.matchPreview.mockResolvedValue({ persisted: false });
  });

  const post = (path: string, body: unknown) =>
    fetch(`${base}/admin/scholarships/${path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });

  it('GET eligibility-coverage atteint la couverture, jamais une route en :id', async () => {
    const response = await fetch(`${base}/admin/scholarships/eligibility-coverage`);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ total: 0 });
    expect(service.coverage).toHaveBeenCalledTimes(1);
    expect(quality.getReadiness).not.toHaveBeenCalled();
  });

  it('GET eligibility-options sert la liste des pays', async () => {
    const response = await fetch(`${base}/admin/scholarships/eligibility-options`);
    expect(response.status).toBe(200);
    expect(service.options).toHaveBeenCalledTimes(1);
  });

  it('les routes en :id existantes restent atteignables', async () => {
    quality.getReadiness.mockResolvedValue({ ok: true });
    const response = await fetch(`${base}/admin/scholarships/sch-1/readiness`);
    expect(response.status).toBe(200);
    expect(quality.getReadiness).toHaveBeenCalledWith('sch-1');
  });

  it('POST match-preview accepte des jetons inconnus (le moteur les abandonne) : 200', async () => {
    const response = await post('match-preview', {
      nationalityCode: 'Atlantide',
      scholarshipTargetLevel: 'phd',
      languageTests: [{ type: 'inconnu', score: 3 }],
    });
    expect(response.status).toBe(200);
    expect(service.matchPreview).toHaveBeenCalledWith(
      expect.objectContaining({ nationalityCode: 'Atlantide', scholarshipTargetLevel: 'phd' }),
    );
  });

  it('POST match-preview refuse un champ non déclaré (forbidNonWhitelisted)', async () => {
    const response = await post('match-preview', { userId: 'student-1' });
    expect(response.status).toBe(400);
    expect(service.matchPreview).not.toHaveBeenCalled();
  });

  it('POST match-preview refuse une date de naissance mal formée', async () => {
    const response = await post('match-preview', { birthDate: '10/05/2000' });
    expect(response.status).toBe(400);
  });
});
