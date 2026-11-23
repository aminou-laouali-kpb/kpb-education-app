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
// Au-delà, on purge les entrées expirées pour borner la mémoire (le couple
// e-mail/IP est contrôlé par le client).
const LOGIN_ATTEMPTS_PRUNE_THRESHOLD = 10_000;

/**
 * Clé du compteur d'échecs : couple (e-mail, IP). Indexé par e-mail seul,
 * n'importe qui pouvait verrouiller un compte admin connu (5 requêtes /
 * 15 min) et l'admin légitime recevait un 429 même avec le bon mot de passe
 * (audit 2026-11-22, constat 5). Le brute force reste limité par IP (ce
 * compteur + ADMIN_LOGIN_THROTTLE) et par le coût bcrypt.
 */
function loginAttemptKey(email: string, clientIp?: string): string {
  return `${email}|${clientIp?.trim() || 'unknown'}`;
}

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

  async login(email: string, password?: string, clientIp?: string) {
    const normalizedEmail = email.trim().toLowerCase();
    const attemptKey = loginAttemptKey(normalizedEmail, clientIp);
    this.checkLoginAttempts(attemptKey);

    const dbUser = await this.adminUsersService.findActiveUserByEmailWithCredentials(normalizedEmail);
    
    // For legacy/mock users without DB entries (e.g. initial setup)
    if (!dbUser) {
      // Fallback to memory search only if we are allowing mock access (not strictly production)
      const mockUser = await this.adminUsersService.findActiveUserByEmail(email);
      if (!mockUser) {
        this.recordFailedAttempt(attemptKey);
        throw new UnauthorizedException('Unknown or inactive admin account.');
      }
      
      // If we are relying on mock data, we bypass password check for backwards compatibility during dev
      if (process.env.NODE_ENV === 'production') {
        this.recordFailedAttempt(attemptKey);
        throw new UnauthorizedException('Invalid credentials.');
      }
      
      this.loginAttempts.delete(attemptKey);
      const sessionUser = this.toSessionUser(mockUser);
      return this.issueTokens(sessionUser);
    }

    // Standard secure flow for DB users
    if (dbUser.passwordHash) {
      if (!password) {
        this.recordFailedAttempt(attemptKey);
        throw new UnauthorizedException('Password required.');
      }
      const valid = await bcrypt.compare(password, dbUser.passwordHash);
      if (!valid) {
        this.recordFailedAttempt(attemptKey);
        throw new UnauthorizedException('Invalid email or password.');
      }
    } else {
      // If passwordHash is null, the account has no password set.
      // In dev, we might allow it. In prod, we should block it until a password is set.
      if (process.env.NODE_ENV === 'production') {
        throw new UnauthorizedException('Admin account has no password set.');
      }
    }

    this.loginAttempts.delete(attemptKey);
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
      const email = typeof payload?.email === 'string' ? payload.email : '';
      if (!email) {
        throw new UnauthorizedException('Invalid admin token.');
      }

      // Base disponible : seul l'utilisateur actif lu en base fait autorité.
      // Pas de repli mock ici (sinon un compte fondateur désactivé en base
      // restait accepté via la liste mock, sans contrôle d'empreinte pwd).
      if (this.adminUsersService.usesDatabase()) {
        const credentials =
          await this.adminUsersService.findActiveUserByEmailWithCredentials(
            email,
          );
        if (!credentials) {
          throw new UnauthorizedException('Admin account is no longer active.');
        }

        // Rejette un jeton dont l'empreinte du mot de passe ne correspond plus
        // (ex. après un reset) : le reset révoque immédiatement toute session.
        if (payload.pwd !== passwordFingerprint(credentials.passwordHash)) {
          throw new UnauthorizedException('Admin session has been revoked.');
        }

        return this.toSessionUser(credentials);
      }

      // Sans base : repli mock permis seulement hors production (même garde
      // que login).
      if (process.env.NODE_ENV === 'production') {
        throw new UnauthorizedException('Admin account is no longer active.');
      }
      const user = await this.adminUsersService.findActiveUserByEmail(email);
      if (!user) {
        throw new UnauthorizedException('Admin account is no longer active.');
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

  private checkLoginAttempts(key: string): void {
    const attempt = this.loginAttempts.get(key);
    if (!attempt) return;

    const elapsed = Date.now() - attempt.firstAttemptAt;
    if (elapsed > LOGIN_WINDOW_MS) {
      this.loginAttempts.delete(key);
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

  private recordFailedAttempt(key: string): void {
    const now = Date.now();
    const attempt = this.loginAttempts.get(key);
    if (!attempt || now - attempt.firstAttemptAt > LOGIN_WINDOW_MS) {
      if (this.loginAttempts.size >= LOGIN_ATTEMPTS_PRUNE_THRESHOLD) {
        for (const [k, a] of this.loginAttempts) {
          if (now - a.firstAttemptAt > LOGIN_WINDOW_MS) {
            this.loginAttempts.delete(k);
          }
        }
      }
      this.loginAttempts.set(key, { count: 1, firstAttemptAt: now });
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
