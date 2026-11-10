import type { INestApplication } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import {
  getOptionsToken,
  ThrottlerGuard,
  ThrottlerModule,
  type ThrottlerOptions,
} from '@nestjs/throttler';
import type { Application } from 'express';

import { AppModule } from '../app.module';
import { AuthController } from '../modules/auth/auth.controller';
import { AuthService } from '../modules/auth/auth.service';
import { AppConfigController } from '../modules/config/app-config.controller';
import { EefSearchController } from '../modules/etudes-en-france/search/eef-search.controller';
import { EefSearchService } from '../modules/etudes-en-france/search/eef-search.service';
import { KayakController } from '../modules/kayak/kayak.controller';
import { KayakService } from '../modules/kayak/kayak.service';
import { AdminAuthGuard } from './guards/admin-auth.guard';
import {
  buildThrottlerOptions,
  GLOBAL_THROTTLER,
  PRODUCTION_READ_LIMIT,
  PRODUCTION_WRITE_LIMIT,
  productionLimit,
} from './throttler-options';

/**
 * Le défaut mesuré le 02/10/2026 : un second limiteur nommé `auth` (10/min),
 * déclaré dans `ThrottlerModule.forRoot`, s'appliquait à TOUTES les routes —
 * `@nestjs/throttler` 6.x applique chaque limiteur déclaré partout et `@Throttle`
 * n'en change que la valeur. `GET /config/app` et la recherche publique
 * `GET /etudes-en-france/search` recevaient un 429 à la 11e requête de la minute.
 *
 * Ces tests passent par le VRAI `ThrottlerGuard`, les VRAIS contrôleurs et la
 * VRAIE configuration (`buildThrottlerOptions`, celle qu'`AppModule` consomme —
 * le dernier bloc le prouve). Rien n'est simulé de la limitation elle-même : un
 * test qui moquerait le garde ne verrait pas le défaut, qui vit dans la
 * résolution des limiteurs.
 */

const authService = { login: jest.fn(), refresh: jest.fn() };
const eefSearchService = { search: jest.fn() };
const kayakService = { getRoutes: jest.fn(), getCalendar: jest.fn() };

async function boot(options: {
  nodeEnv: string;
  trustProxyHops?: number;
}): Promise<{ app: INestApplication; base: string }> {
  const moduleRef = await Test.createTestingModule({
    imports: [ThrottlerModule.forRoot(buildThrottlerOptions(options.nodeEnv))],
    controllers: [
      AppConfigController,
      EefSearchController,
      AuthController,
      KayakController,
    ],
    providers: [
      { provide: APP_GUARD, useClass: ThrottlerGuard },
      { provide: AuthService, useValue: authService },
      { provide: EefSearchService, useValue: eefSearchService },
      { provide: KayakService, useValue: kayakService },
    ],
  })
    // `session` exige une session admin ; la limitation n'a rien à y voir.
    .overrideGuard(AdminAuthGuard)
    .useValue({ canActivate: () => true })
    .compile();

  const app = moduleRef.createNestApplication();
  // Même réglage que `main.ts` : sans lui, l'IP vue est celle du proxy.
  (app.getHttpAdapter().getInstance() as Application).set(
    'trust proxy',
    options.trustProxyHops ?? 0,
  );
  await app.listen(0, '127.0.0.1');
  const { port } = app.getHttpServer().address() as { port: number };
  return { app, base: `http://127.0.0.1:${port}` };
}

const login = (base: string, clientIp?: string) =>
  fetch(`${base}/auth/admin/login`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(clientIp ? { 'x-forwarded-for': clientIp } : {}),
    },
    body: JSON.stringify({ email: 'admin@kpb.test', password: 'x' }),
  });

const statuses = async (n: number, call: () => Promise<Response>) => {
  const out: number[] = [];
  for (let i = 0; i < n; i += 1) out.push((await call()).status);
  return out;
};

