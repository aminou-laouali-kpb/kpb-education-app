import {
  UnauthorizedException,
  ValidationPipe,
  type ExecutionContext,
  type INestApplication,
} from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';

import { GlobalExceptionFilter } from '../../common/filters/http-exception.filter';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { buildThrottlerOptions } from '../../common/throttler-options';
import { ScholarshipsController } from '../scholarships-index/admin-scholarships.controller';
import { DailyScholarshipService } from '../scholarships-index/daily-scholarship.service';
import { ScholarshipsIndexService } from '../scholarships-index/scholarships-index.service';
import { CandidateSnapshotService } from './candidate-snapshot';
import { ScholarshipMatchController } from './scholarship-match.controller';
import { ScholarshipMatchEnabledGuard } from './scholarship-match.feature';
import { ScholarshipMatchService } from './scholarship-match.service';
import { candidateRow, FakeMatchDb } from './testing/fake-match-db';
import { makeScholarship, NOW } from './testing/match-fixtures';

/**
 * Les routes `/scholarships/match/*` de bout en bout : la VRAIE ValidationPipe
 * de `main.ts` (`forbidNonWhitelisted`), le vrai filtre global, le vrai
 * limiteur, le vrai service sur une base en mémoire. Seule l'authentification
 * Supabase est remplacée (le jeton dit le type de compte).
 */

const FLAG = 'KPB_SCHOLARSHIP_MATCH_ENABLED';
const previousFlag = process.env[FLAG];

/** `Bearer <accountType>` ; pas d'en-tête : 401, comme le vrai garde. */
const fakeStudentGuard = {
  canActivate: (context: ExecutionContext) => {
    const request = context.switchToHttp().getRequest();
    const header = request.headers?.authorization as string | undefined;
    if (!header?.startsWith('Bearer ')) throw new UnauthorizedException('Missing authorization token.');
    const accountType = header.slice(7);
    request.studentUser = { id: 'stu-1', accountType };
    return true;
  },
};

function profile(overrides: Record<string, unknown> = {}) {
  return {
    id: 'stu-1',
    countryOfResidence: 'Niger',
    birthDate: new Date('2006-05-10T00:00:00.000Z'),
    guardianConsentedAt: null,
    guardianName: null,
    guardianContact: null,
    nationalityCode: 'ner',
    secondNationalityCode: null,
    highestDiploma: 'bac',
    scholarshipTargetLevel: 'bachelor',
    fieldIds: ['d01'],
    targetCountryIds: [],
    gradeBandOn20: '12_14',
    englishLevel: 'b1',
    frenchLevel: null,
    languageTests: null,
    workExperienceBand: null,
    scholarshipProfileConfirmedAt: null,
    scholarshipMatchAlertsOptInAt: null,
    currentLevel: null,
    targetLevel: 'Bachelor',
    languageLevel: 'Intermediate',
    gradeRange: '12 - 14/20',
    ...overrides,
  };
}

