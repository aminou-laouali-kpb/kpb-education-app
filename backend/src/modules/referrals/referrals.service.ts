import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomBytes } from 'crypto';

import { PrismaService } from '../prisma/prisma.service';

export interface ReferralSummary {
  code: string;
  /// Friends who redeemed this code (signed up).
  signedUpCount: number;
  /// …of those, how many have created at least one case (derived milestone).
  caseCreatedCount: number;
}

@Injectable()
export class ReferralsService {
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
  async redeem(
    userId: string,
    rawCode: string,
  ): Promise<{ attributed: boolean; alreadyReferred: boolean }> {
    const code = rawCode.trim().toUpperCase();
    const out = await this.prisma.execute(async (db) => {
      const referrer = await db.userProfile.findUnique({
        where: { referralCode: code },
        select: { id: true },
      });
      if (!referrer) throw new NotFoundException('Invalid referral code.');
      if (referrer.id === userId) {
        throw new ForbiddenException('You cannot use your own referral code.');
      }

      const existing = await db.referral.findUnique({
        where: { refereeProfileId: userId },
      });
      if (existing) {
        // Already attributed (to anyone) — do not reassign.
        return {
          attributed: existing.referrerId === referrer.id,
          alreadyReferred: true,
        };
      }

      // Parrainage croisé : A parrain de B puis B parrain de A, et chacun
      // gagnait un crédit (ferme à comptes).
      const reverse = await db.referral.findFirst({
        where: { referrerId: userId, refereeProfileId: referrer.id },
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

      await db.referral.create({
        data: { referrerId: referrer.id, refereeProfileId: userId },
      });
      return { attributed: true, alreadyReferred: false };
    });

    return out ?? { attributed: false, alreadyReferred: false };
  }
}

/** 8 characters, unambiguous (no 0/O, 1/I) — easy to dictate over WhatsApp. */
function generateReferralCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = randomBytes(8);
  let out = '';
  for (let i = 0; i < 8; i += 1) out += alphabet[bytes[i] % alphabet.length];
  return out;
}
