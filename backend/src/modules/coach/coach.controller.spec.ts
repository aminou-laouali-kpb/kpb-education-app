import 'reflect-metadata';

import {
  ArgumentMetadata,
  ExecutionContext,
  INestApplication,
  Logger,
  MessageEvent,
  RequestMethod,
  ValidationPipe,
} from '@nestjs/common';
import {
  METHOD_METADATA,
  PATH_METADATA,
  SSE_METADATA,
} from '@nestjs/common/constants';
import { Test } from '@nestjs/testing';
import { Observable, of } from 'rxjs';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';

import { LlmService, LlmUnavailableError } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import { CoachController } from './coach.controller';
import { CoachQuotaService } from './coach-quota.service';
import { CoachService, describeCoachError } from './coach.service';
import { StreamCoachMessageDto } from './dto/stream-coach-message.dto';

/**
 * Audit 22/11/2026, constat 33 : le message libre de l'élève partait en query
 * string (GET SSE), donc dans les journaux d'accès des proxys. Il part
 * désormais dans le corps d'un POST SSE ; le GET reste servi pour les
 * versions de l'app déjà installées.
 */

const SECRET = "Je m'appelle Awa Diop, mes parents gagnent 150 000 FCFA";

function handler(name: keyof CoachController) {
  return CoachController.prototype[name] as unknown as object;
}

function makeController() {
  const streamReply = jest.fn(
    (): Observable<MessageEvent> => of({ data: { type: 'done' } }),
  );
  const ctrl = new CoachController({ streamReply } as unknown as CoachService);
  return { ctrl, streamReply };
}

const req = { studentUser: { id: 'user-real' } };

describe('CoachController — flux du coach', () => {
  it('expose un POST SSE sur conversations/:id/messages/stream', () => {
    const fn = handler('streamMessageFromBody');
    expect(Reflect.getMetadata(SSE_METADATA, fn)).toBe(true);
    expect(Reflect.getMetadata(METHOD_METADATA, fn)).toBe(RequestMethod.POST);
    expect(Reflect.getMetadata(PATH_METADATA, fn)).toBe(
      'conversations/:id/messages/stream',
    );
  });

  it("garde le GET SSE historique pour les versions installées de l'app", () => {
    const fn = handler('streamMessage');
    expect(Reflect.getMetadata(SSE_METADATA, fn)).toBe(true);
    expect(Reflect.getMetadata(METHOD_METADATA, fn)).toBe(RequestMethod.GET);
    expect(Reflect.getMetadata(PATH_METADATA, fn)).toBe(
      'conversations/:id/messages/stream',
    );
  });

  it('POST : lit le message et le profil dans le corps, userId authentifié', () => {
    const { ctrl, streamReply } = makeController();
    const body = Object.assign(new StreamCoachMessageDto(), {
      message: SECRET,
      profile: {
        currentLevel: 'terminale',
        targetCountryIds: ['fr', 'ca'],
        preferredLanguage: 'fr',
      },
    });
    ctrl.streamMessageFromBody('conv-1', body, req);
    expect(streamReply).toHaveBeenCalledWith({
      conversationId: 'conv-1',
      userId: 'user-real',
      message: SECRET,
      profile: {
        currentLevel: 'terminale',
        targetCountryIds: ['fr', 'ca'],
        preferredLanguage: 'fr',
      },
    });
  });

  it('POST : corps sans message ni profil => chaîne vide (refus SSE du service)', () => {
    const { ctrl, streamReply } = makeController();
    ctrl.streamMessageFromBody('conv-1', new StreamCoachMessageDto(), req);
    expect(streamReply).toHaveBeenCalledWith(
      expect.objectContaining({ message: '', profile: {} }),
    );
  });

  it('GET : continue de fonctionner avec la query string', () => {
    const { ctrl, streamReply } = makeController();
    ctrl.streamMessage('conv-1', req, 'Bonjour', 'Awa', 'l3', 'fr,,ca', 'en');
    expect(streamReply).toHaveBeenCalledWith({
      conversationId: 'conv-1',
      userId: 'user-real',
      message: 'Bonjour',
      profile: {
        fullName: 'Awa',
        currentLevel: 'l3',
        targetCountryIds: ['fr', 'ca'],
        preferredLanguage: 'en',
      },
    });
  });
});

describe('StreamCoachMessageDto — validation globale (whitelist)', () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });
  const meta: ArgumentMetadata = {
    type: 'body',
    metatype: StreamCoachMessageDto,
  };

  it("accepte le corps envoyé par l'app", async () => {
    const value = await pipe.transform(
      {
        message: 'Bonjour',
        profile: {
          currentLevel: 'terminale',
          targetCountryIds: ['fr'],
          preferredLanguage: 'fr',
        },
      },
      meta,
    );
    expect(value).toMatchObject({ message: 'Bonjour' });
  });

  it('refuse un message non chaîne', async () => {
    await expect(pipe.transform({ message: ['a'] }, meta)).rejects.toThrow();
  });

  it('refuse un champ inconnu (forbidNonWhitelisted)', async () => {
    await expect(
      pipe.transform({ message: 'a', userId: 'x' }, meta),
    ).rejects.toThrow();
  });
});

