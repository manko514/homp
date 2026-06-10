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
import { BarService } from './bar.service';
import { CreateDrinkDto } from './dto/create-drink.dto';
import { RecordSaleDto } from './dto/record-sale.dto';
import { LogWasteDto } from './dto/log-waste.dto';

@Controller('bar')
@UseGuards(JwtAuthGuard, RolesGuard)
export class BarController {
  constructor(private barService: BarService) {}

  // ─── Drinks ──────────────────────────────────────────────────────────────────

  @Get('drinks')
  @Roles(Role.BARTENDER, Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.GUEST)
  getDrinks(@CurrentUser() user: User) {
    return this.barService.getDrinks(user.tenantId);
  }

  @Post('drinks')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  createDrink(@CurrentUser() user: User, @Body() dto: CreateDrinkDto) {
    return this.barService.createDrink(user.tenantId, dto);
  }

  @Patch('drinks/:id/toggle')
  @Roles(Role.BARTENDER, Role.MANAGER, Role.ADMIN)
  toggleAvailability(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.barService.toggleDrinkAvailability(user.tenantId, id);
  }

  // ─── Sales ───────────────────────────────────────────────────────────────────

  @Get('sales')
  @Roles(Role.BARTENDER, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getSales(
    @CurrentUser() user: User,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.barService.getSales(
      user.tenantId,
      from ? new Date(from) : undefined,
      to ? new Date(to) : undefined,
    );
  }

  @Post('sales')
  @Roles(Role.BARTENDER, Role.MANAGER, Role.ADMIN)
  recordSale(@CurrentUser() user: User, @Body() dto: RecordSaleDto) {
    return this.barService.recordSale(user.tenantId, user.id, dto);
  }

  // ─── Waste & Bottles ─────────────────────────────────────────────────────────

  @Post('waste')
  @Roles(Role.BARTENDER, Role.MANAGER, Role.ADMIN)
  logWaste(@CurrentUser() user: User, @Body() dto: LogWasteDto) {
    return this.barService.logWaste(user.tenantId, user.id, dto);
  }

  @Get('bottles')
  @Roles(Role.BARTENDER, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getBottleLog(@CurrentUser() user: User) {
    return this.barService.getBottleLog(user.tenantId);
  }

  // ─── Shift summary ────────────────────────────────────────────────────────────

  @Get('shift-summary')
  @Roles(Role.BARTENDER, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getShiftSummary(
    @CurrentUser() user: User,
    @Query('from') from: string,
    @Query('bartenderId') bartenderId?: string,
  ) {
    const targetBartender = bartenderId ?? user.id;
    return this.barService.getShiftSummary(
      user.tenantId,
      targetBartender,
      new Date(from ?? new Date().setHours(0, 0, 0, 0)),
    );
  }
}
