import { CampaignExecutorService } from './campaign-executor.service';
import { CampaignMailService } from './campaign-mail.service';
import { PushSenderService } from './push-sender.service';
import { PrismaService } from '../prisma/prisma.service';

/**
 * L'exécuteur décide ce que l'admin affiche. Il n'avait aucun test, et il
 * peignait en vert des campagnes qui n'avaient rien livré : le 04/09/2026,
 * « Rentree Decalee » a trouvé 2 destinataires, en a livré 0, et s'est
 * affichée « terminée ».
 */
describe('CampaignExecutorService', () => {
  type Delivery = { channel: string; recipientId: string; status: string };

  function makeService(options: {
    channels: string[];
    template: Record<string, string> | null;
    pushOk?: boolean;
    recipients?: Array<{
      id: string;
      preferredLanguage: string;
      email?: string | null;
      disabledNotificationTypes?: string[];
      promotionsEmailOptIn?: boolean;
      promotionsPushOptIn?: boolean;
      birthDate?: Date | null;
      guardianConsentedAt?: Date | null;
    }>;
    audienceType?: string;
    filters?: Record<string, unknown>;
    route?: string | null;
    purpose?: string;
    mailEnabled?: boolean;
  }) {
    // Par défaut, deux comptes qui ont accepté le push promotionnel (la
    // finalité par défaut est `promotional`, qui exige cet opt-in).
    const recipients = options.recipients ?? [
      { id: 'u1', preferredLanguage: 'fr', promotionsPushOptIn: true },
      { id: 'u2', preferredLanguage: 'fr', promotionsPushOptIn: true },
    ];
    let deliveries: Delivery[] = [];
    const profileQueries: unknown[] = [];
    const campaign = {
      id: 'c1',
      templateId: options.template ? 't1' : null,
      audienceType: options.audienceType ?? 'all_users',
      filters: options.filters ?? {},
      channels: options.channels,
      linkedCaseId: null,
      route: options.route ?? null,
      purpose: options.purpose,
      status: 'sending',
    };
    let campaignStatus = campaign.status;

    const match = (where: Record<string, unknown>) => (d: Delivery) =>
      (!where.channel || d.channel === where.channel) &&
      (!where.status || d.status === where.status) &&
      (!where.recipientId || d.recipientId === where.recipientId);

    const client = {
      notificationCampaign: {
        findUnique: async () => campaign,
        update: async ({ data }: { data: { status: string } }) => {
          campaignStatus = data.status;
          return campaign;
        },
      },
      notificationTemplate: { findUnique: async () => options.template },
      userProfile: {
        findMany: async (args?: { where?: unknown }) => {
          profileQueries.push(args?.where);
          return recipients;
        },
      },
      notificationDelivery: {
        createMany: async ({ data }: { data: Delivery[] }) => {
          deliveries = deliveries.concat(data);
          return { count: data.length };
        },
        updateMany: async ({
          where,
          data,
        }: {
          where: Record<string, unknown>;
          data: { status: string };
        }) => {
          const hit = deliveries.filter(match(where));
          hit.forEach((d) => (d.status = data.status));
          return { count: hit.length };
        },
        count: async ({ where }: { where?: Record<string, unknown> } = {}) =>
          deliveries.filter(match(where ?? {})).length,
      },
    };

    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
      tryExecute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;

    const pushData: Array<Record<string, unknown> | undefined> = [];
    const push = {
      isConfigured: true,
      sendToUser: async (
        userId: string,
        _title: string,
        _body: string,
        data?: Record<string, unknown>,
      ) => {
        pushData.push(data);
        pushedTo.push(userId);
        return options.pushOk ?? true;
      },
    } as unknown as PushSenderService;
    const mails: Array<{
      to: string;
      subject: string;
      text: string;
      options?: { headers?: Record<string, string> };
    }> = [];
    const mail = {
      isEnabled: options.mailEnabled ?? false,
      send: async (
        to: string,
        subject: string,
        text: string,
        opts?: { headers?: Record<string, string> },
      ) => {
        mails.push({ to, subject, text, options: opts });
        return true;
      },
    } as unknown as CampaignMailService;
    const pushedTo: string[] = [];

    return {
      service: new CampaignExecutorService(prisma, push, mail),
      deliveries: () => deliveries,
      status: () => campaignStatus,
      profileQueries: () => profileQueries,
      pushData: () => pushData,
      pushedTo: () => pushedTo,
      mails: () => mails,
    };
  }

  const TEMPLATE = {
    titleFr: 'Titre',
    titleEn: 'Title',
    bodyFr: 'Corps',
    bodyEn: 'Body',
  };

  it('marque la campagne « completed » quand au moins un push part', async () => {
    const h = makeService({ channels: ['push'], template: TEMPLATE });
    await h.service.execute('c1');
    expect(h.status()).toBe('completed');
    expect(h.deliveries().every((d) => d.status === 'delivered')).toBe(true);
  });

  // Une campagne « nouvelle bourse » ouvrait l'accueil au tap : l'élève devait
  // retrouver seul la bourse annoncée.
  it('transmet la route de la campagne au push, pour ouvrir le bon écran', async () => {
    const h = makeService({
      channels: ['push'],
      template: TEMPLATE,
      route: '/scholarships/abc',
    });
    await h.service.execute('c1');
    expect(h.pushData().every((d) => d?.route === '/scholarships/abc')).toBe(
      true,
    );
  });

  it('sans route, n’en invente pas (l’app ouvre l’accueil)', async () => {
    const h = makeService({ channels: ['push'], template: TEMPLATE });
    await h.service.execute('c1');
    expect(h.pushData().every((d) => d && !('route' in d))).toBe(true);
  });

  // Le défaut central : 2 destinataires, 0 livré, badge vert.
  it('marque « failed » quand tous les envois échouent', async () => {
    const h = makeService({
      channels: ['push'],
      template: TEMPLATE,
      pushOk: false,
    });
    await h.service.execute('c1');
    expect(h.status()).toBe('failed');
    expect(h.deliveries().every((d) => d.status === 'failed')).toBe(true);
  });

  // Sans modèle, les deux boucles d'envoi sont sautées : les livraisons
  // restaient « queued » à vie pendant que la campagne passait à « terminée ».
  // Or l'absence de modèle est le choix PAR DÉFAUT du formulaire admin.
  it('sans modèle, échoue franchement au lieu de laisser des envois en attente', async () => {
    const h = makeService({ channels: ['push'], template: null });
    await h.service.execute('c1');
    expect(h.deliveries().some((d) => d.status === 'queued')).toBe(false);
    expect(h.status()).toBe('failed');
  });

  // `in_app` est accepté partout et n'a aucune branche d'exécution.
  it('ne laisse pas les envois in_app en attente perpétuelle', async () => {
    const h = makeService({ channels: ['in_app'], template: TEMPLATE });
    await h.service.execute('c1');
    const inApp = h.deliveries().filter((d) => d.channel === 'in_app');
    expect(inApp.length).toBeGreaterThan(0);
    expect(inApp.every((d) => d.status === 'failed')).toBe(true);
  });

  // Une campagne partiellement livrée reste une campagne livrée.
  it('reste « completed » si une seule livraison réussit', async () => {
    let calls = 0;
    const h = makeService({ channels: ['push'], template: TEMPLATE });
    (
      h.service as unknown as { pushService: { sendToUser: () => unknown } }
    ).pushService.sendToUser = async () => ++calls === 1;
    await h.service.execute('c1');
    expect(h.status()).toBe('completed');
  });

  it('reste « completed » quand il n’y avait rien à envoyer', async () => {
    const h = makeService({
      channels: ['push'],
      template: TEMPLATE,
      recipients: [],
    });
    await h.service.execute('c1');
    expect(h.status()).toBe('completed');
  });

  // ── Un filtre manquant ne doit JAMAIS devenir une diffusion générale ─────
  //
  // `where: undefined` en Prisma ne veut pas dire « personne » : il veut dire
  // « aucun filtre », donc tous les comptes. `case_status`, `account_type` et
  // `country_of_residence` construisaient exactement ça, et `study_level`
  // retombait sur tous les étudiants. Tant que le DTO refusait ces audiences,
  // le chemin était injoignable ; les rendre sélectionnables le mettait à un
  // clic — un filtre oublié, et la campagne partait à toute la base.
  describe.each([
    ['case_status', {}],
    ['account_type', {}],
    ['country_of_residence', {}],
    ['study_level', {}],
    ['country', {}],
    ['single_user', {}],
    ['case_status', { status: '   ' }],
    ['study_level', { levels: [] }],
  ])('audience « %s » sans son filtre', (audienceType, filters) => {
    it('ne vise personne, et n’interroge jamais sans clause', async () => {
      const h = makeService({
        channels: ['push'],
        template: TEMPLATE,
        audienceType,
        filters: filters as Record<string, unknown>,
      });
      await h.service.execute('c1');

      // Aucune livraison créée : la campagne n'a atteint personne.
      expect(h.deliveries()).toEqual([]);
      // Et surtout : aucune requête profil sans clause `where`, qui aurait
      // ramené la totalité des comptes.
      expect(h.profileQueries()).not.toContainEqual(undefined);
    });
  });

  // Le pendant : avec son filtre, l'audience interroge bien AVEC une clause.
  it('une audience filtrée interroge avec sa clause', async () => {
    const h = makeService({
      channels: ['push'],
      template: TEMPLATE,
      audienceType: 'country_of_residence',
      filters: { countryCode: 'NE' },
    });
    await h.service.execute('c1');
    expect(h.profileQueries()).toContainEqual({ countryOfResidence: 'NE' });
  });

  // Les diffusions assumées restent possibles : leur nom le dit.
  it('all_users interroge sans clause, et c’est voulu', async () => {
    const h = makeService({
      channels: ['push'],
      template: TEMPLATE,
      audienceType: 'all_users',
    });
    await h.service.execute('c1');
    expect(h.deliveries().length).toBeGreaterThan(0);
  });

  // ── LIV-24 : les déclarants « Études en France » et l'exclusion des pays ──
  describe('audiences Études en France', () => {
    it('all_students_except_countries exclut les pays donnés, sans casse', async () => {
      const h = makeService({
        channels: ['push'],
        template: TEMPLATE,
        audienceType: 'all_students_except_countries',
        filters: { exceptCountries: ['Niger', 'NE'] },
      });
      await h.service.execute('c1');

      const where = h.profileQueries().at(-1) as Record<string, any>;
      expect(where.accountType).toBe('student');
      expect(where.NOT.OR).toEqual([
        { countryOfResidence: { equals: 'Niger', mode: 'insensitive' } },
        { countryOfResidence: { equals: 'NE', mode: 'insensitive' } },
      ]);
    });

    // Une exclusion illisible est « personne », JAMAIS « tous les étudiants ».
    it.each([
      ['absente', {}],
      ['vide', { exceptCountries: [] }],
      ['blanche', { exceptCountries: ['  '] }],
      ['illisible', { exceptCountries: 42 }],
    ])(
      'all_students_except_countries : exclusion %s → personne',
      async (_n, filters) => {
        const h = makeService({
          channels: ['push'],
          template: TEMPLATE,
          audienceType: 'all_students_except_countries',
          filters: filters as Record<string, unknown>,
        });
        await h.service.execute('c1');

        expect(h.deliveries()).toEqual([]);
        expect(h.profileQueries()).not.toContainEqual(undefined);
      },
    );

    it('le jeton eef_suspended suit KPB_EEF_SUSPENDED_COUNTRIES', async () => {
      const previous = process.env.KPB_EEF_SUSPENDED_COUNTRIES;
      process.env.KPB_EEF_SUSPENDED_COUNTRIES = 'Niger';
      try {
        const h = makeService({
          channels: ['push'],
          template: TEMPLATE,
          audienceType: 'all_students_except_countries',
          filters: { exceptCountries: ['eef_suspended'] },
        });
        await h.service.execute('c1');

        const where = h.profileQueries().at(-1) as Record<string, any>;
        expect(where.NOT.OR).toEqual([
          { countryOfResidence: { equals: 'Niger', mode: 'insensitive' } },
        ]);
      } finally {
        if (previous === undefined)
          delete process.env.KPB_EEF_SUSPENDED_COUNTRIES;
        else process.env.KPB_EEF_SUSPENDED_COUNTRIES = previous;
      }
    });

    // Le défaut de la relecture : une exclusion non vide qui ne désigne personne
    // (jeton mal écrit) était ignorée et l'envoi partait vers tous.
    it.each([
      ['all_students_except_countries', { exceptCountries: ['eef_suspendd'] }],
      ['eef_interest', { exceptCountries: ['eef_suspendd'] }],
      ['eef_interest', { exceptCountry: ['Niger'] }],
      ['eef_interest', { exceptCountries: null }],
    ])(
      '%s avec un filtre mal formé %j → personne, aucune requête',
      async (audienceType, filters) => {
        const h = makeService({
          channels: ['push'],
          template: TEMPLATE,
          audienceType,
          filters: filters as Record<string, unknown>,
        });
        await h.service.execute('c1');

        expect(h.deliveries()).toEqual([]);
        expect(h.profileQueries()).toEqual([]);
      },
    );

    it('eef_interest vise les étudiants qui ont une déclaration', async () => {
      const h = makeService({
        channels: ['push'],
        template: TEMPLATE,
        audienceType: 'eef_interest',
      });
      await h.service.execute('c1');

      const where = h.profileQueries().at(-1) as Record<string, any>;
      expect(where).toEqual({
        accountType: 'student',
        eefInterest: { isNot: null },
      });
    });

    it('eef_interest peut exclure les pays suspendus', async () => {
      const h = makeService({
        channels: ['push'],
        template: TEMPLATE,
        audienceType: 'eef_interest',
        filters: { exceptCountries: ['Niger'] },
      });
      await h.service.execute('c1');

      const where = h.profileQueries().at(-1) as Record<string, any>;
      expect(where.eefInterest).toEqual({ isNot: null });
      expect(where.NOT.OR).toHaveLength(1);
    });
  });

  // ── Correctifs 57 (XC-06) : finalité et consentement ──────────────────────
  describe('finalité promotionnelle (défaut)', () => {
    const previous = process.env.KPB_JWT_SECRET;
    const previousDedicated = process.env.KPB_PROMOTIONS_UNSUBSCRIBE_SECRET;
    beforeEach(() => {
      process.env.KPB_JWT_SECRET = 'jwt-secret';
      delete process.env.KPB_PROMOTIONS_UNSUBSCRIBE_SECRET;
    });
    afterAll(() => {
      if (previous === undefined) delete process.env.KPB_JWT_SECRET;
      else process.env.KPB_JWT_SECRET = previous;
      if (previousDedicated !== undefined) {
        process.env.KPB_PROMOTIONS_UNSUBSCRIBE_SECRET = previousDedicated;
      }
    });

    const people = [
      // Majeur, consentant (e-mail ET push).
      {
        id: 'yes',
        preferredLanguage: 'fr',
        email: 'yes@example.test',
        promotionsEmailOptIn: true,
        promotionsPushOptIn: true,
        birthDate: new Date('2000-01-01T00:00:00Z'),
      },
      // A activé le push puis coupé `kpb_promotions` ; jamais d'e-mail.
      {
        id: 'no',
        preferredLanguage: 'fr',
        email: 'no@example.test',
        promotionsEmailOptIn: false,
        promotionsPushOptIn: true,
        disabledNotificationTypes: ['kpb_promotions'],
      },
      // Mineur consentant SANS accord du représentant légal.
      {
        id: 'minor',
        preferredLanguage: 'en',
        email: 'minor@example.test',
        promotionsEmailOptIn: true,
        promotionsPushOptIn: true,
        birthDate: new Date('2012-01-01T00:00:00Z'),
      },
      // Compte d'une build sans l'interrupteur push (champ jamais posé) :
      // opt-in absent = non (chantier juridique 57, App Store 4.5.4).
      {
        id: 'old',
        preferredLanguage: 'fr',
        email: 'old@example.test',
        promotionsEmailOptIn: false,
      },
    ];

    it('sans finalité déclarée : ni e-mail ni push sans consentement, aucun push vers qui l’a coupé', async () => {
      const { service, deliveries, pushedTo, mails } = makeService({
        channels: ['push', 'email'],
        template: TEMPLATE,
        recipients: people,
        mailEnabled: true,
      });
      await service.execute('c1');
      // Push : opt-in exigé ; le mineur sans accord du représentant légal et
      // l'ancienne build (opt-in absent) ne reçoivent rien.
      expect(pushedTo().sort()).toEqual(['yes']);
      expect(mails().map((m) => m.to)).toEqual(['yes@example.test']);
      // Rien n'est même mis en file pour un canal fermé.
      expect(
        deliveries()
          .map((d) => `${d.recipientId}:${d.channel}`)
          .sort(),
      ).toEqual(['yes:email', 'yes:push']);
    });

    it('chaque e-mail promotionnel porte un lien de désinscription et List-Unsubscribe', async () => {
      const { service, mails } = makeService({
        channels: ['email'],
        template: TEMPLATE,
        recipients: people,
        mailEnabled: true,
        purpose: 'promotional',
      });
      await service.execute('c1');
      expect(mails()).toHaveLength(1);
      const [mail] = mails();
      expect(mail.text.startsWith('Corps\n\n')).toBe(true);
      expect(mail.text).toMatch(
        /Te désinscrire en un clic : https:\/\/api\.kpbeducation\.cloud\/api\/public\/promotions\/unsubscribe\?u=yes&t=/,
      );
      expect(mail.options?.headers?.['List-Unsubscribe']).toMatch(/^<https:\/\/.+u=yes&t=.+>$/);
      expect(mail.options?.headers?.['List-Unsubscribe-Post']).toBe('List-Unsubscribe=One-Click');
    });

    it('sans secret pour signer le lien : l’e-mail promotionnel ne part pas', async () => {
      delete process.env.KPB_JWT_SECRET;
      const { service, deliveries, mails, status } = makeService({
        channels: ['email'],
        template: TEMPLATE,
        recipients: people,
        mailEnabled: true,
      });
      await service.execute('c1');
      expect(mails()).toHaveLength(0);
      expect(deliveries()).toEqual([{ ...deliveries()[0], recipientId: 'yes', status: 'failed' }]);
      expect(status()).toBe('failed');
    });

    it('une campagne d’information n’est pas filtrée et n’ajoute pas de pied promotionnel', async () => {
      const { service, pushedTo, mails } = makeService({
        channels: ['push', 'email'],
        template: TEMPLATE,
        recipients: people,
        mailEnabled: true,
        purpose: 'informational',
      });
      await service.execute('c1');
      expect(pushedTo().sort()).toEqual(['minor', 'no', 'old', 'yes']);
      expect(mails().map((m) => m.to).sort()).toEqual([
        'minor@example.test',
        'no@example.test',
        'old@example.test',
        'yes@example.test',
      ]);
      expect(mails().every((m) => !m.text.includes('désinscrire') && !m.options)).toBe(true);
    });
  });
});
