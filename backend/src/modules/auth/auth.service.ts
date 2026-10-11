import { createHash } from 'crypto';

import {
  Injectable,
  UnauthorizedException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';

import { AdminUsersService } from '../admin-users/admin-users.service';

/**
 * Opaque, stable fingerprint of the current password hash. It changes whenever
 * the password is (re)set, so binding an access token to it lets a password
 * reset invalidate any already-issued token on its next request.
 */
function passwordFingerprint(passwordHash: string | null): string | null {
  if (!passwordHash) {
    return null;
  }
  return createHash('sha256').update(passwordHash).digest('hex').slice(0, 16);
}

export interface AdminSessionUser {
  id: string;
  fullName: string;
  email: string;
  role: string;
  languageScope: string[];
}

interface LoginAttempt {
  count: number;
  firstAttemptAt: number;
}

const LOGIN_MAX_ATTEMPTS = 5;
const LOGIN_WINDOW_MS = 15 * 60 * 1000;

@Injectable()
export class AuthService {
  private readonly refreshSecret = (() => {
    const env = process.env.KPB_ADMIN_REFRESH_SECRET;
    if (!env && process.env.NODE_ENV === 'production') {
      throw new Error('KPB_ADMIN_REFRESH_SECRET must be set in production');
    }
    return env ?? 'kpb-admin-refresh-dev';
  })();

  private readonly loginAttempts = new Map<string, LoginAttempt>();

  constructor(
    private readonly adminUsersService: AdminUsersService,
    private readonly jwtService: JwtService,
  ) {}

  async login(email: string, password?: string) {
    const normalizedEmail = email.trim().toLowerCase();
    this.checkLoginAttempts(normalizedEmail);

    const dbUser = await this.adminUsersService.findActiveUserByEmailWithCredentials(normalizedEmail);
    
    // For legacy/mock users without DB entries (e.g. initial setup)
    if (!dbUser) {
      // Fallback to memory search only if we are allowing mock access (not strictly production)
      const mockUser = await this.adminUsersService.findActiveUserByEmail(email);
      if (!mockUser) {
        this.recordFailedAttempt(normalizedEmail);
        throw new UnauthorizedException('Unknown or inactive admin account.');
      }
      
      // If we are relying on mock data, we bypass password check for backwards compatibility during dev
      if (process.env.NODE_ENV === 'production') {
        this.recordFailedAttempt(normalizedEmail);
        throw new UnauthorizedException('Invalid credentials.');
      }
      
      this.loginAttempts.delete(normalizedEmail);
      const sessionUser = this.toSessionUser(mockUser);
      return this.issueTokens(sessionUser);
    }

    // Standard secure flow for DB users
    if (dbUser.passwordHash) {
      if (!password) {
        this.recordFailedAttempt(normalizedEmail);
        throw new UnauthorizedException('Password required.');
      }
      const valid = await bcrypt.compare(password, dbUser.passwordHash);
      if (!valid) {
        this.recordFailedAttempt(normalizedEmail);
        throw new UnauthorizedException('Invalid email or password.');
      }
    } else {
      // If passwordHash is null, the account has no password set.
      // In dev, we might allow it. In prod, we should block it until a password is set.
      if (process.env.NODE_ENV === 'production') {
        throw new UnauthorizedException('Admin account has no password set.');
      }
    }

    this.loginAttempts.delete(normalizedEmail);
    const sessionUser = this.toSessionUser(dbUser);
    return this.issueTokens(sessionUser);
  }

  async refresh(refreshToken: string) {
    let payload: { sub: string; email: string; type: string };
    try {
      payload = this.jwtService.verify(refreshToken, {
        secret: this.refreshSecret,
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token.');
    }

    if (payload.type !== 'admin-refresh') {
      throw new UnauthorizedException('Invalid token type.');
    }

    // Needs DB user to check refreshToken hash
    const dbUser = await this.adminUsersService.findActiveUserByEmailWithCredentials(payload.email || '');
    if (!dbUser || !dbUser.refreshToken) {
      throw new UnauthorizedException('Session expired.');
    }

    const valid = await bcrypt.compare(refreshToken, dbUser.refreshToken);
    if (!valid) {
      await this.adminUsersService.updateRefreshToken(dbUser.id, null);
      throw new UnauthorizedException('Refresh token revoked.');
    }

    return this.issueTokens(this.toSessionUser(dbUser));
  }

  /**
   * Révoque la session de refresh au logout. Avant, le logout effaçait
   * seulement les cookies : un refresh token copié restait valable 7 jours.
   * Silencieux sur un jeton invalide ou déjà révoqué (le logout réussit).
   */
  async revokeRefreshToken(refreshToken: string): Promise<void> {
    if (!refreshToken) return;
    let payload: { sub: string; email: string; type: string };
    try {
      payload = this.jwtService.verify(refreshToken, {
        secret: this.refreshSecret,
      });
    } catch {
      return;
    }
    if (payload.type !== 'admin-refresh') return;
    const dbUser =
      await this.adminUsersService.findActiveUserByEmailWithCredentials(
        payload.email || '',
      );
    if (!dbUser?.refreshToken) return;
    if (await bcrypt.compare(refreshToken, dbUser.refreshToken)) {
      await this.adminUsersService.updateRefreshToken(dbUser.id, null);
    }
  }

  async verifyToken(token: string): Promise<AdminSessionUser> {
    try {
      const payload = this.jwtService.verify(token);
      
      const user = await this.adminUsersService.findActiveUserByEmail(payload.email);
      if (!user) {
        throw new UnauthorizedException('Admin account is no longer active.');
      }

      // For DB-backed accounts, reject a token whose password fingerprint no
      // longer matches (e.g. after a reset), so a reset revokes any live
      // session immediately rather than only blocking future refreshes.
      const credentials =
        await this.adminUsersService.findActiveUserByEmailWithCredentials(
          payload.email,
        );
      if (
        credentials &&
        payload.pwd !== passwordFingerprint(credentials.passwordHash)
      ) {
        throw new UnauthorizedException('Admin session has been revoked.');
      }

      return this.toSessionUser(user);
    } catch {
      throw new UnauthorizedException('Invalid or expired admin token.');
    }
  }

  private async issueTokens(user: AdminSessionUser) {
    // Load credentials first so the access token can carry the current password
    // fingerprint (used by verifyToken to revoke tokens after a password reset).
    const dbUser = await this.adminUsersService.findActiveUserByEmailWithCredentials(user.email);

    const token = this.jwtService.sign(
      {
        sub: user.id,
        email: user.email,
        role: user.role,
        languageScope: user.languageScope,
        fullName: user.fullName,
        pwd: passwordFingerprint(dbUser?.passwordHash ?? null),
      },
      { expiresIn: '1h' },
    );

    const refreshToken = this.jwtService.sign(
      { sub: user.id, email: user.email, type: 'admin-refresh' },
      { secret: this.refreshSecret, expiresIn: '7d' },
    );

    const refreshHash = await bcrypt.hash(refreshToken, 10);

    // Only save refresh token if it's a DB user
    if (dbUser) {
      await this.adminUsersService.updateRefreshToken(user.id, refreshHash);
    }

    return { token, refreshToken, user };
  }

  private checkLoginAttempts(email: string): void {
    const attempt = this.loginAttempts.get(email);
    if (!attempt) return;

    const elapsed = Date.now() - attempt.firstAttemptAt;
    if (elapsed > LOGIN_WINDOW_MS) {
      this.loginAttempts.delete(email);
      return;
    }

    if (attempt.count >= LOGIN_MAX_ATTEMPTS) {
      const minutesLeft = Math.ceil((LOGIN_WINDOW_MS - elapsed) / 60000);
      throw new HttpException(
        `Too many login attempts. Try again in ${minutesLeft} minute(s).`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private recordFailedAttempt(email: string): void {
    const attempt = this.loginAttempts.get(email);
    if (!attempt || Date.now() - attempt.firstAttemptAt > LOGIN_WINDOW_MS) {
      this.loginAttempts.set(email, { count: 1, firstAttemptAt: Date.now() });
    } else {
      attempt.count++;
    }
  }

  private toSessionUser(user: {
    id: string;
    fullName: string;
    email: string;
    role: string;
    languageScope: string[];
  }): AdminSessionUser {
    return {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      role: user.role,
      languageScope: user.languageScope,
    };
  }
}
