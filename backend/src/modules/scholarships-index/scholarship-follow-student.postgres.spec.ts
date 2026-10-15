import { randomUUID } from 'node:crypto';

import { AccountType, PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import { SavedItemsService } from '../saved-items/saved-items.service';
import { FollowedScholarshipsService } from './followed-scholarships.service';
import { SCHOLARSHIP_OPENING_MODE_ENV } from './opening/scholarship-opening.contract';
import { ScholarshipAlertsService } from './scholarship-alerts.service';
import type { ScholarshipContentQualityService } from './scholarship-content-quality.service';
import { ScholarshipsIndexService } from './scholarships-index.service';
import type { GreatYopScraper } from './scrapers/greatyop.scraper';
import type { MastereTnScraper } from './scrapers/mastereTn.scraper';
import { UserNotificationsService } from './user-notifications.service';

/**
 * Les routes étudiant du suivi (chantier C) contre un vrai PostgreSQL.
 *
 * Les tests unitaires jouent contre une base en mémoire ou des doubles ; ici,
 * ce sont les vraies contraintes (unicité, clés étrangères, `ON CONFLICT`), la
 * vraie requête partagée « qui suit » et les vraies transactions : la liste
 * suivie (closes gardées, orphelins et fiches non approuvées écartés), la
 * sourdine aller-retour vue par les builds 53/56 et par les récentes, la
 * cascade du favori retiré selon le mode, et la lecture par référence bornée à
 * l'étudiant connecté.
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Suivi des bourses, routes étudiant — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;

  const alerts = new ScholarshipAlertsService(prismaService);
  const savedItems = new SavedItemsService(prismaService);
  const followed = new FollowedScholarshipsService(prismaService);
  const notifications = new UserNotificationsService(prismaService);
  const index = new ScholarshipsIndexService(
    prismaService,
    {} as GreatYopScraper,
    {} as MastereTnScraper,
    {} as ScholarshipContentQualityService,
  );

  const sfx = randomUUID().replace(/-/g, '').slice(0, 10);
  // Un pays propre à cette exécution : la liste publique ne lit que nos fiches.
  const country = `it-${sfx}`;
  const users: string[] = [];
  const scholarships: string[] = [];
  const DAY = 24 * 60 * 60 * 1000;
  const now = new Date();
  const previousMode = process.env[SCHOLARSHIP_OPENING_MODE_ENV];

  async function student(name: string): Promise<string> {
    const id = `it-follow-${name}-${sfx}`;
    users.push(id);
    await prisma.userProfile.create({
      data: {
        id,
        accountType: AccountType.student,
        preferredLanguage: 'fr',
        fullName: `Suivi ${name}`,
        email: `${id}@example.test`,
        phone: '',
        countryOfResidence: 'Sénégal',
      },
    });
    return id;
  }

  async function scholarship(
    name: string,
    opts: {
      moderationStatus?: 'approved' | 'pending';
      deadlineAt?: Date | null;
      cycle?: { status: 'open' | 'forecast' | 'closed'; closesAt?: Date };
    } = {},
  ): Promise<string> {
    const id = `it-follow-${name}-${sfx}`;
    scholarships.push(id);
    await prisma.scholarship.create({
      data: {
        id,
        nameFr: `Bourse ${name}`,
        nameEn: `Scholarship ${name}`,
        countryId: country,
        levelEligibleFr: 'Master',
        levelEligibleEn: "Master's",
        typeOfFundingFr: 'Complète',
        typeOfFundingEn: 'Full',
        deadlineLabelFr: '—',
        deadlineLabelEn: '—',
        isActive: true,
        moderationStatus: opts.moderationStatus ?? 'approved',
        lastVerifiedAt: new Date(now.getTime() - 30 * DAY),
        deadlineAt:
          opts.deadlineAt === undefined
            ? new Date(now.getTime() + 30 * DAY)
            : opts.deadlineAt,
      },
    });
    if (opts.cycle) {
      await prisma.scholarshipCycle.create({
        data: {
          scholarshipId: id,
          academicYear: '2026-2027',
          status: opts.cycle.status,
          dateConfidence: 'confirmed',
          closesAt: opts.cycle.closesAt ?? null,
        },
      });
    }
    return id;
  }

  async function favorite(userId: string, itemId: string): Promise<string> {
    const row = await prisma.savedItem.create({
      data: { userId, itemType: 'scholarship', itemId },
    });
    return row.id;
  }

  async function alert(
    userId: string,
    scholarshipId: string,
    mutedAt: Date | null = null,
  ): Promise<void> {
    await prisma.scholarshipAlertSubscription.create({
      data: { userId, scholarshipId, mutedAt },
    });
  }

  function setMode(mode: string): void {
    process.env[SCHOLARSHIP_OPENING_MODE_ENV] = mode;
  }

  afterEach(() => {
    if (previousMode === undefined) delete process.env[SCHOLARSHIP_OPENING_MODE_ENV];
    else process.env[SCHOLARSHIP_OPENING_MODE_ENV] = previousMode;
  });

  afterAll(async () => {
    await prisma.userNotification.deleteMany({ where: { userId: { in: users } } });
    await prisma.scholarshipAlertSubscription.deleteMany({
      where: { userId: { in: users } },
    });
    await prisma.savedItem.deleteMany({ where: { userId: { in: users } } });
    await prisma.userProfile.deleteMany({ where: { id: { in: users } } });
    await prisma.scholarship.deleteMany({ where: { id: { in: scholarships } } });
    await prisma.$disconnect();
  });

  it('la liste suivie garde les bourses closes, écarte orphelins, fiches non approuvées et sourdines seules', async () => {
    const me = await student('list');
    const other = await student('list-other');
    const open = await scholarship('list-open', {
      cycle: { status: 'open', closesAt: new Date(now.getTime() + 20 * DAY) },
    });
    const closed = await scholarship('list-closed', {
      deadlineAt: new Date(now.getTime() - 40 * DAY),
      cycle: { status: 'open', closesAt: new Date(now.getTime() - 40 * DAY) },
    });
    const pending = await scholarship('list-pending', { moderationStatus: 'pending' });
    const alertOnly = await scholarship('list-alert', {
      cycle: { status: 'forecast' },
    });
    const mutedOnly = await scholarship('list-muted');
    const othersOnly = await scholarship('list-others');

    await favorite(me, open);
    await favorite(me, closed);
    await favorite(me, pending);
    await favorite(me, `it-follow-deleted-${sfx}`); // orphelin : aucune FK
    await alert(me, alertOnly);
    await alert(me, mutedOnly, now);
    await favorite(other, othersOnly);

    const result = await followed.list(me, 'fr');

    expect(result.items.map((item) => [item.id, item.displayStatus])).toEqual([
      [open, 'open'],
      [alertOnly, 'forecast'],
      [closed, 'closed'],
    ]);
    expect(result.total).toBe(3);
    const byId = new Map(result.items.map((item) => [item.id, item]));
    expect(byId.get(open)).toMatchObject({
      viaFavorite: true,
      viaAlert: false,
      notifyOpening: true,
      detailAvailable: true,
    });
    expect(byId.get(alertOnly)).toMatchObject({ viaFavorite: false, viaAlert: true });
    expect(byId.get(closed)).toMatchObject({ detailAvailable: false });
    expect(result.globalOptOut).toBe(false);
  });

  it('sourdine puis reprise : cloche éteinte pour les builds 53/56, bourse toujours suivie', async () => {
    setMode('legacy');
    const me = await student('mute');
    const sid = await scholarship('mute', {
      cycle: { status: 'open', closesAt: new Date(now.getTime() + 20 * DAY) },
    });
    await favorite(me, sid);
    await alerts.subscribe(me, sid);

    await expect(alerts.updatePreference(me, sid, false)).resolves.toEqual({
      scholarshipId: sid,
      following: true,
      notifyOpening: false,
    });
    expect((await alerts.list(me)).items).toEqual([]);
    const detail = await index.getForProfile(sid, { lang: 'fr', userId: me });
    expect(detail.alert).toEqual({ subscribed: false, pushEnabled: false, inAppEnabled: false });
    expect(detail.follow).toMatchObject({ following: true, viaFavorite: true, notifyOpening: false });
    const listed = await index.listForProfile({ lang: 'fr', userId: me, countryId: country });
    expect(listed.items.find((item) => item.id === sid)?.isAlertEnabled).toBe(false);
    expect((await followed.list(me, 'fr')).items).toEqual([
      expect.objectContaining({ id: sid, notifyOpening: false }),
    ]);

    await expect(alerts.updatePreference(me, sid, true)).resolves.toEqual({
      scholarshipId: sid,
      following: true,
      notifyOpening: true,
    });
    expect((await alerts.list(me)).items.map((item) => item.scholarshipId)).toEqual([sid]);
    const after = await index.getForProfile(sid, { lang: 'fr', userId: me });
    expect(after.alert.subscribed).toBe(true);
  });

  it.each(['legacy', 'outbox_alerts'])(
    'retirer le favori en %s : la sourdine part avec lui, une alerte active reste',
    async (mode) => {
      setMode(mode);
      const me = await student(`cascade-${mode}`);
      const muted = await scholarship(`cascade-muted-${mode}`);
      const active = await scholarship(`cascade-active-${mode}`);
      const mutedFav = await favorite(me, muted);
      const activeFav = await favorite(me, active);
      await alert(me, muted, now);
      await alert(me, active);

      await savedItems.remove(mutedFav, me);
      await savedItems.remove(activeFav, me);

      const remaining = await prisma.scholarshipAlertSubscription.findMany({
        where: { userId: me },
        select: { scholarshipId: true },
      });
      expect(remaining).toEqual([{ scholarshipId: active }]);
    },
  );

  it('retirer le favori en outbox_followers retire toute alerte', async () => {
    setMode('outbox_followers');
    const me = await student('cascade-followers');
    const sid = await scholarship('cascade-followers');
    const fav = await favorite(me, sid);
    await alert(me, sid);

    await expect(savedItems.remove(fav, me)).resolves.toEqual({ id: fav });

    expect(
      await prisma.scholarshipAlertSubscription.count({ where: { userId: me } }),
    ).toBe(0);
  });

  it('outbox_followers : la cloche pose le favori ; un favori explicite survit à la cloche éteinte', async () => {
    setMode('outbox_followers');
    const me = await student('bell');
    const sid = await scholarship('bell');

    await alerts.subscribe(me, sid);
    expect(
      await prisma.scholarshipAlertSubscription.findUnique({
        where: { userId_scholarshipId: { userId: me, scholarshipId: sid } },
        select: { impliedFollow: true, mutedAt: true },
      }),
    ).toEqual({ impliedFollow: true, mutedAt: null });
    expect(await prisma.savedItem.count({ where: { userId: me, itemId: sid } })).toBe(1);

    await savedItems.create({ type: 'scholarship', itemId: sid }, me);
    await alerts.unsubscribe(me, sid);

    expect(await prisma.savedItem.count({ where: { userId: me, itemId: sid } })).toBe(1);
    const row = await prisma.scholarshipAlertSubscription.findUnique({
      where: { userId_scholarshipId: { userId: me, scholarshipId: sid } },
      select: { impliedFollow: true, mutedAt: true },
    });
    expect(row?.impliedFollow).toBe(false);
    expect(row?.mutedAt).toBeInstanceOf(Date);
  });

  it('lecture par référence : seules les entrées de l’étudiant connecté', async () => {
    const me = await student('read');
    const other = await student('read-other');
    const sid = await scholarship('read');
    const cycleId = `it-follow-cycle-${sfx}`;
    const entry = (userId: string, cycle: string) => ({
      userId,
      scholarshipId: sid,
      cycleId: cycle,
      kind: 'scholarship_opened',
      dedupeKey: `scholarship-opened:${cycle}:${userId}`,
      titleFr: 't',
      titleEn: 't',
      bodyFr: 'b',
      bodyEn: 'b',
      route: `/scholarships/${sid}`,
    });
    await prisma.userNotification.createMany({
      data: [
        entry(me, cycleId),
        entry(me, `${cycleId}-2`),
        entry(other, cycleId),
      ],
    });
    await expect(notifications.unreadCount(me)).resolves.toEqual({ unreadCount: 2 });

    // La dedupeKey complète d'un autre compte ne désigne rien pour moi.
    await expect(
      notifications.markReadByRefs(me, [`scholarship-opened:${cycleId}:${other}`]),
    ).resolves.toEqual({ updated: 0 });
    await expect(
      notifications.markReadByRefs(me, [`scholarship-opened:${cycleId}`]),
    ).resolves.toEqual({ updated: 1 });

    await expect(notifications.unreadCount(me)).resolves.toEqual({ unreadCount: 1 });
    await expect(notifications.unreadCount(other)).resolves.toEqual({ unreadCount: 1 });
  });
});
