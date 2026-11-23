import {
  ExecutionContext,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { ADMIN_ACCESS_COOKIE } from './admin-cookies';
import { AuthService } from './auth.service';
import { SupabaseAuthService } from './supabase-auth.service';

/**
 * Audit 41 : gardes d'authentification testées directement (elles ne
 * l'étaient qu'en dépendance, souvent remplacées par des mocks).
 */
function httpContext(request: Record<string, unknown>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
    getHandler: () => function handler() {},
    getClass: () => class Controller {},
  } as unknown as ExecutionContext;
}

describe('AdminAuthGuard', () => {
  function setup() {
    const authService = {
      verifyToken: jest.fn(async (token: string) => ({ id: 'a1', token })),
    };
    const guard = new AdminAuthGuard(authService as unknown as AuthService);
    return { guard, authService };
  }

  it('401 sans cookie ni Bearer', async () => {
    const { guard, authService } = setup();
    await expect(
      guard.canActivate(httpContext({ headers: {} })),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(authService.verifyToken).not.toHaveBeenCalled();
  });

  it('401 pour un en-tête Authorization qui n’est pas Bearer', async () => {
    const { guard } = setup();
    await expect(
      guard.canActivate(httpContext({ headers: { authorization: 'Basic abc' } })),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('préfère le cookie httpOnly au Bearer', async () => {
    const { guard, authService } = setup();
    const request: Record<string, unknown> = {
      headers: {
        cookie: `${ADMIN_ACCESS_COOKIE}=cookie-token`,
        authorization: 'Bearer bearer-token',
      },
    };
    await expect(guard.canActivate(httpContext(request))).resolves.toBe(true);
    expect(authService.verifyToken).toHaveBeenCalledWith('cookie-token');
    expect(request.adminUser).toEqual({ id: 'a1', token: 'cookie-token' });
  });

  it('retombe sur le Bearer sans cookie', async () => {
    const { guard, authService } = setup();
    await guard.canActivate(
      httpContext({ headers: { authorization: 'Bearer bearer-token' } }),
    );
    expect(authService.verifyToken).toHaveBeenCalledWith('bearer-token');
  });

  it('propage le refus de verifyToken (jeton invalide)', async () => {
    const { guard, authService } = setup();
    authService.verifyToken.mockRejectedValueOnce(
      new UnauthorizedException('Invalid token.'),
    );
    await expect(
      guard.canActivate(httpContext({ headers: { authorization: 'Bearer bad' } })),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});

describe('RolesGuard', () => {
  function guardFor(required: InternalRole[] | undefined) {
    const reflector = {
      getAllAndOverride: jest.fn(() => required),
    } as unknown as Reflector;
    return new RolesGuard(reflector);
  }

  it('laisse passer une route sans @Roles', () => {
    expect(guardFor(undefined).canActivate(httpContext({}))).toBe(true);
    expect(guardFor([]).canActivate(httpContext({}))).toBe(true);
  });

  it('401 sans session admin (rôle manquant)', () => {
    expect(() =>
      guardFor([InternalRole.Admin]).canActivate(httpContext({ adminUser: {} })),
    ).toThrow(UnauthorizedException);
  });

  it('403 pour un rôle non autorisé', () => {
    expect(() =>
      guardFor([InternalRole.Admin]).canActivate(
        httpContext({ adminUser: { role: InternalRole.Moderator } }),
      ),
    ).toThrow(ForbiddenException);
  });

  it('laisse passer un rôle autorisé', () => {
    expect(
      guardFor([InternalRole.Admin, InternalRole.SuperAdmin]).canActivate(
        httpContext({ adminUser: { role: InternalRole.SuperAdmin } }),
      ),
    ).toBe(true);
  });
});

describe('StudentAuthGuard', () => {
  function setup() {
    const supabase = {
      verifyAndResolve: jest.fn(async () => ({ id: 's1' })),
    };
    const guard = new StudentAuthGuard(supabase as unknown as SupabaseAuthService);
    return { guard, supabase };
  }

  it('401 sans Bearer', async () => {
    const { guard, supabase } = setup();
    await expect(
      guard.canActivate(httpContext({ headers: {} })),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(
      guard.canActivate(httpContext({ headers: { authorization: 'Token x' } })),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(supabase.verifyAndResolve).not.toHaveBeenCalled();
  });

  it('vérifie le jeton et attache request.studentUser', async () => {
    const { guard, supabase } = setup();
    const request: Record<string, unknown> = {
      headers: { authorization: 'Bearer sb-token' },
    };
    await expect(guard.canActivate(httpContext(request))).resolves.toBe(true);
    expect(supabase.verifyAndResolve).toHaveBeenCalledWith('sb-token');
    expect(request.studentUser).toEqual({ id: 's1' });
  });

  it('propage le refus d’un jeton invalide', async () => {
    const { guard, supabase } = setup();
    supabase.verifyAndResolve.mockRejectedValueOnce(new UnauthorizedException());
    await expect(
      guard.canActivate(httpContext({ headers: { authorization: 'Bearer bad' } })),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
