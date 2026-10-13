import { NotFoundException } from '@nestjs/common';
import { GATEWAY_OPTIONS } from '@nestjs/websockets/constants';
import type { Server, Socket } from 'socket.io';

import { InternalRole } from '../../common/enums/internal-role.enum';
import type { SupabaseAuthService } from '../auth/supabase-auth.service';
import type { PushSenderService } from '../notifications/push-sender.service';
import {
  CASE_SOCKET_RATE_LIMITS,
  CaseMessagingGateway,
} from './case-messaging.gateway';
import type { CasesService } from './cases.service';

function makeSocket(
  data: Record<string, unknown> = {
    userId: 'student-1',
    role: 'student',
    fullName: 'Aïcha Étudiante',
  },
) {
  const emit = jest.fn();
  const toEmit = jest.fn();
  const socket = {
    handshake: { auth: {}, query: {} },
    data,
    rooms: new Set(['socket-1', 'case:case-1']),
    disconnect: jest.fn(),
    join: jest.fn(),
    leave: jest.fn(),
    emit,
    to: jest.fn(() => ({ emit: toEmit })),
  } as unknown as Socket;
  return { socket, emit, toEmit };
}

function makeGateway() {
  const verifyAndResolve = jest.fn();
  const casesService = {
    assertCanAccessMessaging: jest.fn().mockResolvedValue({
      id: 'case-1',
      userId: 'student-1',
    }),
    createMessage: jest.fn().mockResolvedValue({
      id: 'message-1',
      senderName: 'Aïcha Étudiante',
      senderRole: 'student',
      body: 'Bonjour',
      createdAt: new Date().toISOString(),
    }),
    findOne: jest.fn().mockResolvedValue({
      id: 'case-1',
      userId: 'student-1',
    }),
  };
  const pushService = { sendToUser: jest.fn() };
  const gateway = new CaseMessagingGateway(
    { verifyAndResolve } as unknown as SupabaseAuthService,
    casesService as unknown as CasesService,
    pushService as unknown as PushSenderService,
  );
  const serverEmit = jest.fn();
  gateway.server = {
    to: jest.fn(() => ({ emit: serverEmit })),
  } as unknown as Server;
  return { gateway, verifyAndResolve, casesService, pushService, serverEmit };
}

