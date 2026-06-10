import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { AnomalyService } from './anomaly.service';
import { AnomalyController } from './anomaly.controller';
import { AiModule } from '../ai/ai.module';

@Module({
  imports: [ScheduleModule.forRoot(), AiModule],
  providers: [AnomalyService],
  controllers: [AnomalyController],
  exports: [AnomalyService],
})
export class AnomalyModule {}
