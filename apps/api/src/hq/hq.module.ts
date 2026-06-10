import { Module } from '@nestjs/common';
import { HqService } from './hq.service';
import { HqController } from './hq.controller';

@Module({
  controllers: [HqController],
  providers: [HqService],
})
export class HqModule {}