describe('ScholarshipMatchController (HTTP)', () => {
  let app: INestApplication;
  let base: string;
  let db: FakeMatchDb;
  const scholarshipsIndex = {
    getForProfile: jest.fn(async (id: string) => ({ id })),
    listForProfile: jest.fn(async () => ({ items: [] })),
  };

  beforeEach(async () => {
    process.env[FLAG] = 'true';
    db = new FakeMatchDb();
    db.addProfile(profile());
    db.scholarships = [
      candidateRow(makeScholarship({ id: 'bach-01', eligibleLevels: ['bachelor'] })),
      candidateRow(makeScholarship({ id: 'master-only', eligibleLevels: ['master'] })),
    ];
    const clock = () => NOW;
    const snapshots = new CandidateSnapshotService(db.prismaService, clock);

    const moduleRef = await Test.createTestingModule({
      // `test` : 600/min de limite globale, la route des runs garde ses 10/min.
      imports: [ThrottlerModule.forRoot(buildThrottlerOptions('test'))],
      controllers: [ScholarshipMatchController, ScholarshipsController],
      providers: [
        { provide: APP_GUARD, useClass: ThrottlerGuard },
        ScholarshipMatchEnabledGuard,
        {
          provide: ScholarshipMatchService,
          useValue: new ScholarshipMatchService(db.prismaService, snapshots, clock),
        },
        { provide: ScholarshipsIndexService, useValue: scholarshipsIndex },
        { provide: DailyScholarshipService, useValue: {} },
      ],
    })
      .overrideGuard(StudentAuthGuard)
      .useValue(fakeStudentGuard)
      .compile();

    app = moduleRef.createNestApplication();
    // Même réglage que main.ts.
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterEach(async () => {
    await app.close();
    jest.clearAllMocks();
  });

  afterAll(() => {
    if (previousFlag === undefined) delete process.env[FLAG];
    else process.env[FLAG] = previousFlag;
  });

  function call(
    method: string,
    path: string,
    options: { token?: string; body?: unknown } = {},
  ): Promise<Response> {
    return fetch(`${base}${path}`, {
      method,
      headers: {
        'content-type': 'application/json',
        ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
      },
      ...(options.body !== undefined ? { body: JSON.stringify(options.body) } : {}),
    });
  }

  describe('drapeau coupé', () => {
    it.each([
      ['GET', '/scholarships/match/state?lang=fr', undefined],
      ['POST', '/scholarships/match/runs', { confirm: true }],
      ['PUT', '/scholarships/match/alerts', { enabled: true }],
    ])('%s %s → 404 { disabled: true }, avant toute authentification', async (method, path, body) => {
      for (const value of [undefined, '', 'false', 'yes']) {
        if (value === undefined) delete process.env[FLAG];
        else process.env[FLAG] = value;
        const response = await call(method, path, { body });
        expect(response.status).toBe(404);
        await expect(response.json()).resolves.toMatchObject({
          statusCode: 404,
          disabled: true,
          code: 'scholarship_match_disabled',
        });
      }
      expect(db.runsOf('stu-1')).toEqual([]);
    });
  });

  describe('authentification et type de compte', () => {
    it.each([
      ['GET', '/scholarships/match/state', undefined],
      ['POST', '/scholarships/match/runs', {}],
      ['PUT', '/scholarships/match/alerts', { enabled: true }],
    ])('%s %s sans jeton → 401', async (method, path, body) => {
      expect((await call(method, path, { body })).status).toBe(401);
    });

    it.each(['parent', 'partner'])('compte %s → 403 sur les trois routes, rien n’est écrit', async (accountType) => {
      expect((await call('GET', '/scholarships/match/state', { token: accountType })).status).toBe(403);
      expect(
        (await call('POST', '/scholarships/match/runs', { token: accountType, body: { confirm: true } })).status,
      ).toBe(403);
      expect(
        (await call('PUT', '/scholarships/match/alerts', { token: accountType, body: { enabled: true } })).status,
      ).toBe(403);
      expect(db.runsOf('stu-1')).toEqual([]);
      expect(db.profile('stu-1')).toMatchObject({
        scholarshipProfileConfirmedAt: null,
        scholarshipMatchAlertsOptInAt: null,
      });
    });
  });

  describe('POST /scholarships/match/runs', () => {
    it('jetons et clés de réponse inconnus : 200, abandonnés, jamais un 400', async () => {
      const response = await call('POST', '/scholarships/match/runs', {
        token: 'student',
        body: {
          lang: 'fr-SN',
          trigger: 'wizard_v3_from_the_future',
          confirm: true,
          answers: {
            englishLevel: 'c3',
            gradeBandOn20: 42,
            fieldIds: ['d01', 'd77'],
            workExperienceBand: 'eternity',
            nationalityCode: 'NER',
            languageTests: [{ type: 'pte', score: 70 }, 'garbage'],
            budgetEur: 1000,
            nested: { anything: true },
          },
        },
      });

      expect(response.status).toBe(200);
      const json = await response.json();
      expect(json.status).toBe('ok');
      expect(json.run.items.map((item: { scholarshipId: string }) => item.scholarshipId)).toEqual(['bach-01']);
      expect(json.run.trigger).toBe('other');
      expect(db.profile('stu-1')).toMatchObject({
        englishLevel: 'b1',
        gradeBandOn20: '12_14',
        fieldIds: ['d01'],
        nationalityCode: 'ner',
        languageTests: [],
        scholarshipProfileConfirmedAt: NOW,
      });
    });

    it('profil non confirmé : 200 { status: profile_incomplete }, rien n’est persisté', async () => {
      const response = await call('POST', '/scholarships/match/runs', {
        token: 'student',
        body: { answers: { englishLevel: 'b2' } },
      });

      expect(response.status).toBe(200);
      await expect(response.json()).resolves.toMatchObject({
        status: 'profile_incomplete',
        readiness: { ready: false },
      });
      expect(db.runsOf('stu-1')).toEqual([]);
      expect(db.profile('stu-1')?.englishLevel).toBe('b1');
    });

    it('le corps de premier niveau reste déclaré : une clé inconnue y est refusée (400)', async () => {
      const response = await call('POST', '/scholarships/match/runs', {
        token: 'student',
        body: { confirm: true, userId: 'someone-else' },
      });
      expect(response.status).toBe(400);
      expect(db.runsOf('stu-1')).toEqual([]);
    });

    it('limite à 10 calculs par minute (le 11e : 429)', async () => {
      const statuses: number[] = [];
      for (let i = 0; i < 11; i += 1) {
        statuses.push(
          (await call('POST', '/scholarships/match/runs', { token: 'student', body: { confirm: true } })).status,
        );
      }
      expect(statuses.slice(0, 10).every((status) => status === 200)).toBe(true);
      expect(statuses[10]).toBe(429);
    });
  });

  describe('GET /scholarships/match/state et PUT /scholarships/match/alerts', () => {
    it('sert l’état de l’élève connecté, sans passer par GET /scholarships/:id', async () => {
      const response = await call('GET', '/scholarships/match/state?lang=en&unknown=1', { token: 'student' });

      expect(response.status).toBe(200);
      const json = await response.json();
      expect(json).toMatchObject({ algorithmVersion: 'sm-1', catalogSize: 2, latestRun: null });
      expect(json.options.countries[0]).toEqual({ code: 'ner', name: 'Niger', priority: true });
      expect(scholarshipsIndex.getForProfile).not.toHaveBeenCalled();

      // Le détail d'une bourse, lui, répond toujours.
      expect((await call('GET', '/scholarships/bach-01', { token: 'student' })).status).toBe(200);
      expect(scholarshipsIndex.getForProfile).toHaveBeenCalledWith('bach-01', expect.anything());
    });

    it('PUT alerts : booléen strict', async () => {
      expect(
        (await call('PUT', '/scholarships/match/alerts', { token: 'student', body: { enabled: 'yes' } })).status,
      ).toBe(400);

      const response = await call('PUT', '/scholarships/match/alerts', {
        token: 'student',
        body: { enabled: true },
      });
      expect(response.status).toBe(200);
      await expect(response.json()).resolves.toEqual({ enabled: true, optedInAt: NOW.toISOString() });
      expect(db.profile('stu-1')?.scholarshipMatchAlertsOptInAt).toEqual(NOW);
    });
  });
});
