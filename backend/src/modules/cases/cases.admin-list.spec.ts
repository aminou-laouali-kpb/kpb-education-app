import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';

import { CaseStatus } from '../../common/enums/case-status.enum';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  ADMIN_DETAIL_TIMELINE_LIMIT,
  CasesService,
  decodeCaseCursor,
  encodeCaseCursor,
} from './cases.service';
import { ListAdminCasesQueryDto } from './dto/list-admin-cases.query.dto';

/**
 * La liste des dossiers de l'administration (audit avant la 59).
 *
 * Avant : un `findMany` sans limite, avec les tâches, l'historique, les
 * pièces et les notes de TOUS les dossiers — environ 1 250 dossiers et plus
 * de 80 000 événements en production, à chaque ouverture de la page. Ces
 * tests tiennent le contrat qui le remplace : une page bornée, aucune
 * relation en liste, filtres et recherche faits par le serveur, la portée du
 * conseiller conservée quel que soit le filtre.
 */

const RELATIONS = ['timelineEvents', 'tasks', 'documents', 'internalNotes', 'messages'];

function row(n: number, overrides: Record<string, unknown> = {}) {
  return {
    id: `case-${String(n).padStart(3, '0')}`,
    userId: 'user-1',
    referenceCode: `KPB-2026-${String(n).padStart(3, '0')}`,
    type: 'consultation',
    title: 'Consultation',
    status: 'submitted',
    description: 'd',
    contextLabel: 'c',
    nextStepTitle: 'n',
    nextStepDescription: 'nd',
    assignedAdvisorName: 'Awa KPB',
    createdAt: new Date(Date.UTC(2026, 10, 1, 0, 0, 0, 1000 - n)),
    updatedAt: new Date('2026-11-01T00:00:00.000Z'),
    user: { fullName: 'Awa Diallo', email: 'awa@example.test', preferredLanguage: 'fr' },
    ...overrides,
  };
}

function makeService(options: {
  rows?: unknown[];
  awaitingIds?: string[];
  lastMessages?: Array<{ caseId: string; senderRole: string; createdAt: Date }>;
  detail?: unknown;
  advisorRows?: Array<{ assignedAdvisorName: string | null }>;
  count?: number;
} = {}) {
  const findMany: any[] = [];
  const findFirst: any[] = [];
  const counts: any[] = [];
  const client = {
    case: {
      findMany: async (args: any) => {
        findMany.push(args);
        return args.distinct ? (options.advisorRows ?? []) : (options.rows ?? []);
      },
      findFirst: async (args: any) => {
        findFirst.push(args);
        return options.detail ?? null;
      },
      count: async (args: any) => {
        counts.push(args);
        return options.count ?? 0;
      },
    },
    $queryRaw: async (strings: TemplateStringsArray) =>
      strings.join('?').includes('JOIN LATERAL')
        ? (options.awaitingIds ?? []).map((id) => ({ id }))
        : (options.lastMessages ?? []),
  };
  const prisma = {
    isEnabled: true,
    execute: async (fn: (c: unknown) => Promise<unknown>) => fn(client),
  } as unknown as PrismaService;
  const service = new CasesService(
    prisma,
    { get: () => null } as unknown as ModuleRef,
    { sendToUser: async () => undefined } as unknown as PushSenderService,
  );
  return { service, findMany, findFirst, counts };
}

const admin = { id: 'adm-1', role: InternalRole.Admin, fullName: 'Admin' };
const counselor = { id: 'adm-7', role: InternalRole.Counselor, fullName: 'Awa KPB' };
const counselorScope = {
  OR: [
    { counsellor: { adminUserId: 'adm-7' } },
    { assignedAdvisorName: { equals: 'Awa KPB', mode: 'insensitive' } },
  ],
};

