import { randomBytes } from 'crypto';

import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';

import { mockAdminData } from '../../common/data/mock-admin';
import { InternalRole } from '../../common/enums/internal-role.enum';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAdminUserDto } from './dto/create-admin-user.dto';
import { UpdateAdminUserDto } from './dto/update-admin-user.dto';

type AdminUserRecord = (typeof mockAdminData.adminUsers)[number];

/** A short, strong, easy-to-dictate temporary password (~12 url-safe chars). */
function generateTempPassword(): string {
  return randomBytes(9).toString('base64url');
}

/** Prisma unique-constraint violation (e.g. duplicate email). */
function isUniqueConstraintError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: string }).code === 'P2002'
  );
}

@Injectable()
export class AdminUsersService {
  constructor(private readonly prismaService: PrismaService) {}

  private readonly users = [...mockAdminData.adminUsers];

  async listUsers() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.adminUser.findMany({
        orderBy: { createdAt: 'desc' },
      }),
    );

    if (items) {
      return {
        items: items.map((item) => ({
          id: item.id,
          fullName: item.fullName,
          email: item.email,
          role: item.role,
          isActive: item.isActive,
          languageScope: item.languageScope,
          workload: item.workload,
        })),
      };
    }

    return { items: this.users };
  }

  /** Rôle d'un opérateur (null s'il n'existe pas). */
  async getRole(id: string): Promise<string | null> {
    const dbUser = await this.prismaService.execute((prisma) =>
      prisma.adminUser.findUnique({ where: { id }, select: { role: true } }),
    );
    if (dbUser) return dbUser.role;
    return this.users.find((item) => item.id === id)?.role ?? null;
  }

  async findActiveUserByEmail(email: string) {
    const dbUser = await this.prismaService.execute((prisma) =>
      prisma.adminUser.findFirst({
        where: {
          email: { equals: email, mode: 'insensitive' },
          isActive: true,
        },
      }),
    );

    if (dbUser) {
      return {
        id: dbUser.id,
        fullName: dbUser.fullName,
        email: dbUser.email,
        role: dbUser.role,
        isActive: dbUser.isActive,
        languageScope: dbUser.languageScope,
        workload: dbUser.workload,
      };
    }

    return this.users.find(
      (user) =>
        user.email.toLowerCase() === email.toLowerCase() && user.isActive,
    );
  }

  async findActiveUserByEmailWithCredentials(email: string) {
    return this.prismaService.execute((prisma) =>
      prisma.adminUser.findFirst({
        where: {
          email: { equals: email, mode: 'insensitive' },
          isActive: true,
        },
      }),
    );
  }

  async updateRefreshToken(id: string, refreshToken: string | null) {
    return this.prismaService.execute((prisma) =>
      prisma.adminUser.update({
        where: { id },
        data: { refreshToken },
      }),
    );
  }

  /**
   * Create an internal operator. A per-user temporary password is generated and
   * bcrypt-hashed server-side so the account can log in immediately; the
   * plaintext is returned ONCE (as `tempPassword`) for the admin to hand over.
   */
  async createUser(input: CreateAdminUserDto) {
    const email = input.email.trim().toLowerCase();
    const tempPassword = generateTempPassword();
    const passwordHash = await bcrypt.hash(tempPassword, 12);
    const isActive = input.isActive ?? true;
    const languageScope = input.languageScope ?? ['fr', 'en'];
    const workload = input.workload ?? 0;

    let created;
    try {
      created = await this.prismaService.execute((prisma) =>
        prisma.adminUser.create({
          data: {
            fullName: input.fullName,
            email,
            role: input.role,
            isActive,
            languageScope,
            workload,
            passwordHash,
          },
        }),
      );
    } catch (error) {
      if (isUniqueConstraintError(error)) {
        throw new ConflictException(
          `An admin account with email ${email} already exists.`,
        );
      }
      throw error;
    }

    if (created) {
      return {
        id: created.id,
        fullName: created.fullName,
        email: created.email,
        role: created.role,
        isActive: created.isActive,
        languageScope: created.languageScope,
        workload: created.workload,
        tempPassword,
      };
    }

    // DB-less fallback (local dev without DATABASE_URL).
    const record: AdminUserRecord = {
      id: `admin-user-${Date.now()}`,
      fullName: input.fullName,
      email,
      role: input.role,
      isActive,
      languageScope,
      workload,
    };
    this.users.unshift(record);
    return { ...record, tempPassword };
  }

  /**
   * Re-issue a temporary password for an operator. Rotating the password hash
   * invalidates any live access token (AuthService binds each token to the
   * password fingerprint) and clearing the refresh token stops future
   * refreshes — so this fully signs the operator out. Returns the plaintext once.
   */
  async resetPassword(id: string) {
    const tempPassword = generateTempPassword();
    const passwordHash = await bcrypt.hash(tempPassword, 12);

    const updated = await this.prismaService.execute((prisma) =>
      prisma.adminUser.update({
        where: { id },
        data: { passwordHash, refreshToken: null },
      }),
    );

    if (!updated) {
      throw new NotFoundException(`Admin user ${id} not found.`);
    }

    return { id: updated.id, email: updated.email, tempPassword };
  }

  // `passwordHash`/`refreshToken` are not part of UpdateAdminUserDto, so they
  // can never be set through the PATCH endpoint (the global whitelist pipe
  // strips unknown fields). They are accepted here only for internal callers
  // such as AuthService.issueTokens (refresh token) and resetPassword.
  async updateUser(
    id: string,
    input: UpdateAdminUserDto & {
      passwordHash?: string;
      refreshToken?: string | null;
    },
  ) {
    const updated = await this.prismaService.execute((prisma) =>
      prisma.adminUser.update({
        where: { id },
        data: {
          ...(input.role ? { role: input.role } : {}),
          ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
          ...(input.workload !== undefined ? { workload: input.workload } : {}),
          ...(input.languageScope
            ? { languageScope: input.languageScope }
            : {}),
          ...(input.passwordHash ? { passwordHash: input.passwordHash } : {}),
          ...(input.refreshToken !== undefined
            ? { refreshToken: input.refreshToken }
            : {}),
        },
      }),
    );

    if (updated) {
      return {
        id: updated.id,
        fullName: updated.fullName,
        email: updated.email,
        role: updated.role,
        isActive: updated.isActive,
        languageScope: updated.languageScope,
        workload: updated.workload,
      };
    }

    const index = this.users.findIndex((item) => item.id === id);
    if (index < 0) {
      throw new NotFoundException(`Admin user ${id} not found.`);
    }
    this.users[index] = {
      ...this.users[index],
      ...input,
    } as AdminUserRecord;
    return this.users[index];
  }
}
