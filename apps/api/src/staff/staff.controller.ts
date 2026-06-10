import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  Req,
  Query,
  UseGuards,
} from '@nestjs/common';
import { StaffService } from './staff.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { ClockInDto } from './dto/clock-in.dto';

@Controller('staff')
@UseGuards(JwtAuthGuard, RolesGuard)
export class StaffController {
  constructor(private readonly staffService: StaffService) {}

  // ─── Attendance ───────────────────────────────────────────────────────────────

  @Post('clock-in')
  @Roles('WAITER', 'BARTENDER', 'HOUSEKEEPER', 'MANAGER', 'ADMIN')
  clockIn(@Req() req: any, @Body() dto: ClockInDto) {
    return this.staffService.clockIn(req.user.id, req.user.tenantId, dto.lat, dto.lng);
  }

  @Post('clock-out')
  @Roles('WAITER', 'BARTENDER', 'HOUSEKEEPER', 'MANAGER', 'ADMIN')
  clockOut(@Req() req: any, @Body() dto: ClockInDto) {
    return this.staffService.clockOut(req.user.id, dto.lat, dto.lng);
  }

  @Get('attendance/today')
  @Roles('WAITER', 'BARTENDER', 'HOUSEKEEPER', 'MANAGER', 'ADMIN')
  getTodayAttendance(@Req() req: any) {
    return this.staffService.getTodayAttendance(req.user.id);
  }

  @Get('attendance')
  @Roles('MANAGER', 'ADMIN')
  getAttendanceByDate(@Req() req: any, @Query('date') date?: string) {
    return this.staffService.getAttendanceByDate(req.user.tenantId, date ?? '');
  }

  // ─── Housekeeper ──────────────────────────────────────────────────────────────

  @Get('housekeeper/rooms')
  @Roles('HOUSEKEEPER', 'MANAGER', 'ADMIN')
  getHousekeeperRooms(@Req() req: any) {
    return this.staffService.getHousekeeperRooms(req.user.tenantId);
  }

  @Patch('housekeeper/rooms/:roomId/cleaning')
  @Roles('HOUSEKEEPER', 'MANAGER', 'ADMIN')
  markRoomCleaning(@Req() req: any, @Param('roomId') roomId: string) {
    return this.staffService.markRoomCleaning(req.user.tenantId, roomId);
  }

  @Patch('housekeeper/rooms/:roomId/clean')
  @Roles('HOUSEKEEPER', 'MANAGER', 'ADMIN')
  markRoomClean(@Req() req: any, @Param('roomId') roomId: string) {
    return this.staffService.markRoomClean(req.user.tenantId, roomId);
  }

  // ─── Waiter ───────────────────────────────────────────────────────────────────

  @Get('waiter/orders')
  @Roles('WAITER', 'MANAGER', 'ADMIN')
  getWaiterOrders(@Req() req: any) {
    return this.staffService.getWaiterOrders(req.user.tenantId);
  }

  // ─── Bartender ────────────────────────────────────────────────────────────────

  @Get('bartender/summary')
  @Roles('BARTENDER', 'MANAGER', 'ADMIN')
  getBartenderSummary(@Req() req: any) {
    return this.staffService.getBartenderSummary(req.user.tenantId);
  }
}
