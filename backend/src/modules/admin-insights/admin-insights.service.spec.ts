import { computeInsights } from './admin-insights.service';

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.parse('2026-10-11T12:00:00.000Z');
const day = (iso: string) => Date.parse(`${iso}T00:00:00.000Z`);

describe('computeInsights', () => {
  const users = [
    { createdAt: NOW - 2 * DAY, lastSignInAt: NOW - 3 * 60 * 60 * 1000 },
    { createdAt: NOW - 20 * DAY, lastSignInAt: NOW - 40 * 60 * 60 * 1000 },
    { createdAt: NOW - 60 * DAY, lastSignInAt: NOW - 10 * DAY },
    { createdAt: NOW - 90 * DAY, lastSignInAt: null },
  ];

  it('compte les fenêtres glissantes', () => {
    const r = computeInsights(users, day('2026-09-12'), day('2026-10-11'), NOW);
    expect(r.totals).toMatchObject({
      totalUsers: 4,
      activeLast24h: 1,
      activeLast48h: 2,
      activeLast7d: 2,
      activeLast30d: 3,
      signupsLast7d: 1,
    });
  });

  it('filtre la période et remplit chaque jour', () => {
    const r = computeInsights(users, day('2026-10-01'), day('2026-10-11'), NOW);
    expect(r.daily).toHaveLength(11);
    expect(r.period).toEqual({ signups: 1, active: 3 });
    expect(r.daily.reduce((s, d) => s + d.signups, 0)).toBe(1);
  });
});