describe('liste des dossiers de l’administration — une page, pas tout', () => {
  it('ne lit jamais plus d’une page (50 par défaut) et aucune relation', async () => {
    const { service, findMany } = makeService({ rows: [row(1)] });

    await service.findAllForAdmin(admin);

    expect(findMany).toHaveLength(1);
    expect(findMany[0].take).toBe(51);
    expect(findMany[0].orderBy).toEqual([{ createdAt: 'desc' }, { id: 'desc' }]);
    for (const relation of RELATIONS) {
      expect(findMany[0].include).not.toHaveProperty(relation);
    }
    // De l'élève, trois champs — pas tout le profil.
    expect(findMany[0].include.user).toEqual({
      select: { fullName: true, email: true, preferredLanguage: true },
    });
  });

  it('les éléments ne portent ni tâches, ni historique, ni pièces, ni notes, ni messages', async () => {
    const { service } = makeService({ rows: [row(1)] });

    const { items } = await service.findAllForAdmin(admin);

    for (const key of ['tasks', 'timeline', 'documentRequests', 'internalNotes', 'messages']) {
      expect(items[0]).not.toHaveProperty(key);
    }
    expect(items[0]).toMatchObject({
      id: 'case-001',
      referenceCode: 'KPB-2026-001',
      studentName: 'Awa Diallo',
      studentEmail: 'awa@example.test',
      assignedAdvisorName: 'Awa KPB',
    });
  });

  it('garde `lastMessageAt` et `awaitingReply`, lus pour la seule page rendue', async () => {
    const at = new Date('2026-11-09T10:00:00.000Z');
    const { service } = makeService({
      rows: [row(1), row(2)],
      lastMessages: [{ caseId: 'case-001', senderRole: 'student', createdAt: at }],
    });

    const { items } = await service.findAllForAdmin(admin);

    expect(items[0]).toMatchObject({ awaitingReply: true, lastMessageAt: at.toISOString() });
    expect(items[1]).toMatchObject({ awaitingReply: false, lastMessageAt: null });
  });

  it('rend 50 dossiers et un curseur quand il en reste, `null` à la dernière page', async () => {
    const rows = Array.from({ length: 51 }, (_, i) => row(i + 1));
    const full = await makeService({ rows }).service.findAllForAdmin(admin);

    expect(full.items).toHaveLength(50);
    expect(full.nextCursor).not.toBeNull();
    expect(decodeCaseCursor(full.nextCursor!)).toEqual({
      createdAt: rows[49].createdAt,
      id: 'case-050',
    });

    const last = await makeService({ rows: rows.slice(0, 50) }).service.findAllForAdmin(admin);
    expect(last.items).toHaveLength(50);
    expect(last.nextCursor).toBeNull();
  });

  it('la page suivante reprend APRÈS le curseur (date, puis identifiant)', async () => {
    const { service, findMany } = makeService();
    const anchor = { createdAt: new Date('2026-11-05T08:00:00.123Z'), id: 'case-050' };

    await service.findAllForAdmin(admin, { cursor: encodeCaseCursor(anchor) });

    expect(findMany[0].where).toEqual({
      AND: [
        {
          OR: [
            { createdAt: { lt: anchor.createdAt } },
            { createdAt: anchor.createdAt, id: { lt: 'case-050' } },
          ],
        },
      ],
    });
  });

  it('refuse un curseur fabriqué', async () => {
    const { service, findMany } = makeService();
    for (const cursor of ['n-importe-quoi', Buffer.from('pas-une-date|x').toString('base64url')]) {
      await expect(service.findAllForAdmin(admin, { cursor })).rejects.toBeInstanceOf(
        BadRequestException,
      );
    }
    expect(findMany).toHaveLength(0);
  });

  it('borne la taille de page à 100', async () => {
    const { service, findMany } = makeService();
    await service.findAllForAdmin(admin, { limit: 5000 });
    await service.findAllForAdmin(admin, { limit: 10 });
    expect(findMany.map((call) => call.take)).toEqual([101, 11]);
  });
});

describe('liste des dossiers de l’administration — filtres côté serveur', () => {
  it('sans filtre, un admin lit tout (aucune condition)', async () => {
    const { service, findMany } = makeService();
    await service.findAllForAdmin(admin);
    expect(findMany[0].where).toBeUndefined();
  });

  it('statut, conseiller et recherche deviennent des conditions de la requête', async () => {
    const { service, findMany } = makeService();

    await service.findAllForAdmin(admin, {
      status: CaseStatus.UnderReview,
      advisor: '  Fatou Conseil ',
      q: '  awa   diallo ',
    });

    const contains = { contains: 'awa diallo', mode: 'insensitive' };
    expect(findMany[0].where).toEqual({
      AND: [
        { status: 'under_review' },
        { assignedAdvisorName: { equals: 'Fatou Conseil', mode: 'insensitive' } },
        {
          OR: [
            { referenceCode: contains },
            { title: contains },
            { user: { fullName: contains } },
            { user: { email: contains } },
          ],
        },
      ],
    });
  });

  it('« sans conseiller » : nom absent ou vide', async () => {
    const { service, findMany } = makeService();
    await service.findAllForAdmin(admin, { unassigned: true });
    expect(findMany[0].where).toEqual({
      AND: [{ OR: [{ assignedAdvisorName: null }, { assignedAdvisorName: '' }] }],
    });
  });

  it('« réponse attendue » : seulement les dossiers dont le dernier message vient de l’élève', async () => {
    const { service, findMany } = makeService({ awaitingIds: ['case-004', 'case-009'] });
    await service.findAllForAdmin(admin, { awaiting: true });
    expect(findMany[0].where).toEqual({ AND: [{ id: { in: ['case-004', 'case-009'] } }] });
  });

  it('un conseiller ne voit que SES dossiers, quel que soit le filtre', async () => {
    const { service, findMany } = makeService({ awaitingIds: ['case-004'] });

    await service.findAllForAdmin(counselor, {
      status: CaseStatus.Submitted,
      advisor: 'Fatou Conseil',
      q: 'KPB-2026',
      awaiting: true,
      unassigned: true,
    });

    const where = findMany[0].where;
    // La portée est la PREMIÈRE condition d'un ET : aucun filtre ne l'élargit.
    expect(where.AND[0]).toEqual(counselorScope);
    expect(where.AND).toHaveLength(6);
    expect(Object.keys(where)).toEqual(['AND']);
  });
});

