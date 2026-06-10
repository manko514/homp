import { Module } from '@nestjs/common';
import { RestaurantService } from './restaurant.service';
import { RestaurantController } from './restaurant.controller';
import { RestaurantGateway } from './restaurant.gateway';

@Module({
  controllers: [RestaurantController],
  providers: [RestaurantService, RestaurantGateway],
  exports: [RestaurantService],
})
export class RestaurantModule {}
