import { randomUUID } from 'node:crypto';

import { PrismaClient } from '@prisma/client';

import type { CasesService } from '../cases/cases.service';
import type { PrismaService } from '../prisma/prisma.service';
import { ProfilesService } from '../profiles/profiles.service';
import type { StorageService } from '../storage/storage.service';
import { CampaignExecutorService } from './campaign-executor.service';
import type { CampaignMailService } from './campaign-mail.service';
import { NotificationsService } from './notifications.service';
import { PromotionsUnsubscribeController } from './promotions-unsubscribe.controller';
import { promotionsUnsubscribeToken } from './promotions-unsubscribe';
import type { PushSenderService } from './push-sender.service';

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true' ? describe : describe.skip;

/**
 * Correctifs 57 (XC-06), contre un vrai Postgres : la colonne `purpose` vaut
 * `promotional` par défaut, l'aperçu compte ce qui partira RÉELLEMENT, l'envoi
 * ne touche que les comptes qui y ont droit, le consentement se pose (et
 * s'horodate) par le PATCH du profil, et le lien de désinscription le retire.
 */
describePostgres('Campagnes : finalité et consentement — PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 10);
  const country = `Pays-${sfx}`;
  const id = (name: string) => `it-cc-${name}-${sfx}`;
  const prismaService = {
    isEnabled: true,
    execute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma),
    tryExecute: async <T>(op: (c: PrismaClient) => Promise<T>) => op(prisma).catch(() => null),
  } as unknown as PrismaService;

  const pushedTo: string[] = [];
  const mailedTo: string[] = [];
  const push = {
    isConfigured: true,
    sendToUser: async (userId: string) => {
      pushedTo.push(userId);
      return true;
    },
  } as unknown as PushSenderService;
  const mail = {
    isEnabled: true,
    send: async (to: string) => {
      mailedTo.push(to);
      return true;
    },
  } as unknown as CampaignMailService;
  const executor = new CampaignExecutorService(prismaService, push, mail);
  const notifications = new NotificationsService({} as CasesService, prismaService, executor);
  const profiles = new ProfilesService(prismaService, {} as StorageService);

  const previousSecret = process.env.KPB_JWT_SECRET;
  let templateId = '';
  const campaignIds: string[] = [];

  beforeAll(async () => {
    process.env.KPB_JWT_SECRET = 'jwt-secret-it';
    const people: Array<[string, Record<string, unknown>]> = [
      ['adult', { birthDate: new Date('2000-01-01T00:00:00Z') }],
      ['nopush', { disabledNotificationTypes: ['kpb_promotions'] }],
      ['minor', { birthDate: new Date('2011-01-01T00:00:00Z') }],
      ['minorok', { birthDate: new Date('2011-01-01T00:00:00Z'), guardianConsentedAt: new Date() }],
    ];
    for (const [name, extra] of people) {
      await prisma.userProfile.create({
        data: {
          id: id(name),
          accountType: 'student',
          preferredLanguage: 'fr',
          fullName: `Test ${name}`,
          email: `${id(name)}@example.test`,
          phone: '+22900000000',
          countryOfResidence: country,
          fieldIds: [],
          targetCountryIds: [],
          ...extra,
        },
      });
    }
    const template = await prisma.notificationTemplate.create({
      data: {
        name: `it-cc-${sfx}`,
        titleFr: 'Offre',
        titleEn: 'Offer',
        bodyFr: 'Une offre KPB',
        bodyEn: 'A KPB offer',
        channels: ['push', 'email'],
      },
    });
    templateId = template.id;
  });

  afterAll(async () => {
    try {
      await prisma.notificationDelivery.deleteMany({ where: { campaignId: { in: campaignIds } } });
      await prisma.notificationCampaign.deleteMany({ where: { id: { in: campaignIds } } });
      await prisma.notificationTemplate.deleteMany({ where: { id: templateId } });
      await prisma.userProfile.deleteMany({ where: { id: { startsWith: 'it-cc-' }, countryOfResidence: country } });
    } finally {
      if (previousSecret === undefined) delete process.env.KPB_JWT_SECRET;
      else process.env.KPB_JWT_SECRET = previousSecret;
      await prisma.$disconnect();
    }
  });

  it('la colonne purpose vaut promotional par défaut (migration additive)', async () => {
    const row = await prisma.notificationCampaign.create({
      data: {
        name: `it-cc-default-${sfx}`,
        audienceType: 'country',
        filters: { countryId: country },
        channels: ['push'],
        status: 'draft',
      },
    });
    campaignIds.push(row.id);
    expect(row.purpose).toBe('promotional');
    const profile = await prisma.userProfile.findUniqueOrThrow({ where: { id: id('adult') } });
    expect(profile.promotionsEmailOptIn).toBe(false);
    expect(profile.promotionsEmailConsentedAt).toBeNull();
  });

  it('le consentement se pose par le PATCH du profil, horodaté une seule fois', async () => {
    for (const name of ['adult', 'minor', 'minorok']) {
      await profiles.updateMe({ promotionsEmailOptIn: true }, id(name));
    }
    const first = await prisma.userProfile.findUniqueOrThrow({ where: { id: id('adult') } });
    expect(first.promotionsEmailOptIn).toBe(true);
    expect(first.promotionsEmailConsentedAt).toBeInstanceOf(Date);
    await profiles.updateMe({ promotionsEmailOptIn: true }, id('adult'));
    const again = await prisma.userProfile.findUniqueOrThrow({ where: { id: id('adult') } });
    expect(again.promotionsEmailConsentedAt).toEqual(first.promotionsEmailConsentedAt);
    expect((await profiles.getMe(id('adult'))) as Record<string, unknown>).toMatchObject({
      promotionsEmailOptIn: true,
    });
  });

  it('l’aperçu compte ce qui partira réellement, canal par canal', async () => {
    const promo = await notifications.previewAudience({
      audienceType: 'country',
      filters: { countryId: country },
      channels: ['push', 'email'],
    });
    expect(promo).toMatchObject({
      purpose: 'promotional',
      recipients: 4,
      // « nopush » n'a plus aucun canal ouvert (push coupé, pas de consentement).
      reachable: 3,
      byChannel: [
        { channel: 'push', eligible: 3, blocked: { push_opted_out: 1 } },
        {
          channel: 'email',
          eligible: 2,
          blocked: { email_no_consent: 1, email_minor_without_guardian: 1 },
        },
      ],
    });
    const info = await notifications.previewAudience({
      audienceType: 'country',
      filters: { countryId: country },
      channels: ['email'],
      purpose: 'informational',
    });
    expect(info.byChannel).toEqual([{ channel: 'email', eligible: 4, blocked: {} }]);
  });

  it('l’envoi promotionnel ne touche que les comptes qui y ont droit', async () => {
    const created = await notifications.createCampaign({
      name: `it-cc-send-${sfx}`,
      templateId,
      audienceType: 'country',
      filters: { countryId: country },
      channels: ['push', 'email'],
    });
    campaignIds.push(created.id);
    expect(created.purpose).toBe('promotional');
    expect(pushedTo.sort()).toEqual([id('adult'), id('minor'), id('minorok')].sort());
    expect(mailedTo.sort()).toEqual([`${id('adult')}@example.test`, `${id('minorok')}@example.test`].sort());
    const deliveries = await prisma.notificationDelivery.findMany({ where: { campaignId: created.id } });
    expect(deliveries).toHaveLength(5);
    expect(deliveries.every((d) => d.status === 'delivered')).toBe(true);
  });

  it('le lien de désinscription retire le consentement, et l’envoi suivant le respecte', async () => {
    const ctrl = new PromotionsUnsubscribeController(prismaService);
    const token = promotionsUnsubscribeToken(id('adult'), 'jwt-secret-it');
    expect(await ctrl.unsubscribe(id('adult'), token)).toContain('Désinscription faite');
    const after = await prisma.userProfile.findUniqueOrThrow({ where: { id: id('adult') } });
    expect(after.promotionsEmailOptIn).toBe(false);

    mailedTo.length = 0;
    const created = await notifications.createCampaign({
      name: `it-cc-send2-${sfx}`,
      templateId,
      audienceType: 'country',
      filters: { countryId: country },
      channels: ['email'],
      purpose: 'promotional',
    });
    campaignIds.push(created.id);
    expect(mailedTo).toEqual([`${id('minorok')}@example.test`]);
  });
});
