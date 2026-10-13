import { CallHandler, ExecutionContext, Logger } from '@nestjs/common';
import { lastValueFrom, of } from 'rxjs';

import { PrismaService } from '../prisma/prisma.service';
import { AppBuildInterceptor } from './app-build.interceptor';
import { AppBuildTrackerService } from './app-build-tracker.service';

function httpContext(request: unknown): ExecutionContext {
  return {
    getType: () => 'http',
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

function handlerReturning(body: unknown) {
  const handle = jest.fn(() => of(body));
  return { handler: { handle } as CallHandler, handle };
}

describe('AppBuildInterceptor', () => {
  let record: jest.Mock;
  let interceptor: AppBuildInterceptor;
  let debug: jest.SpyInstance;

  beforeEach(() => {
    record = jest.fn().mockReturnValue(true);
    interceptor = new AppBuildInterceptor({
      record,
    } as unknown as AppBuildTrackerService);
    debug = jest.spyOn(Logger.prototype, 'debug').mockImplementation(() => {});
  });

  afterEach(() => {
    debug.mockRestore();
  });

  it('note la build d’une requête élève authentifiée, et rend la réponse intacte', async () => {
    const body = { items: [1, 2, 3] };
    const { handler, handle } = handlerReturning(body);
    const request = {
      headers: { 'x-kpb-app-version': '2.3.0', 'x-kpb-app-build': '56' },
      studentUser: { id: 'profile-1' },
    };

    const result = await lastValueFrom(
      interceptor.intercept(httpContext(request), handler),
    );

    expect(result).toBe(body);
    expect(handle).toHaveBeenCalledTimes(1);
    expect(record).toHaveBeenCalledWith('profile-1', {
      version: '2.3.0',
      build: 56,
    });
  });

  it('une build 53 (aucun en-tête) est notée « inconnue », pas refusée', async () => {
    const { handler } = handlerReturning('ok');
    const request = { headers: {}, studentUser: { id: 'profile-53' } };

    await expect(
      lastValueFrom(interceptor.intercept(httpContext(request), handler)),
    ).resolves.toBe('ok');
    expect(record).toHaveBeenCalledWith('profile-53', {
      version: null,
      build: null,
    });
  });

  it('des en-têtes illisibles ne font pas échouer la requête', async () => {
    const { handler } = handlerReturning('ok');
    const request = {
      headers: { 'x-kpb-app-version': 'x'.repeat(500), 'x-kpb-app-build': '-1' },
      studentUser: { id: 'profile-1' },
    };

    await expect(
      lastValueFrom(interceptor.intercept(httpContext(request), handler)),
    ).resolves.toBe('ok');
    expect(record).toHaveBeenCalledWith('profile-1', {
      version: null,
      build: null,
    });
  });

  it.each([
    ['route publique', { headers: { 'x-kpb-app-build': '56' } }],
    [
      'back-office',
      { headers: { 'x-kpb-app-build': '56' }, adminUser: { id: 'admin-1' } },
    ],
    ['identifiant vide', { headers: {}, studentUser: { id: '' } }],
    ['identifiant non textuel', { headers: {}, studentUser: { id: 42 } }],
  ])('ne note rien hors session élève (%s)', async (_label, request) => {
    const { handler, handle } = handlerReturning('ok');
    await lastValueFrom(interceptor.intercept(httpContext(request), handler));
    expect(record).not.toHaveBeenCalled();
    expect(handle).toHaveBeenCalledTimes(1);
  });

  it('ignore les contextes non HTTP (WebSocket)', () => {
    const { handler, handle } = handlerReturning('ok');
    const context = {
      getType: () => 'ws',
      switchToHttp: () => {
        throw new Error('not http');
      },
    } as unknown as ExecutionContext;

    interceptor.intercept(context, handler);
    expect(record).not.toHaveBeenCalled();
    expect(handle).toHaveBeenCalledTimes(1);
  });

  it('avec le vrai suivi, une base qui ne répond pas ne retarde pas la réponse', async () => {
    const hanging = jest.fn(() => new Promise<never>(() => {}));
    const realInterceptor = new AppBuildInterceptor(
      new AppBuildTrackerService({
        isEnabled: true,
        execute: hanging,
      } as unknown as PrismaService),
    );
    const { handler } = handlerReturning('ok');
    const request = {
      headers: { 'x-kpb-app-build': '56' },
      studentUser: { id: 'profile-1' },
    };

    await expect(
      lastValueFrom(realInterceptor.intercept(httpContext(request), handler)),
    ).resolves.toBe('ok');
    expect(hanging).toHaveBeenCalledTimes(1);
  });

  it('une panne du suivi ne coûte jamais la requête', async () => {
    record.mockImplementation(() => {
      throw new Error('boom');
    });
    const { handler } = handlerReturning('ok');
    const request = { headers: {}, studentUser: { id: 'profile-1' } };

    await expect(
      lastValueFrom(interceptor.intercept(httpContext(request), handler)),
    ).resolves.toBe('ok');
    expect(debug).toHaveBeenCalledTimes(1);
  });
});
