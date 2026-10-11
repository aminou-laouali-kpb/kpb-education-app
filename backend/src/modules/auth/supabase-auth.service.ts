import {
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { verify as jsonwebtokenVerify } from 'jsonwebtoken';
import { createPublicKey } from 'crypto';
import type { JsonWebKey as CryptoJsonWebKey } from 'crypto';

import { PrismaService } from '../prisma/prisma.service';
import type { AccountType } from '@prisma/client';

/// Shape attached to `request.studentUser` by the guard. Kept identical to the
/// legacy `StudentTokenUser` contract so the ~13 student-facing controllers
/// need no changes.
export interface SupabaseTokenUser {
  id: string;
  email: string;
  fullName: string;
  role: 'student';
  accountType: AccountType;
}

interface Jwk {
  kid?: string;
  kty: string;
  [key: string]: unknown;
}

const JWKS_CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes
// Un `kid` inconnu ne force pas un nouveau fetch plus d'une fois par minute :
// sinon chaque token forgé déclenche une requête sortante vers Supabase.
const JWKS_MIN_REFRESH_INTERVAL_MS = 60 * 1000;
const JWKS_FETCH_TIMEOUT_MS = 5000;
const SUPABASE_ROLE_TO_ACCOUNT: Record<string, AccountType> = {
  student: 'student',
  parent: 'parent',
  partner: 'partner',
  // `commercial` is an internal staff role, never provisioned here as a
  // student profile; commercial users authenticate through the admin path.
};

/**
 * Verifies Supabase Auth access tokens and maps them to a local UserProfile.
 *
 * Supports both signing schemes:
 *  - Asymmetric (ES256/RS256) via the project JWKS endpoint (default for new
 *    projects). Public keys are fetched on demand and cached.
 *  - Symmetric (HS256) via `SUPABASE_JWT_SECRET` (legacy projects). When the
 *    secret is set it takes precedence.
 *
 * Business data stays in Postgres/Prisma — Supabase is used for auth only.
 */
@Injectable()
export class SupabaseAuthService {
  private readonly supabaseUrl = (
    process.env.SUPABASE_URL ?? ''
  ).replace(/\/+$/, '');
  private readonly jwtSecret = process.env.SUPABASE_JWT_SECRET;

  private jwksCache: { keys: Jwk[]; fetchedAt: number } | null = null;

  constructor(
    private readonly prismaService: PrismaService,
    private readonly jwtService: JwtService,
  ) {
    // Fail loud at boot rather than silently 401-ing every student/parent
    // request: SUPABASE_URL is required for both the JWKS and HS256 (issuer) paths.
    if (process.env.NODE_ENV === 'production' && !this.supabaseUrl) {
      throw new Error(
        'SUPABASE_URL must be set in production — student/parent authentication depends on it.',
      );
    }
  }

  private get issuer(): string {
    return `${this.supabaseUrl}/auth/v1`;
  }

  /** Verifies the token signature/claims and resolves the local profile. */
  async verifyAndResolve(token: string): Promise<SupabaseTokenUser> {
    if (!this.supabaseUrl && !this.jwtSecret) {
      throw new UnauthorizedException('Supabase auth is not configured.');
    }

    const payload = await this.verifyToken(token);

    const sub = typeof payload.sub === 'string' ? payload.sub : undefined;
    const email =
      typeof payload.email === 'string'
        ? payload.email.trim().toLowerCase()
        : undefined;
    if (!sub || !email) {
      throw new UnauthorizedException('Token missing subject or email.');
    }

    const role = this.extractRole(payload);
    const profile = await this.resolveProfile({ sub, email, role });

    return {
      id: profile.id,
      email,
      fullName: profile.fullName,
      role: 'student',
      accountType: profile.accountType,
    };
  }

  // ── Signature verification ──────────────────────────────────────────────

  private async verifyToken(
    token: string,
  ): Promise<Record<string, unknown>> {
    const verifyOptions = {
      issuer: this.issuer,
      audience: 'authenticated',
    } as const;

    try {
      if (this.jwtSecret) {
        return this.jwtService.verify(token, {
          secret: this.jwtSecret,
          algorithms: ['HS256'],
          ...verifyOptions,
        });
      }

      const pem = await this.resolveSigningKey(token);
      // Deliberately NOT this.jwtService.verify here: @nestjs/jwt resolves the
      // module-level `secret` (KPB_JWT_SECRET, registered globally in
      // AppModule) with higher priority than a per-call `publicKey`, so the
      // ES256 signature would be checked against the HS256 secret and always
      // fail. jsonwebtoken.verify takes the key positionally — no shadowing.
      return jsonwebtokenVerify(token, pem, {
        algorithms: ['ES256', 'RS256'],
        ...verifyOptions,
      }) as Record<string, unknown>;
    } catch (error) {
      // Une panne d'infrastructure (JWKS injoignable) est un 503, PAS un 401 :
      // l'app traite un 401 comme une session morte et déconnecte l'utilisateur.
      if (
        error instanceof UnauthorizedException ||
        error instanceof ServiceUnavailableException
      ) {
        throw error;
      }
      throw new UnauthorizedException('Invalid or expired access token.');
    }
  }

  private async resolveSigningKey(token: string): Promise<string> {
    const kid = this.decodeHeader(token).kid;
    let jwk = await this.findJwk(kid);
    if (
      !jwk &&
      (!this.jwksCache ||
        Date.now() - this.jwksCache.fetchedAt > JWKS_MIN_REFRESH_INTERVAL_MS)
    ) {
      // Key may have rotated since last fetch — force a refresh once.
      this.jwksCache = null;
      jwk = await this.findJwk(kid);
    }
    if (!jwk) {
      throw new UnauthorizedException('No matching signing key for token.');
    }
    return createPublicKey({ key: jwk as unknown as CryptoJsonWebKey, format: 'jwk' })
      .export({ type: 'spki', format: 'pem' })
      .toString();
  }

  private decodeHeader(token: string): { kid?: string; alg?: string } {
    const segment = token.split('.')[0];
    if (!segment) throw new UnauthorizedException('Malformed token.');
    try {
      return JSON.parse(
        Buffer.from(segment, 'base64url').toString('utf8'),
      );
    } catch {
      throw new UnauthorizedException('Malformed token header.');
    }
  }

  private async findJwk(kid?: string): Promise<Jwk | undefined> {
    const keys = await this.getJwks();
    if (!kid) return keys[0];
    return keys.find((k) => k.kid === kid) ?? undefined;
  }

  private async getJwks(): Promise<Jwk[]> {
    const now = Date.now();
    if (this.jwksCache && now - this.jwksCache.fetchedAt < JWKS_CACHE_TTL_MS) {
      return this.jwksCache.keys;
    }
    let body: { keys?: Jwk[] };
    try {
      const res = await fetch(
        `${this.supabaseUrl}/auth/v1/.well-known/jwks.json`,
        { signal: AbortSignal.timeout(JWKS_FETCH_TIMEOUT_MS) },
      );
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      body = (await res.json()) as { keys?: Jwk[] };
    } catch {
      throw new ServiceUnavailableException('Unable to fetch signing keys.');
    }
    const keys = body.keys ?? [];
    this.jwksCache = { keys, fetchedAt: now };
    return keys;
  }

  // ── Profile mapping (provision-on-first-login) ───────────────────────────

  private extractRole(payload: Record<string, unknown>): AccountType {
    const appMeta = payload.app_metadata as
      | { role?: unknown }
      | undefined;
    const raw =
      typeof appMeta?.role === 'string' ? appMeta.role.toLowerCase() : '';
    return SUPABASE_ROLE_TO_ACCOUNT[raw] ?? 'student';
  }

  private async resolveProfile(input: {
    sub: string;
    email: string;
    role: AccountType;
  }): Promise<{ id: string; accountType: AccountType; fullName: string }> {
    const { sub, email, role } = input;

    const byId = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({
        where: { supabaseUserId: sub },
        select: { id: true, accountType: true, fullName: true },
      }),
    );
    if (byId) return byId;

    // Link an existing (legacy) profile that shares the email, then stamp it
    // with the Supabase id so future lookups hit the fast path above.
    const byEmail = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({
        where: { email },
        select: {
          id: true,
          supabaseUserId: true,
          accountType: true,
          fullName: true,
        },
      }),
    );
    if (byEmail) {
      if (!byEmail.supabaseUserId) {
        await this.prismaService.tryExecute((prisma) =>
          prisma.userProfile.update({
            where: { id: byEmail.id },
            data: { supabaseUserId: sub },
          }),
        );
      }
      return {
        id: byEmail.id,
        accountType: byEmail.accountType,
        fullName: byEmail.fullName,
      };
    }

    const displayName =
      email.split('@')[0]?.replace(/[._-]+/g, ' ').trim() || 'Utilisateur';
    const created = await this.prismaService.execute((prisma) =>
      prisma.userProfile.create({
        data: {
          supabaseUserId: sub,
          accountType: role,
          fullName: displayName.slice(0, 80),
          email,
          phone: '',
          countryOfResidence: '',
          preferredLanguage: 'fr',
        },
        select: { id: true, accountType: true, fullName: true },
      }),
    );
    if (!created) {
      throw new ServiceUnavailableException('Database unavailable.');
    }
    return created;
  }
}
