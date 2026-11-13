import { ModuleRef } from '@nestjs/core';
import { BadRequestException, NotFoundException } from '@nestjs/common';

import { InternalRole } from '../../common/enums/internal-role.enum';
import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { CaseLeadMailService } from './case-lead-mail.service';
import { CasesService } from './cases.service';

function makeService(): CasesService {
  const prisma = {
    isEnabled: true,
    execute: async (fn: (p: any) => Promise<any>) => {
      return fn({
        case: {
          findUnique: async () => ({
            id: 'case-1',
            userId: 'user-1',
            counsellor: null,
          }),
        },
        $transaction: async (fn2: (tx: any) => Promise<any>) => {
          const msg = { id: 'msg-1', senderName: '', senderRole: '', body: '', createdAt: new Date() };
          return fn2({
            caseMessage: {
              create: async ({ data }: { data: any }) => ({ ...msg, ...data }),
            },
            caseTimelineEvent: { create: async () => ({}) },
            case: {
              findUnique: async () => ({ id: 'case-1', userId: 'user-1', status: 'submitted', updatedAt: new Date() }),
              update: async () => ({}),
            },
          });
        },
      });
    },
    tryExecute: async () => null,
  } as unknown as PrismaService;

  const push = {
    sendToUser: async () => {},
  } as unknown as PushSenderService;

  const moduleRef = { get: () => null } as unknown as ModuleRef;

  return new CasesService(prisma, moduleRef, push);
}

