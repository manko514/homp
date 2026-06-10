import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { ForecastService } from './forecast.service';
import { ForecastController } from './forecast.controller';
import { AiModule } from '../ai/ai.module';

@Module({
  imports: [
    ScheduleModule.forRoot(), // registers the cron scheduler
    AiModule,                  // provides AiService
  ],
  providers: [ForecastService],
  controllers: [ForecastController],
  exports: [ForecastService],
})
export class ForecastModule {}