describe('dossier ouvert dans l’administration', () => {
  const detailRow = (events: number) => ({
    ...row(1),
    timelineEvents: Array.from({ length: events }, (_, i) => ({
      id: `e-${i}`,
      title: 't',
      description: 'd',
      status: 'submitted',
      createdAt: new Date('2026-11-01T00:00:00.000Z'),
    })),
    tasks: [{ id: 't1', title: 'Relancer', status: 'open', createdAt: new Date() }],
    documents: [],
    internalNotes: [
      { id: 'n1', authorName: 'Fatou', authorRole: 'counselor', body: 'note', createdAt: new Date() },
    ],
  });

  it('charge les relations de CE dossier, historique borné, sans le fil', async () => {
    const { service, findFirst } = makeService({ detail: detailRow(2) });

    const detail = await service.findOneForAdmin('case-001', admin);

    expect(findFirst[0].where).toEqual({ id: 'case-001' });
    expect(Object.keys(findFirst[0].include)).toEqual(
      expect.arrayContaining(['timelineEvents', 'tasks', 'documents', 'internalNotes']),
    );
    expect(findFirst[0].include).not.toHaveProperty('messages');
    expect(findFirst[0].include.timelineEvents.take).toBe(ADMIN_DETAIL_TIMELINE_LIMIT + 1);
    expect(detail.tasks).toHaveLength(1);
    expect(detail.internalNotes).toHaveLength(1);
    expect(detail.timeline).toHaveLength(2);
    expect(detail.timelineTruncated).toBe(false);
    expect(detail).not.toHaveProperty('messages');
    expect(detail).toMatchObject({ awaitingReply: false, lastMessageAt: null });
  });

  it('dit quand l’historique est coupé', async () => {
    const { service } = makeService({ detail: detailRow(ADMIN_DETAIL_TIMELINE_LIMIT + 1) });
    const detail = await service.findOneForAdmin('case-001', admin);
    expect(detail.timeline).toHaveLength(ADMIN_DETAIL_TIMELINE_LIMIT);
    expect(detail.timelineTruncated).toBe(true);
  });
});

describe('résumé de la liste (compteur et conseillers)', () => {
  it('compte les réponses attendues dans la portée, pas sur la page', async () => {
    const { service, counts } = makeService({ awaitingIds: ['a', 'b', 'c'], count: 2 });

    const summary = await service.adminCaseListSummary(counselor);

    expect(summary.awaitingCount).toBe(2);
    expect(counts[0].where).toEqual({
      AND: [counselorScope, { id: { in: ['a', 'b', 'c'] } }],
    });
  });

  it('aucune réponse attendue : zéro, sans requête de comptage', async () => {
    const { service, counts } = makeService();
    expect((await service.adminCaseListSummary(admin)).awaitingCount).toBe(0);
    expect(counts).toHaveLength(0);
  });

  it('liste chaque conseiller une fois, triés, sans tenir compte de la casse', async () => {
    const { service, findMany } = makeService({
      advisorRows: [
        { assignedAdvisorName: 'Richard' },
        { assignedAdvisorName: 'awa kpb' },
        { assignedAdvisorName: ' Awa KPB ' },
        { assignedAdvisorName: '' },
        { assignedAdvisorName: 'Élodie' },
      ],
    });

    const summary = await service.adminCaseListSummary(counselor);

    expect(summary.advisors).toEqual(['awa kpb', 'Élodie', 'Richard']);
    expect(findMany[0].where.AND[0]).toEqual(counselorScope);
  });
});

describe('ListAdminCasesQueryDto', () => {
  const pipe = new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true });
  const validate = (value: unknown) =>
    pipe.transform(value, { type: 'query', metatype: ListAdminCasesQueryDto });

  it('accepte les filtres et convertit la taille de page', async () => {
    await expect(
      validate({ status: 'under_review', advisor: 'Awa', q: 'kpb', awaiting: 'true', limit: '25' }),
    ).resolves.toMatchObject({ status: 'under_review', limit: 25, awaiting: 'true' });
    await expect(validate({})).resolves.toEqual({});
  });

  it.each([
    [{ status: 'inconnu' }],
    [{ limit: '0' }],
    [{ limit: '101' }],
    [{ awaiting: 'oui' }],
    [{ q: 'x'.repeat(121) }],
    [{ tout: 'true' }],
  ])('refuse %j', async (query) => {
    await expect(validate(query)).rejects.toBeInstanceOf(BadRequestException);
  });
});
