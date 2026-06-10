import { Controller, Post, Get, Patch, Param, Query, Req, UseGuards, Body } from '@nestjs/common';
import { InventoryAiService } from './inventory-ai.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

@Controller('inventory-ai')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('MANAGER', 'ADMIN')
export class InventoryAiController {
  constructor(private readonly inventoryAiService: InventoryAiService) {}

  /** Manually trigger AI inventory prediction */
  @Post('predict')
  predict(@Req() req: any) {
    return this.inventoryAiService.predict(req.user.tenantId);
  }

  /** List purchase orders */
  @Get('orders')
  getOrders(@Req() req: any, @Query('status') status?: string) {
    return this.inventoryAiService.getPurchaseOrders(req.user.tenantId, status);
  }

  /** Approve or dismiss a purchase order */
  @Patch('orders/:id')
  updateOrder(
    @Req() req: any,
    @Param('id') id: string,
    @Body('status') status: 'APPROVED' | 'DISMISSED',
  ) {
    return this.inventoryAiService.updateOrderStatus(req.user.tenantId, id, status);
  }

  /** Items currently below reorder level */
  @Get('alerts')
  getAlerts(@Req() req: any) {
    return this.inventoryAiService.getStockAlerts(req.user.tenantId);
  }
}
