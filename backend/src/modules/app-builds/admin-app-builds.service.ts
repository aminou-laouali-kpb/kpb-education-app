import { Injectable, ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

/** Un compte « actif » a fait une requête authentifiée dans cette fenêtre. */
export const APP_BUILD_WINDOW_DAYS = 30;

const DAY_MS = 24 * 60 * 60 * 1000;

export interface CountShare {
  count: number;
  /** Ratio 0–1, arrondi à 4 décimales (0.0123 = 1,23 %). */
  share: number;
}

export interface BuildShare extends CountShare {
  build: number;
  /**
   * Part des comptes actifs sur cette build OU une plus récente — c'est-à-dire
   * la part qui resterait ouverte si l'app exigeait cette build au minimum.
   * Les builds inconnues comptent comme plus anciennes : elles n'envoient pas
   * l'en-tête, apparu à la 54.
   */
  shareAtOrAbove: number;
}

export interface VersionShare extends CountShare {
  version: string;
}

export interface AppBuildAdoption {
  windowDays: number;
  since: string;
  generatedAt: string;
  /** Comptes vus dans la fenêtre : le dénominateur des parts par build/version. */
  activeProfiles: number;
  /** Du plus récent au plus ancien. */
  byBuild: BuildShare[];
  /** Du plus récent au plus ancien. */
  byVersion: VersionShare[];
  /** Vus dans la fenêtre sans build lisible : en pratique les builds ≤ 53. */
  unknownBuild: CountShare;
  unknownVersion: CountShare;
  /** Jamais vus depuis la mise en service du suivi, sur tous les comptes. */
  neverSeen: CountShare;
  allProfiles: number;
}

function ratio(part: number, whole: number): number {
  return whole > 0 ? Math.round((part / whole) * 10_000) / 10_000 : 0;
}

function countShare(count: number, whole: number): CountShare {
  return { count, share: ratio(count, whole) };
}

/** `2.10.0` après `2.9.0` : comparaison numérique segment par segment. */
function newestVersionFirst(a: string, b: string): number {
  return b.localeCompare(a, 'en', { numeric: true });
}

/**
 * Répartition des comptes actifs par build et par version de l'app.
 *
 * Que des comptages : ni identifiant, ni nom, ni date par compte. La question
 * à laquelle elle répond — « combien de comptes actifs bloquerait-on en
 * relevant `minVersion` ? » — n'a besoin d'aucune ligne individuelle.
 */
@Injectable()
export class AdminAppBuildsService {
  constructor(private readonly prismaService: PrismaService) {}

  async getAdoption(now: Date = new Date()): Promise<AppBuildAdoption> {
    // Pas de zéros de repli : « 0 compte actif » se lirait comme une mesure.
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }

    const since = new Date(now.getTime() - APP_BUILD_WINDOW_DAYS * DAY_MS);
    const seenInWindow = { lastAppSeenAt: { gte: since } };

    const rows = await this.prismaService.execute(async (prisma) => {
      const [allProfiles, neverSeen, buildGroups, versionGroups] =
        await Promise.all([
          prisma.userProfile.count(),
          prisma.userProfile.count({ where: { lastAppSeenAt: null } }),
          prisma.userProfile.groupBy({
            by: ['lastAppBuild'],
            where: seenInWindow,
            _count: { _all: true },
          }),
          prisma.userProfile.groupBy({
            by: ['lastAppVersion'],
            where: seenInWindow,
            _count: { _all: true },
          }),
        ]);
      return { allProfiles, neverSeen, buildGroups, versionGroups };
    });
    if (!rows) {
      throw new ServiceUnavailableException('Failed to read app build counts.');
    }

    // Le total vient des groupes par build, groupe « inconnu » compris : les
    // parts par build somment donc exactement à 1 avec `unknownBuild`.
    const activeProfiles = rows.buildGroups.reduce(
      (sum, group) => sum + group._count._all,
      0,
    );

    let unknownBuild = 0;
    const knownBuilds: { build: number; count: number }[] = [];
    for (const group of rows.buildGroups) {
      if (group.lastAppBuild === null) unknownBuild += group._count._all;
      else knownBuilds.push({ build: group.lastAppBuild, count: group._count._all });
    }
    knownBuilds.sort((a, b) => b.build - a.build);

    let atOrAbove = 0;
    const byBuild = knownBuilds.map(({ build, count }) => {
      atOrAbove += count;
      return {
        build,
        ...countShare(count, activeProfiles),
        shareAtOrAbove: ratio(atOrAbove, activeProfiles),
      };
    });

    let unknownVersion = 0;
    const byVersion: VersionShare[] = [];
    for (const group of rows.versionGroups) {
      if (group.lastAppVersion === null) unknownVersion += group._count._all;
      else {
        byVersion.push({
          version: group.lastAppVersion,
          ...countShare(group._count._all, activeProfiles),
        });
      }
    }
    byVersion.sort((a, b) => newestVersionFirst(a.version, b.version));

    return {
      windowDays: APP_BUILD_WINDOW_DAYS,
      since: since.toISOString(),
      generatedAt: now.toISOString(),
      activeProfiles,
      byBuild,
      byVersion,
      unknownBuild: countShare(unknownBuild, activeProfiles),
      unknownVersion: countShare(unknownVersion, activeProfiles),
      neverSeen: countShare(rows.neverSeen, rows.allProfiles),
      allProfiles: rows.allProfiles,
    };
  }
}
