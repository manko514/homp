import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  Inject,
} from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';
import { PrismaService } from '../database/prisma.service';
import { ReservationStatus, RoomStatus } from '@prisma/client';
import { CreateRoomDto } from './dto/create-room.dto';
import { UpdateRoomStatusDto } from './dto/update-room-status.dto';
import { CreateReservationDto } from './dto/create-reservation.dto';
import { QueryReservationsDto } from './dto/query-reservations.dto';
import { AuditService } from '../audit/audit.service';

const ROOMS_TTL = 30;       // 30 seconds

// Valid state transitions for reservations
const ALLOWED_TRANSITIONS: Partial<Record<ReservationStatus, ReservationStatus[]>> = {
  [ReservationStatus.PENDING]: [ReservationStatus.CONFIRMED, ReservationStatus.CANCELLED],
  [ReservationStatus.CONFIRMED]: [ReservationStatus.CHECKED_IN, ReservationStatus.CANCELLED, ReservationStatus.NO_SHOW],
  [ReservationStatus.CHECKED_IN]: [ReservationStatus.CHECKED_OUT],
};

@Injectable()
export class HotelService {
  constructor(
    private prisma: PrismaService,
    @Inject(CACHE_MANAGER) private cache: Cache,
    private audit: AuditService,
  ) {}

  // ─── Rooms ──────────────────────────────────────────────────────────────────

  async getRooms(tenantId: string) {
    const key = `rooms:${tenantId}`;
    const cached = await this.cache.get(key);
    if (cached) return cached;

    const rooms = await this.prisma.room.findMany({
      where: { tenantId },
      orderBy: [{ floor: 'asc' }, { roomNumber: 'asc' }],
    });
    await this.cache.set(key, rooms, ROOMS_TTL);
    return rooms;
  }

  async getRoom(tenantId: string, roomId: string) {
    const room = await this.prisma.room.findFirst({
      where: { id: roomId, tenantId },
    });
    if (!room) throw new NotFoundException('Room not found');
    return room;
  }

  async createRoom(tenantId: string, dto: CreateRoomDto) {
    const existing = await this.prisma.room.findUnique({
      where: { tenantId_roomNumber: { tenantId, roomNumber: dto.roomNumber } },
    });
    if (existing) throw new ConflictException(`Room ${dto.roomNumber} already exists`);

    const room = await this.prisma.room.create({
      data: {
        tenantId,
        roomNumber: dto.roomNumber,
        type: dto.type,
        floor: dto.floor,
        baseRate: dto.baseRate,
        amenities: dto.amenities ?? [],
        photos: dto.photos ?? [],
      },
    });
    await this.cache.del(`rooms:${tenantId}`);
    return room;
  }

  async updateRoomStatus(tenantId: string, roomId: string, dto: UpdateRoomStatusDto) {
    await this.getRoom(tenantId, roomId);
    const room = await this.prisma.room.update({
      where: { id: roomId },
      data: { status: dto.status },
    });
    await this.cache.del(`rooms:${tenantId}`);
    return room;
  }

  async getRoomAvailability(tenantId: string, checkIn: Date, checkOut: Date) {
    const allRooms = await this.prisma.room.findMany({
      where: { tenantId, status: { not: RoomStatus.OUT_OF_ORDER } },
    });

    const bookedRoomIds = await this.getConflictingRoomIds(tenantId, checkIn, checkOut);

    return allRooms.map((room) => ({
      ...room,
      available: !bookedRoomIds.has(room.id),
    }));
  }

  // ─── Reservations ───────────────────────────────────────────────────────────

  async getReservations(tenantId: string, query: QueryReservationsDto) {
    return this.prisma.reservation.findMany({
      where: {
        tenantId,
        ...(query.status && { status: query.status }),
        ...(query.roomId && { roomId: query.roomId }),
        ...(query.from && { checkIn: { gte: new Date(query.from) } }),
        ...(query.to && { checkOut: { lte: new Date(query.to) } }),
      },
      include: {
        room: { select: { roomNumber: true, type: true, floor: true } },
        guest: { select: { id: true, name: true, email: true } },
      },
      orderBy: { checkIn: 'asc' },
    });
  }

