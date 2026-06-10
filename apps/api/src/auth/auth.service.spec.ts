import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../database/prisma.service';
import { UnauthorizedException, ConflictException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';

const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    create: jest.fn(),
  },
  tenant: {
    findUnique: jest.fn(),
  },
  refreshToken: {
    findUnique: jest.fn(),
    create: jest.fn(),
    delete: jest.fn(),
  },
};

const mockJwt = {
  sign: jest.fn().mockReturnValue('mock-token'),
};

const mockConfig = {
  get: jest.fn().mockReturnValue(undefined),
};

describe('AuthService', () => {
  let service: AuthService;

  // bcrypt with cost 12 is intentionally slow — extend timeout for password tests
  jest.setTimeout(15000);

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwt },
        { provide: ConfigService, useValue: mockConfig },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    jest.clearAllMocks();
  });

  describe('login', () => {
    it('throws UnauthorizedException for unknown user', async () => {

      mockPrisma.user.findUnique.mockResolvedValue(null);
      await expect(
        service.login({ email: 'x@x.com', password: 'pass', tenantId: 't1' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException for wrong password', async () => {
      const hash = await bcrypt.hash('correct', 12);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        email: 'x@x.com',
        passwordHash: hash,
        status: 'active',
        role: 'GUEST',
        tenantId: 't1',
      });
      await expect(
        service.login({ email: 'x@x.com', password: 'wrong', tenantId: 't1' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('returns tokens for valid credentials', async () => {
      const hash = await bcrypt.hash('password123', 12);
      const user = { id: 'u1', email: 'x@x.com', passwordHash: hash, status: 'active', role: 'GUEST', tenantId: 't1' };
      mockPrisma.user.findUnique.mockResolvedValue(user);
      mockPrisma.refreshToken.create.mockResolvedValue({});

      const result = await service.login({ email: 'x@x.com', password: 'password123', tenantId: 't1' });
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      expect(result.user.email).toBe('x@x.com');
    });
  });

  describe('register', () => {
    it('throws ConflictException if email already exists', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'existing' });
      await expect(
        service.register({ tenantId: 't1', name: 'Test', email: 'x@x.com', password: 'pass123', role: 'GUEST' as any }),
      ).rejects.toThrow(ConflictException);
    });

    it('throws UnauthorizedException for invalid tenant', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      mockPrisma.tenant.findUnique.mockResolvedValue(null);
      await expect(
        service.register({ tenantId: 'bad', name: 'Test', email: 'x@x.com', password: 'pass123', role: 'GUEST' as any }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('creates user and returns tokens', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      mockPrisma.tenant.findUnique.mockResolvedValue({ id: 't1' });
      mockPrisma.user.create.mockResolvedValue({ id: 'u2', email: 'new@x.com', role: 'GUEST', tenantId: 't1' });
      mockPrisma.refreshToken.create.mockResolvedValue({});

      const result = await service.register({ tenantId: 't1', name: 'New', email: 'new@x.com', password: 'pass123', role: 'GUEST' as any });
      expect(result).toHaveProperty('accessToken');
      expect(mockPrisma.user.create).toHaveBeenCalledTimes(1);
    });
  });
});
