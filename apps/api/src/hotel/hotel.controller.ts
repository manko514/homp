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
import { HotelService } from './hotel.service';
import { CreateRoomDto } from './dto/create-room.dto';
import { UpdateRoomStatusDto } from './dto/update-room-status.dto';
import { CreateReservationDto } from './dto/create-reservation.dto';
import { QueryReservationsDto } from './dto/query-reservations.dto';

@Controller('hotel')
@UseGuards(JwtAuthGuard, RolesGuard)
export class HotelController {
  constructor(private hotelService: HotelService) {}

  // ─── Rooms ──────────────────────────────────────────────────────────────────

  @Get('rooms')
  @Roles(Role.RECEPTIONIST, Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.HOUSEKEEPER)
  getRooms(@CurrentUser() user: User) {
    return this.hotelService.getRooms(user.tenantId);
  }

  @Get('rooms/availability')
  @Roles(Role.RECEPTIONIST, Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.GUEST)
  getAvailability(
    @CurrentUser() user: User,
    @Query('checkIn') checkIn: string,
    @Query('checkOut') checkOut: string,
  ) {
    return this.hotelService.getRoomAvailability(
      user.tenantId,
      new Date(checkIn),
      new Date(checkOut),
    );
  }

  @Get('rooms/:id')
  @Roles(Role.RECEPTIONIST, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getRoom(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.hotelService.getRoom(user.tenantId, id);
  }

  @Post('rooms')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  createRoom(@CurrentUser() user: User, @Body() dto: CreateRoomDto) {
    return this.hotelService.createRoom(user.tenantId, dto);
  }

  @Patch('rooms/:id/status')
  @Roles(Role.RECEPTIONIST, Role.HOUSEKEEPER, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  updateRoomStatus(
    @CurrentUser() user: User,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateRoomStatusDto,
  ) {
    return this.hotelService.updateRoomStatus(user.tenantId, id, dto);
  }

  // ─── Housekeeping ────────────────────────────────────────────────────────────

  @Get('housekeeping/queue')
  @Roles(Role.HOUSEKEEPER, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getHousekeepingQueue(@CurrentUser() user: User) {
    return this.hotelService.getHousekeepingQueue(user.tenantId);
  }

  @Patch('housekeeping/rooms/:id/cleaned')
  @Roles(Role.HOUSEKEEPER, Role.MANAGER, Role.ADMIN)
  markRoomCleaned(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.hotelService.markRoomCleaned(user.tenantId, id);
  }

  // ─── Reservations ────────────────────────────────────────────────────────────

  @Get('reservations')
  @Roles(Role.RECEPTIONIST, Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getReservations(@CurrentUser() user: User, @Query() query: QueryReservationsDto) {
    return this.hotelService.getReservations(user.tenantId, query);
  }

  @Get('reservations/:id')
  @Roles(Role.RECEPTIONIST, Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.GUEST)
  getReservation(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.hotelService.getReservation(user.tenantId, id);
  }

  @Post('reservations')
  @Roles(Role.GUEST, Role.RECEPTIONIST, Role.MANAGER, Role.ADMIN)
  createReservation(@CurrentUser() user: User, @Body() dto: CreateReservationDto) {
    return this.hotelService.createReservation(user.tenantId, user.id, dto);
  }

  @Patch('reservations/:id/confirm')
  @Roles(Role.RECEPTIONIST, Role.MANAGER, Role.ADMIN)
  confirmReservation(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.hotelService.confirmReservation(user.tenantId, id, user.id);
  }

  @Patch('reservations/:id/checkin')
  @Roles(Role.RECEPTIONIST, Role.MANAGER, Role.ADMIN)
  checkIn(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.hotelService.checkIn(user.tenantId, id, user.id);
  }

  @Patch('reservations/:id/checkout')
  @Roles(Role.RECEPTIONIST, Role.MANAGER, Role.ADMIN)
  checkOut(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.hotelService.checkOut(user.tenantId, id, user.id);
  }

  @Patch('reservations/:id/cancel')
  @Roles(Role.GUEST, Role.RECEPTIONIST, Role.MANAGER, Role.ADMIN)
  cancelReservation(@CurrentUser() user: User, @Param('id', ParseUUIDPipe) id: string) {
    return this.hotelService.cancelReservation(user.tenantId, id, user.id);
  }
}