beforeEach(() => {
  jest.clearAllMocks();
  authService.login.mockResolvedValue({
    token: 'jwt',
    refreshToken: 'refresh',
    user: { id: 'admin-1' },
  });
  eefSearchService.search.mockResolvedValue({ items: [] });
  kayakService.getRoutes.mockResolvedValue({ routes: [] });
  kayakService.getCalendar.mockResolvedValue({ days: [] });
});

describe('configuration des limiteurs', () => {
  it('déclare UN seul limiteur, « global » — un second s’appliquerait à toutes les routes', () => {
    // Si ce test rougit parce qu'on a ajouté un limiteur : il ne protège PAS la
    // route qui le nomme dans `@Throttle`, il plafonne chaque route de l'API.
    // Surcharger `global` sur la route sensible (voir `ADMIN_LOGIN_THROTTLE`).
    expect(buildThrottlerOptions('production').map((t) => t.name)).toEqual([
      GLOBAL_THROTTLER,
    ]);
    expect(buildThrottlerOptions('development').map((t) => t.name)).toEqual([
      GLOBAL_THROTTLER,
    ]);
  });

  it('limite globale : 300 lectures et 60 écritures par minute en production, 600 ailleurs', () => {
    expect(buildThrottlerOptions('production')[0]).toMatchObject({
      limit: productionLimit,
      ttl: 60_000,
    });
    expect(buildThrottlerOptions('development')[0]).toMatchObject({ limit: 600, ttl: 60_000 });
    expect(buildThrottlerOptions(undefined)[0]).toMatchObject({ limit: 600 });
  });

  it('une lecture a le plafond haut, une écriture le plafond bas', () => {
    const context = (method?: string) =>
      ({
        switchToHttp: () => ({ getRequest: () => ({ method }) }),
      }) as unknown as Parameters<typeof productionLimit>[0];

    expect(PRODUCTION_READ_LIMIT).toBe(300);
    expect(PRODUCTION_WRITE_LIMIT).toBe(60);
    expect(productionLimit(context('GET'))).toBe(300);
    expect(productionLimit(context('head'))).toBe(300);
    for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
      expect(productionLimit(context(method))).toBe(60);
    }
    // Méthode inconnue ou absente : le plafond prudent.
    expect(productionLimit(context(undefined))).toBe(60);
  });
});

describe.each(['production', 'development'])('HTTP — NODE_ENV=%s', (nodeEnv) => {
  let app: INestApplication;
  let base: string;

  beforeEach(async () => {
    ({ app, base } = await boot({ nodeEnv }));
  });
  afterEach(() => app.close());

  it('GET /config/app (sans @Throttle) n’est PAS plafonné à 10/min', async () => {
    const results = await statuses(30, () => fetch(`${base}/config/app`));

    expect(results.filter((s) => s !== 200)).toEqual([]);
  });

  it('GET /etudes-en-france/search (publique) tient 30 requêtes de filtres sans 429', async () => {
    const results = await statuses(30, () =>
      fetch(`${base}/etudes-en-france/search?cycle=master&q=droit`),
    );

    expect(results.filter((s) => s !== 200)).toEqual([]);
    expect(eefSearchService.search).toHaveBeenCalledTimes(30);
  });

  it('une route sans @Throttle ne porte aucun en-tête du limiteur « auth »', async () => {
    const response = await fetch(`${base}/config/app`);

    const names = [...response.headers.keys()];
    expect(names).toContain('x-ratelimit-limit-global');
    expect(names.filter((name) => name.endsWith('-auth'))).toEqual([]);
  });

  it('la connexion admin reste plafonnée à 10/min : 10 passent, la 11e est refusée', async () => {
    const results = await statuses(11, () => login(base));

    expect(results.slice(0, 10)).toEqual(Array(10).fill(201));
    expect(results[10]).toBe(429);
    // La 11e n'a pas atteint le service : le mot de passe n'est plus testé.
    expect(authService.login).toHaveBeenCalledTimes(10);
  });

  it('le plafond de connexion n’est pas hérité par les autres routes d’AuthController', async () => {
    const results = await statuses(15, () =>
      fetch(`${base}/auth/admin/logout`, { method: 'POST' }),
    );

    expect(results.filter((s) => s !== 201)).toEqual([]);
  });

  it('les compteurs sont par route : épuiser la connexion ne coupe pas /config/app', async () => {
    await statuses(11, () => login(base));

    expect((await fetch(`${base}/config/app`)).status).toBe(200);
  });
});

