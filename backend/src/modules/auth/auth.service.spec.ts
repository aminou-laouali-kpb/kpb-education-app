import { Test, TestingModule } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';

import { AuthService } from './auth.service';
import { AdminUsersService } from '../admin-users/admin-users.service';

const mockAdminUsersService = {
  findActiveUserByEmail: jest.fn(),
  findActiveUserByEmailWithCredentials: jest.fn(),
  updateRefreshToken: jest.fn(),
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
