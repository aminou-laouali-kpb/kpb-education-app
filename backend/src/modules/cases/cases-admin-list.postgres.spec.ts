import { randomUUID } from 'node:crypto';

import { NotFoundException } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import {
  AccountType,
  CaseStatus,
  CaseType,
  InternalRole as DbInternalRole,
  PrismaClient,
} from '@prisma/client';

import { CaseStatus as CaseStatusFilter } from '../../common/enums/case-status.enum';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { CasesService } from './cases.service';

/**
 * La liste des dossiers de l'administration sur un vrai Postgres : le curseur
 * (deux dossiers de même date à cheval sur deux pages), les filtres, la
 * recherche, la requête SQL « l'élève attend une réponse » et la portée du
 * conseiller vivent dans des `where` et du SQL que les tests unitaires ne
 * font que décrire.
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
  'liste des dossiers de l’administration — intégration PostgreSQL',
  () => {
    const prisma = new PrismaClient();
    const s = randomUUID();
    const tag = s.slice(0, 8).toUpperCase();
    // Tous les dossiers de ce fichier portent cette marque dans leur
    // référence : `q: mark` isole la lecture des autres lignes de la base.
    const mark = `ADM-${tag}`;
    const awaId = `adm-awa-${s}`;
    const moussaId = `adm-moussa-${s}`;
    const staffId = `adm-staff-${s}`;
    const counsellorId = `adm-counsellor-${s}`;
    const id = (n: number) => `adm-case-${n}-${s}`;
    const service = new CasesService(
      {
        isEnabled: true,
        execute: (fn: (p: PrismaClient) => Promise<unknown>) => fn(prisma),
        tryExecute: (fn: (p: PrismaClient) => Promise<unknown>) => fn(prisma),
      } as unknown as PrismaService,
      { get: () => null } as unknown as ModuleRef,
      { sendToUser: async () => {} } as unknown as PushSenderService,
    );
    const admin = { id: 'adm-admin', role: InternalRole.Admin, fullName: 'Admin' };
    const fatou = {
      id: staffId,
      role: InternalRole.Counselor,
      fullName: `Fatou ${tag}`,
    };
    const day = (d: number, ms = 0) => new Date(Date.UTC(2026, 9, d, 8, 0, 0, ms));

    // n° → (élève, date, statut, conseiller). Les n° 3 et 4 ont la MÊME date.
    const seed: Array<{
      n: number;
      userId: string;
      createdAt: Date;
      status: CaseStatus;
      advisor: string | null;
      counsellorId?: string;
      title?: string;
    }> = [
      { n: 1, userId: awaId, createdAt: day(1), status: CaseStatus.submitted, advisor: null },
      { n: 2, userId: awaId, createdAt: day(2), status: CaseStatus.under_review, advisor: `Jojo ${tag}` },
      { n: 3, userId: moussaId, createdAt: day(3, 500), status: CaseStatus.submitted, advisor: `Jojo ${tag}` },
      { n: 4, userId: awaId, createdAt: day(3, 500), status: CaseStatus.submitted, advisor: `fatou ${tag.toLowerCase()}` },
      { n: 5, userId: moussaId, createdAt: day(5), status: CaseStatus.completed, advisor: `Richard ${tag}`, counsellorId },
      { n: 6, userId: awaId, createdAt: day(6), status: CaseStatus.submitted, advisor: '' },
      { n: 7, userId: moussaId, createdAt: day(7), status: CaseStatus.in_progress, advisor: `Jojo ${tag}`, title: `Master droit ${tag}` },
    ];

    const message = (n: number, senderRole: string, at: Date) =>
      prisma.caseMessage.create({
        data: { caseId: id(n), senderRole, senderName: senderRole, body: 'm', createdAt: at },
      });

    beforeAll(async () => {
      await prisma.userProfile.createMany({
        data: [
          {
            id: awaId,
            accountType: AccountType.student,
            preferredLanguage: 'fr',
            fullName: `Awa Diallo ${tag}`,
            email: `awa-${s}@example.test`,
            phone: '+2250700000000',
            countryOfResidence: 'CI',
          },
          {
            id: moussaId,
            accountType: AccountType.student,
            preferredLanguage: 'en',
            fullName: `Moussa Traoré ${tag}`,
            email: `moussa-${s}@example.test`,
            phone: '+2250700000001',
            countryOfResidence: 'ML',
          },
        ],
      });
      await prisma.adminUser.create({
        data: {
          id: staffId,
          fullName: fatou.fullName,
          email: `fatou-${s}@example.test`,
          role: DbInternalRole.counselor,
          languageScope: ['fr'],
        },
      });
      await prisma.counsellor.create({
        data: {
          id: counsellorId,
          fullName: fatou.fullName,
          email: `fatou-profile-${s}@example.test`,
          phone: '+2250700000002',
          countryOfResidence: 'CI',
          bioFr: 'b',
          bioEn: 'b',
          adminUserId: staffId,
        },
      });
      for (const c of seed) {
        await prisma.case.create({
          data: {
            id: id(c.n),
            referenceCode: `KPB-${mark}-${c.n}`,
            userId: c.userId,
            type: CaseType.consultation,
            status: c.status,
            title: c.title ?? 'Consultation',
            description: 'Dossier de test.',
            contextLabel: 'Test',
            nextStepTitle: 'En attente',
            nextStepDescription: 'Un conseiller arrive.',
            assignedAdvisorName: c.advisor,
            counsellorId: c.counsellorId ?? null,
            createdAt: c.createdAt,
          },
        });
      }
      // n° 2 : l'élève a écrit en dernier. n° 5 : l'équipe a répondu après
      // lui. n° 7 : deux messages de l'élève, le dernier fait foi. Les autres
      // n'ont aucun message.
      await message(2, 'system', day(10));
      await message(2, 'student', day(11));
      await message(5, 'student', day(10));
      await message(5, 'counselor', day(12));
      await message(7, 'student', day(13));
      await message(7, 'student', day(14));
      await prisma.caseTimelineEvent.createMany({
        data: [1, 2, 3].map((i) => ({
          caseId: id(7),
          status: 'submitted',
          title: `Événement ${i}`,
          description: 'd',
          createdAt: day(20 + i),
        })),
      });
      await prisma.caseTask.create({
        data: { caseId: id(7), title: 'Relancer', status: 'open' },
      });
      await prisma.caseInternalNote.create({
        data: { caseId: id(7), authorName: 'Jojo', authorRole: 'commercial', body: 'note interne' },
      });
    });

    afterAll(async () => {
      const ids = seed.map((c) => id(c.n));
      const where = { where: { caseId: { in: ids } } };
      await prisma.caseMessage.deleteMany(where);
      await prisma.caseTimelineEvent.deleteMany(where);
      await prisma.caseTask.deleteMany(where);
      await prisma.caseInternalNote.deleteMany(where);
      await prisma.case.deleteMany({ where: { id: { in: ids } } });
      await prisma.counsellor.deleteMany({ where: { id: counsellorId } });
      await prisma.adminUser.deleteMany({ where: { id: staffId } });
      await prisma.userProfile.deleteMany({ where: { id: { in: [awaId, moussaId] } } });
      await prisma.$disconnect();
    });

    const numbers = (items: Array<{ referenceCode: string }>) =>
      items.map((item) => Number(item.referenceCode.split('-').pop()));

    it('parcourt tout par pages de 2 : aucun dossier sauté ni rendu deux fois', async () => {
      const seen: number[] = [];
      let cursor: string | undefined;
      const sizes: number[] = [];
      for (let guard = 0; guard < 10; guard++) {
        const page = await service.findAllForAdmin(admin, { q: mark, limit: 2, cursor });
        sizes.push(page.items.length);
        seen.push(...numbers(page.items));
        if (!page.nextCursor) break;
        cursor = page.nextCursor;
      }
      // Du plus récent au plus ancien ; à date égale (3 et 4), l'identifiant
      // tranche — et la coupure de page tombe ENTRE les deux.
      expect(seen).toEqual([7, 6, 5, 4, 3, 2, 1]);
      expect(sizes).toEqual([2, 2, 2, 1]);
    });

    it('filtre par statut', async () => {
      const { items } = await service.findAllForAdmin(admin, {
        q: mark,
        status: CaseStatusFilter.Submitted,
      });
      expect(numbers(items)).toEqual([6, 4, 3, 1]);
    });

    it('filtre par conseiller, sans tenir compte de la casse', async () => {
      const jojo = await service.findAllForAdmin(admin, {
        q: mark,
        advisor: `JOJO ${tag}`.toLowerCase(),
      });
      expect(numbers(jojo.items)).toEqual([7, 3, 2]);
    });

    it('« sans conseiller » : nom absent ou vide', async () => {
      const { items } = await service.findAllForAdmin(admin, { q: mark, unassigned: true });
      expect(numbers(items)).toEqual([6, 1]);
    });

    it('recherche par nom, e-mail, référence ou titre', async () => {
      const by = async (q: string) =>
        numbers((await service.findAllForAdmin(admin, { q })).items);
      expect(await by(`awa diallo ${tag}`)).toEqual([6, 4, 2, 1]);
      expect(await by(`MOUSSA-${s}@example`)).toEqual([7, 5, 3]);
      expect(await by(`kpb-${mark}-5`)).toEqual([5]);
      expect(await by(`master droit ${tag}`)).toEqual([7]);
      expect(await by(`introuvable-${s}`)).toEqual([]);
    });

    it('« réponse attendue » : le DERNIER message vient de l’élève', async () => {
      const { items } = await service.findAllForAdmin(admin, { q: mark, awaiting: true });
      expect(numbers(items)).toEqual([7, 2]);
      expect(items[0]).toMatchObject({
        awaitingReply: true,
        lastMessageAt: day(14).toISOString(),
      });
    });

    it('rend `awaitingReply` et `lastMessageAt` pour chaque dossier de la page', async () => {
      const { items } = await service.findAllForAdmin(admin, { q: mark });
      const byNumber = new Map(numbers(items).map((n, i) => [n, items[i]]));
      expect(byNumber.get(2)).toMatchObject({ awaitingReply: true });
      expect(byNumber.get(5)).toMatchObject({
        awaitingReply: false,
        lastMessageAt: day(12).toISOString(),
      });
      expect(byNumber.get(1)).toMatchObject({ awaitingReply: false, lastMessageAt: null });
      for (const key of ['tasks', 'timeline', 'internalNotes', 'documentRequests', 'messages']) {
        expect(byNumber.get(7)).not.toHaveProperty(key);
      }
    });

    it('un conseiller ne voit que ses dossiers : profil lié (5) ou nom d’affectation (4)', async () => {
      const mine = await service.findAllForAdmin(fatou, { q: mark });
      expect(numbers(mine.items)).toEqual([5, 4]);
      // Aucun filtre n'élargit la portée.
      const widened = await service.findAllForAdmin(fatou, {
        q: mark,
        advisor: `Jojo ${tag}`,
      });
      expect(widened.items).toEqual([]);
      const awaiting = await service.findAllForAdmin(fatou, { awaiting: true });
      expect(awaiting.items).toEqual([]);
    });

    it('le résumé compte dans la portée et liste les conseillers une fois', async () => {
      const mine = await service.adminCaseListSummary(fatou);
      expect(mine).toEqual({
        awaitingCount: 0,
        advisors: [`fatou ${tag.toLowerCase()}`, `Richard ${tag}`],
      });

      const all = await service.adminCaseListSummary(admin);
      expect(all.awaitingCount).toBeGreaterThanOrEqual(2);
      expect(all.advisors).toEqual(
        expect.arrayContaining([`Jojo ${tag}`, `Richard ${tag}`]),
      );
      expect(all.advisors).not.toContain('');
    });

    it('le dossier ouvert porte ses tâches, ses notes et son historique, pas son fil', async () => {
      const detail = await service.findOneForAdmin(id(7), admin);
      expect(detail.tasks.map((t: { title: string }) => t.title)).toEqual(['Relancer']);
      expect(detail.internalNotes.map((n: { body: string }) => n.body)).toEqual(['note interne']);
      expect(detail.timeline.map((e: { title: string }) => e.title)).toEqual([
        'Événement 3',
        'Événement 2',
        'Événement 1',
      ]);
      expect(detail.timelineTruncated).toBe(false);
      expect(detail).toMatchObject({
        awaitingReply: true,
        studentName: `Moussa Traoré ${tag}`,
        preferredLanguage: 'en',
      });
      expect(detail).not.toHaveProperty('messages');
    });

    it('un conseiller n’ouvre pas le dossier d’un autre (404), mais ouvre le sien', async () => {
      await expect(service.findOneForAdmin(id(7), fatou)).rejects.toBeInstanceOf(
        NotFoundException,
      );
      await expect(service.findOneForAdmin(id(4), fatou)).resolves.toMatchObject({
        id: id(4),
      });
    });
  },
);
