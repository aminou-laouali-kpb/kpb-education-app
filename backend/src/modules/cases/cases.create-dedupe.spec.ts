import { ModuleRef } from '@nestjs/core';

import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { CaseLeadMailService } from './case-lead-mail.service';
import { CasesService, DUPLICATE_CASE_WINDOW_MS } from './cases.service';
import { CreateCaseDto } from './dto/create-case.dto';

/**
 * Dossiers créés en double (audit avant la 59).
 *
 * Sur un réseau instable, `POST /cases` arrive mais la réponse se perd : l'app
 * garde le dossier sous un identifiant local et le renvoie à sa synchronisation
 * suivante. Le serveur créait alors un second dossier, attribué au conseiller
 * suivant du tourniquet. Les apps installées n'envoient aucun identifiant de
 * demande : le renvoi est reconnu à son contenu.
 *
 * Ces tests tiennent la logique ; `cases-create-dedupe.postgres.spec.ts`
 * prouve la requête et le verrou sur un vrai Postgres.
 */

const NOW = new Date('2026-11-10T10:00:00.000Z');

const INPUT = {
  type: 'consultation',
  title: 'Licence informatique',
  description: 'Je veux être accompagné.',
  contextLabel: 'Université de Lille',
} as unknown as CreateCaseDto;

function caseRow(overrides: Record<string, unknown> = {}) {
  return {
    id: 'case-existing',
    userId: 'user-1',
    referenceCode: 'KPB-2026-041',
    type: 'consultation',
    title: INPUT.title,
    description: INPUT.description,
    contextLabel: INPUT.contextLabel,
    status: 'counselor_assigned',
    assignedAdvisorName: 'Jojo',
    createdAt: NOW,
    updatedAt: NOW,
    scholarshipId: null,
    messages: [],
    timelineEvents: [],
    tasks: [],
    documents: [],
    internalNotes: [],
    ...overrides,
  };
}

function makeService(existing: unknown | null, scholarships: string[] = []) {
  const lookups: any[] = [];
  const created: any[] = [];
  const locks: string[] = [];
  const pushes: unknown[][] = [];
  const credits: string[] = [];
  const mails: unknown[] = [];
  const tx = {
    $executeRaw: async (strings: TemplateStringsArray, ...values: unknown[]) => {
      if (strings.join('?').includes('pg_advisory_xact_lock')) {
        locks.push(String(values[0]));
      }
      return 1;
    },
    counsellor: { findMany: async () => [] },
    scholarship: {
      findUnique: async ({ where }: { where: { id: string } }) =>
        scholarships.includes(where.id) ? { id: where.id } : null,
    },
    case: {
      findFirst: async (args: any) => {
        lookups.push(args);
        return existing;
      },
      create: async ({ data }: { data: Record<string, unknown> }) => {
        created.push(data);
        return { id: 'case-new', seq: 42, createdAt: NOW };
      },
      update: async () => ({}),
      findUnique: async () => caseRow({ id: 'case-new' }),
    },
    caseTimelineEvent: { create: async () => ({}) },
    caseMessage: { create: async () => ({}) },
  };
  const prisma = {
    isEnabled: true,
    execute: async (fn: (client: unknown) => Promise<unknown>) =>
      fn({ $transaction: async (body: (t: typeof tx) => Promise<unknown>) => body(tx) }),
  } as unknown as PrismaService;
  const push = {
    sendToUser: async (...args: unknown[]) => {
      pushes.push(args);
    },
  } as unknown as PushSenderService;
  const moduleRef = {
    get: () => ({
      creditReferrerForFirstCase: async (userId: string) => {
        credits.push(userId);
      },
    }),
  } as unknown as ModuleRef;
  const leadMail = {
    notifyNewCase: async (record: unknown) => {
      mails.push(record);
    },
  } as unknown as CaseLeadMailService;
  return {
    service: new CasesService(prisma, moduleRef, push, leadMail),
    lookups,
    created,
    locks,
    pushes,
    credits,
    mails,
  };
}

