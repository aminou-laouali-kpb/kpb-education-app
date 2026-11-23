import { createHash } from 'crypto';
import { isIPv4, isIPv6 } from 'net';

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

// Verrou dur par couple (e-mail, réseau client).
const LOGIN_MAX_ATTEMPTS = 5;
const LOGIN_WINDOW_MS = 15 * 60 * 1000;
// Plafond global par e-mail, toutes IP confondues : borne la force brute
// distribuée (rotation d'IP). Nettement plus haut que le verrou par couple :
// pour bloquer un admin il faut ≥ 50 échecs depuis ≥ 10 réseaux distincts
// par fenêtre, au lieu de 5 requêtes depuis n'importe où.
const LOGIN_EMAIL_MAX_FAILURES = 50;
// Avant le plafond : délai progressif (sans blocage) au-delà de ce seuil.
const LOGIN_EMAIL_DELAY_AFTER = 10;
const LOGIN_EMAIL_DELAY_STEP_MS = 250;
const LOGIN_EMAIL_DELAY_MAX_MS = 5000;
// Taille max de chaque Map de compteurs (clés contrôlées par le client) :
// au-delà, éviction de l'entrée la plus ancienne (ordre d'insertion, O(1)).
const LOGIN_ATTEMPTS_MAX_ENTRIES = 10_000;

/**
 * Réseau client utilisé dans la clé : IPv4 telle quelle (y compris
 * ::ffff:a.b.c.d), IPv6 regroupée par /64 — un hôte IPv6 dispose en général
 * d'un /64 entier et pourrait sinon changer d'adresse à chaque essai.
 */
export function clientNetworkKey(clientIp?: string): string {
  const ip = clientIp?.trim().toLowerCase() ?? '';
  if (!ip) return 'unknown';
  const mapped = /^::ffff:(\d{1,3}(?:\.\d{1,3}){3})$/.exec(ip);
  if (mapped && isIPv4(mapped[1])) return mapped[1];
  if (isIPv4(ip)) return ip;
  if (!isIPv6(ip)) return ip;

  const [headRaw, tailRaw] = ip.split('::');
  const head = headRaw ? headRaw.split(':') : [];
  const tail = tailRaw !== undefined && tailRaw ? tailRaw.split(':') : [];
  const groups =
    tailRaw === undefined
      ? head
      : [...head, ...Array(8 - head.length - tail.length).fill('0'), ...tail];
  return `${groups
    .slice(0, 4)
    .map((g) => parseInt(g, 16).toString(16))
    .join(':')}::/64`;
}

/**
 * Clé du compteur d'échecs : couple (e-mail, réseau). Indexé par e-mail seul,
 * n'importe qui pouvait verrouiller un compte admin connu (5 requêtes /
 * 15 min) et l'admin légitime recevait un 429 même avec le bon mot de passe
 * (audit 2026-11-22, constat 5).
 */
function loginAttemptKey(email: string, clientIp?: string): string {
  return `${email}|${clientNetworkKey(clientIp)}`;
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
  private readonly emailFailures = new Map<string, LoginAttempt>();

  constructor(
    private readonly adminUsersService: AdminUsersService,
    private readonly jwtService: JwtService,
  ) {}

  async login(email: string, password?: string, clientIp?: string) {
    const normalizedEmail = email.trim().toLowerCase();
    const attemptKey = loginAttemptKey(normalizedEmail, clientIp);
    this.checkLoginAttempts(attemptKey);
    await this.throttleByEmail(normalizedEmail);

    const dbUser = await this.adminUsersService.findActiveUserByEmailWithCredentials(normalizedEmail);
    
    // For legacy/mock users without DB entries (e.g. initial setup)
    if (!dbUser) {
      // Fallback to memory search only if we are allowing mock access (not strictly production)
      const mockUser = await this.adminUsersService.findActiveUserByEmail(email);
      if (!mockUser) {
        this.recordFailedAttempt(attemptKey, normalizedEmail);
        throw new UnauthorizedException('Unknown or inactive admin account.');
      }
      
      // If we are relying on mock data, we bypass password check for backwards compatibility during dev
      if (process.env.NODE_ENV === 'production') {
        this.recordFailedAttempt(attemptKey, normalizedEmail);
        throw new UnauthorizedException('Invalid credentials.');
      }
      
      this.loginAttempts.delete(attemptKey);
      const sessionUser = this.toSessionUser(mockUser);
      return this.issueTokens(sessionUser);
    }

    // Standard secure flow for DB users
    if (dbUser.passwordHash) {
      if (!password) {
        this.recordFailedAttempt(attemptKey, normalizedEmail);
        throw new UnauthorizedException('Password required.');
      }
      const valid = await bcrypt.compare(password, dbUser.passwordHash);
      if (!valid) {
        this.recordFailedAttempt(attemptKey, normalizedEmail);
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
    const attempt = this.activeAttempt(this.loginAttempts, key);
    if (attempt && attempt.count >= LOGIN_MAX_ATTEMPTS) {
      this.throwTooManyAttempts(attempt);
    }
  }

  /**
   * Limite globale par e-mail : délai progressif au-delà de
   * LOGIN_EMAIL_DELAY_AFTER échecs, puis 429 au plafond. Le compteur n'est
   * pas remis à zéro par un succès : il mesure l'attaque, pas l'admin.
   */
  private async throttleByEmail(email: string): Promise<void> {
    const failures = this.activeAttempt(this.emailFailures, email);
    if (!failures) return;
    if (failures.count >= LOGIN_EMAIL_MAX_FAILURES) {
      this.throwTooManyAttempts(failures);
    }
    if (failures.count > LOGIN_EMAIL_DELAY_AFTER) {
      await this.sleep(
        Math.min(
          (failures.count - LOGIN_EMAIL_DELAY_AFTER) * LOGIN_EMAIL_DELAY_STEP_MS,
          LOGIN_EMAIL_DELAY_MAX_MS,
        ),
      );
    }
  }

  /** Point d'injection pour les tests (évite d'attendre réellement). */
  protected sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  private activeAttempt(
    map: Map<string, LoginAttempt>,
    key: string,
  ): LoginAttempt | undefined {
    const attempt = map.get(key);
    if (attempt && Date.now() - attempt.firstAttemptAt > LOGIN_WINDOW_MS) {
      map.delete(key);
      return undefined;
    }
    return attempt;
  }

  private throwTooManyAttempts(attempt: LoginAttempt): never {
    const elapsed = Date.now() - attempt.firstAttemptAt;
    const minutesLeft = Math.max(
      1,
      Math.ceil((LOGIN_WINDOW_MS - elapsed) / 60000),
    );
    throw new HttpException(
      `Too many login attempts. Try again in ${minutesLeft} minute(s).`,
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }

  private recordFailedAttempt(key: string, email: string): void {
    this.bumpAttempt(this.loginAttempts, key);
    this.bumpAttempt(this.emailFailures, email);
  }

  private bumpAttempt(map: Map<string, LoginAttempt>, key: string): void {
    const attempt = this.activeAttempt(map, key);
    if (attempt) {
      attempt.count++;
      return;
    }
    // Map bornée : l'ordre d'insertion d'une Map donne la plus ancienne
    // entrée en tête, évincée en O(1).
    while (map.size >= LOGIN_ATTEMPTS_MAX_ENTRIES) {
      const oldest = map.keys().next().value;
      if (oldest === undefined) break;
      map.delete(oldest);
    }
    map.set(key, { count: 1, firstAttemptAt: Date.now() });
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
