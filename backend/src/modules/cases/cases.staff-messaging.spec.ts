import { ModuleRef } from '@nestjs/core';
import { NotFoundException } from '@nestjs/common';

import { InternalRole } from '../../common/enums/internal-role.enum';
import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { CaseLeadMailService } from './case-lead-mail.service';
import { CasesService, STAFF_ALERT_QUIET_MS } from './cases.service';

/**
 * Build 59 : la messagerie des dossiers marche dans les deux sens. L'équipe
 * lit le fil page par page et répond ; l'élève reçoit un push ; l'équipe est
 * alertée par e-mail quand un élève écrit (une fois par rafale).
 */

type Row = {
  id: string;
  caseId: string;
  senderName: string;
  senderRole: string;
  body: string;
  createdAt: Date;
  clientMessageId: string | null;
};

const at = (minutes: number) =>
  new Date(Date.UTC(2026, 10, 9, 10, 0) + minutes * 60_000);

function makeWorld(opts: {
  caseRow?: Record<string, unknown> | null;
  messages?: Row[];
  recentStudentMessages?: number;
}) {
  const messages: Row[] = [...(opts.messages ?? [])];
  const pushes: any[] = [];
  const mails: any[] = [];
  const caseRow =
    opts.caseRow === undefined
      ? {
          id: 'case-1',
          userId: 'user-1',
          assignedAdvisorName: 'Richard Ahogle',
          referenceCode: 'KPB-2026-0001',
          title: 'Bourse',
          counsellor: {
            adminUserId: 'admin-richard',
            email: 'r@kpb.test',
            isActive: true,
          },
          user: { fullName: 'Awa Diallo', email: 'awa@test.dev' },
        }
      : opts.caseRow;
  const client = {
    case: { findUnique: async () => caseRow },
    caseMessage: {
      findUnique: async () => null,
      findFirst: async ({ where }: any) =>
        messages.find((m) => m.id === where.id && m.caseId === where.caseId) ??
        null,
      findMany: async ({ where, take }: any) =>
        messages
          .filter((m) => m.caseId === where.caseId)
          .filter(
            (m) => !where.createdAt?.lt || m.createdAt < where.createdAt.lt,
          )
          .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
          .slice(0, take),
      count: async () => opts.recentStudentMessages ?? 0,
    },
    $transaction: async (fn: (tx: any) => Promise<any>) =>
      fn({
        caseMessage: {
          create: async ({ data }: any) => {
            const created = {
              id: `msg-${messages.length + 1}`,
              createdAt: at(60),
              ...data,
            };
            messages.push(created);
            return created;
          },
        },
        case: { update: async () => ({}) },
      }),
  };
  const prisma = {
    isEnabled: true,
    execute: async (fn: (p: any) => Promise<any>) => fn(client),
    tryExecute: async () => null,
  } as unknown as PrismaService;
  const push = {
    sendToUser: async (...args: any[]) => {
      pushes.push(args);
    },
  } as unknown as PushSenderService;
  const leadMail = {
    notifyStudentMessage: async (record: any) => {
      mails.push(record);
    },
  } as unknown as CaseLeadMailService;
  const svc = new CasesService(
    prisma,
    {
      get: () => ({ emitCaseMessage: () => {}, emitCaseUpdated: () => {} }),
    } as unknown as ModuleRef,
    push,
    leadMail,
  );
  return { svc, messages, pushes, mails };
}

const row = (i: number, role = 'student'): Row => ({
  id: `m${i}`,
  caseId: 'case-1',
  senderName: role === 'student' ? 'Awa' : 'Richard',
  senderRole: role,
  body: `message ${i}`,
  createdAt: at(i),
  clientMessageId: null,
});

const commercial = {
  id: 'admin-jojo',
  role: InternalRole.Commercial,
  fullName: 'Jojo',
};

