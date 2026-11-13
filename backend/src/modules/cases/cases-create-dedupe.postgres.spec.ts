import { randomUUID } from 'node:crypto';

import { ModuleRef } from '@nestjs/core';
import { AccountType, CaseStatus, PrismaClient } from '@prisma/client';

import { CaseType } from '../../common/enums/case-type.enum';
import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { CasesService, DUPLICATE_CASE_WINDOW_MS } from './cases.service';
import { CreateCaseDto } from './dto/create-case.dto';

/**
 * Dossiers créés en double, sur un vrai Postgres : la comparaison « demande
 * identique » est un `where`, et deux envois simultanés ne sont départagés que
 * par le verrou consultatif — aucun test unitaire ne dit si l'un ou l'autre
 * tient.
 *
 *   createdb -h /tmp kpb_cases_admin_test
 *   DATABASE_URL=postgresql:///kpb_cases_admin_test?host=/tmp npx prisma migrate deploy
 *   KPB_RUN_POSTGRES_INTEGRATION=true DATABASE_URL=… npm run test:integration:cases-admin
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres(
  'POST /cases — pas de dossier en double, intégration PostgreSQL',
  () => {
    const prisma = new PrismaClient();
    const s = randomUUID();
    const awaId = `dup-awa-${s}`;
    const moussaId = `dup-moussa-${s}`;
    const pushes: string[] = [];
    const service = new CasesService(
      {
        isEnabled: true,
        execute: (fn: (p: PrismaClient) => Promise<unknown>) => fn(prisma),
        tryExecute: (fn: (p: PrismaClient) => Promise<unknown>) => fn(prisma),
      } as unknown as PrismaService,
      {
        get: () => ({ creditReferrerForFirstCase: async () => undefined }),
      } as unknown as ModuleRef,
      {
        sendToUser: async (userId: string) => {
          pushes.push(userId);
        },
      } as unknown as PushSenderService,
    );

    const input = (overrides: Partial<CreateCaseDto> = {}): CreateCaseDto =>
      ({
        type: CaseType.Consultation,
        title: `Licence informatique ${s}`,
        description: 'Je veux être accompagné.',
        contextLabel: 'Université de Lille',
        preferredContactMethod: 'whatsapp',
        ...overrides,
      }) as CreateCaseDto;

    const casesOf = (userId: string, title: string) =>
      prisma.case.findMany({ where: { userId, title }, orderBy: { seq: 'asc' } });

    beforeAll(async () => {
      await prisma.userProfile.createMany({
        data: [awaId, moussaId].map((id, i) => ({
          id,
          accountType: AccountType.student,
          preferredLanguage: 'fr',
          fullName: `Élève ${i}`,
          email: `${id}@example.test`,
          phone: `+225070000001${i}`,
          countryOfResidence: 'CI',
        })),
      });
    });

    afterAll(async () => {
      const cases = await prisma.case.findMany({
        where: { userId: { in: [awaId, moussaId] } },
        select: { id: true },
      });
      const ids = cases.map((c) => c.id);
      await prisma.caseMessage.deleteMany({ where: { caseId: { in: ids } } });
      await prisma.caseTimelineEvent.deleteMany({ where: { caseId: { in: ids } } });
      await prisma.case.deleteMany({ where: { id: { in: ids } } });
      await prisma.userProfile.deleteMany({ where: { id: { in: [awaId, moussaId] } } });
      await prisma.$disconnect();
    });

    it('un renvoi rend le même dossier : une ligne, une notification', async () => {
      const first = await service.create(input(), awaId);
      const again = await service.create(input(), awaId);

      expect(again.id).toBe(first.id);
      expect(again.referenceCode).toBe(first.referenceCode);
      expect(await casesOf(awaId, input().title)).toHaveLength(1);
      expect(pushes.filter((id) => id === awaId)).toHaveLength(1);
      // L'historique n'a pas été réécrit par le renvoi.
      expect(
        await prisma.caseTimelineEvent.count({
          where: { caseId: first.id, title: 'Demande envoyée' },
        }),
      ).toBe(1);
    });

    it('deux envois simultanés : un seul dossier, les deux réponses portent son id', async () => {
      const title = `Simultané ${s}`;
      const results = await Promise.all(
        Array.from({ length: 4 }, () => service.create(input({ title }), awaId)),
      );

      expect(new Set(results.map((r) => r.id)).size).toBe(1);
      expect(await casesOf(awaId, title)).toHaveLength(1);
    });

    it('une demande différente (description) crée un autre dossier', async () => {
      const title = `Différent ${s}`;
      const a = await service.create(input({ title }), awaId);
      const b = await service.create(
        input({ title, description: 'Autre besoin.' }),
        awaId,
      );
      expect(b.id).not.toBe(a.id);
      expect(await casesOf(awaId, title)).toHaveLength(2);
    });

    it('le même texte pour un autre contexte crée un autre dossier', async () => {
      const title = `Contexte ${s}`;
      const a = await service.create(input({ title }), awaId);
      const b = await service.create(
        input({ title, contextLabel: 'Université de Bordeaux' }),
        awaId,
      );
      expect(b.id).not.toBe(a.id);
    });

    it('la même demande d’un AUTRE élève crée son dossier', async () => {
      const title = `Autre élève ${s}`;
      const a = await service.create(input({ title }), awaId);
      const b = await service.create(input({ title }), moussaId);
      expect(b.id).not.toBe(a.id);
      expect(b.userId).toBe(moussaId);
    });

    it('un dossier clos ne retient pas une nouvelle demande identique', async () => {
      const title = `Clos ${s}`;
      const a = await service.create(input({ title }), awaId);
      await prisma.case.update({
        where: { id: a.id },
        data: { status: CaseStatus.cancelled },
      });
      const b = await service.create(input({ title }), awaId);
      expect(b.id).not.toBe(a.id);
    });

    it('passé la fenêtre, la même demande est une nouvelle demande', async () => {
      const title = `Ancien ${s}`;
      const a = await service.create(input({ title }), awaId);
      await prisma.case.update({
        where: { id: a.id },
        data: { createdAt: new Date(Date.now() - DUPLICATE_CASE_WINDOW_MS - 60_000) },
      });
      const b = await service.create(input({ title }), awaId);
      expect(b.id).not.toBe(a.id);

      // Juste avant la fin de la fenêtre : encore un renvoi.
      await prisma.case.update({
        where: { id: b.id },
        data: { createdAt: new Date(Date.now() - DUPLICATE_CASE_WINDOW_MS + 60_000) },
      });
      const c = await service.create(input({ title }), awaId);
      expect(c.id).toBe(b.id);
    });
  },
);
