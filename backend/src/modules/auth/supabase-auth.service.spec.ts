import { ServiceUnavailableException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { sign as jsonwebtokenSign } from 'jsonwebtoken';
import { generateKeyPairSync } from 'crypto';

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
  };

  beforeAll(() => {
    process.env.SUPABASE_URL = SUPABASE_URL;
    delete process.env.SUPABASE_JWT_SECRET;
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
  });

  beforeEach(() => {
    jest.clearAllMocks();
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
});