describe('CasesService — createMessage role enforcement', () => {
  it('stores senderRole as "student" regardless of input when called from the student path', async () => {
    const svc = makeService();
    const spoofedInput = {
      body: 'hello',
      senderRole: 'advisor',
      senderName: 'KPB Advisor',
    };
    const result = await svc.createMessage(
      'case-1',
      spoofedInput,
      { userId: 'user-1', role: 'student', fullName: 'Student' },
    );
    expect(result).toMatchObject({
      senderRole: 'student',
      senderName: 'Student',
      body: 'hello',
    });
  });

  it.each([
    { body: '', label: 'empty' },
    { body: '   ', label: 'whitespace-only' },
    { body: 'x'.repeat(3001), label: 'oversized' },
  ])('rejects $label message bodies at the service boundary', async ({ body }) => {
    const svc = makeService();

    await expect(
      svc.createMessage('case-1', { body }, { userId: 'user-1', role: 'student' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});

describe('CasesService — realtime case authorization', () => {
  function makeAuthorizationService(caseRecord: {
    id: string;
    userId: string;
    counsellor: { adminUserId: string | null } | null;
  }) {
    const prisma = {
      isEnabled: true,
      execute: async (operation: (client: any) => Promise<any>) =>
        operation({
          case: { findUnique: async () => caseRecord },
        }),
    } as unknown as PrismaService;
    return new CasesService(
      prisma,
      { get: () => null } as unknown as ModuleRef,
      { sendToUser: async () => {} } as unknown as PushSenderService,
    );
  }

  const caseRecord = {
    id: 'case-1',
    userId: 'student-1',
    counsellor: { adminUserId: 'counselor-1' },
  };

  it('allows only the student who owns the case', async () => {
    const service = makeAuthorizationService(caseRecord);

    await expect(
      service.assertCanAccessMessaging('case-1', {
        userId: 'student-1',
        role: 'student',
      }),
    ).resolves.toMatchObject({ id: 'case-1' });
    await expect(
      service.assertCanAccessMessaging('case-1', {
        userId: 'student-other',
        role: 'student',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('allows administrators and commercial staff', async () => {
    const service = makeAuthorizationService(caseRecord);

    for (const role of [
      InternalRole.Admin,
      InternalRole.SuperAdmin,
      InternalRole.Commercial,
    ]) {
      await expect(
        service.assertCanAccessMessaging('case-1', {
          userId: `staff-${role}`,
          role,
        }),
      ).resolves.toMatchObject({ id: 'case-1' });
    }
  });

  it('allows only the counselor linked to the assigned counselor profile', async () => {
    const service = makeAuthorizationService(caseRecord);

    await expect(
      service.assertCanAccessMessaging('case-1', {
        userId: 'counselor-1',
        role: InternalRole.Counselor,
      }),
    ).resolves.toMatchObject({ id: 'case-1' });
    await expect(
      service.assertCanAccessMessaging('case-1', {
        userId: 'counselor-other',
        role: InternalRole.Counselor,
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('denies staff roles outside case operations', async () => {
    const service = makeAuthorizationService(caseRecord);

    await expect(
      service.assertCanAccessMessaging('case-1', {
        userId: 'content-1',
        role: InternalRole.ContentManager,
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});

describe('CasesService — referral crediting is fire-and-forget (KPB-77)', () => {
  it('still returns the created case even when crediting throws', async () => {
    const prisma = {
      isEnabled: true,
      // create() awaits this and treats `record` as the persisted case.
      execute: async () => ({ record: { id: 'case-1' }, duplicate: false }),
    } as unknown as PrismaService;
    const push = { sendToUser: async () => {} } as unknown as PushSenderService;
    // The credits service blows up — the case path must not.
    const moduleRef = {
      get: () => ({
        creditReferrerForFirstCase: async () => {
          throw new Error('boom');
        },
      }),
    } as unknown as ModuleRef;

    const svc = new CasesService(prisma, moduleRef, push);
    (svc as any).mapDbCase = () => ({ id: 'case-1', assignedAdvisorName: 'KPB' });

    const result = await svc.create(
      { type: 'study_abroad', title: 'x', description: 'y' } as any,
      'user-1',
    );
    expect(result.id).toBe('case-1');
  });
});

describe('CasesService — commercial lead email', () => {
  function makeCreateService(leadMail?: CaseLeadMailService) {
    const prisma = {
      isEnabled: true,
      execute: async () => ({ record: { id: 'case-1' }, duplicate: false }),
    } as unknown as PrismaService;
    const push = { sendToUser: async () => {} } as unknown as PushSenderService;
    const moduleRef = {
      get: () => ({ creditReferrerForFirstCase: async () => undefined }),
    } as unknown as ModuleRef;
    const svc = new CasesService(prisma, moduleRef, push, leadMail);
    (svc as any).mapDbCase = () => ({ id: 'case-1', assignedAdvisorName: 'KPB' });
    return svc;
  }

  it('notifies the commercials after the case is stored', async () => {
    const seen: unknown[] = [];
    const leadMail = {
      notifyNewCase: async (row: unknown) => {
        seen.push(row);
      },
    } as unknown as CaseLeadMailService;

    const result = await makeCreateService(leadMail).create(
      { type: 'consultation', title: 'x', description: 'y' } as any,
      'user-1',
    );

    expect(result.id).toBe('case-1');
    expect(seen).toEqual([{ id: 'case-1' }]);
  });

  it('still returns the created case when the lead email throws', async () => {
    const leadMail = {
      notifyNewCase: async () => {
        throw new Error('smtp down');
      },
    } as unknown as CaseLeadMailService;

    const result = await makeCreateService(leadMail).create(
      { type: 'consultation', title: 'x', description: 'y' } as any,
      'user-1',
    );

    expect(result.id).toBe('case-1');
  });
});

describe('CasesService — private document ownership', () => {
  it('queries a document through both the case id and its student owner', async () => {
    let receivedWhere: any;
    const prisma = {
      isEnabled: true,
      execute: async (operation: (client: any) => Promise<any>) =>
        operation({
          caseDocument: {
            findFirst: async ({ where }: { where: any }) => {
              receivedWhere = where;
              return {
                id: 'doc-1',
                title: 'Passport',
                fileUrl: 'storage://2026-07-11/123e4567-e89b-12d3-a456-426614174000.pdf',
              };
            },
          },
        }),
    } as unknown as PrismaService;
    const service = new CasesService(
      prisma,
      { get: () => null } as unknown as ModuleRef,
      { sendToUser: async () => {} } as unknown as PushSenderService,
    );

    await expect(
      service.getOwnedDocument('case-1', 'doc-1', 'student-1'),
    ).resolves.toMatchObject({ id: 'doc-1' });
    expect(receivedWhere).toEqual({
      id: 'doc-1',
      caseId: 'case-1',
      case: { userId: 'student-1' },
    });
  });

  it('allows only an assigned counsellor or administrator to read document bytes', async () => {
    const prisma = {
      isEnabled: true,
      execute: async (operation: (client: any) => Promise<any>) =>
        operation({
          caseDocument: {
            findFirst: async () => ({
              id: 'doc-1',
              title: 'Passport',
              fileUrl: 'storage://2026-07-11/123e4567-e89b-12d3-a456-426614174000.pdf',
              case: {
                assignedAdvisorName: 'Awa KPB',
                counsellor: { adminUserId: 'admin-linked' },
              },
            }),
          },
        }),
    } as unknown as PrismaService;
    const service = new CasesService(
      prisma,
      { get: () => null } as unknown as ModuleRef,
      { sendToUser: async () => {} } as unknown as PushSenderService,
    );

    await expect(
      service.getInternalDocument('case-1', 'doc-1', {
        role: 'counselor',
        fullName: 'awa kpb',
      }),
    ).resolves.toMatchObject({ id: 'doc-1' });
    await expect(
      service.getInternalDocument('case-1', 'doc-1', {
        role: 'counselor',
        fullName: 'Other advisor',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
    // Le conseiller lié par son profil y accède même sous un autre nom.
    await expect(
      service.getInternalDocument('case-1', 'doc-1', {
        role: 'counselor',
        fullName: 'Renamed advisor',
        id: 'admin-linked',
      }),
    ).resolves.toMatchObject({ id: 'doc-1' });
  });
});

describe('CasesService — student projection never leaks internal data', () => {
  const dbCase = {
    id: 'case-1',
    userId: 'user-1',
    referenceCode: 'KPB-1',
    type: 'orientation',
    title: 'Dossier',
    status: 'in_review',
    assignedAdvisorName: 'Fatou',
    assignedAdvisorPhone: '+221700000000',
    assignedAdvisorWhatsapp: '+221700000001',
    leadTag: 'hot',
    discussionMotive: 'prix',
    lastCommercialInteractionAt: new Date(),
    createdAt: new Date(),
    updatedAt: new Date(),
    internalNotes: [
      {
        id: 'n1',
        authorName: 'Fatou',
        authorRole: 'counselor',
        body: 'note interne',
        createdAt: new Date(),
      },
    ],
  };

  function makeListService(emitted: Record<string, unknown>[]) {
    const prisma = {
      isEnabled: true,
      execute: async (fn: (p: any) => Promise<any>) =>
        fn({
          case: {
            findMany: async () => [dbCase],
            findUnique: async () => dbCase,
            findFirst: async () => dbCase,
          },
          $transaction: async (fn2: (tx: any) => Promise<any>) =>
            fn2({
              case: {
                findUnique: async () => dbCase,
                update: async () => dbCase,
              },
              caseTimelineEvent: { create: async () => ({}) },
            }),
        }),
      tryExecute: async () => null,
    } as unknown as PrismaService;
    const moduleRef = {
      get: () => ({
        emitCaseUpdated: (_id: string, payload: Record<string, unknown>) =>
          emitted.push(payload),
      }),
    } as unknown as ModuleRef;
    return new CasesService(
      prisma,
      moduleRef,
      { sendToUser: async () => {} } as unknown as PushSenderService,
    );
  }

  function expectNoInternal(payload: any) {
    expect(payload.internalNotes).toEqual([]);
    expect(payload.assignedAdvisorPhone).toBeNull();
    expect(payload.assignedAdvisorWhatsapp).toBeNull();
    expect(payload.leadTag).toBeNull();
    expect(payload.discussionMotive).toBeNull();
    expect(JSON.stringify(payload)).not.toContain('note interne');
  }

  it('GET /cases for a student hides notes, advisor phones and commercial fields', async () => {
    const [item] = await makeListService([]).findAll('user-1');
    expectNoInternal(item);
  });

  it('the admin list still includes internal fields, without the relations', async () => {
    const { items } = await makeListService([]).findAllForAdmin();
    expect(items[0].assignedAdvisorPhone).toBe('+221700000000');
    expect(items[0].leadTag).toBe('hot');
    // Les notes se lisent pour le dossier ouvert, pas dans la liste.
    expect(items[0]).not.toHaveProperty('internalNotes');
  });

  it('the opened case still includes internal notes for staff', async () => {
    const detail = await makeListService([]).findOneForAdmin('case-1', {
      id: 'a',
      role: InternalRole.Admin,
      fullName: 'A',
    });
    expect(detail.internalNotes).toHaveLength(1);
    expect(detail.assignedAdvisorPhone).toBe('+221700000000');
  });

  it('broadcasts the student projection on caseUpdated after an admin update', async () => {
    const emitted: Record<string, unknown>[] = [];
    const result = await makeListService(emitted).update('case-1', {
      status: 'in_review',
    } as any);
    expect(result.internalNotes).toHaveLength(1);
    expect(emitted).toHaveLength(1);
    expectNoInternal(emitted[0]);
  });
});

describe('CasesService — counselor scope on admin routes', () => {
  function makeScoped(found: boolean) {
    const calls: any[] = [];
    const prisma = {
      isEnabled: true,
      execute: async (fn: (p: any) => Promise<any>) =>
        fn({
          case: {
            findFirst: async (args: any) => {
              calls.push(args);
              return found ? { id: 'case-1' } : null;
            },
            findMany: async (args: any) => {
              calls.push(args);
              return [];
            },
          },
        }),
      tryExecute: async () => null,
    } as unknown as PrismaService;
    const service = new CasesService(
      prisma,
      { get: () => null } as unknown as ModuleRef,
      { sendToUser: async () => {} } as unknown as PushSenderService,
    );
    return { service, calls };
  }
  const counselor = { id: 'admin-7', role: InternalRole.Counselor, fullName: 'Awa KPB' };

  it('lists only the cases assigned to the counselor', async () => {
    const { service, calls } = makeScoped(true);
    await service.findAllForAdmin(counselor);
    expect(calls[0].where.AND[0].OR).toEqual([
      { counsellor: { adminUserId: 'admin-7' } },
      { assignedAdvisorName: { equals: 'Awa KPB', mode: 'insensitive' } },
    ]);
  });

  it('opens only a case assigned to the counselor (404 otherwise)', async () => {
    const { service, calls } = makeScoped(false);
    await expect(
      service.findOneForAdmin('case-9', counselor),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(calls[0].where).toMatchObject({
      id: 'case-9',
      OR: [
        { counsellor: { adminUserId: 'admin-7' } },
        { assignedAdvisorName: { equals: 'Awa KPB', mode: 'insensitive' } },
      ],
    });
  });

  it("refuses a counselor writing to a case that isn't theirs", async () => {
    const { service } = makeScoped(false);
    await expect(
      service.assertStaffCanAccessCase('case-9', counselor),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('lets admins through without a lookup', async () => {
    const { service, calls } = makeScoped(false);
    await service.assertStaffCanAccessCase('case-9', {
      id: 'a',
      role: InternalRole.Admin,
      fullName: 'A',
    });
    expect(calls).toHaveLength(0);
  });
});

describe('CasesService — ordre du fil de messages (revue avant la 58)', () => {
  it('demande et rend les messages du plus ancien au plus récent', async () => {
    const t0 = new Date('2026-11-01T10:00:00Z');
    const t1 = new Date('2026-11-01T11:00:00Z');
    let include: any;
    const prisma = {
      isEnabled: true,
      execute: async (fn: (p: any) => Promise<any>) =>
        fn({
          case: {
            findUnique: async (args: any) => {
              include = args.include;
              return {
                id: 'case-1',
                userId: 'user-1',
                createdAt: t0,
                updatedAt: t1,
                timelineEvents: [],
                documents: [],
                tasks: [],
                internalNotes: [],
                messages: [
                  { id: 'm1', senderName: 'KPB', senderRole: 'system', body: 'Merci', createdAt: t0 },
                  { id: 'm2', senderName: 'Awa', senderRole: 'student', body: 'Bonjour', createdAt: t1 },
                ],
              };
            },
          },
        }),
      tryExecute: async () => null,
    } as unknown as PrismaService;
    const svc = new CasesService(
      prisma,
      { get: () => null } as unknown as ModuleRef,
      { sendToUser: async () => {} } as unknown as PushSenderService,
    );

    const result = (await svc.findOne('case-1', 'user-1')) as any;

    expect(include.messages.orderBy).toEqual({ createdAt: 'asc' });
    expect(result.messages.map((m: any) => m.id)).toEqual(['m1', 'm2']);
  });
});
