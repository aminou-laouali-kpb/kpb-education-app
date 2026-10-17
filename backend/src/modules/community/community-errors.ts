import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  NotFoundException,
} from '@nestjs/common';

/**
 * Les erreurs du contrat (§3). Le filtre global recopie `code` et `details`
 * dans la réponse : `{ statusCode, message, code, details?, requestId, … }`.
 */
export const CommunityErrors = {
  studentsOnly: () =>
    new ForbiddenException({
      message: 'Only student accounts can use the community.',
      code: 'community_students_only',
    }),
  charterRequired: (charterVersion: string) =>
    new ForbiddenException({
      message: 'Accept the community guidelines first.',
      code: 'community_charter_required',
      details: { charterVersion },
    }),
  charterOutdated: (charterVersion: string) =>
    new ConflictException({
      message: 'This is not the current version of the guidelines.',
      code: 'community_charter_outdated',
      details: { charterVersion },
    }),
  readOnly: (kind: 'read_only' | 'ban', until: Date | null) =>
    new ForbiddenException({
      message: 'Your community access is read-only.',
      code: 'community_read_only',
      details: { kind, until: until?.toISOString() ?? null },
    }),
  rateLimited: (scope: string, limit: number, retryAfterSeconds: number) =>
    new HttpException(
      {
        message: 'Too many contributions, try again later.',
        code: 'community_rate_limited',
        details: { scope, limit, retryAfterSeconds },
      },
      HttpStatus.TOO_MANY_REQUESTS,
    ),
  postNotFound: () =>
    new NotFoundException({ message: 'Post not found.', code: 'community_post_not_found' }),
  replyNotFound: () =>
    new NotFoundException({ message: 'Reply not found.', code: 'community_reply_not_found' }),
  memberNotFound: () =>
    new NotFoundException({ message: 'Member not found.', code: 'community_member_not_found' }),
  entityNotFound: () =>
    new NotFoundException({ message: 'Entity not found.', code: 'community_entity_not_found' }),
  notAuthor: () =>
    new ForbiddenException({ message: 'Not your content.', code: 'community_not_author' }),
  editWindowClosed: (editableUntil: Date) =>
    new ForbiddenException({
      message: 'This content can no longer be edited.',
      code: 'community_edit_window_closed',
      details: { editableUntil: editableUntil.toISOString() },
    }),
  postNotOpen: () =>
    new ConflictException({
      message: 'This post is not open for replies.',
      code: 'community_post_not_open',
    }),
  invalidMention: (type: string, id: string) =>
    new BadRequestException({
      message: 'Invalid mention.',
      code: 'community_invalid_mention',
      details: { type, id },
    }),
  tooManyMentions: (max: number) =>
    new BadRequestException({
      message: 'Too many mentions.',
      code: 'community_too_many_mentions',
      details: { max },
    }),
  tooManyHashtags: (max: number) =>
    new BadRequestException({
      message: 'Too many hashtags.',
      code: 'community_too_many_hashtags',
      details: { max },
    }),
  cannotReactOwn: () =>
    new BadRequestException({
      message: 'You cannot mark your own content as helpful.',
      code: 'community_cannot_react_own',
    }),
  cannotBlockSelf: () =>
    new BadRequestException({ message: 'You cannot block yourself.', code: 'community_cannot_block_self' }),
  cannotReportSelf: () =>
    new BadRequestException({ message: 'You cannot report yourself.', code: 'community_cannot_report_self' }),
  pinLimit: (max: number) =>
    new ConflictException({
      message: 'Too many pinned posts.',
      code: 'community_pin_limit',
      details: { max },
    }),
  invalidTransition: (status: string) =>
    new ConflictException({
      message: 'This action is not possible in the current state.',
      code: 'community_invalid_transition',
      details: { status },
    }),
};