describe('CaseMessagingGateway security', () => {
  it('caps raw Socket.IO frames before DTO validation', () => {
    const options = Reflect.getMetadata(GATEWAY_OPTIONS, CaseMessagingGateway) as {
      maxHttpBufferSize?: number;
    };

    expect(options.maxHttpBufferSize).toBe(16 * 1024);
  });

  it('uses handshake auth and ignores client-supplied identity fields', async () => {
    const { gateway, verifyAndResolve } = makeGateway();
    verifyAndResolve.mockResolvedValue({
      id: 'student-1',
      email: 'student@example.test',
      fullName: 'Aïcha Étudiante',
      role: 'student',
      accountType: 'student',
    });
    const { socket } = makeSocket({});
    Object.assign(socket.handshake, {
      auth: { token: 'verified-token' },
      query: {
        role: InternalRole.SuperAdmin,
        fullName: 'Conseiller KPB',
      },
    });

    await gateway.handleConnection(socket);

    expect(verifyAndResolve).toHaveBeenCalledWith('verified-token');
    expect(socket.data).toMatchObject({
      userId: 'student-1',
      role: 'student',
      fullName: 'Aïcha Étudiante',
    });
    expect(socket.data).not.toHaveProperty('email');
    expect(socket.disconnect).not.toHaveBeenCalled();
  });

  it('rejects legacy query-string bearer tokens', async () => {
    const { gateway, verifyAndResolve } = makeGateway();
    const { socket } = makeSocket({});
    Object.assign(socket.handshake, {
      auth: {},
      query: { token: 'must-not-be-accepted' },
    });

    await gateway.handleConnection(socket);

    expect(verifyAndResolve).not.toHaveBeenCalled();
    expect(socket.disconnect).toHaveBeenCalled();
  });

  it.each([
    [{ caseId: 'case-1', body: 42 }, 'non-string body'],
    [{ caseId: 'case-1', body: 'ok', senderRole: 'admin' }, 'extra role'],
    [null, 'null payload'],
  ])('rejects malformed newMessage payloads: %s (%s)', async (payload, _label) => {
    const { gateway, casesService } = makeGateway();
    const { socket } = makeSocket();

    const result = await gateway.handleNewMessage(socket, payload);

    expect(result).toMatchObject({
      event: 'newMessageError',
      data: { code: 'INVALID_PAYLOAD' },
    });
    expect(casesService.createMessage).not.toHaveBeenCalled();
  });

  it('rejects an oversized message before reaching persistence', async () => {
    const { gateway, casesService } = makeGateway();
    const { socket } = makeSocket();

    const result = await gateway.handleNewMessage(socket, {
      caseId: 'case-1',
      body: 'x'.repeat(3001),
    });

    expect(result).toMatchObject({ data: { code: 'INVALID_PAYLOAD' } });
    expect(casesService.createMessage).not.toHaveBeenCalled();
  });

  it('rate-limits message spam per authenticated user and event', async () => {
    const { gateway, casesService } = makeGateway();
    const { socket } = makeSocket();
    const { limit } = CASE_SOCKET_RATE_LIMITS.newMessage;

    for (let i = 0; i < limit; i += 1) {
      await expect(
        gateway.handleNewMessage(socket, {
          caseId: 'case-1',
          body: `Message ${i}`,
        }),
      ).resolves.toMatchObject({ event: 'messageAccepted' });
    }
    const rejected = await gateway.handleNewMessage(socket, {
      caseId: 'case-1',
      body: 'One too many',
    });

    expect(rejected).toMatchObject({
      event: 'newMessageError',
      data: { code: 'RATE_LIMITED' },
    });
    expect(casesService.createMessage).toHaveBeenCalledTimes(limit);

    const { socket: otherUserSocket } = makeSocket({
      userId: 'student-2',
      role: 'student',
      fullName: 'Other Student',
    });
    await expect(
      gateway.handleNewMessage(otherUserSocket, {
        caseId: 'case-1',
        body: 'Independent user bucket',
      }),
    ).resolves.toMatchObject({ event: 'messageAccepted' });
    await expect(
      gateway.handleJoinCase(socket, { caseId: 'case-1' }),
    ).resolves.toMatchObject({ event: 'joinedCase' });
  });

  it('denies joining a case the authenticated actor cannot access', async () => {
    const { gateway, casesService } = makeGateway();
    casesService.assertCanAccessMessaging.mockRejectedValue(
      new NotFoundException(),
    );
    const { socket } = makeSocket();

    const result = await gateway.handleJoinCase(socket, {
      caseId: 'case-other',
    });

    expect(result).toMatchObject({
      event: 'joinCaseError',
      data: { code: 'ACCESS_DENIED', caseId: 'case-other' },
    });
    expect(socket.join).not.toHaveBeenCalled();
  });

  it('denies cross-case typing even when a room name is supplied', async () => {
    const { gateway, casesService } = makeGateway();
    casesService.assertCanAccessMessaging.mockRejectedValue(
      new NotFoundException(),
    );
    const { socket, toEmit } = makeSocket();
    (socket.rooms as Set<string>).add('case:case-other');

    const result = await gateway.handleTyping(socket, {
      caseId: 'case-other',
      isTyping: true,
    });

    expect(result).toMatchObject({
      event: 'typingError',
      data: { code: 'ACCESS_DENIED', caseId: 'case-other' },
    });
    expect(toEmit).not.toHaveBeenCalled();
  });

  it('rejects unsupported staff roles before any case lookup', async () => {
    const { gateway, casesService } = makeGateway();
    const { socket } = makeSocket({
      userId: 'staff-1',
      role: InternalRole.ContentManager,
      fullName: 'Content Staff',
    });

    const result = await gateway.handleJoinCase(socket, { caseId: 'case-1' });

    expect(result).toMatchObject({ data: { code: 'UNAUTHORIZED' } });
    expect(socket.disconnect).toHaveBeenCalled();
    expect(casesService.assertCanAccessMessaging).not.toHaveBeenCalled();
  });
});
