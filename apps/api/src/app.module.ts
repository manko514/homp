import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { WellKnownController } from './common/well-known.controller';
import { AuthModule } from './auth/auth.module';
import { DatabaseModule } from './database/database.module';
import { HotelModule } from './hotel/hotel.module';
import { RestaurantModule } from './restaurant/restaurant.module';
import { BarModule } from './bar/bar.module';
import { InventoryModule } from './inventory/inventory.module';
import { ReportsModule } from './reports/reports.module';
import { GuestModule } from './guest/guest.module';
import { StaffModule } from './staff/staff.module';
import { NotificationModule } from './notifications/notification.module';
import { AiModule } from './ai/ai.module';
import { ForecastModule } from './forecast/forecast.module';
import { AnomalyModule } from './anomaly/anomaly.module';
import { InventoryAiModule } from './inventory-ai/inventory-ai.module';
import { PayrollModule } from './payroll/payroll.module';
import { TicketsModule } from './tickets/tickets.module';
import { FinanceModule } from './finance/finance.module';
import { AuditModule } from './audit/audit.module';
import { SettingsModule } from './settings/settings.module';
import { AppCacheModule } from './cache/cache.module';
import { HqModule } from './hq/hq.module';
import { appConfig } from './config/app.config';

@Module({
  controllers: [WellKnownController],
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig],
      validationOptions: { abortEarly: false },
    }),
    AppCacheModule,
    DatabaseModule,
    AuditModule,
    AuthModule,
    HotelModule,
    RestaurantModule,
    BarModule,
    InventoryModule,
    ReportsModule,
    GuestModule,
    StaffModule,
    NotificationModule,
    AiModule,
    ForecastModule,
    AnomalyModule,
    InventoryAiModule,
    PayrollModule,
    TicketsModule,
    FinanceModule,
    SettingsModule,
    HqModule,
  ],
})
export class AppModule {}
