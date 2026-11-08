import { ModuleRef } from '@nestjs/core';
import { BadRequestException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { PushSenderService } from '../notifications/push-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { CasesService } from './cases.service';
import { CreateCaseMessageDto } from './dto/create-case-message.dto';

/**
 * Revue avant la 58 (PR #408) : l'app renvoie depuis sa file un message dont
 * le POST a pu aboutir sans qu'elle reçoive la réponse. Avec le même
 * `clientMessageId` dans le même dossier, le serveur rend le message existant
 * — ni second message chez le conseiller, ni second « Nouveau message » dans
 * la chronologie.
 */
function makeService(opts: {
  existing?: Record<string, unknown> | null;
  failCreateWith?: unknown;
  winnerAfterConflict?: Record<string, unknown> | null;
}) {
  const created: any[] = [];
  const timeline: any[] = [];
  let lookups = 0;
  const findUnique = jest.fn(async () => {
    lookups += 1;
    if (lookups === 1) return opts.existing ?? null;
    return opts.winnerAfterConflict ?? null;
  });
  const prisma = {
    isEnabled: true,
    execute: async (fn: (p: any) => Promise<any>) =>
      fn({
        case: {
          findUnique: async () => ({
            id: 'case-1',
            userId: 'user-1',
            counsellor: null,
          }),
        },
        caseMessage: { findUnique },
        $transaction: async (fn2: (tx: any) => Promise<any>) => {
          if (opts.failCreateWith) throw opts.failCreateWith;
          return fn2({
            caseMessage: {
              create: async ({ data }: { data: any }) => {
                created.push(data);
                return { id: 'msg-new', createdAt: new Date(), ...data };
              },
            },
            caseTimelineEvent: {
              create: async ({ data }: { data: any }) => {
                timeline.push(data);
                return {};
              },
            },
            case: {
              findUnique: async () => ({ id: 'case-1', status: 'submitted' }),
              update: async () => ({}),
            },
          });
        },
      }),
    tryExecute: async () => null,
  } as unknown as PrismaService;
  const svc = new CasesService(
    prisma,
    { get: () => null } as unknown as ModuleRef,
    { sendToUser: async () => {} } as unknown as PushSenderService,
  );
  return { svc, created, timeline, findUnique };
}

const student = { userId: 'user-1', role: 'student' as const, fullName: 'Awa' };

const existingRow = {
  id: 'msg-1',
  caseId: 'case-1',
  senderName: 'Awa',
  senderRole: 'student',
  body: 'Bonjour',
  createdAt: new Date('2026-11-08T10:00:00.000Z'),
  clientMessageId: 'user-1794136840140550',
};

describe('CasesService.createMessage — clientMessageId (idempotence)', () => {
  it('un renvoi avec le même identifiant rend le message existant, sans rien créer', async () => {
    const { svc, created, timeline } = makeService({ existing: existingRow });

    const result = await svc.createMessage(
      'case-1',
      { body: 'Bonjour', clientMessageId: 'user-1794136840140550' },
      student,
    );

    expect(result).toEqual({
      id: 'msg-1',
      senderName: 'Awa',
      senderRole: 'student',
      body: 'Bonjour',
      createdAt: '2026-11-08T10:00:00.000Z',
      clientMessageId: 'user-1794136840140550',
    });
    expect(created).toHaveLength(0);
    expect(timeline).toHaveLength(0);
  });

  it('premier envoi : le message est créé avec son identifiant et le rend', async () => {
    const { svc, created, timeline } = makeService({ existing: null });

    const result = await svc.createMessage(
      'case-1',
      { body: 'Bonjour', clientMessageId: 'user-42' },
      student,
    );

    expect(created).toEqual([
      expect.objectContaining({ caseId: 'case-1', clientMessageId: 'user-42' }),
    ]);
    expect(timeline).toHaveLength(1);
    expect(result).toMatchObject({ id: 'msg-new', clientMessageId: 'user-42' });
  });

  it('sans identifiant (anciennes apps) : créé comme avant, identifiant NULL, pas de recherche', async () => {
    const { svc, created, findUnique } = makeService({ existing: existingRow });

    const result = await svc.createMessage(
      'case-1',
      { body: 'Bonjour' },
      student,
    );

    expect(findUnique).not.toHaveBeenCalled();
    expect(created).toEqual([
      expect.objectContaining({ clientMessageId: null }),
    ]);
    expect(result).toMatchObject({ id: 'msg-new', clientMessageId: null });
  });

  it("deux renvois simultanés : le second bute sur l'index unique et rend le message du premier", async () => {
    const { svc } = makeService({
      existing: null,
      failCreateWith: Object.assign(new Error('Unique constraint'), {
        code: 'P2002',
      }),
      winnerAfterConflict: existingRow,
    });

    await expect(
      svc.createMessage(
        'case-1',
        { body: 'Bonjour', clientMessageId: 'user-1794136840140550' },
        student,
      ),
    ).resolves.toMatchObject({ id: 'msg-1' });
  });

  it('refuse un identifiant mal formé à la frontière du service', async () => {
    const { svc } = makeService({});
    await expect(
      svc.createMessage(
        'case-1',
        { body: 'Bonjour', clientMessageId: 'pas un id !' },
        student,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});

describe('CreateCaseMessageDto — clientMessageId', () => {
  const errorsFor = async (payload: Record<string, unknown>) =>
    (await validate(plainToInstance(CreateCaseMessageDto, payload))).map(
      (e) => e.property,
    );

  it('optionnel', async () => {
    expect(await errorsFor({ body: 'Bonjour' })).toEqual([]);
  });

  it("accepte l'id de bulle de l'app", async () => {
    expect(
      await errorsFor({
        body: 'Bonjour',
        clientMessageId: 'user-1794136840140550',
      }),
    ).toEqual([]);
  });

  it.each([
    ['trop long', 'a'.repeat(65)],
    ['espace', 'user 1'],
    ['caractère spécial', "user-1';drop"],
    ['vide', ''],
  ])('refuse un identifiant %s', async (_label, clientMessageId) => {
    expect(await errorsFor({ body: 'Bonjour', clientMessageId })).toEqual([
      'clientMessageId',
    ]);
  });
});
