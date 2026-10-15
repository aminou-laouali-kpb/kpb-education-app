import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import type { ScholarshipCycleStatus, ScholarshipDateConfidence } from '@prisma/client';

import { selectCurrentCycle } from '../../common/current-scholarship-cycle';
import {
  publicScholarshipWhere,
  servedCycleStatus,
} from '../../common/public-scholarship-where';
import { PrismaService } from '../prisma/prisma.service';
import {
  followedScholarshipIdsSql,
  type FollowedScholarshipRow,
} from './opening/scholarship-follow.query';
import {
  FOLLOWED_SCHOLARSHIPS_LIMIT,
  type FollowedDisplayStatus,
  type FollowedScholarshipItem,
  type FollowedScholarshipsResponse,
} from './opening/scholarship-opening.contract';
import {
  followFlags,
  hasFollowedScholarshipOptOut,
} from './scholarship-follow-state';

/** Les champs d'un cycle que la liste affiche. */
export interface FollowedCycle {
  academicYear: string;
  status: ScholarshipCycleStatus;
  dateConfidence: ScholarshipDateConfidence;
  opensAt: Date | null;
  closesAt: Date | null;
  estimatedOpenAt: Date | null;
  estimatedCloseAt: Date | null;
}

const STATUS_ORDER: Record<FollowedDisplayStatus, number> = {
  open: 0,
  opening_confirmed: 1,
  forecast: 2,
  closed: 3,
};

/**
 * L'état affiché d'une bourse suivie, à partir du cycle COURANT
 * (`selectCurrentCycle` : ouvert, sinon prévision, sinon le premier, sur des
 * cycles triés par année décroissante) passé par `servedCycleStatus`. Jamais
 * « le cycle de l'année la plus récente » : une campagne 2026-2027 ouverte et
 * confirmée, avec une prévision 2027-2028 déjà saisie, se lirait « prévision ».
 *
 * Une fiche sans cycle (héritée) a une date vraie : ouverte tant que sa date
 * limite n'est pas passée — la règle de `publicScholarshipWhere`.
 */
export function followedDisplayStatus(
  cycle: FollowedCycle | undefined,
  deadlineAt: Date | null,
  now: Date,
): FollowedDisplayStatus {
  if (!cycle) {
    return deadlineAt && deadlineAt.getTime() < now.getTime() ? 'closed' : 'open';
  }
  const served = servedCycleStatus(
    cycle.status,
    cycle.closesAt,
    cycle.estimatedCloseAt,
    now,
  );
  if (served === 'open') {
    // « Ouverte » n'est jamais dit avant la date d'ouverture confirmée.
    return cycle.opensAt && cycle.opensAt.getTime() > now.getTime()
      ? 'opening_confirmed'
      : 'open';
  }
  if (served === 'forecast') return 'forecast';
  return 'closed';
}

function iso(value: Date | null | undefined): string | null {
  return value ? value.toISOString() : null;
}

function time(value: string | null): number | null {
  return value === null ? null : Date.parse(value);
}

/** Croissant, dates absentes en dernier. */
function ascNullsLast(a: number | null, b: number | null): number {
  if (a === b) return 0;
  if (a === null) return 1;
  if (b === null) return -1;
  return a - b;
}

/** La date qui ordonne une ligne dans son groupe d'état. */
function sortTime(item: FollowedScholarshipItem): number | null {
  switch (item.displayStatus) {
    case 'open':
      return time(item.closesAt ?? item.estimatedCloseAt ?? item.deadlineAt);
    case 'opening_confirmed':
      return time(item.opensAt);
    case 'forecast':
      return time(item.estimatedOpenAt);
    case 'closed': {
      // Les plus récemment closes d'abord.
      const closed = time(item.closesAt ?? item.estimatedCloseAt ?? item.deadlineAt);
      return closed === null ? null : -closed;
    }
  }
}

/**
 * Ouvertes par clôture la plus proche, puis ouverture confirmée par date
 * d'ouverture, puis prévisions par ouverture estimée, puis closes.
 */
export function compareFollowedItems(
  a: FollowedScholarshipItem,
  b: FollowedScholarshipItem,
): number {
  return (
    STATUS_ORDER[a.displayStatus] - STATUS_ORDER[b.displayStatus] ||
    ascNullsLast(sortTime(a), sortTime(b)) ||
    a.title.localeCompare(b.title, 'fr') ||
    a.id.localeCompare(b.id)
  );
}

