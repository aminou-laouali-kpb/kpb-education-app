import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { AppBuildThrottle } from './app-build-throttle';
import type { AppVersionReading } from './app-version-headers';

/**
 * Note sur le profil la dernière build vue, sans jamais peser sur la requête.
 *
 * Trois règles, et chacune protège les builds déjà installées :
 *  - l'écriture n'est PAS attendue : la requête ne gagne aucune latence, et un
 *    échec ne la fait jamais échouer (journalisé ici en debug, code borné ;
 *    `PrismaService.execute` garde en plus sa ligne d'erreur habituelle) ;
 *  - au plus une écriture par compte et par 6 h, plus tôt seulement quand
 *    l'app a changé de build ou de version (voir [AppBuildThrottle]) ;
 *  - SQL brut plutôt que `prisma.userProfile.update` : Prisma poserait
 *    `updatedAt`, que l'API renvoie et sur lequel le back-office trie — voir
 *    une requête passer n'est pas modifier un profil.
 */
@Injectable()
export class AppBuildTrackerService {
  private readonly logger = new Logger(AppBuildTrackerService.name);
  private readonly throttle = new AppBuildThrottle();

  constructor(private readonly prismaService: PrismaService) {}

  /** `true` si une écriture a été lancée. Ne jette pas, n'attend pas. */
  record(
    profileId: string,
    reading: AppVersionReading,
    now: Date = new Date(),
  ): boolean {
    try {
      if (!this.prismaService.isEnabled) return false;
      if (!this.throttle.shouldWrite(profileId, reading, now.getTime())) {
        return false;
      }
      void this.prismaService
        .execute((prisma) =>
          prisma.$executeRaw(buildSeenUpdate(profileId, reading, now)),
        )
        .catch((error: unknown) => {
          this.logger.debug(
            `Dernière build vue non enregistrée (${boundedErrorCode(error)}).`,
          );
        });
      return true;
    } catch (error) {
      this.logger.debug(
        `Dernière build vue non enregistrée (${boundedErrorCode(error)}).`,
      );
      return false;
    }
  }
}

/**
 * `COALESCE` : un en-tête absent ou illisible n'efface jamais une valeur
 * connue — une requête d'un autre client HTTP, ou d'une app dont la lecture
 * de version a échoué, ne fait pas redescendre un compte en « inconnu ». La
 * date de passage, elle, est toujours posée. Aucune ligne touchée (compte
 * supprimé entre-temps) n'est pas une erreur.
 *
 * `AT TIME ZONE 'UTC'` : Prisma envoie la date d'une requête brute comme un
 * instant, que Postgres convertirait dans le fuseau de la SESSION pour une
 * colonne `timestamp` sans fuseau. Prisma, lui, y lit de l'UTC : sans la
 * conversion explicite, une base réglée hors UTC décalerait la date (mesuré).
 */
export function buildSeenUpdate(
  profileId: string,
  reading: AppVersionReading,
  seenAt: Date,
): Prisma.Sql {
  return Prisma.sql`
    UPDATE "UserProfile"
    SET
      "lastAppVersion" = COALESCE(${reading.version}::text, "lastAppVersion"),
      "lastAppBuild" = COALESCE(${reading.build}::integer, "lastAppBuild"),
      "lastAppSeenAt" = (${seenAt}::timestamptz AT TIME ZONE 'UTC')
    WHERE "id" = ${profileId}
  `;
}

/** Un code Prisma (`P2010`) ou un nom d'erreur, jamais un message. */
function boundedErrorCode(error: unknown): string {
  if (error && typeof error === 'object' && 'code' in error) {
    const code = (error as { code?: unknown }).code;
    if (typeof code === 'string' && /^P\d{4}$/.test(code)) return code;
  }
  return error instanceof Error ? error.name : 'UNKNOWN';
}
