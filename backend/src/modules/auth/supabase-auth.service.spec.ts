import { ServiceUnavailableException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { sign as jsonwebtokenSign } from 'jsonwebtoken';
import { generateKeyPairSync } from 'crypto';
import { Prisma } from '@prisma/client';

import { SupabaseAuthService } from './supabase-auth.service';
import { PrismaService } from '../prisma/prisma.service';

const SUPABASE_URL = 'https://unit-test.supabase.co';
const ISSUER = `${SUPABASE_URL}/auth/v1`;
const KID = 'test-key-1';

const mockPrismaService = {
  execute: jest.fn(),
  tryExecute: jest.fn(),
};

// One ES256 keypair for the whole suite; the public half is served through the
// mocked JWKS endpoint, the private half signs the test tokens.
const { publicKey, privateKey } = generateKeyPairSync('ec', {
  namedCurve: 'P-256',
});

function makeToken(
  payload: Record<string, unknown> = {},
  options: { expiresIn?: number } = {},
): string {
  return jsonwebtokenSign(
    {
      sub: 'supabase-user-1',
      email: 'student@example.com',
      aud: 'authenticated',
      iss: ISSUER,
      ...payload,
    },
    privateKey,
    {
      algorithm: 'ES256',
      keyid: KID,
      expiresIn: options.expiresIn ?? 3600,
    },
  );
}

async function makeService(): Promise<SupabaseAuthService> {
  const module: TestingModule = await Test.createTestingModule({
    // Mirrors AppModule: a module-level HS256 secret is registered globally.
    // This is exactly the condition under which @nestjs/jwt used to shadow
    // the per-call ES256 publicKey — the regression this suite guards.
    imports: [JwtModule.register({ secret: 'kpb-student-jwt-secret-local-dev' })],
    providers: [
      SupabaseAuthService,
      { provide: PrismaService, useValue: mockPrismaService },
    ],
  }).compile();
  return module.get(SupabaseAuthService);
}

describe('SupabaseAuthService', () => {
  const originalEnv = {
    SUPABASE_URL: process.env.SUPABASE_URL,
    SUPABASE_JWT_SECRET: process.env.SUPABASE_JWT_SECRET,
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
  };

  beforeAll(() => {
    process.env.SUPABASE_URL = SUPABASE_URL;
    delete process.env.SUPABASE_JWT_SECRET;
    // La CI (backend-ci.yml) définit une clé service-role pour tout le job :
    // sans ce retrait, les tests de provisionnement ci-dessous appelleraient
    // l'API admin. Les tests qui en ont besoin la posent eux-mêmes.
    delete process.env.SUPABASE_SERVICE_ROLE_KEY;
  });

  afterAll(() => {
    if (originalEnv.SUPABASE_URL === undefined) {
      delete process.env.SUPABASE_URL;
    } else {
      process.env.SUPABASE_URL = originalEnv.SUPABASE_URL;
    }
    if (originalEnv.SUPABASE_JWT_SECRET !== undefined) {
      process.env.SUPABASE_JWT_SECRET = originalEnv.SUPABASE_JWT_SECRET;
    }
    if (originalEnv.SUPABASE_SERVICE_ROLE_KEY !== undefined) {
      process.env.SUPABASE_SERVICE_ROLE_KEY =
        originalEnv.SUPABASE_SERVICE_ROLE_KEY;
    }
  });

  beforeEach(() => {
    jest.clearAllMocks();
    // mockReset (et non seulement clear) : un test qui échoue ne laisse pas
    // de mockResolvedValueOnce en file pour le suivant.
    mockPrismaService.execute.mockReset();
    mockPrismaService.tryExecute.mockReset();
    const jwk = { ...publicKey.export({ format: 'jwk' }), kid: KID };
    jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({ keys: [jwk] }),
    } as unknown as Response);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('verifies an ES256 token via JWKS despite the module-level HS256 secret', async () => {
    const service = await makeService();
    mockPrismaService.execute.mockResolvedValueOnce({
      id: 'profile-1',
      accountType: 'student',
      fullName: 'Étudiante Test',
    });

    const result = await service.verifyAndResolve(makeToken());

    expect(result).toEqual({
      id: 'profile-1',
      email: 'student@example.com',
      fullName: 'Étudiante Test',
      role: 'student',
      accountType: 'student',
    });
    expect(global.fetch).toHaveBeenCalledWith(
      `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`,
      expect.objectContaining({ signal: expect.anything() }),
    );
  });

  it('rejects an expired token', async () => {
    const service = await makeService();

    await expect(
      service.verifyAndResolve(makeToken({}, { expiresIn: -60 })),
    ).rejects.toThrow(UnauthorizedException);
    expect(mockPrismaService.execute).not.toHaveBeenCalled();
  });

  it('rejects a token signed by an unknown key', async () => {
    const service = await makeService();
    const rogue = generateKeyPairSync('ec', { namedCurve: 'P-256' });
    const forged = jsonwebtokenSign(
      {
        sub: 'supabase-user-1',
        email: 'student@example.com',
        aud: 'authenticated',
        iss: ISSUER,
      },
      rogue.privateKey,
      { algorithm: 'ES256', keyid: KID, expiresIn: 3600 },
    );

    await expect(service.verifyAndResolve(forged)).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('rejects a token with the wrong issuer', async () => {
    const service = await makeService();

    await expect(
      service.verifyAndResolve(
        makeToken({ iss: 'https://evil.example.com/auth/v1' }),
      ),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('provisions a profile on first login when none exists', async () => {
    const service = await makeService();
    // findUnique by supabaseUserId → null, findUnique by email → null,
    // create → new profile.
    mockPrismaService.execute
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 'profile-new',
        accountType: 'student',
        fullName: 'student',
      });

    const result = await service.verifyAndResolve(makeToken());

    expect(result.id).toBe('profile-new');
    const createCall = mockPrismaService.execute.mock.calls[2][0];
    const prisma = {
      userProfile: { create: jest.fn().mockResolvedValue({ id: 'profile-new' }) },
    };
    await createCall(prisma);
    expect(prisma.userProfile.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          supabaseUserId: 'supabase-user-1',
          email: 'student@example.com',
          accountType: 'student',
        }),
      }),
    );
  });

  it('uses the database accountType instead of a stale token role', async () => {
    const service = await makeService();
    mockPrismaService.execute.mockResolvedValueOnce({
      id: 'profile-parent',
      accountType: 'parent',
      fullName: 'Parent Test',
    });

    const result = await service.verifyAndResolve(
      makeToken({ app_metadata: { role: 'student' } }),
    );

    expect(result.accountType).toBe('parent');
  });

  it('answers 503 (not 401) when the JWKS endpoint is unreachable', async () => {
    const service = await makeService();
    jest.spyOn(global, 'fetch').mockRejectedValue(new Error('ECONNRESET'));
    await expect(service.verifyAndResolve(makeToken({}))).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
  it('premier login en parallèle : un P2002 au create relit le profil gagnant au lieu de répondre 500', async () => {
    const service = await makeService();
    mockPrismaService.execute
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null)
      .mockImplementationOnce(async (op: (p: unknown) => Promise<unknown>) => {
        const winner = {
          id: 'profile-winner',
          accountType: 'student',
          fullName: 'student',
        };
        const prisma = {
          userProfile: {
            create: jest.fn().mockRejectedValue(
              new Prisma.PrismaClientKnownRequestError(
                'Unique constraint failed',
                { code: 'P2002', clientVersion: 'test' },
              ),
            ),
            findUnique: jest.fn().mockResolvedValue(winner),
          },
        };
        const result = await op(prisma);
        expect(prisma.userProfile.findUnique).toHaveBeenCalledWith(
          expect.objectContaining({
            where: { supabaseUserId: 'supabase-user-1' },
          }),
        );
        return result;
      });

    const result = await service.verifyAndResolve(makeToken());
    expect(result.id).toBe('profile-winner');
  });

  it('une autre erreur Prisma au create reste remontée', async () => {
    const service = await makeService();
    const failure = new Prisma.PrismaClientKnownRequestError('FK', {
      code: 'P2003',
      clientVersion: 'test',
    });
    mockPrismaService.execute
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null)
      .mockImplementationOnce(async (op: (p: unknown) => Promise<unknown>) =>
        op({
          userProfile: {
            create: jest.fn().mockRejectedValue(failure),
            findUnique: jest.fn(),
          },
        }),
      );

    await expect(service.verifyAndResolve(makeToken())).rejects.toBe(failure);
  });

  describe('provisionnement après suppression du compte (constat 6)', () => {
    const SERVICE_KEY = `sb_secret_${'s'.repeat(32)}`;
    let previousKey: string | undefined;

    beforeEach(() => {
      previousKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
      process.env.SUPABASE_SERVICE_ROLE_KEY = SERVICE_KEY;
    });

    afterEach(() => {
      if (previousKey === undefined) {
        delete process.env.SUPABASE_SERVICE_ROLE_KEY;
      } else {
        process.env.SUPABASE_SERVICE_ROLE_KEY = previousKey;
      }
    });

    function mockFetch(adminLookup: () => Promise<Response>) {
      const jwk = { ...publicKey.export({ format: 'jwk' }), kid: KID };
      jest
        .spyOn(global, 'fetch')
        .mockImplementation(async (input: string | URL | Request) => {
          const url = String(input);
          if (url.endsWith('/.well-known/jwks.json')) {
            return {
              ok: true,
              json: async () => ({ keys: [jwk] }),
            } as unknown as Response;
          }
          return adminLookup();
        });
    }

    it("refuse (401) un jeton encore valide dont l'identité Supabase a été supprimée, sans recréer de profil", async () => {
      const service = await makeService();
      mockFetch(async () => ({ ok: false, status: 404 }) as Response);
      // Profil purgé : ni par supabaseUserId, ni par e-mail.
      mockPrismaService.execute
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);

      await expect(service.verifyAndResolve(makeToken())).rejects.toThrow(
        UnauthorizedException,
      );
      // Seules les deux lectures ont eu lieu : aucun create.
      expect(mockPrismaService.execute).toHaveBeenCalledTimes(2);
      expect(global.fetch).toHaveBeenCalledWith(
        `${SUPABASE_URL}/auth/v1/admin/users/supabase-user-1`,
        expect.objectContaining({
          method: 'GET',
          headers: expect.objectContaining({
            authorization: `Bearer ${SERVICE_KEY}`,
          }),
        }),
      );
    });

    it('refuse aussi une identité soft-deleted côté Supabase', async () => {
      const service = await makeService();
      mockFetch(
        async () =>
          ({
            ok: true,
            status: 200,
            json: async () => ({
              id: 'supabase-user-1',
              deleted_at: '2026-11-22T10:00:00Z',
            }),
          }) as unknown as Response,
      );
      mockPrismaService.execute
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);

      await expect(service.verifyAndResolve(makeToken())).rejects.toThrow(
        UnauthorizedException,
      );
      expect(mockPrismaService.execute).toHaveBeenCalledTimes(2);
    });

    it('provisionne normalement quand l\'identité existe encore', async () => {
      const service = await makeService();
      mockFetch(
        async () =>
          ({
            ok: true,
            status: 200,
            json: async () => ({ id: 'supabase-user-1', deleted_at: null }),
          }) as unknown as Response,
      );
      mockPrismaService.execute
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({
          id: 'profile-new',
          accountType: 'student',
          fullName: 'student',
        });

      const result = await service.verifyAndResolve(makeToken());
      expect(result.id).toBe('profile-new');
      expect(mockPrismaService.execute).toHaveBeenCalledTimes(3);
    });

    it("répond 503 sans provisionner si l'API admin Supabase est injoignable", async () => {
      const service = await makeService();
      mockFetch(async () => {
        throw new Error('ECONNRESET');
      });
      mockPrismaService.execute
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);

      await expect(
        service.verifyAndResolve(makeToken()),
      ).rejects.toBeInstanceOf(ServiceUnavailableException);
      expect(mockPrismaService.execute).toHaveBeenCalledTimes(2);
    });

    it("ne consulte pas l'API admin quand le profil existe déjà (chemin courant)", async () => {
      const service = await makeService();
      mockFetch(async () => {
        throw new Error('ne doit pas être appelé');
      });
      mockPrismaService.execute.mockResolvedValueOnce({
        id: 'profile-1',
        accountType: 'student',
        fullName: 'Étudiante Test',
      });

      const result = await service.verifyAndResolve(makeToken());
      expect(result.id).toBe('profile-1');
      expect(global.fetch).not.toHaveBeenCalledWith(
        expect.stringContaining('/auth/v1/admin/users/'),
        expect.anything(),
      );
    });

    it('refuse le provisionnement en production sans clé service-role', async () => {
      delete process.env.SUPABASE_SERVICE_ROLE_KEY;
      const previousNodeEnv = process.env.NODE_ENV;
      const service = await makeService();
      mockFetch(async () => ({ ok: false, status: 404 }) as Response);
      mockPrismaService.execute
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);
      process.env.NODE_ENV = 'production';
      try {
        await expect(
          service.verifyAndResolve(makeToken()),
        ).rejects.toBeInstanceOf(ServiceUnavailableException);
      } finally {
        process.env.NODE_ENV = previousNodeEnv;
      }
      expect(mockPrismaService.execute).toHaveBeenCalledTimes(2);
    });
  });
});
