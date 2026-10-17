import {
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, type PrismaClient } from '@prisma/client';
import { randomBytes } from 'crypto';

import { PrismaService } from '../prisma/prisma.service';
import { hashAttributionSignals } from './campaigns/referral-signals';
import { normalizeReferralCode, refereeDisplayName } from './referral-code';

export interface ReferralSummary {
  code: string;
  /// Friends who redeemed this code (signed up).
  signedUpCount: number;
  /// …of those, how many have created at least one case (derived milestone).
  caseCreatedCount: number;
}

@Injectable()
export class ReferralsService {
  private readonly logger = new Logger(ReferralsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /// Get-or-create the caller's stable referral code + attribution stats.
  async getMine(userId: string): Promise<ReferralSummary> {
    const result = await this.prisma.execute(async (db) => {
      const profile = await db.userProfile.findUnique({
        where: { id: userId },
        select: { referralCode: true },
      });
      if (!profile) throw new NotFoundException('Profile not found.');

      let code = profile.referralCode;
      if (!code) {
        for (let attempt = 0; attempt < 5 && !code; attempt += 1) {
          const candidate = generateReferralCode();
          try {
            const updated = await db.userProfile.update({
              where: { id: userId },
              data: { referralCode: candidate },
            });
            code = updated.referralCode;
          } catch {
            // Unique collision — retry with a fresh code.
          }
        }
        if (!code) throw new Error('Could not allocate a referral code.');
      }

      const [signedUpCount, caseCreatedCount] = await Promise.all([
        db.referral.count({ where: { referrerId: userId } }),
        db.referral.count({
          where: { referrerId: userId, referee: { cases: { some: {} } } },
        }),
      ]);
      return { code, signedUpCount, caseCreatedCount };
    });

    // No database (demo mode): a non-persisted code so the UI still renders.
    return result ?? { code: 'KPBDEMO1', signedUpCount: 0, caseCreatedCount: 0 };
  }

  /// Attribute the caller (referee) to the owner of `code`. Idempotent: a
  /// profile can be referred at most once, and never by itself.
  ///
  /// Codes unifiés (compétition ambassadeurs) : le code saisi peut être un code
  /// PERSONNEL (`UserProfile.referralCode`) ou un code AMBASSADEUR
  /// (`Ambassador.code`, « KTOU-AB-1a2b3c ») ; la recherche ignore la casse, les
  /// espaces et les tirets (`normalizeReferralCode`). Dans les deux cas le
  /// filleul est rattaché au PROFIL du parrain par une ligne `Referral` — la
  /// seule source du comptage — et, si ce parrain est ambassadeur, une ligne
  /// `AmbassadorReferral` est créée pour son espace.
  async redeem(
    userId: string,
    rawCode: string,
    context: RedeemContext = {},
  ): Promise<{ attributed: boolean; alreadyReferred: boolean }> {
    const code = normalizeReferralCode(rawCode);
    if (code.length < 4) throw new NotFoundException('Invalid referral code.');
    const now = context.now ?? new Date();
    const out = await this.prisma.execute(async (db) => {
      const referrer = await this.resolveReferrer(db, code, rawCode);
      if (!referrer) throw new NotFoundException('Invalid referral code.');
      if (referrer.profileId === userId) {
        throw new ForbiddenException('You cannot use your own referral code.');
      }

      const existing = await db.referral.findUnique({
        where: { refereeProfileId: userId },
      });
      if (existing) {
        // Already attributed (to anyone) — do not reassign.
        return {
          result: {
            attributed: existing.referrerId === referrer.profileId,
            alreadyReferred: true,
          },
          created: null,
        };
      }

      // Parrainage croisé : A parrain de B puis B parrain de A, et chacun
      // gagnait un crédit (ferme à comptes).
      const reverse = await db.referral.findFirst({
        where: { referrerId: userId, refereeProfileId: referrer.profileId },
        select: { id: true },
      });
      if (reverse) {
        throw new ForbiddenException('Mutual referrals are not allowed.');
      }

      // Un code saisi après coup ne doit pas rémunérer un dossier déjà déposé :
      // le parrainage s'applique avant la première demande.
      const existingCases = await db.case.count({ where: { userId } });
      if (existingCases > 0) {
        throw new ForbiddenException(
          'A referral code must be used before your first request.',
        );
      }

      // Plafond de rattachements par code et par heure (anti-ferme). Au-delà,
      // le filleul réessaie plus tard ; rien n'est créé.
      const lastHour = await db.referral.count({
        where: {
          referrerId: referrer.profileId,
          createdAt: { gte: new Date(now.getTime() - 60 * 60 * 1000) },
        },
      });
      if (lastHour >= referralCodeHourlyLimit()) {
        throw new HttpException(
          {
            statusCode: HttpStatus.TOO_MANY_REQUESTS,
            code: 'referral_code_rate_limited',
            message: 'This code has reached its hourly limit. Try again later.',
          },
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      await db.referral.create({
        data: { referrerId: referrer.profileId, refereeProfileId: userId },
      });
      if (referrer.ambassadorId) {
        await this.attachToAmbassador(db, referrer.ambassadorId, userId);
      }
      return {
        result: { attributed: true, alreadyReferred: false },
        created: referrer,
      };
    });

    if (out?.created) {
      await this.recordSignal(userId, out.created, context);
    }
    return out?.result ?? { attributed: false, alreadyReferred: false };
  }

  /** Code normalisé → profil du parrain (+ sa ligne ambassadeur s'il en a une). */
  private async resolveReferrer(
    db: PrismaClient,
    code: string,
    rawCode: string,
  ): Promise<ResolvedReferrer | null> {
    const personal = await db.userProfile.findUnique({
      where: { referralCode: code },
      select: { id: true },
    });
    if (personal) {
      const amb = await db.ambassador.findUnique({
        where: { userProfileId: personal.id },
        select: { id: true },
      });
      return { profileId: personal.id, ambassadorId: amb?.id ?? null, codeKind: 'personal' };
    }
    const amb =
      (await db.ambassador.findUnique({
        where: { codeNormalized: code },
        select: { id: true, userProfileId: true },
      })) ??
      // Repli : une collision au rattrapage a laissé `codeNormalized` vide.
      (await db.ambassador.findFirst({
        where: { code: { equals: rawCode.trim(), mode: 'insensitive' } },
        select: { id: true, userProfileId: true },
      }));
    if (!amb) return null;
    return { profileId: amb.userProfileId, ambassadorId: amb.id, codeKind: 'ambassador' };
  }

  /** La ligne de l'espace ambassadeur (nom affiché « Prénom I. », jamais l'e-mail). */
  private async attachToAmbassador(
    db: PrismaClient,
    ambassadorId: string,
    refereeId: string,
  ): Promise<void> {
    const referee = await db.userProfile.findUnique({
      where: { id: refereeId },
      select: { fullName: true },
    });
    try {
      await db.ambassadorReferral.create({
        data: {
          ambassadorId,
          refereeProfileId: refereeId,
          refereeName: refereeDisplayName(referee?.fullName ?? ''),
        },
      });
      await db.ambassador.update({
        where: { id: ambassadorId },
        data: { totalReferrals: { increment: 1 } },
      });
    } catch (error) {
      // Déjà rattaché à un ambassadeur (contrainte unique) : rien à refaire.
      if (
        !(error instanceof Prisma.PrismaClientKnownRequestError) ||
        error.code !== 'P2002'
      ) {
        throw error;
      }
    }
  }

  /**
   * Empreintes anti-fraude (IP, plage, jetons push déjà enregistrés, identifiant
   * d'installation de la build 57). Au mieux : un échec ici ne doit jamais
   * annuler un rattachement déjà écrit.
   */
  private async recordSignal(
    refereeId: string,
    referrer: ResolvedReferrer,
    context: RedeemContext,
  ): Promise<void> {
    try {
      await this.prisma.execute(async (db) => {
        const tokens = await db.deviceToken.findMany({
          where: { userProfileId: refereeId },
          select: { token: true },
        });
        const hashes = hashAttributionSignals({
          ip: context.ip,
          pushTokens: tokens.map((t) => t.token),
          clientDeviceId: context.clientDeviceId,
        });
        await db.referralAttributionSignal.upsert({
          where: { refereeProfileId: refereeId },
          create: {
            refereeProfileId: refereeId,
            referrerProfileId: referrer.profileId,
            codeKind: referrer.codeKind,
            ...hashes,
          },
          update: {},
        });
      });
    } catch {
      this.logger.warn('Referral signal not recorded (non-blocking).');
    }
  }
}

export interface RedeemContext {
  /** Adresse IP vue par Express (`trust proxy` réglé dans main.ts). */
  ip?: string;
  /** En-tête `X-KPB-Device-Id` (build 57+) ; absent de l'app installée. */
  clientDeviceId?: string;
  now?: Date;
}

interface ResolvedReferrer {
  profileId: string;
  ambassadorId: string | null;
  codeKind: 'personal' | 'ambassador';
}

/** Rattachements maximum par code et par heure (`REFERRAL_CODE_HOURLY_LIMIT`, 30). */
export function referralCodeHourlyLimit(): number {
  const n = Number(process.env.REFERRAL_CODE_HOURLY_LIMIT ?? 30);
  return Number.isInteger(n) && n > 0 ? n : 30;
}

/** 8 characters, unambiguous (no 0/O, 1/I) — easy to dictate over WhatsApp. */
function generateReferralCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = randomBytes(8);
  let out = '';
  for (let i = 0; i < 8; i += 1) out += alphabet[bytes[i] % alphabet.length];
  return out;
}
