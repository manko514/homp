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
import { Role, User } from '@prisma/client';
import { InventoryService } from './inventory.service';
import { CreateStockItemDto, UpdateStockItemDto } from './dto/create-stock-item.dto';
import { RecordMovementDto } from './dto/record-movement.dto';

@Controller('inventory')
@UseGuards(JwtAuthGuard, RolesGuard)
export class InventoryController {
  constructor(private inventoryService: InventoryService) {}

  // ─── Stock items ─────────────────────────────────────────────────────────────

  @Get('stock')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.BARTENDER, Role.WAITER)
  getStockItems(@CurrentUser() user: User) {
    return this.inventoryService.getStockItems(user.tenantId);
  }

  @Get('stock/alerts')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.BARTENDER)
  getLowStockAlerts(@CurrentUser() user: User) {
    return this.inventoryService.getLowStockAlerts(user.tenantId);
  }

  @Get('stock/:id')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.BARTENDER)
  getStockItem(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.inventoryService.getStockItem(user.tenantId, id);
  }

  @Post('stock')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  createStockItem(@CurrentUser() user: User, @Body() dto: CreateStockItemDto) {
    return this.inventoryService.createStockItem(user.tenantId, dto);
  }

  @Patch('stock/:id')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  updateStockItem(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateStockItemDto,
  ) {
    return this.inventoryService.updateStockItem(user.tenantId, id, dto);
  }

  // ─── Movements ────────────────────────────────────────────────────────────────

  @Post('movements')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.BARTENDER, Role.WAITER)
  recordMovement(@CurrentUser() user: User, @Body() dto: RecordMovementDto) {
    return this.inventoryService.recordMovement(user.tenantId, dto);
  }

  @Get('movements')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.BARTENDER)
  getMovementHistory(
    @CurrentUser() user: User,
    @Query('stockItemId') stockItemId?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.inventoryService.getMovementHistory(
      user.tenantId,
      stockItemId,
      from ? new Date(from) : undefined,
      to ? new Date(to) : undefined,
    );
  }
}
