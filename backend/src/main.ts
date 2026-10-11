import { loadEnvFile } from 'node:process';
import { existsSync } from 'node:fs';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
// `import * as`, PAS un import par défaut — et ce n'est pas un détail de style.
//
// Ce tsconfig a `allowSyntheticDefaultImports: true` mais PAS `esModuleInterop`.
// La combinaison est un mensonge de type : TypeScript ACCEPTE
// `import compression from 'compression'` à la compilation, mais n'émet aucun
// helper d'interop — le JS produit appelle `compression_1.default()`, et
// `compression` est un module CommonJS pur dont `.default` vaut `undefined`.
// Résultat mesuré : « TypeError: (0, compression_1.default) is not a function »
// au bootstrap, l'API ne démarre plus DU TOUT. `tsc --noEmit` et les 400+ tests
// jest passaient tous ; seul le boot smoke de la CI l'a vu.
//
// `helmet` survit à la même écriture uniquement parce que helmet v7 pose
// lui-même `module.exports.default` — ce n'est pas une règle générale, c'est une
// politesse de ce paquet-là. Pour tout module CJS, on écrit `import * as`,
// comme `express` juste en dessous.
import * as compression from 'compression';
import * as express from 'express';

import { AppModule } from './app.module';
import { validateAccountDeletionEnvironment } from './common/account-deletion-env';
import { validateCompetitionReadinessEnvironment } from './common/competition-readiness-env';
import { resolveCorsOrigins } from './common/cors-origins';
import { GlobalExceptionFilter } from './common/filters/http-exception.filter';

async function bootstrap() {
  // Only load .env when the file is present — in prod Docker, env is injected
  // by the container runtime and there is no .env file on disk.
  if (existsSync('.env')) {
    loadEnvFile('.env');
  }
  validateAccountDeletionEnvironment();
  validateCompetitionReadinessEnvironment();
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api');

  // The API is deployed behind exactly one Nginx proxy. Without this setting,
  // Express sees the proxy address for every request and rate limiting groups
  // all users into the same bucket. Keep the hop count explicit so a spoofed
  // X-Forwarded-For header from an untrusted network is not accepted.
  const trustProxyHops = Number(
    process.env.KPB_TRUST_PROXY_HOPS ??
      (process.env.NODE_ENV === 'production' ? 1 : 0),
  );
  if (!Number.isInteger(trustProxyHops) || trustProxyHops < 0 || trustProxyHops > 3) {
    throw new Error('KPB_TRUST_PROXY_HOPS must be an integer between 0 and 3.');
  }
  (app.getHttpAdapter().getInstance() as express.Application).set(
    'trust proxy',
    trustProxyHops,
  );

  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  // TST-T13: gzip JSON above the default threshold (~1 KB). The uncompressed
  // catalog is ~721 KB; gzip brings it to ~46 KB. Verify locally with
  // `scripts/delivery-gate.sh` after a backend deploy — do not run it here.
  app.use(compression());

  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true, limit: '1mb' }));

  // ── Validation ─────────────────────────────────────────────────────────────
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // ── Global exception filter ─────────────────────────────────────────────
  app.useGlobalFilters(new GlobalExceptionFilter());

  // ── CORS ────────────────────────────────────────────────────────────────────
  app.enableCors({
    origin: resolveCorsOrigins(),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type',
      'Authorization',
      'Accept',
      'Idempotency-Key',
      'If-Match',
      'X-Request-Id',
    ],
    maxAge: 86400, // 24h preflight cache
  });

  // Run onModuleDestroy hooks (Prisma $disconnect, cron teardown) on SIGTERM/SIGINT
  // so redeploys drain in-flight work instead of being killed mid-request.
  app.enableShutdownHooks();

  const port = Number(process.env.PORT ?? 4000);
  await app.listen(port);
}

// Filet de sécurité : sans ce handler, une promesse lancée par `void` qui
// rejette (bug dans une tâche de fond) arrête tout le process Node et coupe
// toutes les requêtes en cours. On journalise au lieu de mourir.
process.on('unhandledRejection', (reason) => {
  console.error(
    'Unhandled promise rejection',
    reason instanceof Error ? (reason.stack ?? reason.message) : reason,
  );
});

bootstrap().catch((error) => {
  // A boot failure (port in use, misconfigured module) must exit non-zero with a
  // clear log, not surface as an unhandled promise rejection.
  console.error('Fatal: application failed to start', error);
  process.exit(1);
});
