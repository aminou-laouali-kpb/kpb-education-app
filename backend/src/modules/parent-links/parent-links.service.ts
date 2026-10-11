import { randomBytes } from 'crypto';
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

/**
 * Parent ↔ child linking (Track C1). A parent account creates an invite and
 * shares the 8-character code (via WhatsApp, usually) with their child. The
 * child — already signed in — accepts the code, which activates the link.
 *
 * Activated parents get read-only access to the child's cases that are
 * marked `parentCanView = true` and a "Pay" button that routes through
 * PaymentsService.
 */
@Injectable()
export class ParentLinksService {
  constructor(private readonly prismaService: PrismaService) {}

  /** Called by a parent to invite a child. Returns the share-able code. */
  async invite(parentId: string) {
    const parent = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({ where: { id: parentId } }),
    );
    if (!parent || parent.accountType !== 'parent') {
      throw new ForbiddenException('Only parent accounts can create invites.');
    }

    const code = generateInviteCode();
    const created = await this.prismaService.execute((prisma) =>
      prisma.parentChildLink.create({
        data: {
          parentId,
          // childId is null until the student accepts.
          inviteCode: code,
          status: 'pending',
        },
      }),
    );
    return { id: created?.id, inviteCode: code };
  }

  /** Called by a signed-in child/student to accept an invite. */
  async accept(childUserId: string, inviteCode: string) {
    const child = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({ where: { id: childUserId } }),
    );
    if (!child || child.accountType !== 'student') {
      throw new ForbiddenException(
        'Only student accounts can accept parent invites.',
      );
    }

    const link = await this.prismaService.execute((prisma) =>
      prisma.parentChildLink.findUnique({ where: { inviteCode } }),
    );
    if (!link || link.status !== 'pending') {
      throw new NotFoundException('Invite is invalid or already used.');
    }
    if (link.parentId === childUserId) {
      throw new BadRequestException('Cannot link an account to itself.');
    }

    const updated = await this.prismaService.execute((prisma) =>
      prisma.parentChildLink.update({
        where: { id: link.id },
        data: {
          childId: childUserId,
          status: 'active',
          acceptedAt: new Date(),
        },
      }),
    );
    return updated;
  }

  /** Revoke an existing link. Either side can revoke. */
  async revoke(userId: string, linkId: string) {
    const link = await this.prismaService.execute((prisma) =>
      prisma.parentChildLink.findUnique({ where: { id: linkId } }),
    );
    if (!link) {
      throw new NotFoundException('Link not found.');
    }
    if (link.parentId !== userId && link.childId !== userId) {
      throw new ForbiddenException('Not a party to this link.');
    }
    return this.prismaService.execute((prisma) =>
      prisma.parentChildLink.update({
        where: { id: linkId },
        data: { status: 'revoked' },
      }),
    );
  }

  /** List a parent's active children. */
  async listChildren(parentId: string) {
    const links = await this.prismaService.execute((prisma) =>
      prisma.parentChildLink.findMany({
        where: { parentId, status: 'active' },
        include: {
          child: {
            select: {
              id: true,
              fullName: true,
              email: true,
              countryOfResidence: true,
              currentLevel: true,
              targetLevel: true,
            },
          },
        },
      }),
    );
    return { items: links ?? [] };
  }

  /**
   * List the cases a parent can view — only those of linked active children
   * that the student has explicitly opted into sharing.
   */
  async listParentVisibleCases(parentId: string) {
    const links = await this.prismaService.execute((prisma) =>
      prisma.parentChildLink.findMany({
        where: { parentId, status: 'active' },
        select: { childId: true },
      }),
    );
    // childId is nullable on ParentChildLink (pending invites have no child
    // yet); filter those out so the `in:` clause receives only non-null ids.
    const childIds = (links ?? [])
      .map((l) => l.childId)
      .filter((id): id is string => id !== null);
    if (childIds.length === 0) return { items: [] };

    const cases = await this.prismaService.execute((prisma) =>
      prisma.case.findMany({
        where: { userId: { in: childIds }, parentCanView: true },
        orderBy: { updatedAt: 'desc' },
        select: {
          id: true,
          referenceCode: true,
          title: true,
          contextLabel: true,
          status: true,
          nextStepTitle: true,
          nextStepDescription: true,
          updatedAt: true,
          userId: true,
        },
      }),
    );
    return { items: cases ?? [] };
  }

  /**
   * Fetch a single case for a parent. Enforces both link + parentCanView flag
   * so this can be wired up directly to the parent-facing case detail screen.
   */
  async getParentVisibleCase(parentId: string, caseId: string) {
    const caseRecord = await this.prismaService.execute((prisma) =>
      prisma.case.findUnique({
        where: { id: caseId },
        // Projection explicite : un parent ne voit ni les coordonnées perso du
        // conseiller, ni les champs commerciaux (leadTag, discussionMotive),
        // ni les chemins des fichiers déposés.
        select: {
          id: true,
          userId: true,
          parentCanView: true,
          referenceCode: true,
          title: true,
          contextLabel: true,
          status: true,
          nextStepTitle: true,
          nextStepDescription: true,
          assignedAdvisorName: true,
          requestedCountryId: true,
          scheduledAt: true,
          createdAt: true,
          updatedAt: true,
          messages: {
            orderBy: { createdAt: 'asc' },
            select: {
              id: true,
              senderName: true,
              senderRole: true,
              body: true,
              createdAt: true,
            },
          },
          documents: {
            select: { id: true, title: true, isProvided: true, uploadedAt: true },
          },
          timelineEvents: {
            orderBy: { createdAt: 'asc' },
            select: {
              id: true,
              title: true,
              description: true,
              status: true,
              createdAt: true,
            },
          },
        },
      }),
    );
    if (!caseRecord || !caseRecord.parentCanView) {
      throw new NotFoundException('Case not found.');
    }

    const link = await this.prismaService.execute((prisma) =>
      prisma.parentChildLink.findFirst({
        where: {
          parentId,
          childId: caseRecord.userId,
          status: 'active',
        },
      }),
    );
    if (!link) {
      throw new ForbiddenException('Not linked to this student.');
    }
    return caseRecord;
  }

  /** Student toggles whether their parent can see a given case. */
  async setParentVisibility(
    studentUserId: string,
    caseId: string,
    parentCanView: boolean,
  ) {
    const caseRecord = await this.prismaService.execute((prisma) =>
      prisma.case.findUnique({ where: { id: caseId } }),
    );
    if (!caseRecord || caseRecord.userId !== studentUserId) {
      throw new NotFoundException('Case not found.');
    }
    return this.prismaService.execute((prisma) =>
      prisma.case.update({
        where: { id: caseId },
        data: { parentCanView },
      }),
    );
  }
}

/** 8 characters, unambiguous (no 0/O, 1/I). Easy to dictate on a phone call. */
function generateInviteCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = randomBytes(8);
  let out = '';
  for (let i = 0; i < 8; i += 1) {
    out += alphabet[bytes[i] % alphabet.length];
  }
  return out;
}
