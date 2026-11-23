import { BadRequestException, ConflictException } from '@nestjs/common';

import type { PrismaService } from '../../prisma/prisma.service';
import type { RecordPayoutDto } from './dto/referral-campaign.dto';
import { ReferralCampaignService } from './referral-campaign.service';

/**
 * Audit 2026-11-22, constat 8 : `recordPayout` lit le lauréat et écrit le
 * versement dans la même transaction, avec une écriture conditionnelle
 * (participantId lu + payoutStatus ≠ paid). Un forfait concurrent ou un
 * second versement ne peut plus marquer payé le mauvais lauréat ni écraser
 * la première référence.
 *
 * Le faux client applique réellement le WHERE de `updateMany`.
 */
type Award = {
  id: string;
  campaignId: string;
  rank: number;
  participantId: string | null;
  amountFcfa: number;
  recipient: string;
  payoutStatus: string;
  payoutReference: string | null;
  payoutMethod: string | null;
  paidAmountFcfa: number | null;
  paidAt: Date | null;
  paidByAdminId: string | null;
  note: string | null;
};

const actor = { id: 'admin_1', role: 'admin' } as never;

function setup(
  opts: {
    award?: Partial<Award>;
    minor?: Record<string, string>;
    /** Simule un forfait validé entre la lecture et l'écriture. */
    beforeWrite?: (award: Award) => void;
  } = {},
) {
  const award: Award = {
    id: 'award_1',
    campaignId: 'camp_1',
    rank: 1,
    participantId: 'p_awa',
    amountFcfa: 100000,
    recipient: 'ambassador',
    payoutStatus: 'pending',
    payoutReference: null,
    payoutMethod: null,
    paidAmountFcfa: null,
    paidAt: null,
    paidByAdminId: null,
    note: null,
    ...opts.award,
  };
  const minorStatus = opts.minor ?? {};
  const audits: unknown[] = [];
  const tx = {
    referralCampaignPrizeAward: {
      findUnique: async () => ({
        ...award,
        participant: award.participantId
          ? { minorStatus: minorStatus[award.participantId] ?? 'adult' }
          : null,
      }),
      updateMany: async ({
        where,
        data,
      }: {
        where: { id: string; participantId: string | null; payoutStatus: { not: string } };
        data: Partial<Award>;
      }) => {
        opts.beforeWrite?.(award);
        const ok =
          where.id === award.id &&
          where.participantId === award.participantId &&
          award.payoutStatus !== where.payoutStatus.not;
        if (!ok) return { count: 0 };
        Object.assign(award, data);
        return { count: 1 };
      },
      findUniqueOrThrow: async () => ({ ...award }),
    },
    adminAuditEvent: {
      create: async ({ data }: { data: unknown }) => {
        audits.push(data);
        return data;
      },
    },
  };
  const client = {
    referralCampaign: {
      findUnique: async () => ({ id: 'camp_1', slug: 'c', podiumValidatedAt: new Date('2026-11-12') }),
    },
    $transaction: async (fn: (t: typeof tx) => unknown) => fn(tx),
  };
  const prisma = {
    execute: async (fn: (c: typeof client) => unknown) => fn(client),
  } as unknown as PrismaService;
  const svc = new ReferralCampaignService(prisma);
  const pay = (dto: Partial<RecordPayoutDto>) =>
    svc.recordPayout('camp_1', 1, { payoutReference: 'WAVE-1', ...dto } as RecordPayoutDto, actor, 'rq');
  return { award, audits, pay };
}

describe('ReferralCampaignService.recordPayout — garde transactionnelle', () => {
  it('versement nominal : écrit et audite dans la transaction', async () => {
    const { award, audits, pay } = setup();
    const out = await pay({ participantId: 'p_awa' });
    expect(out).toMatchObject({ payoutStatus: 'paid', payoutReference: 'WAVE-1', paidAmountFcfa: 100000 });
    expect(award.paidByAdminId).toBe('admin_1');
    expect(audits).toHaveLength(1);
  });

  it('refuse un second versement et garde la première référence', async () => {
    const { award, audits, pay } = setup();
    await pay({ payoutReference: 'WAVE-1' });
    await expect(pay({ payoutReference: 'WAVE-2' })).rejects.toBeInstanceOf(ConflictException);
    expect(award.payoutReference).toBe('WAVE-1');
    expect(audits).toHaveLength(1);
  });

  it('forfait concurrent entre lecture et écriture : 409, rien n’est écrit', async () => {
    const { award, audits, pay } = setup({
      minor: { p_junior: 'minor' },
      beforeWrite: (a) => {
        // forfeitPrize a réattribué la MÊME ligne au 4e (mineur).
        a.participantId = 'p_junior';
        a.recipient = 'parent';
      },
    });
    await expect(pay({ recipient: 'ambassador' })).rejects.toBeInstanceOf(ConflictException);
    expect(award.payoutStatus).toBe('pending');
    expect(award.recipient).toBe('parent');
    expect(award.payoutReference).toBeNull();
    expect(audits).toHaveLength(0);
  });

  it('lauréat affiché différent du lauréat actuel : 409 prize_holder_changed', async () => {
    const { award, pay } = setup({ award: { participantId: 'p_junior' } });
    await expect(pay({ participantId: 'p_awa' })).rejects.toMatchObject({
      response: { code: 'prize_holder_changed' },
    });
    expect(award.payoutStatus).toBe('pending');
  });

  it('le contrôle mineur porte sur le lauréat lu dans la transaction', async () => {
    const { award, pay } = setup({ award: { participantId: 'p_junior' }, minor: { p_junior: 'minor' } });
    await expect(pay({ recipient: 'ambassador' })).rejects.toBeInstanceOf(BadRequestException);
    expect(award.payoutStatus).toBe('pending');
  });
});
