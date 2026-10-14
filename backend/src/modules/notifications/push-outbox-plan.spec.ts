import { userJitterMs } from '../../common/push-quiet-hours';
import {
  openingCollapseKey,
  planUserPush,
  type OutboxPlanRow,
  type OutboxPlanSettings,
  type OutboxPlanUser,
} from './push-outbox-plan';

const MIN = 60 * 1000;
const HOUR = 60 * MIN;

const settings: OutboxPlanSettings = {
  ttlHours: 72,
  coalesceMinutes: 30,
  maxOpeningPushesPerDay: 2,
  quiet: { startHour: 21, endHour: 8 },
  pushConfigured: true,
  random: () => 0.5,
};

let seq = 0;
function row(over: Partial<OutboxPlanRow> = {}): OutboxPlanRow {
  seq += 1;
  const cycleId = over.cycleId ?? `c${seq}`;
  const userId = over.userId ?? 'u1';
  return {
    id: `row-${String(seq).padStart(3, '0')}`,
    userId,
    scholarshipId: `s${seq}`,
    cycleId,
    dedupeKey: `scholarship-opened:${cycleId}:${userId}`,
    titleFr: "C'est ouvert",
    titleEn: 'Applications are open',
    bodyFr: `Bourse ${seq} : candidatures jusqu'au 5 novembre.`,
    bodyEn: `Scholarship ${seq}: apply by 5 November.`,
    pushAttempts: 0,
    createdAt: new Date('2026-10-15T09:00:00Z'),
    variant: 'favorite',
    favorite: true,
    alertActive: false,
    muted: false,
    pushEnabled: true,
    scholarshipPublic: true,
    scholarshipNameFr: `Bourse ${seq}`,
    scholarshipNameEn: `Scholarship ${seq}`,
    cycleExists: true,
    cycleCloseAt: new Date('2026-11-05T23:59:59.999Z'),
    cycleStoppedAt: null,
    ...over,
  };
}

function user(
  rows: OutboxPlanRow[],
  over: Partial<OutboxPlanUser> = {},
): OutboxPlanUser {
  return {
    userId: 'u1',
    preferredLanguage: 'fr',
    countryOfResidence: 'Sénégal',
    optedOut: false,
    recentPushes: [],
    contended: false,
    rows,
    ...over,
  };
}

const noon = new Date('2026-10-15T12:00:00Z');