describe('CasesService — fil des messages côté équipe', () => {
  it('rend la page la plus récente, du plus ancien au plus récent, et dit s’il en reste', async () => {
    const { svc } = makeWorld({
      messages: Array.from({ length: 5 }, (_, i) => row(i)),
    });
    const page = await svc.findMessagesForAdmin('case-1', commercial, {
      limit: 3,
    });
    expect(page.items.map((m) => m.id)).toEqual(['m2', 'm3', 'm4']);
    expect(page.hasMore).toBe(true);
  });

  it('`before` charge les messages plus anciens que celui donné', async () => {
    const { svc } = makeWorld({
      messages: Array.from({ length: 5 }, (_, i) => row(i)),
    });
    const page = await svc.findMessagesForAdmin('case-1', commercial, {
      limit: 3,
      before: 'm2',
    });
    expect(page.items.map((m) => m.id)).toEqual(['m0', 'm1']);
    expect(page.hasMore).toBe(false);
  });

  it('un `before` inconnu dans ce dossier est un 404', async () => {
    const { svc } = makeWorld({ messages: [row(0)] });
    await expect(
      svc.findMessagesForAdmin('case-1', commercial, { before: 'ailleurs' }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('un conseiller attribué par son NOM lit le fil (même portée que la liste)', async () => {
    const { svc } = makeWorld({
      caseRow: {
        id: 'case-1',
        userId: 'user-1',
        assignedAdvisorName: 'Richard Ahogle',
        counsellor: null,
      },
      messages: [row(0)],
    });
    const counselor = {
      id: 'admin-x',
      role: InternalRole.Counselor,
      fullName: ' richard ahogle ',
    };
    await expect(
      svc.findMessagesForAdmin('case-1', counselor),
    ).resolves.toBeDefined();
  });

  it('un conseiller qui n’est pas attribué ne lit pas le fil', async () => {
    const { svc } = makeWorld({ messages: [row(0)] });
    const other = {
      id: 'admin-y',
      role: InternalRole.Counselor,
      fullName: 'Autre',
    };
    await expect(
      svc.findMessagesForAdmin('case-1', other),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('CasesService — alertes', () => {
  it('une réponse de l’équipe pousse une notification à l’élève, vers son dossier', async () => {
    const { svc, pushes, mails } = makeWorld({});
    await svc.createMessage(
      'case-1',
      { body: 'Bonjour Awa, voici la suite.' },
      { userId: 'admin-jojo', role: InternalRole.Commercial, fullName: 'Jojo' },
    );
    expect(pushes).toHaveLength(1);
    const [userId, title, body, data] = pushes[0];
    expect(userId).toBe('user-1');
    expect(title).toBe('Jojo t’a répondu');
    expect(body).toBe('Bonjour Awa, voici la suite.');
    expect(data).toMatchObject({
      type: 'case_message',
      caseId: 'case-1',
      route: '/cases/case-1',
    });
    expect(mails).toHaveLength(0);
  });

  it('un long message est tronqué dans la notification', async () => {
    const { svc, pushes } = makeWorld({});
    await svc.createMessage(
      'case-1',
      { body: 'x'.repeat(400) },
      { userId: 'admin-jojo', role: InternalRole.Commercial, fullName: 'Jojo' },
    );
    expect((pushes[0][2] as string).length).toBeLessThanOrEqual(118);
  });

  it('un message d’élève alerte l’équipe par e-mail, sans push à l’élève', async () => {
    const { svc, pushes, mails } = makeWorld({});
    await svc.createMessage(
      'case-1',
      { body: 'Bonjour' },
      { userId: 'user-1', role: 'student' },
    );
    expect(pushes).toHaveLength(0);
    expect(mails).toHaveLength(1);
    expect(mails[0]).toMatchObject({ referenceCode: 'KPB-2026-0001' });
  });

  it('une rafale de messages d’élève ne produit qu’une alerte', async () => {
    const { svc, mails } = makeWorld({ recentStudentMessages: 2 });
    await svc.createMessage(
      'case-1',
      { body: 'Encore moi' },
      { userId: 'user-1', role: 'student' },
    );
    expect(mails).toHaveLength(0);
    expect(STAFF_ALERT_QUIET_MS).toBe(30 * 60 * 1000);
  });
});