  async getReservation(tenantId: string, reservationId: string) {
    const reservation = await this.prisma.reservation.findFirst({
      where: { id: reservationId, tenantId },
      include: {
        room: true,
        guest: { select: { id: true, name: true, email: true } },
      },
    });
    if (!reservation) throw new NotFoundException('Reservation not found');
    return reservation;
  }

  async createReservation(tenantId: string, actorId: string, dto: CreateReservationDto) {
    const checkIn = new Date(dto.checkIn);
    const checkOut = new Date(dto.checkOut);

    if (checkIn >= checkOut) {
      throw new BadRequestException('Check-out must be after check-in');
    }
    if (checkIn < new Date()) {
      throw new BadRequestException('Check-in cannot be in the past');
    }

    const room = await this.getRoom(tenantId, dto.roomId);

    if (room.status === RoomStatus.OUT_OF_ORDER || room.status === RoomStatus.MAINTENANCE) {
      throw new ConflictException('Room is not available for booking');
    }

    // Conflict detection: check for overlapping reservations
    const conflict = await this.prisma.reservation.findFirst({
      where: {
        tenantId,
        roomId: dto.roomId,
        status: { in: [ReservationStatus.CONFIRMED, ReservationStatus.CHECKED_IN, ReservationStatus.PENDING] },
        AND: [
          { checkIn: { lt: checkOut } },
          { checkOut: { gt: checkIn } },
        ],
      },
    });

    if (conflict) {
      throw new ConflictException(
        `Room ${room.roomNumber} is already booked from ${conflict.checkIn.toDateString()} to ${conflict.checkOut.toDateString()}`,
      );
    }

    const nights = Math.ceil((checkOut.getTime() - checkIn.getTime()) / (1000 * 60 * 60 * 24));
    const totalAmount = Number(room.baseRate) * nights;

    const reservation = await this.prisma.reservation.create({
      data: {
        tenantId,
        guestId: actorId,
        roomId: dto.roomId,
        checkIn,
        checkOut,
        totalAmount,
        addOns: (dto.addOns ?? {}) as object,
        notes: dto.notes,
        status: ReservationStatus.PENDING,
      },
      include: {
        room: { select: { roomNumber: true, type: true } },
      },
    });

    await this.audit.log({ tenantId, actorId, eventType: 'CREATE', resourceType: 'reservation', resourceId: reservation.id, diffJson: { roomId: dto.roomId, checkIn: dto.checkIn, checkOut: dto.checkOut, nights, totalAmount } }).catch(() => {});
    return reservation;
  }

  async checkIn(tenantId: string, reservationId: string, actorId: string) {
    const reservation = await this.getReservation(tenantId, reservationId);
    this.assertTransition(reservation.status, ReservationStatus.CHECKED_IN);

    const [updatedReservation] = await this.prisma.$transaction([
      this.prisma.reservation.update({
        where: { id: reservationId },
        data: { status: ReservationStatus.CHECKED_IN },
      }),
      this.prisma.room.update({
        where: { id: reservation.roomId },
        data: { status: RoomStatus.OCCUPIED },
      }),
    ]);

    await this.audit.log({ tenantId, actorId, eventType: 'CHECK_IN', resourceType: 'reservation', resourceId: reservationId, diffJson: { roomId: reservation.roomId, guestId: reservation.guest.id } }).catch(() => {});
    return updatedReservation;
  }

