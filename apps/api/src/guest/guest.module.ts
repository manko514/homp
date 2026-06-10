import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { GuestController } from './guest.controller';
import { AdminGuestController } from './admin-guest.controller';
import { GuestService } from './guest.service';

@Module({
  imports: [
    JwtModule.registerAsync({
      useFactory: (config: ConfigService) => ({
        secret: config.get('app.jwt.secret') || process.env.JWT_SECRET || 'dev-secret',
        signOptions: { expiresIn: config.get('app.jwt.expiresIn') || '24h' },
      }),
      inject: [ConfigService],
    }),
  ],
  controllers: [GuestController, AdminGuestController],
  providers: [GuestService],
})
export class GuestModule {}
