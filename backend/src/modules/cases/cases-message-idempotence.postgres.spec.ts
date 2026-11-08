import { randomUUID } from 'node:crypto';

import { ModuleRef } from '@nestjs/core';
import {
  AccountType,
  CaseStatus,
  CaseType,
  PrismaClient,
} from '@prisma/client';

import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { CasesService } from './cases.service';

/**
 * Idempotence des messages de dossier (`clientMessageId`) sur un vrai
 * Postgres : c'est l'index unique (caseId, clientMessageId) qui tranche les
 * renvois simultanés, et seul Postgres dit qu'il admet plusieurs NULL.
 *
 *   createdb -h /tmp kpb_case_msg_test
 *   DATABASE_URL=postgresql:///kpb_case_msg_test?host=/tmp npx prisma migrate deploy
 *   KPB_RUN_POSTGRES_INTEGRATION=true DATABASE_URL=… npm run test:integration:case-message-idempotence
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres(
  'messages de dossier — idempotence, intégration PostgreSQL',
  () => {
    const prisma = new PrismaClient();
    const s = randomUUID();
    const userId = `idem-user-${s}`;
    const caseId = `idem-case-${s}`;
    const autreCaseId = `idem-case-b-${s}`;
    const service = new CasesService(
      {
        isEnabled: true,
        execute: (fn: (p: PrismaClient) => Promise<unknown>) => fn(prisma),
        tryExecute: (fn: (p: PrismaClient) => Promise<unknown>) => fn(prisma),
      } as unknown as PrismaService,
      { get: () => null } as unknown as ModuleRef,
      { sendToUser: async () => {} } as unknown as PushSenderService,
    );
    const eleve = { userId, role: 'student' as const, fullName: 'Awa' };

    const dossier = (id: string, ref: string) =>
      prisma.case.create({
        data: {
          id,
          referenceCode: `KPB-IDEM-${ref}-${s.slice(0, 8)}`,
          userId,
          type: CaseType.consultation,
          status: CaseStatus.submitted,
          title: 'Consultation',
          description: 'Dossier de test.',
          contextLabel: 'Test',
          nextStepTitle: 'En attente',
          nextStepDescription: 'Un conseiller arrive.',
        },
      });

    beforeAll(async () => {
      await prisma.userProfile.create({
        data: {
          id: userId,
          accountType: AccountType.student,
          preferredLanguage: 'fr',
          fullName: 'Awa',
          email: `idem-${s}@example.test`,
          phone: '+2250700000000',
          countryOfResidence: 'CI',
        },
      });
      await dossier(caseId, 'A');
      await dossier(autreCaseId, 'B');
    });

    afterAll(async () => {
      const ids = [caseId, autreCaseId];
      await prisma.caseMessage.deleteMany({ where: { caseId: { in: ids } } });
      await prisma.caseTimelineEvent.deleteMany({
        where: { caseId: { in: ids } },
      });
      await prisma.case.deleteMany({ where: { id: { in: ids } } });
      await prisma.userProfile.deleteMany({ where: { id: userId } });
      await prisma.$disconnect();
    });

    const messages = (id: string, clientMessageId?: string | null) =>
      prisma.caseMessage.findMany({
        where: {
          caseId: id,
          ...(clientMessageId === undefined ? {} : { clientMessageId }),
        },
      });

    it('un renvoi rend le même message : une seule ligne, un seul événement', async () => {
      const first = await service.createMessage(
        caseId,
        { body: 'Ma disponibilité', clientMessageId: 'user-1' },
        eleve,
      );
      const eventsAfterFirst = await prisma.caseTimelineEvent.count({
        where: { caseId },
      });
      const again = await service.createMessage(
        caseId,
        { body: 'Ma disponibilité', clientMessageId: 'user-1' },
        eleve,
      );

      expect(again.id).toBe(first.id);
      expect(again.clientMessageId).toBe('user-1');
      expect(await messages(caseId, 'user-1')).toHaveLength(1);
      expect(await prisma.caseTimelineEvent.count({ where: { caseId } })).toBe(
        eventsAfterFirst,
      );
    });

    it('deux renvois simultanés : une seule ligne, les deux réponses portent son id', async () => {
      const [a, b] = await Promise.all([
        service.createMessage(
          caseId,
          { body: 'Course', clientMessageId: 'user-2' },
          eleve,
        ),
        service.createMessage(
          caseId,
          { body: 'Course', clientMessageId: 'user-2' },
          eleve,
        ),
      ]);
      expect(a.id).toBe(b.id);
      expect(await messages(caseId, 'user-2')).toHaveLength(1);
    });

    it('sans identifiant (anciennes apps), deux envois font deux messages', async () => {
      await service.createMessage(caseId, { body: 'Ancienne app' }, eleve);
      await service.createMessage(caseId, { body: 'Ancienne app' }, eleve);
      const rows = (await messages(caseId, null)).filter(
        (m) => m.body === 'Ancienne app',
      );
      expect(rows).toHaveLength(2);
    });

    it('le même identifiant dans un AUTRE dossier est un autre message', async () => {
      await service.createMessage(
        autreCaseId,
        { body: 'Ma disponibilité', clientMessageId: 'user-1' },
        eleve,
      );
      expect(await messages(autreCaseId, 'user-1')).toHaveLength(1);
      expect(await messages(caseId, 'user-1')).toHaveLength(1);
    });
  },
);
