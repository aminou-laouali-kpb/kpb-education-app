// Admin « Insights » — utilisateurs inscrits / actifs.
//
// La source de vérité des comptes est Supabase Auth (la base Prisma ne contient
// que les profils complétés, sans date de dernière activité). On lit donc
// `created_at` et `last_sign_in_at` via l'API Admin, avec la clé service-role
// déjà requise pour la suppression de compte. Le résultat est mis en cache
// quelques minutes : la liste complète est paginée et grossit vite.

import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';

const PAGE_SIZE = 1000;
const MAX_PAGES = 50;
const CACHE_TTL_MS = 5 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_RANGE_DAYS = 366;

export interface AuthUserStamp {
  createdAt: number;
  lastSignInAt: number | null;
}

export interface InsightsDailyPoint {
  date: string;
  signups: number;
  active: number;
}

export interface InsightsResult {
  range: { from: string; to: string };
  totals: {
    totalUsers: number;
    activeLast24h: number;
    activeLast48h: number;
    activeLast7d: number;
    activeLast30d: number;
    signupsLast7d: number;
  };
  period: { signups: number; active: number };
  daily: InsightsDailyPoint[];
  generatedAt: string;
}

function dayKey(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

function parseDay(value: string | undefined, label: string): number | null {
  if (value === undefined || value === '') {
    return null;
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new BadRequestException(`${label} doit être au format AAAA-MM-JJ.`);
  }
  const ms = Date.parse(`${value}T00:00:00.000Z`);
  if (Number.isNaN(ms)) {
    throw new BadRequestException(`${label} n'est pas une date valide.`);
  }
  return ms;
}

/** Calcul pur, testable sans réseau. `from`/`to` : jours UTC inclus. */
export function computeInsights(
  users: readonly AuthUserStamp[],
  fromDay: number,
  toDay: number,
  now: number,
): InsightsResult {
  const rangeStart = fromDay;
  const rangeEnd = toDay + DAY_MS; // exclusif
  const within = (ms: number | null) =>
    ms !== null && ms >= rangeStart && ms < rangeEnd;
  const since = (ms: number | null, windowMs: number) =>
    ms !== null && ms >= now - windowMs;

  const daily = new Map<string, InsightsDailyPoint>();
  for (let d = fromDay; d <= toDay; d += DAY_MS) {
    daily.set(dayKey(d), { date: dayKey(d), signups: 0, active: 0 });
  }

  let periodSignups = 0;
  let periodActive = 0;
  const totals = {
    totalUsers: users.length,
    activeLast24h: 0,
    activeLast48h: 0,
    activeLast7d: 0,
    activeLast30d: 0,
    signupsLast7d: 0,
  };

  for (const user of users) {
    if (since(user.lastSignInAt, DAY_MS)) totals.activeLast24h += 1;
    if (since(user.lastSignInAt, 2 * DAY_MS)) totals.activeLast48h += 1;
    if (since(user.lastSignInAt, 7 * DAY_MS)) totals.activeLast7d += 1;
    if (since(user.lastSignInAt, 30 * DAY_MS)) totals.activeLast30d += 1;
    if (since(user.createdAt, 7 * DAY_MS)) totals.signupsLast7d += 1;

    if (within(user.createdAt)) {
      periodSignups += 1;
      daily.get(dayKey(user.createdAt))!.signups += 1;
    }
    if (within(user.lastSignInAt)) {
      periodActive += 1;
      daily.get(dayKey(user.lastSignInAt!))!.active += 1;
    }
  }

  return {
    range: { from: dayKey(fromDay), to: dayKey(toDay) },
    totals,
    period: { signups: periodSignups, active: periodActive },
    daily: [...daily.values()],
    generatedAt: new Date(now).toISOString(),
  };
}

@Injectable()
export class AdminInsightsService {
  private readonly logger = new Logger(AdminInsightsService.name);
  private cache: { at: number; users: AuthUserStamp[] } | null = null;

  async getInsights(from?: string, to?: string): Promise<InsightsResult> {
    const now = Date.now();
    const todayStart = Date.parse(`${dayKey(now)}T00:00:00.000Z`);
    const toDay = parseDay(to, 'to') ?? todayStart;
    const fromDay = parseDay(from, 'from') ?? toDay - 29 * DAY_MS;
    if (fromDay > toDay) {
      throw new BadRequestException('from doit précéder to.');
    }
    if ((toDay - fromDay) / DAY_MS + 1 > MAX_RANGE_DAYS) {
      throw new BadRequestException(
        `La période ne peut pas dépasser ${MAX_RANGE_DAYS} jours.`,
      );
    }
    const users = await this.loadUsers(now);
    return computeInsights(users, fromDay, toDay, now);
  }

  private async loadUsers(now: number): Promise<AuthUserStamp[]> {
    if (this.cache && now - this.cache.at < CACHE_TTL_MS) {
      return this.cache.users;
    }
    const url = process.env.SUPABASE_URL?.trim();
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
    if (!url || !key) {
      throw new ServiceUnavailableException(
        'Les insights nécessitent SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY.',
      );
    }
    const base = url.replace(/\/+$/, '');
    const users: AuthUserStamp[] = [];
    for (let page = 1; page <= MAX_PAGES; page += 1) {
      let res: Response;
      try {
        res = await fetch(
          `${base}/auth/v1/admin/users?page=${page}&per_page=${PAGE_SIZE}`,
          {
            headers: { apikey: key, authorization: `Bearer ${key}` },
            signal: AbortSignal.timeout(15_000),
          },
        );
      } catch {
        this.logger.error('Supabase admin listUsers request failed.');
        throw new ServiceUnavailableException('Supabase Auth injoignable.');
      }
      if (!res.ok) {
        this.logger.error(`Supabase admin listUsers failed (${res.status}).`);
        throw new ServiceUnavailableException('Supabase Auth a refusé la requête.');
      }
      const body = (await res.json()) as {
        users?: { created_at?: string; last_sign_in_at?: string | null }[];
      };
      const batch = body.users ?? [];
      for (const u of batch) {
        const created = u.created_at ? Date.parse(u.created_at) : NaN;
        if (Number.isNaN(created)) continue;
        const last = u.last_sign_in_at ? Date.parse(u.last_sign_in_at) : NaN;
        users.push({
          createdAt: created,
          lastSignInAt: Number.isNaN(last) ? null : last,
        });
      }
      if (batch.length < PAGE_SIZE) {
        break;
      }
    }
    this.cache = { at: now, users };
    return users;
  }
}
