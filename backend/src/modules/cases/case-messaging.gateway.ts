import { forwardRef, Inject, Logger, NotFoundException } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { Server, Socket } from 'socket.io';

import { resolveCorsOrigins } from '../../common/cors-origins';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { SupabaseAuthService } from '../auth/supabase-auth.service';
import { PushSenderService } from '../notifications/push-sender.service';
import { CasesService } from './cases.service';
import type { CaseMessagingActor } from './cases.service';
import {
  CaseSocketMessageDto,
  CaseSocketRoomDto,
  CaseSocketTypingDto,
} from './dto/case-socket-events.dto';

const MAX_SOCKET_PAYLOAD_BYTES = 16 * 1024;

export const CASE_SOCKET_RATE_LIMITS = {
  joinCase: { limit: 20, windowMs: 60_000 },
  leaveCase: { limit: 20, windowMs: 60_000 },
  newMessage: { limit: 10, windowMs: 60_000 },
  typing: { limit: 30, windowMs: 10_000 },
} as const;

type CaseSocketEvent = keyof typeof CASE_SOCKET_RATE_LIMITS;
type PayloadClass<T extends object> = new () => T;

interface RateLimitBucket {
  count: number;
  resetAt: number;
}

// The global HTTP ThrottlerGuard is not compatible with Socket.IO response
// objects. This gateway therefore owns a per-authenticated-user/event limiter.
@SkipThrottle()
@WebSocketGateway({
  namespace: '/cases',
  maxHttpBufferSize: MAX_SOCKET_PAYLOAD_BYTES,
  cors: {
    // Evaluated at import time: in production a missing CORS_ORIGINS throws
    // here and aborts boot instead of silently allowing a development origin.
    origin: resolveCorsOrigins(),
    credentials: true,
  },
})
export class CaseMessagingGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(CaseMessagingGateway.name);
  private readonly rateLimitBuckets = new Map<string, RateLimitBucket>();
  private lastRateLimitCleanupAt = 0;

  @WebSocketServer()
  server!: Server;

  constructor(
    // The mobile namespace currently accepts Supabase student tokens. Any
    // future staff-token adapter must populate the same server-owned fields;
    // no role or name is ever accepted from an event payload.
    private readonly supabaseAuthService: SupabaseAuthService,
    @Inject(forwardRef(() => CasesService))
    private readonly casesService: CasesService,
    private readonly pushService: PushSenderService,
  ) {}

  async handleConnection(client: Socket) {
    const token = client.handshake.auth?.token;
    if (typeof token !== 'string' || !token) {
      client.disconnect();
      return;
    }

    try {
      const user = await this.supabaseAuthService.verifyAndResolve(token);
      client.data.userId = user.id;
      client.data.role = 'student';
      client.data.fullName = user.fullName;
      this.logger.log('Authenticated student case socket connected.');
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect() {
    this.logger.log('Case socket disconnected.');
  }

  @SubscribeMessage('joinCase')
  async handleJoinCase(
    @ConnectedSocket() client: Socket,
    @MessageBody() rawData: unknown,
  ) {
    const actor = this.actorFor(client);
    if (!actor) return this.rejectUnauthenticated(client, 'joinCase');
    const limited = this.consumeRateLimit(actor.userId, 'joinCase');
    if (limited) return limited;
    const data = await this.validPayload(CaseSocketRoomDto, rawData);
    if (!data) return this.error('joinCase', 'INVALID_PAYLOAD');

    try {
      await this.casesService.assertCanAccessMessaging(data.caseId, actor);
    } catch (error) {
      return this.caseOperationError('joinCase', data.caseId, error);
    }

    await client.join(this.roomFor(data.caseId));
    this.logger.log('Authenticated participant joined an authorized case room.');
    return { event: 'joinedCase', data: { caseId: data.caseId } };
  }

  @SubscribeMessage('leaveCase')
  async handleLeaveCase(
    @ConnectedSocket() client: Socket,
    @MessageBody() rawData: unknown,
  ) {
    const actor = this.actorFor(client);
    if (!actor) return this.rejectUnauthenticated(client, 'leaveCase');
    const limited = this.consumeRateLimit(actor.userId, 'leaveCase');
    if (limited) return limited;
    const data = await this.validPayload(CaseSocketRoomDto, rawData);
    if (!data) return this.error('leaveCase', 'INVALID_PAYLOAD');

    await client.leave(this.roomFor(data.caseId));
    return { event: 'leftCase', data: { caseId: data.caseId } };
  }

  @SubscribeMessage('newMessage')
  async handleNewMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() rawData: unknown,
  ) {
    const actor = this.actorFor(client);
    if (!actor) return this.rejectUnauthenticated(client, 'newMessage');
    const limited = this.consumeRateLimit(actor.userId, 'newMessage');
    if (limited) return limited;
    const data = await this.validPayload(CaseSocketMessageDto, rawData);
    if (!data) return this.error('newMessage', 'INVALID_PAYLOAD');

    let message: Awaited<ReturnType<CasesService['createMessage']>>;
    try {
      message = await this.casesService.createMessage(
        data.caseId,
        { body: data.body },
        actor,
      );
    } catch (error) {
      return this.caseOperationError('newMessage', data.caseId, error);
    }

    // CasesService broadcasts staff-authored messages so REST/internal staff
    // paths behave consistently. Student messages originate here.
    if (actor.role === 'student') {
      this.server.to(this.roomFor(data.caseId)).emit('message', message);
    }
    client.emit('messageAck', { messageId: message.id, status: 'delivered' });

    const caseRecord = await this.casesService.findOne(data.caseId);
    if (caseRecord?.userId && caseRecord.userId !== actor.userId) {
      await this.pushService.sendToUser(
        caseRecord.userId,
        'Nouveau message',
        data.body.trim().substring(0, 100),
        { type: 'case_message', caseId: data.caseId },
      );
    }

    return { event: 'messageAccepted', data: { messageId: message.id } };
  }

  @SubscribeMessage('typing')
  async handleTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() rawData: unknown,
  ) {
    const actor = this.actorFor(client);
    if (!actor) return this.rejectUnauthenticated(client, 'typing');
    const limited = this.consumeRateLimit(actor.userId, 'typing');
    if (limited) return limited;
    const data = await this.validPayload(CaseSocketTypingDto, rawData);
    if (!data) return this.error('typing', 'INVALID_PAYLOAD');

    const room = this.roomFor(data.caseId);
    try {
      await this.casesService.assertCanAccessMessaging(data.caseId, actor);
    } catch (error) {
      return this.caseOperationError('typing', data.caseId, error);
    }
    if (!client.rooms.has(room)) {
      return this.error('typing', 'ACCESS_DENIED', data.caseId);
    }

    client.to(room).emit('typing', {
      userId: actor.userId,
      isTyping: data.isTyping,
    });
    return { event: 'typingAccepted', data: { caseId: data.caseId } };
  }

  emitCaseUpdated(caseId: string, payload: Record<string, unknown>) {
    this.server.to(this.roomFor(caseId)).emit('caseUpdated', payload);
  }

  emitCaseMessage(caseId: string, payload: Record<string, unknown>) {
    this.server.to(this.roomFor(caseId)).emit('message', payload);
  }

  private actorFor(client: Socket): CaseMessagingActor | null {
    const userId = client.data.userId;
    const role = client.data.role;
    const allowedRoles: Array<'student' | InternalRole> = [
      'student',
      InternalRole.Counselor,
      InternalRole.Commercial,
      InternalRole.Admin,
      InternalRole.SuperAdmin,
    ];
    if (
      typeof userId !== 'string' ||
      !userId ||
      !allowedRoles.includes(role as 'student' | InternalRole)
    ) {
      return null;
    }
    return {
      userId,
      role: role as 'student' | InternalRole,
      fullName:
        typeof client.data.fullName === 'string'
          ? client.data.fullName
          : undefined,
    };
  }

  private rejectUnauthenticated(client: Socket, event: CaseSocketEvent) {
    client.disconnect();
    return this.error(event, 'UNAUTHORIZED');
  }

  private consumeRateLimit(userId: string, event: CaseSocketEvent) {
    const now = Date.now();
    this.cleanupRateLimits(now);
    const config = CASE_SOCKET_RATE_LIMITS[event];
    const key = `${userId}:${event}`;
    const current = this.rateLimitBuckets.get(key);
    if (!current || now >= current.resetAt) {
      this.rateLimitBuckets.set(key, {
        count: 1,
        resetAt: now + config.windowMs,
      });
      return null;
    }
    if (current.count >= config.limit) {
      return {
        ...this.error(event, 'RATE_LIMITED'),
        data: {
          code: 'RATE_LIMITED',
          retryAfterMs: Math.max(1, current.resetAt - now),
        },
      };
    }
    current.count += 1;
    return null;
  }

  private cleanupRateLimits(now: number) {
    if (now - this.lastRateLimitCleanupAt < 60_000) return;
    for (const [key, bucket] of this.rateLimitBuckets) {
      if (now >= bucket.resetAt) this.rateLimitBuckets.delete(key);
    }
    this.lastRateLimitCleanupAt = now;
  }

  private async validPayload<T extends object>(
    payloadClass: PayloadClass<T>,
    rawData: unknown,
  ): Promise<T | null> {
    if (!rawData || typeof rawData !== 'object' || Array.isArray(rawData)) {
      return null;
    }
    const payload = plainToInstance(payloadClass, rawData);
    const errors = await validate(payload, {
      forbidNonWhitelisted: true,
      forbidUnknownValues: true,
      whitelist: true,
    });
    return errors.length === 0 ? payload : null;
  }

  private roomFor(caseId: string) {
    return `case:${caseId}`;
  }

  private error(event: CaseSocketEvent, code: string, caseId?: string) {
    return {
      event: `${event}Error`,
      data: { code, ...(caseId ? { caseId } : {}) },
    };
  }

  private caseOperationError(
    event: CaseSocketEvent,
    caseId: string,
    error: unknown,
  ) {
    if (error instanceof NotFoundException) {
      return this.error(event, 'ACCESS_DENIED', caseId);
    }
    this.logger.error(`Case socket ${event} operation failed.`);
    return this.error(event, 'INTERNAL_ERROR', caseId);
  }
}