  async checkOut(tenantId: string, reservationId: string, actorId: string) {
    const reservation = await this.getReservation(tenantId, reservationId);
    this.assertTransition(reservation.status, ReservationStatus.CHECKED_OUT);

    const invoice = this.buildInvoice(reservation);

    const [updatedReservation] = await this.prisma.$transaction([
      this.prisma.reservation.update({
        where: { id: reservationId },
        data: { status: ReservationStatus.CHECKED_OUT },
      }),
      // Room goes to CLEANING after checkout
      this.prisma.room.update({
        where: { id: reservation.roomId },
        data: { status: RoomStatus.CLEANING },
      }),
    ]);

    await this.audit.log({ tenantId, actorId, eventType: 'CHECK_OUT', resourceType: 'reservation', resourceId: reservationId, diffJson: { totalAmount: Number(reservation.totalAmount), roomId: reservation.roomId } }).catch(() => {});
    return { reservation: updatedReservation, invoice };
  }

  async cancelReservation(tenantId: string, reservationId: string, actorId: string) {
    const reservation = await this.getReservation(tenantId, reservationId);
    this.assertTransition(reservation.status, ReservationStatus.CANCELLED);

    const updated = await this.prisma.reservation.update({
      where: { id: reservationId },
      data: { status: ReservationStatus.CANCELLED },
    });

    await this.audit.log({ tenantId, actorId, eventType: 'CANCEL', resourceType: 'reservation', resourceId: reservationId, diffJson: { previousStatus: reservation.status } }).catch(() => {});
    return updated;
  }

  async confirmReservation(tenantId: string, reservationId: string, actorId: string) {
    const reservation = await this.getReservation(tenantId, reservationId);
    this.assertTransition(reservation.status, ReservationStatus.CONFIRMED);

    const updated = await this.prisma.reservation.update({
      where: { id: reservationId },
      data: { status: ReservationStatus.CONFIRMED },
    });

    await this.audit.log({ tenantId, actorId, eventType: 'CONFIRM', resourceType: 'reservation', resourceId: reservationId, diffJson: { previousStatus: reservation.status } }).catch(() => {});
    return updated;
  }

  // ─── Housekeeping ────────────────────────────────────────────────────────────

  async getHousekeepingQueue(tenantId: string) {
    return this.prisma.room.findMany({
      where: {
        tenantId,
        status: { in: [RoomStatus.CLEANING, RoomStatus.MAINTENANCE] },
      },
      orderBy: { floor: 'asc' },
    });
  }

  async markRoomCleaned(tenantId: string, roomId: string) {
    await this.getRoom(tenantId, roomId);
    return this.prisma.room.update({
      where: { id: roomId },
      data: { status: RoomStatus.AVAILABLE },
    });
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  private assertTransition(current: ReservationStatus, next: ReservationStatus) {
    const allowed = ALLOWED_TRANSITIONS[current] ?? [];
    if (!allowed.includes(next)) {
      throw new BadRequestException(
        `Cannot transition reservation from ${current} to ${next}`,
      );
    }
  }

  private buildInvoice(reservation: {
    id: string;
    roomId: string;
    checkIn: Date;
    checkOut: Date;
    totalAmount: unknown;
    addOns: unknown;
  }) {
    const nights = Math.ceil(
      (reservation.checkOut.getTime() - reservation.checkIn.getTime()) / (1000 * 60 * 60 * 24),
    );
    return {
      reservationId: reservation.id,
      checkIn: reservation.checkIn,
      checkOut: reservation.checkOut,
      nights,
      roomCharge: Number(reservation.totalAmount),
      addOns: reservation.addOns,
      total: Number(reservation.totalAmount),
      generatedAt: new Date(),
    };
  }

  private async getConflictingRoomIds(
    tenantId: string,
    checkIn: Date,
    checkOut: Date,
  ): Promise<Set<string>> {
    const conflicts = await this.prisma.reservation.findMany({
      where: {
        tenantId,
        status: { in: [ReservationStatus.CONFIRMED, ReservationStatus.CHECKED_IN, ReservationStatus.PENDING] },
        AND: [{ checkIn: { lt: checkOut } }, { checkOut: { gt: checkIn } }],
      },
      select: { roomId: true },
    });
    return new Set(conflicts.map((c) => c.roomId));
  }
}
