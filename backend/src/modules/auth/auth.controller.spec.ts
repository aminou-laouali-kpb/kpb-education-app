import type { Request, Response } from 'express';

import { ADMIN_ACCESS_COOKIE, ADMIN_REFRESH_COOKIE } from './admin-cookies';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

/**
 * Audit 41 : refresh (rotation par cookie) et logout (révocation, cookies
 * effacés même si la base est en panne).
 */
describe('AuthController (admin)', () => {
  function setup() {
    const authService = {
      login: jest.fn(),
      refresh: jest.fn(async () => ({
        token: 'new-access',
        refreshToken: 'rotated-refresh',
        user: { id: 'u1' },
      })),
      revokeRefreshToken: jest.fn(async () => undefined),
    };
    const res = { cookie: jest.fn(), clearCookie: jest.fn() };
    const controller = new AuthController(authService as unknown as AuthService);
    const req = (cookie?: string) =>
      ({ headers: cookie ? { cookie } : {} }) as unknown as Request;
    return { controller, authService, res, response: res as unknown as Response, req };
  }

  describe('refresh', () => {
    it('lit le refresh token du cookie en priorité sur le corps', async () => {
      const { controller, authService, response, req } = setup();
      await controller.refresh(
        req(`${ADMIN_REFRESH_COOKIE}=from-cookie`),
        { refreshToken: 'from-body' },
        response,
      );
      expect(authService.refresh).toHaveBeenCalledWith('from-cookie');
    });

    it('retombe sur le corps puis sur une chaîne vide', async () => {
      const { controller, authService, response, req } = setup();
      await controller.refresh(req(), { refreshToken: 'from-body' }, response);
      await controller.refresh(req(), undefined as never, response);
      expect(authService.refresh.mock.calls).toEqual([['from-body'], ['']]);
    });

    it('pose le jeton tourné en cookie et ne renvoie que l’utilisateur', async () => {
      const { controller, res, response, req } = setup();
      const body = await controller.refresh(
        req(`${ADMIN_REFRESH_COOKIE}=old`),
        {},
        response,
      );
      expect(body).toEqual({ user: { id: 'u1' } });
      expect(res.cookie).toHaveBeenCalledWith(
        ADMIN_ACCESS_COOKIE,
        'new-access',
        expect.objectContaining({ httpOnly: true }),
      );
      expect(res.cookie).toHaveBeenCalledWith(
        ADMIN_REFRESH_COOKIE,
        'rotated-refresh',
        expect.objectContaining({ httpOnly: true, path: '/api/auth/admin' }),
      );
    });

    it('ne pose aucun cookie si le service refuse le jeton', async () => {
      const { controller, authService, res, response, req } = setup();
      authService.refresh.mockRejectedValueOnce(new Error('invalid'));
      await expect(controller.refresh(req(), {}, response)).rejects.toThrow('invalid');
      expect(res.cookie).not.toHaveBeenCalled();
    });
  });

  describe('logout', () => {
    it('révoque le refresh token du cookie puis efface les cookies', async () => {
      const { controller, authService, res, response, req } = setup();
      const body = await controller.logout(req(`${ADMIN_REFRESH_COOKIE}=r1`), response);
      expect(authService.revokeRefreshToken).toHaveBeenCalledWith('r1');
      expect(res.clearCookie).toHaveBeenCalledTimes(2);
      expect(body).toEqual({ ok: true });
    });

    it('efface les cookies même si la révocation échoue (base en panne)', async () => {
      const { controller, authService, res, response, req } = setup();
      authService.revokeRefreshToken.mockRejectedValueOnce(new Error('db down'));
      await expect(
        controller.logout(req(`${ADMIN_REFRESH_COOKIE}=r1`), response),
      ).resolves.toEqual({ ok: true });
      expect(res.clearCookie).toHaveBeenCalledWith(ADMIN_ACCESS_COOKIE, { path: '/' });
      expect(res.clearCookie).toHaveBeenCalledWith(ADMIN_REFRESH_COOKIE, {
        path: '/api/auth/admin',
      });
    });

    it('sans cookie, révoque une chaîne vide', async () => {
      const { controller, authService, response, req } = setup();
      await controller.logout(req(), response);
      expect(authService.revokeRefreshToken).toHaveBeenCalledWith('');
    });
  });
});
