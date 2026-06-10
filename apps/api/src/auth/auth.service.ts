import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../database/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  async login(dto: LoginDto) {
    if (!dto.email && !dto.phone) {
      throw new BadRequestException('Email or phone number is required');
    }

    let user: any = null;

    if (dto.email) {
      user = await this.prisma.user.findUnique({
        where: { tenantId_email: { tenantId: dto.tenantId, email: dto.email } },
      });
    } else if (dto.phone) {
      // Phone is stored on GuestProfile → join to User
      const profile = await this.prisma.guestProfile.findFirst({
        where: { phone: dto.phone, user: { tenantId: dto.tenantId } },
        include: { user: true },
      });
      user = profile?.user ?? null;
    }

    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.status !== 'active') {
      throw new UnauthorizedException('Account is inactive');
    }

    return this.generateTokens(user);
  }

  async register(dto: RegisterDto) {
    const existing = await this.prisma.user.findUnique({
      where: { tenantId_email: { tenantId: dto.tenantId, email: dto.email } },
    });

    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const tenant = await this.prisma.tenant.findUnique({ where: { id: dto.tenantId } });
    if (!tenant) {
      throw new UnauthorizedException('Invalid tenant');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.create({
      data: {
        tenantId: dto.tenantId,
        name: dto.name,
        email: dto.email,
        passwordHash,
        role: dto.role,
        // Automatically create GuestProfile for guests
        ...(dto.role === 'GUEST' && {
          guestProfile: {
            create: {
              loyaltyPoints: 0,
              dietaryPreferences: [],
              roomPreferences: [],
            },
          },
        }),
      },
    });

    return this.generateTokens(user);
  }

  async refresh(refreshToken: string) {
    const stored = await this.prisma.refreshToken.findUnique({
      where: { token: refreshToken },
    });

    if (!stored || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const user = await this.prisma.user.findUnique({ where: { id: stored.userId } });
    if (!user) throw new UnauthorizedException();

    await this.prisma.refreshToken.delete({ where: { token: refreshToken } });

    return this.generateTokens(user);
  }

  private async generateTokens(user: { id: string; name?: string | null; email: string; role: string; tenantId: string }) {
    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      tenantId: user.tenantId,
    };

    const accessToken = this.jwtService.sign(payload);

    const refreshSecret = this.configService.get('app.jwt.refreshSecret') || process.env.JWT_REFRESH_SECRET || 'dev-refresh-secret';
    const refreshExpiresIn = this.configService.get('app.jwt.refreshExpiresIn') || '7d';

    const refreshToken = this.jwtService.sign(payload, {
      secret: refreshSecret,
      expiresIn: refreshExpiresIn,
    });

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await this.prisma.refreshToken.create({
      data: { userId: user.id, token: refreshToken, expiresAt },
    });

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name ?? null,
        email: user.email,
        role: user.role,
        tenantId: user.tenantId,
      },
    };
  }

  async lookupTenant(subdomain: string) {
    const tenant = await this.prisma.tenant.findUnique({
      where: { subdomain },
      select: { id: true, name: true, subdomain: true, logoUrl: true },
    });
    if (!tenant) throw new NotFoundException(`No tenant found for subdomain "${subdomain}"`);
    return tenant;
  }
}
