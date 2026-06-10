import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Role, User, OrderStatus } from '@prisma/client';
import { RestaurantService } from './restaurant.service';
import { RestaurantGateway } from './restaurant.gateway';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { CreateTableDto } from './dto/create-table.dto';

@Controller('restaurant')
@UseGuards(JwtAuthGuard, RolesGuard)
export class RestaurantController {
  constructor(
    private restaurantService: RestaurantService,
    private restaurantGateway: RestaurantGateway,
  ) {}

  // ─── Tables ──────────────────────────────────────────────────────────────────

  @Get('tables')
  @Roles(Role.WAITER, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getTables(@CurrentUser() user: User) {
    return this.restaurantService.getTables(user.tenantId);
  }

  @Post('tables')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  createTable(@CurrentUser() user: User, @Body() dto: CreateTableDto) {
    return this.restaurantService.createTable(user.tenantId, dto);
  }

  @Get('tables/qr/:tableNumber')
  @Roles(Role.GUEST, Role.WAITER, Role.MANAGER, Role.ADMIN)
  getTableByQr(@CurrentUser() user: User, @Param('tableNumber') tableNumber: string) {
    return this.restaurantService.getTableByQr(user.tenantId, parseInt(tableNumber));
  }

  // ─── Menu ────────────────────────────────────────────────────────────────────

  @Get('menu')
  @Roles(Role.GUEST, Role.WAITER, Role.BARTENDER, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getMenu(@CurrentUser() user: User) {
    return this.restaurantService.getMenu(user.tenantId);
  }

  // ─── Orders ──────────────────────────────────────────────────────────────────

  @Get('orders')
  @Roles(Role.WAITER, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getOrders(@CurrentUser() user: User, @Query('status') status?: OrderStatus) {
    return this.restaurantService.getOrders(user.tenantId, status);
  }

  @Get('orders/kds')
  @Roles(Role.WAITER, Role.MANAGER, Role.ADMIN)
  getKdsOrders(@CurrentUser() user: User) {
    return this.restaurantService.getKdsOrders(user.tenantId);
  }

  @Get('orders/:id')
  @Roles(Role.GUEST, Role.WAITER, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getOrder(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.restaurantService.getOrder(user.tenantId, id);
  }

  @Post('orders')
  @Roles(Role.GUEST, Role.WAITER, Role.MANAGER, Role.ADMIN)
  async createOrder(@CurrentUser() user: User, @Body() dto: CreateOrderDto) {
    const waiterId = user.role === Role.WAITER ? user.id : null;
    const order = await this.restaurantService.createOrder(user.tenantId, waiterId, dto);

    // Push to KDS in real time — fires within 2 seconds per spec
    this.restaurantGateway.emitNewOrder(user.tenantId, order);

    return order;
  }

  @Patch('orders/:id/status')
  @Roles(Role.WAITER, Role.MANAGER, Role.ADMIN)
  async updateOrderStatus(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateOrderStatusDto,
  ) {
    const order = await this.restaurantService.updateOrderStatus(
      user.tenantId,
      id,
      dto,
      user.id,
    );

    this.restaurantGateway.emitOrderStatusChange(user.tenantId, id, dto.status, order);

    return order;
  }

  @Patch('orders/:id/bill')
  @Roles(Role.WAITER, Role.MANAGER, Role.ADMIN)
  async billOrder(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    const result = await this.restaurantService.billOrder(user.tenantId, id);
    this.restaurantGateway.emitOrderStatusChange(
      user.tenantId,
      id,
      OrderStatus.BILLED,
      result.order,
    );
    return result;
  }
}