describe('Le message de l’élève n’est jamais journalisé', () => {
  it('describeCoachError ne recopie que la classe d’une erreur inattendue', () => {
    expect(describeCoachError(new TypeError(`bad value ${SECRET}`))).toBe(
      'TypeError',
    );
    expect(describeCoachError(SECRET)).toBe('string');
    expect(
      describeCoachError(new LlmUnavailableError('groq did not answer.')),
    ).toBe('groq did not answer.');
  });

  it('une panne interne qui recopie le message ne le fait pas entrer dans les journaux', async () => {
    const logged: string[] = [];
    const spies = (['log', 'warn', 'error', 'debug', 'verbose'] as const).map(
      (level) =>
        jest
          .spyOn(Logger.prototype, level)
          .mockImplementation((...args: unknown[]) => {
            logged.push(args.map(String).join(" "));
          }),
    );
    try {
      const fakeClient = {
        coachConversation: {
          findUnique: async () => null,
          create: async () => null,
          update: async () => null,
        },
        coachMessage: { create: async () => null },
        country: { findMany: async () => null },
        scholarship: { findMany: async () => null },
        userProfile: {
          findUnique: async () => ({
            aiConsentedAt: new Date(),
            birthDate: new Date('2000-01-01T00:00:00.000Z'),
            guardianConsentedAt: null,
          }),
        },
      };
      const prisma = {
        tryExecute: async (fn: (c: typeof fakeClient) => unknown) =>
          fn(fakeClient),
      } as unknown as PrismaService;
      const llm = {
        async *streamText(): AsyncGenerator<string> {
          throw new TypeError(`Cannot read property of ${SECRET}`);
        },
      } as unknown as LlmService;
      const quota = {
        getQuota: () => ({ remaining: 5, limit: 5, allowed: true }),
        consume: () => ({ allowed: true, remaining: 4, limit: 5 }),
        refund: async () => undefined,
      } as unknown as CoachQuotaService;
      const service = new CoachService(llm, quota, prisma);
      const created = await service.createConversation('user-a', {});
      const events = await new Promise<unknown[]>((resolve) => {
        const out: unknown[] = [];
        service
          .streamReply({
            conversationId: created.conversationId,
            userId: 'user-a',
            message: SECRET,
            profile: {},
          })
          .subscribe({
            next: (e) => out.push(e.data),
            complete: () => resolve(out),
          });
      });
      expect(JSON.stringify(events.at(-1))).toContain('error');
      expect(logged.some((line) => line.includes('TypeError'))).toBe(true);
      expect(logged.join('\n')).not.toContain('Awa');
    } finally {
      spies.forEach((spy) => spy.mockRestore());
    }
  });
});

describe('CoachController — routes HTTP réelles (Nest + ValidationPipe)', () => {
  let app: INestApplication;
  let baseUrl: string;
  const streamReply = jest.fn(
    (): Observable<MessageEvent> =>
      of(
        { data: { type: 'token', text: 'Bon' } },
        { data: { type: 'token', text: 'jour' } },
        { data: { type: 'done', quotaRemaining: 4 } },
      ),
  );

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [CoachController],
      providers: [{ provide: CoachService, useValue: { streamReply } }],
    })
      .overrideGuard(StudentAuthGuard)
      .useValue({
        canActivate: (ctx: ExecutionContext) => {
          ctx.switchToHttp().getRequest().studentUser = { id: 'user-real' };
          return true;
        },
      })
      .compile();
    app = moduleRef.createNestApplication({ logger: false });
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.listen(0, '127.0.0.1');
    baseUrl = await app.getUrl();
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => streamReply.mockClear());

  it('POST : diffuse TOUS les événements SSE (pas seulement le dernier)', async () => {
    const res = await fetch(
      `${baseUrl}/coach/conversations/conv-1/messages/stream`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: SECRET,
          profile: { currentLevel: 'terminale', targetCountryIds: ['fr'] },
        }),
      },
    );
    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toContain('text/event-stream');
    const text = await res.text();
    expect(text).toContain('"text":"Bon"');
    expect(text).toContain('"text":"jour"');
    expect(text).toContain('"type":"done"');
    expect(streamReply).toHaveBeenCalledWith(
      expect.objectContaining({
        conversationId: 'conv-1',
        userId: 'user-real',
        message: SECRET,
      }),
    );
  });

  it('POST : refuse un champ inconnu (400), sans appeler le service', async () => {
    const res = await fetch(
      `${baseUrl}/coach/conversations/conv-1/messages/stream`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: 'a', userId: 'attacker' }),
      },
    );
    expect(res.status).toBe(400);
    expect(streamReply).not.toHaveBeenCalled();
  });

  it('GET historique : toujours servi pour les anciennes versions', async () => {
    const res = await fetch(
      `${baseUrl}/coach/conversations/conv-1/messages/stream?message=Bonjour&lang=fr`,
    );
    expect(res.status).toBe(200);
    expect(await res.text()).toContain('"type":"done"');
    expect(streamReply).toHaveBeenCalledWith(
      expect.objectContaining({ message: 'Bonjour', userId: 'user-real' }),
    );
  });
});