describe('limite globale — production', () => {
  let app: INestApplication;
  let base: string;

  beforeEach(async () => {
    ({ app, base } = await boot({ nodeEnv: 'production' }));
  });
  afterEach(() => app.close());

  // Audit avant la 59 : les opérateurs mobiles partagent une adresse IP entre
  // des milliers d'abonnés. À 60 lectures par minute, une minute d'affluence
  // faisait refuser `/config/app` : l'app retombait sur ses replis.
  it('une lecture tient 300 requêtes par minute et par IP, la 301e est refusée', async () => {
    const results = await statuses(301, () => fetch(`${base}/config/app`));

    expect(results.slice(0, 300).filter((s) => s !== 200)).toEqual([]);
    expect(results[300]).toBe(429);
  });

  // Une lecture publique qui peut appeler un service payant ne profite PAS du
  // plafond des lectures : sans le `@Throttle` de KayakController, ce test
  // rougit à la 61e requête acceptée.
  it('les prix des vols restent à 60 par minute et par IP, la 61e est refusée', async () => {
    const results = await statuses(61, () =>
      fetch(`${base}/flights/routes?origin=NIM&destination=CDG`),
    );

    expect(results.slice(0, 60).filter((s) => s !== 200)).toEqual([]);
    expect(results[60]).toBe(429);
    expect(kayakService.getRoutes).toHaveBeenCalledTimes(60);
  });

  it('une écriture reste à 60 par minute et par IP, la 61e est refusée', async () => {
    const results = await statuses(61, () =>
      fetch(`${base}/auth/admin/logout`, { method: 'POST' }),
    );

    expect(results.slice(0, 60).filter((s) => s !== 201)).toEqual([]);
    expect(results[60]).toBe(429);
  });
});

describe('IP vue par le limiteur derrière le proxy', () => {
  // `getTracker` renvoie `req.ip` : derrière Traefik, tout dépend de
  // `trust proxy`. Ces deux cas fixent ce que `KPB_TRUST_PROXY_HOPS` change.
  it('avec 1 saut de confiance (production), chaque client a son propre compteur', async () => {
    const { app, base } = await boot({ nodeEnv: 'production', trustProxyHops: 1 });
    try {
      await statuses(10, () => login(base, '203.0.113.1'));
      expect((await login(base, '203.0.113.1')).status).toBe(429);

      expect((await login(base, '203.0.113.2')).status).toBe(201);
    } finally {
      await app.close();
    }
  });

  it('sans trust proxy, tous les clients partagent le compteur du proxy', async () => {
    const { app, base } = await boot({ nodeEnv: 'production', trustProxyHops: 0 });
    try {
      await statuses(10, () => login(base, '203.0.113.1'));

      // Un AUTRE client, mais `X-Forwarded-For` est ignoré : même compteur.
      expect((await login(base, '203.0.113.2')).status).toBe(429);
    } finally {
      await app.close();
    }
  });
});

describe('AppModule', () => {
  it('consomme buildThrottlerOptions — la configuration testée ci-dessus est celle de l’application', () => {
    const imports = Reflect.getMetadata('imports', AppModule) as unknown[];
    const throttler = imports.find(
      (entry) =>
        typeof entry === 'object' &&
        entry !== null &&
        (entry as { module?: unknown }).module === ThrottlerModule,
    ) as { providers: Array<{ provide: unknown; useValue?: unknown }> } | undefined;

    expect(throttler).toBeDefined();
    const options = throttler!.providers.find(
      (provider) => provider.provide === getOptionsToken(),
    )?.useValue as ThrottlerOptions[];

    expect(options).toEqual(buildThrottlerOptions());
  });
});