describe('POST /cases — un renvoi ne crée pas un second dossier', () => {
  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(NOW);
  });
  afterEach(() => {
    jest.useRealTimers();
  });

  it('la même demande rend le dossier existant, sans rien créer', async () => {
    const { service, created } = makeService(caseRow());

    const result = await service.create(INPUT, 'user-1');

    expect(result.id).toBe('case-existing');
    expect(result.referenceCode).toBe('KPB-2026-041');
    expect(result.assignedAdvisorName).toBe('Jojo');
    expect(created).toEqual([]);
  });

  it('un renvoi ne renvoie ni notification, ni e-mail à l’équipe, ni crédit de parrainage', async () => {
    const { service, pushes, mails, credits } = makeService(caseRow());

    await service.create(INPUT, 'user-1');

    expect(pushes).toEqual([]);
    expect(mails).toEqual([]);
    expect(credits).toEqual([]);
  });

  it('la réponse reste celle de l’élève : aucune donnée interne', async () => {
    const { service } = makeService(
      caseRow({
        assignedAdvisorPhone: '+221700000000',
        leadTag: 'hot',
        internalNotes: [
          { id: 'n1', authorName: 'F', authorRole: 'counselor', body: 'interne', createdAt: NOW },
        ],
      }),
    );

    const result = await service.create(INPUT, 'user-1');

    expect(result.internalNotes).toEqual([]);
    expect(result.assignedAdvisorPhone).toBeNull();
    expect(result.leadTag).toBeNull();
  });

  it('« identique » = même élève, type, titre, description, contexte et bourse, non clos, dans la fenêtre', async () => {
    const { service, lookups } = makeService(null, ['eiffel']);

    await service.create(
      { ...INPUT, scholarshipId: 'eiffel' } as unknown as CreateCaseDto,
      'user-1',
    );

    expect(lookups).toHaveLength(1);
    expect(lookups[0].where).toEqual({
      userId: 'user-1',
      type: 'consultation',
      title: 'Licence informatique',
      description: 'Je veux être accompagné.',
      contextLabel: 'Université de Lille',
      scholarshipId: 'eiffel',
      status: { notIn: ['completed', 'rejected', 'cancelled'] },
      createdAt: { gte: new Date(NOW.getTime() - DUPLICATE_CASE_WINDOW_MS) },
    });
    expect(lookups[0].orderBy).toEqual({ createdAt: 'desc' });
  });

  it('la fenêtre couvre une synchronisation le lendemain, pas la semaine suivante', () => {
    expect(DUPLICATE_CASE_WINDOW_MS).toBeGreaterThanOrEqual(12 * 60 * 60 * 1000);
    expect(DUPLICATE_CASE_WINDOW_MS).toBeLessThanOrEqual(48 * 60 * 60 * 1000);
  });

  it('une bourse retirée se compare comme « sans bourse », comme à la création', async () => {
    const { service, lookups } = makeService(null, []);
    await service.create(
      { ...INPUT, scholarshipId: 'retiree' } as unknown as CreateCaseDto,
      'user-1',
    );
    expect(lookups[0].where.scholarshipId).toBeNull();
  });

  it('deux envois simultanés du même élève passent l’un après l’autre (verrou par élève)', async () => {
    const { service, locks } = makeService(null);
    await service.create(INPUT, 'user-1');
    expect(locks).toEqual(['case-create:user-1']);
  });

  it('aucune demande identique : le dossier est créé, avec ses effets', async () => {
    const { service, created, pushes, mails, credits } = makeService(null);

    const result = await service.create(INPUT, 'user-1');

    expect(result.id).toBe('case-new');
    expect(created).toHaveLength(1);
    expect(created[0]).toMatchObject({ userId: 'user-1', title: 'Licence informatique' });
    expect(pushes).toHaveLength(1);
    expect(mails).toHaveLength(1);
    expect(credits).toEqual(['user-1']);
  });
});
