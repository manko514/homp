import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { InventoryAiService } from './inventory-ai.service';
import { InventoryAiController } from './inventory-ai.controller';
import { AiModule } from '../ai/ai.module';

@Module({
  imports: [ScheduleModule.forRoot(), AiModule],
  providers: [InventoryAiService],
  controllers: [InventoryAiController],
  exports: [InventoryAiService],
})
export class InventoryAiModule {}
