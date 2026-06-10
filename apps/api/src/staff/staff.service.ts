import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { RoomStatus, ReservationStatus, OrderStatus } from '@prisma/client';

@Injectable()
export class StaffService {
  constructor(private prisma: PrismaService) {}

  // ─── Attendance / GPS Clock-in ────────────────────────────────────────────────

  async clockIn(userId: string, tenantId: string, lat?: number, lng?: number) {
    // Find employee record
    const employee = await this.prisma.employee.findUnique({
      where: { userId },
    });
    if (!employee) throw new NotFoundException('Employee record not found. Contact HR.');

    // Check for existing open session today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const existing = await this.prisma.attendance.findFirst({
      where: {
        userId,
        clockIn: { gte: today },
        clockOut: null,
      },
    });
    if (existing) {
      throw new BadRequestException('Already clocked in. Clock out first.');
    }

    return this.prisma.attendance.create({
      data: {
        employeeId: employee.id,
        userId,
        clockIn: new Date(),
        latIn: lat ?? null,
        lngIn: lng ?? null,
      },
    });
  }

  async clockOut(userId: string, lat?: number, lng?: number) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const record = await this.prisma.attendance.findFirst({
      where: { userId, clockIn: { gte: today }, clockOut: null },
      orderBy: { clockIn: 'desc' },
    });
    if (!record) throw new NotFoundException('No active clock-in found for today.');

    return this.prisma.attendance.update({
      where: { id: record.id },
      data: { clockOut: new Date(), latOut: lat ?? null, lngOut: lng ?? null },
    });
  }

  async getTodayAttendance(userId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return this.prisma.attendance.findFirst({
      where: { userId, clockIn: { gte: today } },
      orderBy: { clockIn: 'desc' },
    });
  }

  async getAttendanceByDate(tenantId: string, date: string) {
    const day = date ? new Date(date) : new Date();
    day.setHours(0, 0, 0, 0);
    const dayEnd = new Date(day);
    dayEnd.setHours(23, 59, 59, 999);

    const records = await this.prisma.attendance.findMany({
      where: {
        user: { tenantId },
        clockIn: { gte: day, lte: dayEnd },
      },
      include: {
        user: { select: { id: true, name: true, email: true, role: true } },
      },
      orderBy: { clockIn: 'asc' },
    });

    return records.map((r) => ({
      id: r.id,
      userId: r.userId,
      clockIn: r.clockIn,
      clockOut: r.clockOut,
      clockInLat: r.latIn ? Number(r.latIn) : null,
      clockInLng: r.lngIn ? Number(r.lngIn) : null,
      clockOutLat: r.latOut ? Number(r.latOut) : null,
      clockOutLng: r.lngOut ? Number(r.lngOut) : null,
      user: r.user,
    }));
  }

  // ─── Housekeeper — Room Tasks ─────────────────────────────────────────────────

  async getHousekeeperRooms(tenantId: string) {
    // Rooms that need attention: CLEANING or recently checked-out (AVAILABLE but had checkout today)
    const rooms = await this.prisma.room.findMany({
      where: {
        tenantId,
        status: { in: [RoomStatus.CLEANING, RoomStatus.MAINTENANCE] },
      },
      orderBy: [{ floor: 'asc' }, { roomNumber: 'asc' }],
      select: {
        id: true,
        roomNumber: true,
        type: true,
        floor: true,
        status: true,
      },
    });

    // Also include rooms with checkouts today
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date();
    todayEnd.setHours(23, 59, 59, 999);

    const checkouts = await this.prisma.reservation.findMany({
      where: {
        tenantId,
        checkOut: { gte: todayStart, lte: todayEnd },
        status: { in: [ReservationStatus.CHECKED_OUT, ReservationStatus.CHECKED_IN] },
      },
      include: {
        room: {
          select: { id: true, roomNumber: true, type: true, floor: true, status: true },
        },
      },
    });

    const checkoutRooms = checkouts
      .map((r) => ({ ...r.room, needsCleaning: true }))
      .filter((r) => !rooms.find((rm) => rm.id === r.id));

    return {
      cleaning: rooms,
      checkouts: checkoutRooms,
    };
  }

  async markRoomCleaning(tenantId: string, roomId: string) {
    const room = await this.prisma.room.findFirst({
      where: { id: roomId, tenantId },
    });
    if (!room) throw new NotFoundException('Room not found');
    return this.prisma.room.update({
      where: { id: roomId },
      data: { status: RoomStatus.CLEANING },
    });
  }

  async markRoomClean(tenantId: string, roomId: string) {
    const room = await this.prisma.room.findFirst({
      where: { id: roomId, tenantId },
    });
    if (!room) throw new NotFoundException('Room not found');
    return this.prisma.room.update({
      where: { id: roomId },
      data: { status: RoomStatus.AVAILABLE },
    });
  }

  // ─── Waiter — Active Orders ────────────────────────────────────────────────────

  async getWaiterOrders(tenantId: string) {
    return this.prisma.order.findMany({
      where: {
        tenantId,
        status: { in: [OrderStatus.PENDING, OrderStatus.KDS, OrderStatus.READY] },
      },
      include: {
        orderItems: {
          include: { menuItem: { select: { name: true, category: true } } },
        },
        table: { select: { tableNumber: true } },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  // ─── Bartender — Pending Drink Info ───────────────────────────────────────────

  async getBartenderSummary(tenantId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [sales, drinks] = await Promise.all([
      this.prisma.barSale.findMany({
        where: { tenantId, createdAt: { gte: today } },
        include: { drink: { select: { name: true, category: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.drink.findMany({
        where: { tenantId, available: true },
        orderBy: [{ category: 'asc' }, { name: 'asc' }],
      }),
    ]);

    const totalRevenue = sales.reduce((s, r) => s + Number(r.total), 0);
    const totalSales = sales.reduce((s, r) => s + r.qty, 0);

    return { sales, drinks, totalRevenue, totalSales };
  }
}
