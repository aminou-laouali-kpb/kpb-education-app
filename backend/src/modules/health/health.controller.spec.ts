import { ServiceUnavailableException } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';
import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { AntivirusService } from '../storage/antivirus.service';
import { HealthController } from './health.controller';

function makeController(
  prisma: PrismaService,
  llm: Pick<LlmService, 'isConfigured'> = { isConfigured: false },
  push: Pick<PushSenderService, 'isConfigured'> &
    Partial<Pick<PushSenderService, 'providers'>> = { isConfigured: false },
  antivirus: Pick<AntivirusService, 'isEnabled' | 'selfTest'> = {
    isEnabled: false,
    selfTest: async () => false,
  },
) {
  return new HealthController(
    prisma,
    llm as LlmService,
    {
      providers: { fcm: false, oneSignal: false },
      ...push,
    } as PushSenderService,
    antivirus as AntivirusService,
  );
}

describe('HealthController', () => {
  const previousBuildSha = process.env.KPB_BUILD_SHA;
  const previousGroqKey = process.env.GROQ_API_KEY;

  afterEach(() => {
    if (previousBuildSha === undefined) {
      delete process.env.KPB_BUILD_SHA;
    } else {
      process.env.KPB_BUILD_SHA = previousBuildSha;
    }
    if (previousGroqKey === undefined) {
      delete process.env.GROQ_API_KEY;
    } else {
      process.env.GROQ_API_KEY = previousGroqKey;
    }
  });

  it('reports live without requiring the database', () => {
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    expect(makeController(prisma).live().status).toBe('live');
  });

  it('reports ready only when PostgreSQL can be queried', async () => {
    const prisma = {
      isReady: jest.fn().mockResolvedValue(true),
    } as unknown as PrismaService;
    await expect(makeController(prisma).ready()).resolves.toMatchObject({
      status: 'ready',
    });
  });

  it('returns 503 when PostgreSQL is unavailable', async () => {
    const prisma = {
      isReady: jest.fn().mockResolvedValue(false),
    } as unknown as PrismaService;
    await expect(makeController(prisma).ready()).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('exposes ai.configured as a boolean and never the provider key', async () => {
    delete process.env.GROQ_API_KEY;
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    const body = await makeController(prisma, { isConfigured: true }).check();
    expect(body.ai).toEqual({ configured: true });
    expect(JSON.stringify(body)).not.toMatch(/gsk_|GROQ_API_KEY/i);

    const off = await makeController(prisma, { isConfigured: false }).check();
    expect(off.ai).toEqual({ configured: false });
  });

  // Le push se désactive EXACTEMENT comme l'IA — par une variable absente — et
  // rien ne le disait. `PushSenderService` se dégrade en no-op journalisé :
  // le fil d'actualité s'écrit, le push ne part pas, et personne ne s'en aperçoit.
  // C'est la forme d'échec qui a envoyé la build 50 sans PostHog.
  it('expose push.configured, et jamais la clé REST', async () => {
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;

    const on = await makeController(
      prisma,
      { isConfigured: false },
      { isConfigured: true, providers: { fcm: true, oneSignal: false } },
    ).check();
    expect(on.push).toEqual({ configured: true, fcm: true, oneSignal: false });

    const off = await makeController(prisma).check();
    expect(off.push).toEqual({
      configured: false,
      fcm: false,
      oneSignal: false,
    });

    // Booléens SEULS : ni les clés, ni leur longueur, ni l'App ID sur une
    // route non authentifiée.
    process.env.ONESIGNAL_REST_API_KEY = 'os_v2_supersecret_value';
    process.env.FCM_SERVICE_ACCOUNT_JSON =
      '{"project_id":"p","client_email":"svc@p.iam","private_key":"fcmsupersecret"}';
    const body = await makeController(
      prisma,
      { isConfigured: false },
      { isConfigured: true, providers: { fcm: true, oneSignal: true } },
    ).check();
    expect(JSON.stringify(body)).not.toMatch(
      /os_v2_|ONESIGNAL_REST_API_KEY|supersecret|svc@p\.iam/i,
    );
    delete process.env.ONESIGNAL_REST_API_KEY;
    delete process.env.FCM_SERVICE_ACCOUNT_JSON;
  });

  // L'IA et le push sont deux capacités indépendantes : les lire d'un seul
  // booléen ferait passer une panne de l'une pour la santé de l'autre.
  it('rapporte l\'IA et le push indépendamment', async () => {
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    const body = await makeController(
      prisma,
      { isConfigured: true },
      { isConfigured: false },
    ).check();
    expect(body.ai).toEqual({ configured: true });
    expect(body.push).toEqual({
      configured: false,
      fcm: false,
      oneSignal: false,
    });
  });

  // ── L'écart qui a coûté vingt jours ──────────────────────────────────────
  //
  // Le 15/08/2026, clamd est mort dans `kpb_clamav`. `CLAMAV_HOST` est resté
  // valide, le conteneur est resté « Up » (freshclam tournait toujours), et
  // `AntivirusService` étant FAIL-CLOSED, tout envoi de fichier repartait en
  // 503 — documents de dossier, avatars, pièces du Success Lab. Personne ne
  // l'a su avant le 04/09.
  //
  // Un seul booléen `configured` aurait annoncé « ✅ » pendant toute la panne.
  // C'est précisément ce que ce test interdit.
  it('distingue « configuré » de « analyse vraiment » pour l\'antivirus', async () => {
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;

    const dead = await makeController(
      prisma,
      { isConfigured: false },
      { isConfigured: false },
      { isEnabled: true, selfTest: async () => false },
    ).check();
    expect(dead.antivirus).toEqual({ configured: true, scanning: false });

    const alive = await makeController(
      prisma,
      { isConfigured: false },
      { isConfigured: false },
      { isEnabled: true, selfTest: async () => true },
    ).check();
    expect(alive.antivirus).toEqual({ configured: true, scanning: true });
  });

  // Une sonde qui échoue est un RÉSULTAT, pas une panne de la route : /health
  // doit répondre 200 surtout quand une dépendance est à terre.
  it('répond quand même si la sonde antivirus rejette', async () => {
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    const body = await makeController(prisma, undefined, undefined, {
      isEnabled: true,
      selfTest: async () => {
        throw new Error('socket explosé');
      },
    })
      .check()
      .catch(() => null);
    expect(body).not.toBeNull();
  });

  // The preflight compares this sha to `git rev-parse --short=12 <ref>`. An
  // empty string would compare equal to nothing and to everything depending on
  // the shell quoting on the other side, and would read as "no answer" rather
  // than "no build stamp" — so an unstamped build must SAY so.
  it('reports an unstamped build as "unknown", never as an empty string', () => {
    delete process.env.KPB_BUILD_SHA;
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    expect(makeController(prisma).version().sha).toBe('unknown');

    process.env.KPB_BUILD_SHA = '   ';
    expect(makeController(prisma).version().sha).toBe('unknown');
  });

  it('shortens the build sha to 12 characters and exposes nothing else', () => {
    process.env.KPB_BUILD_SHA = '0bb0d16098256a35dceb6c6b1a5506180fb99a97';
    const prisma = { isReady: jest.fn() } as unknown as PrismaService;
    const version = makeController(prisma).version();

    expect(version.sha).toBe('0bb0d1609825');
    expect(Object.keys(version).sort()).toEqual(['sha', 'startedAt']);
    expect(new Date(version.startedAt).toISOString()).toBe(version.startedAt);
  });
});
