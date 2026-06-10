import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { TicketsController } from './tickets.controller';
import { TicketsService } from './tickets.service';

@Module({
  imports: [ScheduleModule.forRoot()],
  controllers: [TicketsController],
  providers: [TicketsService],
  exports: [TicketsService],
})
export class TicketsModule {}