/**
 * La liste des bourses suivies d'un étudiant (chantier C) : favori, ou alerte
 * non mise en sourdine (`followedScholarshipIdsSql`). Les bourses closes y
 * restent — l'étudiant les suit pour la prochaine campagne — mais pas les
 * fiches retirées : non approuvées, inactives, jamais vérifiées, ou supprimées
 * (favori orphelin, ignoré par la requête partagée).
 */
@Injectable()
export class FollowedScholarshipsService {
  constructor(private readonly prismaService: PrismaService) {}

  async list(
    userId: string,
    lang: 'fr' | 'en',
    now: Date = new Date(),
  ): Promise<FollowedScholarshipsResponse> {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
    const data = await this.prismaService.execute(async (prisma) => {
      const pairs = await prisma.$queryRaw<FollowedScholarshipRow[]>(
        followedScholarshipIdsSql(userId),
      );
      const ids = pairs.map((pair) => pair.scholarshipId);
      const [scholarships, detailable, profile] = await Promise.all([
        ids.length === 0
          ? []
          : prisma.scholarship.findMany({
              where: {
                id: { in: ids },
                isActive: true,
                moderationStatus: 'approved',
                lastVerifiedAt: { not: null },
              },
              select: {
                id: true,
                nameFr: true,
                nameEn: true,
                countryId: true,
                countryNameFr: true,
                countryNameEn: true,
                deadlineAt: true,
                cycles: {
                  orderBy: { academicYear: 'desc' },
                  select: {
                    academicYear: true,
                    status: true,
                    dateConfidence: true,
                    opensAt: true,
                    closesAt: true,
                    estimatedOpenAt: true,
                    estimatedCloseAt: true,
                  },
                },
              },
            }),
        // La clause de la fiche elle-même : `detailAvailable` ne peut pas dire
        // « disponible » pour une fiche qui répondrait 404.
        ids.length === 0
          ? []
          : prisma.scholarship.findMany({
              where: { id: { in: ids }, ...publicScholarshipWhere(now) },
              select: { id: true },
            }),
        prisma.userProfile.findUnique({
          where: { id: userId },
          select: { disabledNotificationTypes: true },
        }),
      ]);
      return { pairs, scholarships, detailable, profile };
    });

    const pairs = new Map(
      (data?.pairs ?? []).map((pair) => [pair.scholarshipId, pair]),
    );
    const detailable = new Set((data?.detailable ?? []).map((row) => row.id));
    const items: FollowedScholarshipItem[] = [];
    for (const scholarship of data?.scholarships ?? []) {
      const pair = pairs.get(scholarship.id);
      if (!pair) continue;
      const cycle = selectCurrentCycle(scholarship.cycles);
      const flags = followFlags({
        favorite: pair.viaFavorite,
        activeAlert: pair.viaAlert,
        mutedAlert: pair.muted,
      });
      items.push({
        id: scholarship.id,
        title: lang === 'fr' ? scholarship.nameFr : scholarship.nameEn,
        countryId: scholarship.countryId,
        countryName:
          lang === 'fr' ? scholarship.countryNameFr : scholarship.countryNameEn,
        displayStatus: followedDisplayStatus(cycle, scholarship.deadlineAt, now),
        academicYear: cycle?.academicYear ?? null,
        opensAt: iso(cycle?.opensAt),
        closesAt: iso(cycle?.closesAt),
        estimatedOpenAt: iso(cycle?.estimatedOpenAt),
        estimatedCloseAt: iso(cycle?.estimatedCloseAt),
        deadlineAt: iso(scholarship.deadlineAt),
        dateConfidence: cycle?.dateConfidence ?? null,
        viaFavorite: flags.viaFavorite,
        viaAlert: flags.viaAlert,
        notifyOpening: flags.notifyOpening,
        detailAvailable: detailable.has(scholarship.id),
      });
    }
    items.sort(compareFollowedItems);

    return {
      items: items.slice(0, FOLLOWED_SCHOLARSHIPS_LIMIT),
      total: items.length,
      globalOptOut: hasFollowedScholarshipOptOut(
        data?.profile?.disabledNotificationTypes,
      ),
    };
  }
}
