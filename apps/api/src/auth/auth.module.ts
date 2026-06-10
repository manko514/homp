import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { AdminUsersController } from './admin-users.controller';
import { JwtStrategy } from './strategies/jwt.strategy';
import { PrismaService } from '../database/prisma.service';

@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get('app.jwt.secret') || process.env.JWT_SECRET || 'dev-secret',
        signOptions: {
          expiresIn: config.get('app.jwt.expiresIn') || '15m',
        },
      }),
    }),
  ],
  controllers: [AuthController, AdminUsersController],
  providers: [AuthService, JwtStrategy, PrismaService],
  exports: [AuthService, JwtModule],
})
export class AuthModule {}