describe('planUserPush', () => {
  describe('heures calmes', () => {
    it('Dakar à 22 h → 8 h locales + le décalage de l’élève, pour toutes ses lignes', () => {
      const rows = [row(), row(), row()];
      const plan = planUserPush(user(rows), new Date('2026-10-15T22:00:00Z'), settings);
      expect(plan.send).toBeNull();
      expect(plan.finals).toEqual([]);
      expect(plan.deferral).toEqual({
        rowIds: rows.map((r) => r.id),
        until: new Date(Date.parse('2026-10-16T08:00:00Z') + userJitterMs('u1')),
        reason: 'deferred_quiet_hours',
      });
    });

    it('Douala (UTC+1) à 21 h 30 UTC = 22 h 30 locales → 7 h UTC + décalage', () => {
      const plan = planUserPush(
        user([row({ userId: 'u-cm' })], { userId: 'u-cm', countryOfResidence: 'Cameroun' }),
        new Date('2026-10-15T21:30:00Z'),
        settings,
      );
      expect(plan.deferral?.until).toEqual(
        new Date(Date.parse('2026-10-16T07:00:00Z') + userJitterMs('u-cm')),
      );
      expect(plan.deferral?.reason).toBe('deferred_quiet_hours');
    });
  });

  describe('rythme', () => {
    it('un push il y a 10 min → repoussé à +30 min après lui', () => {
      const plan = planUserPush(
        user([row()], {
          recentPushes: [{ pushedAt: new Date(noon.getTime() - 10 * MIN), batchId: 'b1' }],
        }),
        noon,
        settings,
      );
      expect(plan.deferral).toMatchObject({
        until: new Date(noon.getTime() + 20 * MIN),
        reason: 'deferred_pacing',
      });
    });

    it('deux push aujourd’hui → 8 h locales demain + décalage', () => {
      const plan = planUserPush(
        user([row()], {
          recentPushes: [
            { pushedAt: new Date('2026-10-15T09:00:00Z'), batchId: 'b1' },
            { pushedAt: new Date('2026-10-15T10:00:00Z'), batchId: 'b2' },
          ],
        }),
        noon,
        settings,
      );
      expect(plan.deferral).toEqual({
        rowIds: [expect.any(String)],
        until: new Date(Date.parse('2026-10-16T08:00:00Z') + userJitterMs('u1')),
        reason: 'deferred_pacing',
      });
    });

    it('un push d’hier ne compte pas dans le plafond du jour local', () => {
      const plan = planUserPush(
        user([row()], {
          recentPushes: [
            { pushedAt: new Date('2026-10-14T19:00:00Z'), batchId: 'b0' },
            { pushedAt: new Date('2026-10-15T09:00:00Z'), batchId: 'b1' },
          ],
        }),
        noon,
        settings,
      );
      expect(plan.send).not.toBeNull();
    });

    it('le jour local suit le pays : 23 h 30 UTC est déjà demain à Douala', () => {
      // 23 h 30 UTC = 0 h 30 à Douala : heures calmes de toute façon, mais le
      // plafond de « demain » ne voit pas les push de la veille locale.
      const plan = planUserPush(
        user([row({ userId: 'u-cm' })], {
          userId: 'u-cm',
          countryOfResidence: 'Cameroun',
          recentPushes: [
            { pushedAt: new Date('2026-10-15T09:00:00Z'), batchId: 'b1' },
            { pushedAt: new Date('2026-10-15T10:00:00Z'), batchId: 'b2' },
          ],
        }),
        new Date('2026-10-16T07:30:00Z'),
        settings,
      );
      expect(plan.send).not.toBeNull();
    });
  });

  describe('envoi', () => {
    it('une ligne → push seul, charge v1, clés tirées de la dedupeKey', () => {
      const only = row({ cycleId: 'cyc', scholarshipId: 'sch' });
      const plan = planUserPush(user([only]), noon, settings);
      expect(plan.send).toEqual({
        kind: 'single',
        rows: [{ id: only.id, pushAttempts: 0 }],
        leadRowId: only.id,
        title: "C'est ouvert",
        body: only.bodyFr,
        data: {
          route: '/scholarships/sch',
          scholarshipId: 'sch',
          cycleId: 'cyc',
          type: 'scholarship_opened',
          kind: 'scholarship_opened',
          notificationKey: 'scholarship-opened:cyc:u1',
          ref: 'scholarship-opened:cyc',
        },
        idempotencyKey: 'scholarship-opened:cyc:u1',
        collapseKey: openingCollapseKey('scholarship-opened:cyc:u1'),
      });
      expect(plan.send?.collapseKey).toMatch(/^kpb-[0-9a-f]{32}$/);
    });

    it('la langue est choisie à l’envoi', () => {
      const only = row();
      const plan = planUserPush(user([only], { preferredLanguage: 'en-GB' }), noon, settings);
      expect(plan.send).toMatchObject({ title: only.titleEn, body: only.bodyEn });
    });

    it.each([2, 3, 4])('%i lignes → un push groupé vers /deadlines', (n) => {
      const rows = Array.from({ length: n }, (_, i) =>
        row({ createdAt: new Date(Date.parse('2026-10-15T09:00:00Z') + i * MIN) }),
      );
      const plan = planUserPush(user(rows), noon, settings);
      const newestFirst = [...rows].reverse();
      expect(plan.send?.kind).toBe('bundle');
      expect(plan.send?.leadRowId).toBe(newestFirst[0].id);
      expect(plan.send?.rows.map((r) => r.id)).toEqual(newestFirst.map((r) => r.id));
      expect(plan.send?.data).toEqual({
        route: '/deadlines',
        type: 'scholarship_opened_bundle',
        kind: 'scholarship_opened_bundle',
        count: String(n),
        refs: newestFirst.map((r) => `scholarship-opened:${r.cycleId}`).join(','),
        scholarshipIds: newestFirst.map((r) => r.scholarshipId).join(','),
      });
      expect(plan.send?.data).not.toHaveProperty('scholarshipId');
      expect(plan.send?.title).toBe(`${n} bourses que tu suis sont ouvertes`);
      const [a, b] = newestFirst;
      const tail = n === 2 ? '' : n === 3 ? ' et 1 autre' : ` et ${n - 2} autres`;
      expect(plan.send?.body).toBe(
        n === 2
          ? `${a.scholarshipNameFr} et ${b.scholarshipNameFr}. Regarde les dates limites.`
          : `${a.scholarshipNameFr}, ${b.scholarshipNameFr}${tail}. Regarde les dates limites.`,
      );
      // Clé déterministe : les identifiants triés, quel que soit l'ordre.
      const key = rows.map((r) => r.id).sort().join(',');
      expect(plan.send?.idempotencyKey).toBe(key);
      expect(plan.send?.collapseKey).toBe(openingCollapseKey(key));
    });

    it('un « Dates confirmées » groupé avec une ouverture : le groupé ne dit pas « ouvertes »', () => {
      // 20 h 30 : dates de Chevening confirmées (ouverture le 1er novembre) ;
      // 20 h 40 : Eiffel ouvre. Heures calmes : les deux partent ensemble à 8 h.
      const chevening = row({
        variant: 'dates_confirmed',
        titleFr: 'Dates confirmées',
        titleEn: 'Dates confirmed',
        scholarshipNameFr: 'Chevening',
        scholarshipNameEn: 'Chevening',
        createdAt: new Date('2026-10-15T20:30:00Z'),
      });
      const eiffel = row({
        variant: 'alert',
        scholarshipNameFr: 'Eiffel',
        scholarshipNameEn: 'Eiffel',
        createdAt: new Date('2026-10-15T20:40:00Z'),
      });
      const morning = new Date('2026-10-16T08:05:00Z');

      const fr = planUserPush(user([chevening, eiffel]), morning, settings);
      expect(fr.send).toMatchObject({
        kind: 'bundle',
        title: '2 bourses que tu suis ont du nouveau',
        body: 'Eiffel et Chevening. Regarde les dates.',
      });
      expect(`${fr.send?.title} ${fr.send?.body}`).not.toMatch(/ouvert/i);

      const en = planUserPush(
        user([chevening, eiffel], { preferredLanguage: 'en' }),
        morning,
        settings,
      );
      expect(en.send).toMatchObject({
        title: '2 scholarships you follow have updates',
        body: 'Eiffel and Chevening. Check the dates.',
      });
      expect(`${en.send?.title} ${en.send?.body}`).not.toMatch(/open/i);
    });

    it('une variante absente ou illisible n’est jamais dite « ouverte »', () => {
      const plan = planUserPush(user([row({ variant: null }), row()]), noon, settings);
      expect(plan.send?.title).toBe('2 bourses que tu suis ont du nouveau');
    });

    it('des « Dates confirmées » seuls : groupé neutre aussi', () => {
      const plan = planUserPush(
        user([row({ variant: 'dates_confirmed' }), row({ variant: 'dates_confirmed' })]),
        noon,
        settings,
      );
      expect(plan.send?.title).toBe('2 bourses que tu suis ont du nouveau');
    });

    it('un groupé porte au plus 20 références, mais compte toutes les lignes', () => {
      const rows = Array.from({ length: 23 }, (_, i) =>
        row({ createdAt: new Date(Date.parse('2026-10-15T09:00:00Z') + i * MIN) }),
      );
      const plan = planUserPush(user(rows), noon, settings);
      expect(plan.send?.data.count).toBe('23');
      expect(plan.send?.data.refs.split(',')).toHaveLength(20);
      expect(plan.send?.data.scholarshipIds.split(',')).toHaveLength(20);
      expect(plan.send?.rows).toHaveLength(23);
    });
  });

  describe('contention', () => {
    it('un autre worker tient l’élève → tout repoussé deferred_busy, aucun envoi', () => {
      const rows = [row(), row({ createdAt: new Date('2026-01-01T00:00:00Z') })];
      const plan = planUserPush(user(rows, { contended: true }), noon, {
        ...settings,
        random: () => 0.5,
      });
      expect(plan.send).toBeNull();
      // Même la ligne périmée attend : rien d'autre n'est évalué.
      expect(plan.finals).toEqual([]);
      expect(plan.deferral).toEqual({
        rowIds: rows.map((r) => r.id),
        until: new Date(noon.getTime() + 60_000 + 15_000),
        reason: 'deferred_busy',
      });
      const late = planUserPush(user(rows, { contended: true }), noon, {
        ...settings,
        random: () => 0.999,
      });
      expect(late.deferral?.until.getTime()).toBeLessThan(noon.getTime() + 90_000);
    });
  });

  describe('lignes closes sans appel au fournisseur', () => {
    it('TTL compté depuis createdAt', () => {
      const old = row({ createdAt: new Date(noon.getTime() - 73 * HOUR) });
      const fresh = row({ createdAt: new Date(noon.getTime() - 71 * HOUR) });
      const plan = planUserPush(user([old, fresh]), noon, settings);
      expect(plan.finals).toEqual([{ rowId: old.id, status: 'expired' }]);
      expect(plan.send?.rows.map((r) => r.id)).toEqual([fresh.id]);
    });

    it('createdAt <= openingStoppedAt → stopped_by_staff, même revenue d’une nouvelle tentative', () => {
      const stoppedAt = new Date('2026-10-15T10:00:00Z');
      const before = row({
        createdAt: new Date('2026-10-15T09:00:00Z'),
        cycleStoppedAt: stoppedAt,
        pushAttempts: 2,
      });
      const after = row({
        createdAt: new Date('2026-10-15T10:30:00Z'),
        cycleStoppedAt: stoppedAt,
      });
      const plan = planUserPush(user([before, after]), noon, settings);
      expect(plan.finals).toEqual([
        { rowId: before.id, status: 'skipped', reason: 'stopped_by_staff' },
      ]);
      expect(plan.send?.rows.map((r) => r.id)).toEqual([after.id]);
    });

    it.each([
      ['opt_out', {}, { optedOut: true }],
      ['push_disabled', { pushEnabled: false }, {}],
      ['muted', { muted: true, favorite: true }, {}],
      ['unfollowed', { favorite: false, alertActive: false }, {}],
      ['not_public', { scholarshipPublic: false }, {}],
      ['not_public', { scholarshipId: null }, {}],
      ['cycle_closed', { cycleCloseAt: new Date('2026-10-15T11:59:59Z') }, {}],
      ['cycle_closed', { cycleExists: false }, {}],
    ] as const)('%s', (reason, rowOver, userOver) => {
      const r = row(rowOver);
      const plan = planUserPush(user([r], userOver), noon, settings);
      expect(plan.finals).toEqual([{ rowId: r.id, status: 'skipped', reason }]);
      expect(plan.send).toBeNull();
      expect(plan.deferral).toBeNull();
    });

    it('l’alerte seule (sans favori) suffit à suivre', () => {
      const r = row({ favorite: false, alertActive: true });
      expect(planUserPush(user([r]), noon, settings).send).not.toBeNull();
    });

    it('sans fournisseur configuré → push_unconfigured, pas d’arriéré', () => {
      const rows = [row(), row()];
      const plan = planUserPush(user(rows), noon, { ...settings, pushConfigured: false });
      expect(plan.finals).toEqual(
        rows.map((r) => ({ rowId: r.id, status: 'skipped', reason: 'push_unconfigured' })),
      );
      expect(plan.send).toBeNull();
    });

    it('une sautée et une envoyable : l’envoyable part seule', () => {
      const skipped = row({ muted: true });
      const ok = row();
      const plan = planUserPush(user([skipped, ok]), noon, settings);
      expect(plan.finals).toHaveLength(1);
      expect(plan.send?.kind).toBe('single');
      expect(plan.send?.leadRowId).toBe(ok.id);
    });
  });

  it('un report ne touche pas au nombre de tentatives (le plan ne le porte pas)', () => {
    const r = row({ pushAttempts: 3 });
    const plan = planUserPush(user([r]), new Date('2026-10-15T23:00:00Z'), settings);
    expect(plan.deferral).not.toBeNull();
    expect(Object.keys(plan.deferral ?? {})).toEqual(['rowIds', 'until', 'reason']);
  });
});
