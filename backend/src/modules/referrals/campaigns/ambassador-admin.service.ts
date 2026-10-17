import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Prisma, PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';

import { PrismaService } from '../../prisma/prisma.service';
import { ambassadorCodeFor, normalizeReferralCode } from '../referral-code';
import { ReferralsService } from '../referrals.service';
import type { CampaignActor } from './referral-campaign.service';
import { isMinorAt } from './profile-completion';

/**
 * Activation des ambassadeurs par l'équipe — la seule voie depuis que
 * l'auto-activation est fermée côté serveur.
 *
 * Activer = créer (ou reprendre) la ligne `Ambassador` d'un compte existant,
 * la marquer `approvedAt`, et s'assurer que le compte a aussi son code
 * PERSONNEL : c'est celui que l'app installée affiche dans « Parrainage », et
 * les deux codes mènent au même profil (`POST /referrals/redeem`).
 *
 * L'espace « cash » de l'app reste fermé pour un ambassadeur activé ici
 * (`cashProgramEnabled` false à la création, inchangé sur une ligne existante).
 */
@Injectable()
export class AmbassadorAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly referrals: ReferralsService,
  ) {}

  /**
   * `execute` rend null sans base (mode démo) — ET quand l'opération elle-même
   * rend null (`findUnique` sans résultat). Le résultat est donc emballé pour
   * distinguer les deux.
   */
  private async db<T>(fn: (db: PrismaClient) => Promise<T>): Promise<T> {
    const out = await this.prisma.execute(async (client) => ({ value: await fn(client) }));
    if (out === null) throw new BadRequestException('Base de données indisponible.');
    return out.value;
  }

  async list(filters: { search?: string; approved?: 'yes' | 'no' } = {}) {
    const search = filters.search?.trim();
    const rows = await this.db(async (db) => {
      const profileIds = search
        ? (
            await db.userProfile.findMany({
              where: {
                OR: [
                  { email: { contains: search, mode: 'insensitive' } },
                  { fullName: { contains: search, mode: 'insensitive' } },
                ],
              },
              select: { id: true },
              take: 200,
            })
          ).map((p) => p.id)
        : null;
      return db.ambassador.findMany({
        where: {
          ...(profileIds
            ? {
                OR: [
                  { userProfileId: { in: profileIds } },
                  { code: { contains: search!, mode: 'insensitive' } },
                  { city: { contains: search!, mode: 'insensitive' } },
                ],
              }
            : {}),
          ...(filters.approved === 'yes' ? { approvedAt: { not: null } } : {}),
          ...(filters.approved === 'no' ? { approvedAt: null } : {}),
        },
        orderBy: { createdAt: 'desc' },
        take: 200,
      });
    });
    const profiles = await this.db((db) =>
      db.userProfile.findMany({
        where: { id: { in: rows.map((r) => r.userProfileId) } },
        select: { id: true, fullName: true, email: true, referralCode: true, birthDate: true },
      }),
    );
    const byId = new Map(profiles.map((p) => [p.id, p]));
    const now = new Date();
    return {
      items: rows.map((a) => {
        const p = byId.get(a.userProfileId);
        return {
          id: a.id,
          code: a.code,
          personalCode: p?.referralCode ?? null,
          displayName: a.displayName,
          city: a.city,
          campus: a.campus,
          fullName: p?.fullName ?? '',
          email: p?.email ?? '',
          minorStatus: p?.birthDate ? (isMinorAt(p.birthDate, now) ? 'minor' : 'adult') : 'unknown',
          approvedAt: a.approvedAt,
          cashProgramEnabled: a.cashProgramEnabled,
          createdAt: a.createdAt,
        };
      }),
    };
  }

  async activate(
    input: { email: string; city: string; displayName?: string; campus?: string },
    actor: CampaignActor,
    requestId: string,
  ) {
    const email = input.email.trim().toLowerCase();
    const profile = await this.db((db) =>
      db.userProfile.findUnique({
        where: { email },
        select: { id: true, fullName: true, accountType: true },
      }),
    );
    if (!profile) {
      throw new NotFoundException(
        'Aucun compte avec cet e-mail : l’ambassadeur doit d’abord s’inscrire dans l’app.',
      );
    }
    // Code personnel (« Parrainage » dans l'app) : alloué s'il n'existe pas.
    const personal = await this.referrals.getMine(profile.id);
    const displayName = (input.displayName ?? profile.fullName).trim().slice(0, 80);
    const now = new Date();
    const ambassador = await this.db((db) =>
      db.$transaction(async (tx) => {
        const existing = await tx.ambassador.findUnique({ where: { userProfileId: profile.id } });
        let row;
        if (existing) {
          row = await tx.ambassador.update({
            where: { id: existing.id },
            data: {
              approvedAt: existing.approvedAt ?? now,
              approvedByAdminId: existing.approvedAt ? existing.approvedByAdminId : actor.id,
              city: input.city.trim(),
              ...(input.displayName ? { displayName } : {}),
              ...(input.campus !== undefined ? { campus: input.campus.trim() } : {}),
              ...(existing.codeNormalized ? {} : { codeNormalized: normalizeReferralCode(existing.code) }),
            },
          });
        } else {
          // Le suffixe vient d'un hachage 32 bits de l'id : une collision est
          // rare mais possible. On essaie l'id salé avant de créer.
          let code = ambassadorCodeFor(profile.id, displayName);
          for (let salt = 1; salt <= 5; salt += 1) {
            const taken = await tx.ambassador.findFirst({
              where: { OR: [{ code }, { codeNormalized: normalizeReferralCode(code) }] },
              select: { id: true },
            });
            if (!taken) break;
            code = ambassadorCodeFor(`${profile.id}:${salt}`, displayName);
          }
          row = await tx.ambassador.create({
            data: {
              userProfileId: profile.id,
              code,
              codeNormalized: normalizeReferralCode(code),
              displayName,
              city: input.city.trim(),
              campus: input.campus?.trim() ?? '',
              approvedAt: now,
              approvedByAdminId: actor.id,
              cashProgramEnabled: false,
            },
          });
        }
        await this.audit(tx, {
          action: existing ? 'ambassador.approved_existing' : 'ambassador.created',
          entityId: row.id,
          actor,
          requestId,
          changes: { userProfileId: profile.id, city: row.city, code: row.code },
        });
        return row;
      }),
    );
    return {
      id: ambassador.id,
      code: ambassador.code,
      personalCode: personal.code,
      displayName: ambassador.displayName,
      city: ambassador.city,
      approvedAt: ambassador.approvedAt,
      cashProgramEnabled: ambassador.cashProgramEnabled,
      fullName: profile.fullName,
      email,
    };
  }

  async revoke(id: string, reason: string, actor: CampaignActor, requestId: string) {
    const existing = await this.db((db) => db.ambassador.findUnique({ where: { id } }));
    if (!existing) throw new NotFoundException('Ambassadeur introuvable.');
    await this.db((db) =>
      db.$transaction(async (tx) => {
        await tx.ambassador.update({
          where: { id },
          data: { approvedAt: null, approvedByAdminId: null },
        });
        await this.audit(tx, {
          action: 'ambassador.revoked',
          entityId: id,
          actor,
          requestId,
          reasonCode: reason.trim(),
          changes: { approvedAt: { from: existing.approvedAt?.toISOString() ?? null, to: null } },
        });
      }),
    );
    return { ok: true };
  }

  private async audit(
    tx: Prisma.TransactionClient,
    input: {
      action: string;
      entityId: string;
      actor: CampaignActor;
      requestId: string;
      reasonCode?: string;
      changes: Prisma.InputJsonValue;
    },
  ) {
    await tx.adminAuditEvent.create({
      data: {
        actorAdminId: input.actor.id,
        action: input.action,
        purposeCode: 'referral_campaign',
        entityType: 'Ambassador',
        entityId: input.entityId,
        requestId: input.requestId || randomUUID(),
        reasonCode: input.reasonCode?.slice(0, 500),
        result: 'success',
        changes: input.changes,
      },
    });
  }
}
