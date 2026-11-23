import { createHash } from 'crypto';

import { Test, TestingModule } from '@nestjs/testing';
import { HttpStatus, UnauthorizedException } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';

import { AuthService, clientNetworkKey } from './auth.service';
import { AdminUsersService } from '../admin-users/admin-users.service';

const mockAdminUsersService = {
  findActiveUserByEmail: jest.fn(),
  findActiveUserByEmailWithCredentials: jest.fn(),
  updateRefreshToken: jest.fn(),
  usesDatabase: jest.fn(),
};

describe('AuthService', () => {
  let service: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [JwtModule.register({ secret: 'test-secret' })],
      providers: [
        AuthService,
        {
          provide: AdminUsersService,
          useValue: mockAdminUsersService,
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    jest.clearAllMocks();
    // Default: no DB-backed credential row, so login falls back to the mock
    // (non-production) path and issueTokens skips persisting a refresh token.
    mockAdminUsersService.findActiveUserByEmailWithCredentials.mockResolvedValue(
      null,
    );
    mockAdminUsersService.updateRefreshToken.mockResolvedValue(undefined);
    // Par défaut : pas de base, repli mock (hors production).
    mockAdminUsersService.usesDatabase.mockReturnValue(false);
  });

  it('throws UnauthorizedException when login email is unknown', async () => {
    mockAdminUsersService.findActiveUserByEmail.mockResolvedValueOnce(null);

    await expect(service.login('unknown@kpb.education')).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('returns token and user on successful login', async () => {
    const user = {
      id: 'admin-1',
      fullName: 'Admin User',
      email: 'admin@kpb.education',
      role: 'admin',
      languageScope: ['fr'],
      isActive: true,
      workload: 0,
    };

    mockAdminUsersService.findActiveUserByEmail.mockResolvedValueOnce(user);

    const result = await service.login(user.email);

    expect(result.token).toBeDefined();
    expect(result.user.email).toBe(user.email);
    expect(result.user.fullName).toBe(user.fullName);
  });

  it('rejects malformed token', async () => {
    await expect(service.verifyToken('malformed-token')).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('verifies valid token and returns current session user', async () => {
    const user = {
      id: 'admin-2',
      fullName: 'Ops User',
      email: 'ops@kpb.education',
      role: 'counselor',
      languageScope: ['fr', 'en'],
      isActive: true,
      workload: 2,
    };

    mockAdminUsersService.findActiveUserByEmail.mockResolvedValueOnce(user);
    const login = await service.login(user.email);

    mockAdminUsersService.findActiveUserByEmail.mockResolvedValueOnce(user);
    const verified = await service.verifyToken(login.token);

    expect(verified.id).toBe(user.id);
    expect(verified.email).toBe(user.email);
    expect(verified.languageScope).toEqual(user.languageScope);
  });

  describe('verifyToken avec base configurée', () => {
    const founder = {
      id: 'admin-aminou',
      fullName: 'Aminou Laouali',
      email: 'alaoualiabdou@karatoupostbac.com',
      role: 'admin',
      languageScope: ['fr', 'en'],
      isActive: true,
      workload: 0,
    };

    function signAccess(pwd: string | null) {
      const jwt = (service as any).jwtService;
      return jwt.sign(
        { sub: founder.id, email: founder.email, role: founder.role, pwd },
        { expiresIn: '1h' },
      ) as string;
    }

    function fingerprint(hash: string) {
      return createHash('sha256').update(hash).digest('hex').slice(0, 16);
    }

    beforeEach(() => {
      mockAdminUsersService.usesDatabase.mockReturnValue(true);
    });

    it('rejette un compte désactivé en base même si son e-mail est dans le mock', async () => {
      // Compte inactif : la lecture en base ne renvoie rien...
      mockAdminUsersService.findActiveUserByEmailWithCredentials.mockResolvedValue(null);
      // ...alors que la liste mock contient encore cet e-mail comme actif.
      mockAdminUsersService.findActiveUserByEmail.mockResolvedValue(founder);

      await expect(service.verifyToken(signAccess(null))).rejects.toThrow(
        UnauthorizedException,
      );
      expect(mockAdminUsersService.findActiveUserByEmail).not.toHaveBeenCalled();
    });

    it('rejette un jeton dont l\'empreinte pwd est obsolète', async () => {
      mockAdminUsersService.findActiveUserByEmailWithCredentials.mockResolvedValue({
        ...founder,
        passwordHash: '$2b$12$nouveau-hash-apres-reset',
      });

      await expect(
        service.verifyToken(signAccess(fingerprint('$2b$12$ancien-hash'))),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('rejette un jeton sans pwd quand le compte en base a un mot de passe', async () => {
      mockAdminUsersService.findActiveUserByEmailWithCredentials.mockResolvedValue({
        ...founder,
        passwordHash: '$2b$12$hash',
      });

      await expect(service.verifyToken(signAccess(null))).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('accepte un jeton à l\'empreinte pwd courante et renvoie l\'utilisateur en base', async () => {
      const hash = '$2b$12$hash-courant';
      mockAdminUsersService.findActiveUserByEmailWithCredentials.mockResolvedValue({
        ...founder,
        passwordHash: hash,
      });

      const verified = await service.verifyToken(signAccess(fingerprint(hash)));
      expect(verified.id).toBe(founder.id);
      expect(verified.email).toBe(founder.email);
      expect(mockAdminUsersService.findActiveUserByEmail).not.toHaveBeenCalled();
    });
  });

  it('refuse le repli mock de verifyToken en production sans base', async () => {
    const user = {
      id: 'admin-2',
      fullName: 'Ops User',
      email: 'ops@kpb.education',
      role: 'counselor',
      languageScope: ['fr'],
      isActive: true,
      workload: 0,
    };
    mockAdminUsersService.findActiveUserByEmail.mockResolvedValue(user);
    const login = await service.login(user.email);

    const previousEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    try {
      await expect(service.verifyToken(login.token)).rejects.toThrow(
        UnauthorizedException,
      );
    } finally {
      process.env.NODE_ENV = previousEnv;
    }
  });

  describe('verrouillage du login par couple (e-mail, IP)', () => {
    const admin = {
      id: 'admin-lock',
      fullName: 'Admin Lock',
      email: 'admin-lock@kpb.education',
      role: 'admin',
      languageScope: ['fr'],
      isActive: true,
      workload: 0,
    };
    let passwordHash: string;

    beforeAll(async () => {
      passwordHash = await bcrypt.hash('bon-mot-de-passe', 4);
    });

    beforeEach(() => {
      mockAdminUsersService.findActiveUserByEmailWithCredentials.mockResolvedValue(
        { ...admin, passwordHash, refreshToken: null },
      );
    });

    async function failFrom(ip: string, times: number) {
      for (let i = 0; i < times; i++) {
        await expect(
          service.login(admin.email, 'mauvais', ip),
        ).rejects.toThrow(UnauthorizedException);
      }
    }

    it("des échecs depuis l'IP d'un attaquant ne bloquent pas l'admin sur une autre IP", async () => {
      await failFrom('203.0.113.66', 5);
      // L'attaquant est bloqué sur son IP...
      await expect(
        service.login(admin.email, 'mauvais', '203.0.113.66'),
      ).rejects.toMatchObject({ status: HttpStatus.TOO_MANY_REQUESTS });

      // ...mais l'admin légitime se connecte depuis son IP (constat 5).
      const result = await service.login(
        admin.email.toUpperCase(),
        'bon-mot-de-passe',
        '198.51.100.7',
      );
      expect(result.user.id).toBe(admin.id);
    });

    it('garde la protection brute force : 5 échecs depuis une IP la bloquent, même avec le bon mot de passe', async () => {
      await failFrom('203.0.113.66', 5);
      await expect(
        service.login(admin.email, 'bon-mot-de-passe', '203.0.113.66'),
      ).rejects.toMatchObject({ status: HttpStatus.TOO_MANY_REQUESTS });
    });

    it('un succès remet à zéro le compteur de ce couple (e-mail, IP)', async () => {
      await failFrom('198.51.100.7', 4);
      await service.login(admin.email, 'bon-mot-de-passe', '198.51.100.7');
      await failFrom('198.51.100.7', 4);
      const result = await service.login(
        admin.email,
        'bon-mot-de-passe',
        '198.51.100.7',
      );
      expect(result.user.id).toBe(admin.id);
    });
  });

  describe('plafond global par e-mail et regroupement IPv6', () => {
    const admin = {
      id: 'admin-global',
      fullName: 'Admin Global',
      email: 'admin-global@kpb.education',
      role: 'admin',
      languageScope: ['fr'],
      isActive: true,
      workload: 0,
    };
    let passwordHash: string;
    let sleepSpy: jest.SpyInstance;

    beforeAll(async () => {
      passwordHash = await bcrypt.hash('bon-mot-de-passe', 4);
    });

    beforeEach(() => {
      mockAdminUsersService.findActiveUserByEmailWithCredentials.mockResolvedValue(
        { ...admin, passwordHash, refreshToken: null },
      );
      // Pas d'attente réelle : on vérifie seulement les délais demandés.
      sleepSpy = jest
        .spyOn(service as any, 'sleep')
        .mockResolvedValue(undefined);
    });

    it('regroupe les IPv6 par /64 et normalise les IPv4 mappées', () => {
      expect(clientNetworkKey('2001:db8:1:2:aaaa::1')).toBe('2001:db8:1:2::/64');
      expect(clientNetworkKey('2001:db8:1:2:ffff:ffff:ffff:fffe')).toBe(
        '2001:db8:1:2::/64',
      );
      expect(clientNetworkKey('2001:DB8::1')).toBe('2001:db8:0:0::/64');
      expect(clientNetworkKey('::ffff:203.0.113.5')).toBe('203.0.113.5');
      expect(clientNetworkKey('203.0.113.5')).toBe('203.0.113.5');
      expect(clientNetworkKey(undefined)).toBe('unknown');
    });

    it('la rotation d\'adresses dans un même /64 ne contourne pas le verrou', async () => {
      for (let i = 1; i <= 5; i++) {
        await expect(
          service.login(admin.email, 'mauvais', `2001:db8:1:2::${i}`),
        ).rejects.toThrow(UnauthorizedException);
      }
      await expect(
        service.login(admin.email, 'bon-mot-de-passe', '2001:db8:1:2::99'),
      ).rejects.toMatchObject({ status: HttpStatus.TOO_MANY_REQUESTS });
    });

    it('force brute distribuée : délai progressif puis plafond global à 50 échecs', async () => {
      // 50 échecs depuis 50 IP différentes (1 chacune : aucun verrou par couple).
      for (let i = 0; i < 50; i++) {
        await expect(
          service.login(admin.email, 'mauvais', `198.18.${i}.1`),
        ).rejects.toThrow(UnauthorizedException);
      }
      // Délai demandé dès le 12e essai (11 échecs déjà comptés), croissant et borné.
      const delays = sleepSpy.mock.calls.map((c) => c[0] as number);
      expect(delays[0]).toBe(250);
      expect(delays).toEqual([...delays].sort((a, b) => a - b));
      expect(Math.max(...delays)).toBe(5000);

      // Plafond atteint : 429 depuis une IP neuve, sans vérifier le mot de passe.
      await expect(
        service.login(admin.email, 'bon-mot-de-passe', '198.51.100.200'),
      ).rejects.toMatchObject({ status: HttpStatus.TOO_MANY_REQUESTS });
    });

    it('sous le plafond, l\'admin passe (avec délai) malgré des échecs venus d\'ailleurs', async () => {
      for (let i = 0; i < 20; i++) {
        await expect(
          service.login(admin.email, 'mauvais', `198.18.${i}.1`),
        ).rejects.toThrow(UnauthorizedException);
      }
      sleepSpy.mockClear();
      const result = await service.login(
        admin.email,
        'bon-mot-de-passe',
        '198.51.100.7',
      );
      expect(result.user.id).toBe(admin.id);
      expect(sleepSpy).toHaveBeenCalledWith(2500);
    });

    it('borne la Map des compteurs en évinçant la plus ancienne entrée', async () => {
      mockAdminUsersService.findActiveUserByEmailWithCredentials.mockResolvedValue(
        null,
      );
      mockAdminUsersService.findActiveUserByEmail.mockResolvedValue(null);
      const attempts = (service as any).loginAttempts as Map<string, unknown>;
      for (let i = 0; i < 10_001; i++) {
        attempts.set(`seed-${i}@x|10.0.0.1`, {
          count: 1,
          firstAttemptAt: Date.now(),
        });
        if (attempts.size >= 10_000) break;
      }
      expect(attempts.size).toBe(10_000);

      await expect(
        service.login('nouveau@kpb.education', 'x', '10.9.9.9'),
      ).rejects.toThrow(UnauthorizedException);

      expect(attempts.size).toBe(10_000);
      expect(attempts.has('seed-0@x|10.0.0.1')).toBe(false);
      expect(attempts.has('nouveau@kpb.education|10.9.9.9')).toBe(true);
    });
  });

  describe('revokeRefreshToken (logout)', () => {
    it('clears the stored refresh hash when the token matches', async () => {
      const bcrypt = await import('bcrypt');
      const jwt = (service as any).jwtService;
      const token = jwt.sign(
        { sub: 'admin-1', email: 'a@kpb.education', type: 'admin-refresh' },
        { secret: (service as any).refreshSecret, expiresIn: '7d' },
      );
      mockAdminUsersService.findActiveUserByEmailWithCredentials.mockResolvedValueOnce({
        id: 'admin-1',
        refreshToken: await bcrypt.hash(token, 4),
      });
      await service.revokeRefreshToken(token);
      expect(mockAdminUsersService.updateRefreshToken).toHaveBeenCalledWith('admin-1', null);
    });

    it('ignores an invalid token without throwing', async () => {
      await expect(service.revokeRefreshToken('not-a-jwt')).resolves.toBeUndefined();
      expect(mockAdminUsersService.updateRefreshToken).not.toHaveBeenCalled();
    });
  });
});
