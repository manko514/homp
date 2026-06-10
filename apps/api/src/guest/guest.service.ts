import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../database/prisma.service';
import { OrderStatus, TicketStatus, ReservationStatus, Prisma, Role } from '@prisma/client';
import { PlaceGuestOrderDto } from './dto/place-guest-order.dto';
import { BuyTicketDto } from './dto/buy-ticket.dto';
import { NotificationService } from '../notifications/notification.service';
import { randomBytes } from 'crypto';
import * as bcrypt from 'bcryptjs';
import * as archiver from 'archiver';
import { Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';

const MENU_TTL = 300; // 5 minutes

// Ticket types with prices and validity hours
const TICKET_CATALOG: Record<string, { label: string; price: number; validHours: number; icon: string }> = {
  POOL:         { label: 'Pool Day Pass',    price: 25,  validHours: 12, icon: '🏊' },
  SWIM_LESSON:  { label: 'Swim Lesson',      price: 40,  validHours: 2,  icon: '🏊‍♂️' },
  GYM:          { label: 'Gym Day Pass',     price: 15,  validHours: 12, icon: '🏋️' },
  SPA:          { label: 'Spa Session',      price: 60,  validHours: 3,  icon: '💆' },
  BEACH:        { label: 'Beach Club',       price: 30,  validHours: 12, icon: '🏖️' },
  FITNESS:      { label: 'Fitness Class',    price: 20,  validHours: 2,  icon: '🧘' },
  TENNIS:       { label: 'Tennis Court',     price: 35,  validHours: 2,  icon: '🎾' },
  EVENT:        { label: 'Hotel Event',      price: 50,  validHours: 6,  icon: '🎉' },
  DAY_PASS:     { label: 'Full Day Pass',    price: 75,  validHours: 24, icon: '⭐' },
};

// Loyalty points awarded per $ spent
const LOYALTY_RATE = 10; // 10 points per $1

@Injectable()
export class GuestService {
  private readonly logger = new Logger(GuestService.name);

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private notifications: NotificationService,
    @Inject(CACHE_MANAGER) private cache: Cache,
  ) {}

  // ─── Check-in Reminder Cron ───────────────────────────────────────────────────

  /** Runs every 10 minutes. For each CONFIRMED reservation whose check-in is
   *  today, computes reminderTime = checkIn (at 15:00 standard) − 2 hours = 13:00.
   *  Fires the push only if that reminderTime falls in the current 10-min window,
   *  ensuring exactly one "2 hrs before check-in" notification per guest. */
  @Cron(CronExpression.EVERY_10_MINUTES)
  async sendCheckInReminders() {
    const now         = new Date();
    const windowStart = new Date(now.getTime() - 10 * 60 * 1000);

    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    const todayEnd   = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

    const reservations = await this.prisma.reservation.findMany({
      where: {
        status: ReservationStatus.CONFIRMED,
        checkIn: { gte: todayStart, lte: todayEnd },
      },
      include: {
        room:  { select: { roomNumber: true, type: true } },
        guest: { select: { id: true } },
      },
    });

    for (const res of reservations) {
      const d = new Date(res.checkIn);
      // Standard check-in = 15:00; reminder fires 2 hours before = 13:00
      const reminderAt = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 13, 0, 0);

      if (reminderAt >= windowStart && reminderAt <= now) {
        this.notifications.sendToUser(
          res.guest.id,
          '🔔 Check-In in 2 Hours!',
          `Your ${res.room.type} room ${res.room.roomNumber} will be ready at 3 PM. ` +
          `Tap to view your digital key.`,
          { type: 'checkin_reminder', id: res.id },
        ).catch((err) => this.logger.error('Check-in reminder failed', err));
      }
    }
  }

  // ─── Guest Auth ───────────────────────────────────────────────────────────────

  async registerGuest(tenantId: string, dto: { name: string; email: string; password: string; phone?: string }) {
    const tenant = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    if (!tenant) throw new NotFoundException('Hotel not found');

    const existing = await this.prisma.user.findUnique({
      where: { tenantId_email: { tenantId, email: dto.email } },
    });
    if (existing) throw new ConflictException('Email already registered at this hotel');

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.create({
      data: {
        tenantId,
        name: dto.name,
        email: dto.email,
        passwordHash,
        role: Role.GUEST,
        guestProfile: {
          create: {
            phone: dto.phone ?? null,
            loyaltyPoints: 0,
            dietaryPreferences: [],
            roomPreferences: [],
          },
        },
      },
      include: { guestProfile: true },
    });

    const token = this.jwtService.sign({
      sub: user.id,
      email: user.email,
      role: user.role,
      tenantId: user.tenantId,
    });

    return { token, user: { id: user.id, name: user.name, email: user.email, role: user.role, guestProfile: user.guestProfile } };
  }

  async loginGuest(tenantId: string, dto: { email?: string; phone?: string; password: string }) {
    if (!dto.email && !dto.phone) {
      throw new BadRequestException('Email or phone number is required');
    }

    let user: any = null;

    if (dto.email) {
      user = await this.prisma.user.findUnique({
        where: { tenantId_email: { tenantId, email: dto.email } },
        include: { guestProfile: true },
      });
    } else if (dto.phone) {
      const profile = await this.prisma.guestProfile.findFirst({
        where: { phone: dto.phone, user: { tenantId } },
        include: { user: { include: { guestProfile: true } } },
      });
      user = profile?.user ?? null;
    }

    if (!user || user.role !== Role.GUEST) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    const token = this.jwtService.sign({
      sub: user.id,
      email: user.email,
      role: user.role,
      tenantId: user.tenantId,
    });

    return { token, user: { id: user.id, name: user.name, email: user.email, role: user.role, guestProfile: user.guestProfile } };
  }

  async socialLoginGuest(tenantId: string, provider: 'google' | 'apple', idToken: string) {
    const tenant = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    if (!tenant) throw new NotFoundException('Hotel not found');

    let email: string;
    let name: string;

    if (provider === 'google') {
      const res = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`);
      if (!res.ok) throw new UnauthorizedException('Invalid Google token');
      const data: any = await res.json();
      if (!data.email_verified || data.email_verified === 'false') {
        throw new UnauthorizedException('Google email not verified');
      }
      email = data.email;
      name  = data.name ?? data.email.split('@')[0];
    } else {
      // Apple: parse JWT payload — signature already verified by Apple SDK on device
      const parts = idToken.split('.');
      if (parts.length < 2) throw new UnauthorizedException('Invalid Apple token');
      const payload: any = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf-8'));
      if (!payload.email) throw new UnauthorizedException('Apple token missing email claim');
      email = payload.email;
      name  = payload.name ?? email.split('@')[0];
    }

    // Find or create guest by tenantId + email
    let user = await this.prisma.user.findUnique({
      where: { tenantId_email: { tenantId, email } },
      include: { guestProfile: true },
    });

    if (!user) {
      const passwordHash = await bcrypt.hash(randomBytes(24).toString('hex'), 10);
      user = await this.prisma.user.create({
        data: {
          tenantId,
          name,
          email,
          passwordHash,
          role: Role.GUEST,
          guestProfile: { create: { loyaltyPoints: 0, dietaryPreferences: [], roomPreferences: [] } },
        },
        include: { guestProfile: true },
      });
    }

    const token = this.jwtService.sign({
      sub: user.id,
      email: user.email,
      role: user.role,
      tenantId: user.tenantId,
    });

    return { token, user: { id: user.id, name: user.name, email: user.email, role: user.role, guestProfile: user.guestProfile } };
  }

  async getMyProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        guestProfile: true,
        reservations: {
          orderBy: { createdAt: 'desc' },
          take: 5,
          include: { room: { select: { roomNumber: true, type: true } } },
        },
      },
    });
    if (!user) throw new NotFoundException('User not found');

    const recentTxns = await this.prisma.loyaltyTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 10,
    });

    return { ...user, loyaltyTransactions: recentTxns };
  }

  async updateMyProfile(userId: string, dto: {
    name?: string;
    phone?: string;
    dietaryPreferences?: string[];
    roomPreferences?: string[];
    communicationPrefs?: string[];
  }) {
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(dto.name && { name: dto.name }),
        guestProfile: {
          upsert: {
            create: {
              phone: dto.phone ?? null,
              dietaryPreferences: dto.dietaryPreferences ?? [],
              roomPreferences: dto.roomPreferences ?? [],
              communicationPrefs: dto.communicationPrefs ?? [],
            },
            update: {
              ...(dto.phone !== undefined && { phone: dto.phone }),
              ...(dto.dietaryPreferences && { dietaryPreferences: dto.dietaryPreferences }),
              ...(dto.roomPreferences && { roomPreferences: dto.roomPreferences }),
              ...(dto.communicationPrefs && { communicationPrefs: dto.communicationPrefs }),
            },
          },
        },
      },
      include: { guestProfile: true },
    });
    return user;
  }

  // ─── Room Availability ────────────────────────────────────────────────────────

  async getAvailableRooms(tenantId: string, checkIn?: string, checkOut?: string) {
    const checkInDate = checkIn ? new Date(checkIn) : new Date();
    const checkOutDate = checkOut
      ? new Date(checkOut)
      : new Date(Date.now() + 86400000);

    // Find rooms with conflicting reservations
    const conflicting = await this.prisma.reservation.findMany({
      where: {
        tenantId,
        status: { in: [ReservationStatus.CONFIRMED, ReservationStatus.CHECKED_IN] },
        checkIn: { lt: checkOutDate },
        checkOut: { gt: checkInDate },
      },
      select: { roomId: true },
    });

    const unavailableIds = conflicting.map((r) => r.roomId);

    const rooms = await this.prisma.room.findMany({
      where: {
        tenantId,
        id: { notIn: unavailableIds },
        status: { in: ['AVAILABLE', 'CLEANING'] },
      },
      orderBy: [{ type: 'asc' }, { baseRate: 'asc' }],
    });

    const nights = Math.max(
      1,
      Math.ceil((checkOutDate.getTime() - checkInDate.getTime()) / 86400000),
    );

    return rooms.map((r) => ({
      ...r,
      totalPrice: Number(r.baseRate) * nights,
      nights,
    }));
  }

  // ─── Room Booking ─────────────────────────────────────────────────────────────

  async createBooking(tenantId: string, guestId: string, dto: {
    roomId: string;
    checkIn: string;
    checkOut: string;
    addOns?: Record<string, unknown>;
    notes?: string;
  }) {
    const room = await this.prisma.room.findFirst({
      where: { id: dto.roomId, tenantId },
    });
    if (!room) throw new NotFoundException('Room not found');

    const checkIn = new Date(dto.checkIn);
    const checkOut = new Date(dto.checkOut);

    if (checkOut <= checkIn) throw new BadRequestException('Check-out must be after check-in');

    // Conflict check
    const conflict = await this.prisma.reservation.findFirst({
      where: {
        roomId: dto.roomId,
        status: { in: [ReservationStatus.CONFIRMED, ReservationStatus.CHECKED_IN] },
        checkIn: { lt: checkOut },
        checkOut: { gt: checkIn },
      },
    });
    if (conflict) throw new BadRequestException('Room not available for selected dates');

    const nights = Math.ceil((checkOut.getTime() - checkIn.getTime()) / 86400000);
    const totalAmount = Number(room.baseRate) * nights;

    const reservation = await this.prisma.reservation.create({
      data: {
        tenantId,
        guestId,
        roomId: dto.roomId,
        checkIn,
        checkOut,
        totalAmount,
        status: ReservationStatus.CONFIRMED,
        addOns: (dto.addOns ?? {}) as Prisma.InputJsonValue,
        notes: dto.notes ?? null,
      },
      include: {
        room: { select: { roomNumber: true, type: true, floor: true, amenities: true } },
      },
    });

    // Award loyalty points (10 per $1 of total)
    const points = Math.floor(totalAmount * LOYALTY_RATE);
    await this._awardPoints(guestId, tenantId, points, 'BOOKING', reservation.id);

    // Push: booking confirmation
    const checkInDate = checkIn.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    this.notifications.sendToUser(
      guestId,
      '🏨 Booking Confirmed!',
      `${reservation.room.type} Room ${reservation.room.roomNumber} — Check-in ${checkInDate}`,
      { type: 'booking', id: reservation.id },
    ).catch(() => {});

    return reservation;
  }

  async getMyBookings(guestId: string) {
    const reservations = await this.prisma.reservation.findMany({
      where: { guestId },
      orderBy: { createdAt: 'desc' },
      include: {
        room: { select: { roomNumber: true, type: true, floor: true, photos: true, amenities: true } },
        guest: { select: { name: true, email: true } },
      },
    });
    return reservations;
  }

  async checkIn(reservationId: string, guestId: string) {
    const res = await this.prisma.reservation.findFirst({
      where: { id: reservationId, guestId },
      include: { room: true },
    });
    if (!res) throw new NotFoundException('Reservation not found');
    if (res.status !== ReservationStatus.CONFIRMED)
      throw new BadRequestException(`Cannot check in — status is ${res.status}`);

    // Enforce 2-hour pre-arrival window: hotel check-in is 15:00, window opens at 13:00
    const checkInDate = new Date(res.checkIn);
    const windowOpens = new Date(
      checkInDate.getFullYear(),
      checkInDate.getMonth(),
      checkInDate.getDate(),
      13, 0, 0, // 1 PM on check-in date (= 3 PM check-in − 2 h)
    );
    if (new Date() < windowOpens) {
      const opens = windowOpens.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
      const day   = windowOpens.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      throw new BadRequestException(
        `Digital check-in opens at ${opens} on ${day} (2 hours before your 3:00 PM arrival)`,
      );
    }

    const updated = await this.prisma.reservation.update({
      where: { id: reservationId },
      data: { status: ReservationStatus.CHECKED_IN },
      include: { room: true },
    });

    // Generate a digital room key QR token
    const digitalKey = `KEY-${updated.room.roomNumber}-${randomBytes(8).toString('hex').toUpperCase()}`;

    // Push: welcome + room key ready
    this.notifications.sendToUser(
      guestId,
      '✅ Welcome! You\'re Checked In',
      `Room ${updated.room.roomNumber} is ready. Your digital key is active.`,
      { type: 'checkin', id: reservationId },
    ).catch(() => {});

    return { reservation: updated, digitalKey };
  }

  async getBill(reservationId: string, guestId: string) {
    const res = await this.prisma.reservation.findFirst({
      where: { id: reservationId, guestId },
      include: {
        room: { select: { roomNumber: true, type: true, baseRate: true } },
      },
    });
    if (!res) throw new NotFoundException('Reservation not found');

    const nights = Math.ceil(
      (res.checkOut.getTime() - res.checkIn.getTime()) / 86400000,
    );

    // Room service orders for this guest during stay
    const roomOrders = await this.prisma.order.findMany({
      where: {
        tenantId: res.tenantId,
        isRoomService: true,
        createdAt: { gte: res.checkIn, lte: res.checkOut },
        // match by guestId if set, otherwise skip
      },
      include: { orderItems: { include: { menuItem: { select: { name: true, price: true } } } } },
    });

    const roomRate = Number(res.room.baseRate);
    const accommodationTotal = roomRate * nights;
    const roomServiceTotal = roomOrders.reduce((s, o) => s + Number(o.total), 0);
    const grandTotal = accommodationTotal + roomServiceTotal;

    return {
      reservation: res,
      nights,
      lineItems: [
        {
          description: `${res.room.type} — Room ${res.room.roomNumber}`,
          nights,
          ratePerNight: roomRate,
          total: accommodationTotal,
        },
        ...roomOrders.map((o) => ({
          description: `Room Service — ${o.orderItems.map((i) => `${i.qty}× ${i.menuItem.name}`).join(', ')}`,
          nights: null,
          ratePerNight: null,
          total: Number(o.total),
        })),
      ],
      accommodationTotal,
      roomServiceTotal,
      grandTotal,
      paymentStatus: res.paymentStatus,
    };
  }

  async checkOut(reservationId: string, guestId: string) {
    const res = await this.prisma.reservation.findFirst({
      where: { id: reservationId, guestId },
    });
    if (!res) throw new NotFoundException('Reservation not found');
    if (res.status !== ReservationStatus.CHECKED_IN)
      throw new BadRequestException(`Cannot check out — status is ${res.status}`);

    const bill = await this.getBill(reservationId, guestId);

    const updated = await this.prisma.reservation.update({
      where: { id: reservationId },
      data: { status: ReservationStatus.CHECKED_OUT },
    });

    return { reservation: updated, bill };
  }

  // ─── Loyalty Helpers ──────────────────────────────────────────────────────────

  private async _awardPoints(userId: string, tenantId: string, points: number, reason: string, referenceId: string) {
    if (points <= 0) return;
    await this.prisma.$transaction([
      this.prisma.loyaltyTransaction.create({
        data: { userId, tenantId, points, reason, referenceId },
      }),
      this.prisma.guestProfile.updateMany({
        where: { userId },
        data: { loyaltyPoints: { increment: points } },
      }),
    ]);
  }

  async getLoyaltyHistory(userId: string) {
    const profile = await this.prisma.guestProfile.findUnique({ where: { userId } });
    const transactions = await this.prisma.loyaltyTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    return {
      balance: profile?.loyaltyPoints ?? 0,
      walletBalance: Number(profile?.walletBalance ?? 0),
      transactions,
    };
  }

  // ─── Wallet ───────────────────────────────────────────────────────────────────

  async getWallet(userId: string) {
    const profile = await this.prisma.guestProfile.findUnique({ where: { userId } });
    const txns = await this.prisma.walletTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 30,
    });
    return {
      balance: Number(profile?.walletBalance ?? 0),
      transactions: txns,
    };
  }

  async debitWallet(userId: string, tenantId: string, amount: number, note: string) {
    if (amount <= 0) throw new BadRequestException('Amount must be greater than 0');

    const profile = await this.prisma.guestProfile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException('Wallet not found');
    if (Number(profile.walletBalance) < amount)
      throw new BadRequestException(`Insufficient wallet balance (available: $${Number(profile.walletBalance).toFixed(2)})`);

    const [updated, txn] = await this.prisma.$transaction([
      this.prisma.guestProfile.update({
        where: { userId },
        data: { walletBalance: { decrement: amount } },
      }),
      this.prisma.walletTransaction.create({
        data: { userId, tenantId, amount, method: 'Wallet', type: 'DEBIT', note },
      }),
    ]);

    return { balance: Number(updated.walletBalance), transaction: txn };
  }

  async topUpWallet(
    userId: string,
    tenantId: string,
    amount: number,
    method: string,
  ) {
    if (amount <= 0) throw new BadRequestException('Amount must be greater than 0');
    const allowed = ['MTN', 'Airtel', 'M-Pesa', 'Card'];
    if (!allowed.includes(method))
      throw new BadRequestException(`Method must be one of: ${allowed.join(', ')}`);

    const [profile, txn] = await this.prisma.$transaction([
      this.prisma.guestProfile.upsert({
        where: { userId },
        create: { userId, loyaltyPoints: 0, walletBalance: amount, dietaryPreferences: [], roomPreferences: [] },
        update: { walletBalance: { increment: amount } },
      }),
      this.prisma.walletTransaction.create({
        data: { userId, tenantId, amount, method, type: 'TOPUP', note: `Top-up via ${method}` },
      }),
    ]);

    return {
      balance: Number(profile.walletBalance),
      transaction: txn,
    };
  }

  // ─── Availability / Busy Dates ────────────────────────────────────────────────

  /** Returns every date that has at least one room fully booked.
   *  Frontend uses this to grey-out days in the calendar picker. */
  async getBusyDates(tenantId: string) {
    const totalRooms = await this.prisma.room.count({
      where: { tenantId, status: { in: ['AVAILABLE', 'CLEANING'] } },
    });

    // Get all active reservations for the next 12 months
    const from = new Date();
    const to   = new Date(Date.now() + 365 * 86400000);

    const reservations = await this.prisma.reservation.findMany({
      where: {
        tenantId,
        status: { in: [ReservationStatus.CONFIRMED, ReservationStatus.CHECKED_IN] },
        checkIn:  { lt: to },
        checkOut: { gt: from },
      },
      select: { checkIn: true, checkOut: true, roomId: true },
    });

    // Build a map of date → Set<roomId> to count rooms booked per day
    const dayMap = new Map<string, Set<string>>();
    for (const res of reservations) {
      const cur = new Date(res.checkIn);
      while (cur < res.checkOut) {
        const key = cur.toISOString().slice(0, 10);
        if (!dayMap.has(key)) dayMap.set(key, new Set());
        dayMap.get(key)!.add(res.roomId);
        cur.setDate(cur.getDate() + 1);
      }
    }

    // A date is "busy" (fully booked) only when ALL rooms are taken
    const fullyBooked = [...dayMap.entries()]
      .filter(([, rooms]) => rooms.size >= totalRooms)
      .map(([date]) => date);

    return { fullyBooked, totalRooms };
  }

  // ─── FCM Token ───────────────────────────────────────────────────────────────

  async saveFcmToken(userId: string, token: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken: token },
    });
    return { ok: true };
  }

  // ─── Table Lookup (QR) ────────────────────────────────────────────────────────

  async getTableByNumber(tenantId: string, tableNumber: number) {
    const table = await this.prisma.restaurantTable.findUnique({
      where: { tenantId_tableNumber: { tenantId, tableNumber } },
    });
    if (!table) throw new NotFoundException('Table not found');
    return { id: table.id, tableNumber: table.tableNumber, capacity: table.capacity, status: table.status };
  }

  // ─── Menu ─────────────────────────────────────────────────────────────────────

  async getMenu(tenantId: string) {
    const key = `menu:${tenantId}`;
    const cached = await this.cache.get(key);
    if (cached) return cached;

    const items = await this.prisma.menuItem.findMany({
      where: { tenantId, available: true },
      orderBy: [{ category: 'asc' }, { name: 'asc' }],
      select: { id: true, name: true, description: true, category: true, price: true, photoUrl: true },
    });
    await this.cache.set(key, items, MENU_TTL);
    return items;
  }

  // ─── Drinks ───────────────────────────────────────────────────────────────────

  async getDrinks(tenantId: string) {
    const key = `drinks:${tenantId}`;
    const cached = await this.cache.get(key);
    if (cached) return cached;

    const items = await this.prisma.drink.findMany({
      where: { tenantId, available: true },
      orderBy: [{ category: 'asc' }, { name: 'asc' }],
      select: { id: true, name: true, category: true, price: true, photoUrl: true },
    });
    await this.cache.set(key, items, MENU_TTL);
    return items;
  }

  // ─── Place Guest Order ────────────────────────────────────────────────────────

  async placeOrder(tenantId: string, dto: PlaceGuestOrderDto) {
    const hasFood = dto.items && dto.items.length > 0;
    const hasDrinks = dto.drinkItems && dto.drinkItems.length > 0;

    if (!hasFood && !hasDrinks) throw new BadRequestException('Order must contain at least one item');
    if (!dto.tableId && !dto.isRoomService) throw new BadRequestException('Order must have a tableId or be a room service order');
    if (dto.isRoomService && !dto.roomNumber) throw new BadRequestException('Room number is required for room service orders');

    if (dto.tableId) {
      const table = await this.prisma.restaurantTable.findFirst({ where: { id: dto.tableId, tenantId } });
      if (!table) throw new NotFoundException('Table not found');
    }

    let orderItemsData: Array<{ menuItemId: string; qty: number; unitPrice: number; modifiers: object }> = [];
    let foodTotal = 0;

    if (hasFood && dto.items) {
      const menuItems = await this.prisma.menuItem.findMany({
        where: { tenantId, id: { in: dto.items.map((i) => i.menuItemId) }, available: true },
      });
      if (menuItems.length !== dto.items.length) throw new BadRequestException('One or more menu items are invalid or unavailable');
      const menuMap = new Map(menuItems.map((m) => [m.id, m]));
      orderItemsData = dto.items.map((item) => {
        const menuItem = menuMap.get(item.menuItemId)!;
        return { menuItemId: item.menuItemId, qty: item.qty, unitPrice: Number(menuItem.price), modifiers: (item.modifiers ?? {}) as object };
      });
      foodTotal = orderItemsData.reduce((sum, item) => sum + item.unitPrice * item.qty, 0);
    }

    let drinksTotal = 0;
    if (hasDrinks && dto.drinkItems) {
      const drinkIds = dto.drinkItems.map((d) => d.drinkId);
      const drinks = await this.prisma.drink.findMany({ where: { tenantId, id: { in: drinkIds }, available: true } });
      if (drinks.length !== drinkIds.length) throw new BadRequestException('One or more drinks are invalid or unavailable');
      drinksTotal = dto.drinkItems.reduce((sum, d) => sum + Number(d.price) * d.qty, 0);
    }

    const total = foodTotal + drinksTotal;

    const order = await this.prisma.order.create({
      data: {
        tenantId,
        tableId: dto.tableId ?? null,
        waiterId: null,
        isRoomService: dto.isRoomService ?? false,
        roomNumber: dto.roomNumber ?? null,
        notes: dto.notes ?? null,
        drinkItems: hasDrinks ? (dto.drinkItems as unknown as Prisma.InputJsonValue) : Prisma.JsonNull,
        status: OrderStatus.PENDING,
        total,
        orderItems: hasFood ? { create: orderItemsData.map((item) => ({ menuItemId: item.menuItemId, qty: item.qty, unitPrice: item.unitPrice, modifiers: item.modifiers })) } : undefined,
      },
      include: {
        orderItems: { include: { menuItem: { select: { name: true, category: true } } } },
        table: { select: { tableNumber: true } },
      },
    });

    return order;
  }

  // ─── Track Order ──────────────────────────────────────────────────────────────

  async trackOrder(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: {
        id: true, status: true, total: true, isRoomService: true, roomNumber: true,
        notes: true, drinkItems: true, createdAt: true, updatedAt: true,
        table: { select: { tableNumber: true } },
        orderItems: { include: { menuItem: { select: { name: true, category: true, price: true } } } },
      },
    });
    if (!order) throw new NotFoundException('Order not found');
    return order;
  }

  // ─── Ticket Catalog ───────────────────────────────────────────────────────────

  getTicketCatalog() {
    return Object.entries(TICKET_CATALOG).map(([type, info]) => ({ type, ...info }));
  }

  // ─── Buy Ticket ───────────────────────────────────────────────────────────────

  async buyTicket(tenantId: string, dto: BuyTicketDto, guestId?: string) {
    const catalog = TICKET_CATALOG[dto.ticketType.toUpperCase()];
    if (!catalog) throw new BadRequestException(`Unknown ticket type: ${dto.ticketType}`);

    const tenant = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    if (!tenant) throw new NotFoundException('Hotel not found');

    const qrToken  = randomBytes(16).toString('hex');
    const validFrom  = new Date();
    const validUntil = new Date(validFrom.getTime() + catalog.validHours * 60 * 60 * 1000);

    const ticket = await this.prisma.ticket.create({
      data: {
        tenantId,
        guestName: dto.guestName ?? null,
        ticketType: dto.ticketType.toUpperCase(),
        qrToken,
        validFrom,
        validUntil,
        purchasePrice: catalog.price,
        status: TicketStatus.ACTIVE,
      },
    });

    // Push: ticket purchase success
    if (guestId) {
      this.notifications.sendToUser(
        guestId,
        '🎫 Ticket Purchase Confirmed!',
        `Your ${catalog.label} ticket is ready. Valid for ${catalog.validHours}h. Tap to view.`,
        { type: 'ticket', id: ticket.id },
      ).catch(() => {});
    }

    return { ...ticket, catalog };
  }

  // ─── Get Ticket by QR Token ───────────────────────────────────────────────────

  async getTicketByToken(qrToken: string) {
    const ticket = await this.prisma.ticket.findUnique({ where: { qrToken } });
    if (!ticket) throw new NotFoundException('Ticket not found');

    if (ticket.status === TicketStatus.ACTIVE && new Date() > ticket.validUntil) {
      await this.prisma.ticket.update({ where: { id: ticket.id }, data: { status: TicketStatus.EXPIRED } });
      return { ...ticket, status: TicketStatus.EXPIRED };
    }

    return ticket;
  }

  // ─── Validate Ticket (Gate Scan) ──────────────────────────────────────────────

  async validateTicket(qrToken: string) {
    const ticket = await this.prisma.ticket.findUnique({ where: { qrToken } });
    if (!ticket) return { valid: false, message: 'INVALID', ticket: null };

    const now = new Date();

    if (ticket.status === TicketStatus.ACTIVE && now > ticket.validUntil) {
      await this.prisma.ticket.update({ where: { id: ticket.id }, data: { status: TicketStatus.EXPIRED } });
      return { valid: false, message: 'EXPIRED', ticket: { ...ticket, status: TicketStatus.EXPIRED } };
    }

    if (ticket.status === TicketStatus.USED)      return { valid: false, message: 'ALREADY USED', ticket };
    if (ticket.status === TicketStatus.CANCELLED) return { valid: false, message: 'CANCELLED', ticket };
    if (ticket.status === TicketStatus.EXPIRED)   return { valid: false, message: 'EXPIRED', ticket };

    const updated = await this.prisma.ticket.update({
      where: { id: ticket.id },
      data: { status: TicketStatus.USED, usedAt: now },
    });

    return { valid: true, message: 'VALID', ticket: updated };
  }

  // ─── Bar Tab ──────────────────────────────────────────────────────────────────

  async openBarTab(tenantId: string, guestId: string) {
    // Return existing open tab if one exists
    const existing = await this.prisma.barTab.findFirst({
      where: { tenantId, guestId, status: 'OPEN' },
    });
    if (existing) return existing;

    return this.prisma.barTab.create({
      data: { tenantId, guestId, status: 'OPEN', items: [], total: 0 },
    });
  }

  async getBarTab(guestId: string) {
    const tab = await this.prisma.barTab.findFirst({
      where: { guestId, status: 'OPEN' },
      orderBy: { createdAt: 'desc' },
    });
    return tab ?? null;
  }

  async addToBarTab(guestId: string, dto: { drinkId: string; qty: number }) {
    const tab = await this.prisma.barTab.findFirst({
      where: { guestId, status: 'OPEN' },
    });
    if (!tab) throw new NotFoundException('No open bar tab — open one first');
    if (dto.qty < 1) throw new BadRequestException('Quantity must be at least 1');

    const drink = await this.prisma.drink.findUnique({ where: { id: dto.drinkId } });
    if (!drink || !drink.available) throw new NotFoundException('Drink not found or unavailable');

    const items = (tab.items as Array<{drinkId:string;name:string;qty:number;unitPrice:number;total:number}>) ?? [];

    // Merge with existing line if same drink
    const idx = items.findIndex((i) => i.drinkId === dto.drinkId);
    if (idx >= 0) {
      items[idx].qty += dto.qty;
      items[idx].total = items[idx].qty * items[idx].unitPrice;
    } else {
      items.push({
        drinkId: drink.id,
        name: drink.name,
        qty: dto.qty,
        unitPrice: Number(drink.price),
        total: Number(drink.price) * dto.qty,
      });
    }

    const newTotal = items.reduce((s, i) => s + i.total, 0);

    return this.prisma.barTab.update({
      where: { id: tab.id },
      data: { items: items as any, total: newTotal },
    });
  }

  async closeBarTab(guestId: string) {
    const tab = await this.prisma.barTab.findFirst({
      where: { guestId, status: 'OPEN' },
    });
    if (!tab) throw new NotFoundException('No open bar tab found');

    return this.prisma.barTab.update({
      where: { id: tab.id },
      data: { status: 'CLOSED' },
    });
  }

  async getBarTabHistory(guestId: string) {
    return this.prisma.barTab.findMany({
      where: { guestId },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
  }

  // ─── Re-Book ──────────────────────────────────────────────────────────────────

  async rebookReservation(reservationId: string, guestId: string, dto: {
    checkIn: string;
    checkOut: string;
  }) {
    // Load the original reservation
    const original = await this.prisma.reservation.findFirst({
      where: { id: reservationId, guestId },
      include: { room: true },
    });
    if (!original) throw new NotFoundException('Original reservation not found');

    // Re-use same room + tenant, new dates
    return this.createBooking(original.tenantId, guestId, {
      roomId: original.roomId,
      checkIn: dto.checkIn,
      checkOut: dto.checkOut,
      notes: `Re-booked from reservation ${reservationId}`,
    });
  }

  // ─── Receipt (HTML) ───────────────────────────────────────────────────────────

  async getReceiptHtml(reservationId: string, guestId: string): Promise<string> {
    const bill = await this.getBill(reservationId, guestId);
    const res  = bill.reservation as any;
    const room = res.room as any;

    const fmt = (n: number) => `$${n.toFixed(2)}`;
    const fmtDate = (d: string) => new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });

    const lineRows = (bill.lineItems as any[]).map((item: any) => `
      <tr>
        <td style="padding:6px 8px;border-bottom:1px solid #eee">${item.description}</td>
        <td style="padding:6px 8px;border-bottom:1px solid #eee;text-align:right">${fmt(Number(item.total))}</td>
      </tr>`).join('');

    return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>HOMP Receipt</title>
<style>body{font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#1E2A3A}
h1{font-size:24px;letter-spacing:4px;color:#1E2A3A;margin:0}
.sub{color:#4CAF50;font-size:12px;letter-spacing:2px}
.card{background:#f5f6fa;border-radius:10px;padding:16px;margin:16px 0}
table{width:100%;border-collapse:collapse}
.total{font-size:18px;font-weight:bold;color:#4CAF50}
.footer{text-align:center;margin-top:24px;color:#888;font-size:11px}
</style></head>
<body>
<h1>HOMP</h1>
<div class="sub">Guest Receipt</div>

<div class="card">
  <strong>${room?.type ?? 'Room'} — #${room?.roomNumber ?? ''}</strong><br>
  <span style="color:#888;font-size:13px">
    ${fmtDate(res.checkIn)} → ${fmtDate(res.checkOut)} &nbsp;•&nbsp; ${bill.nights} night${bill.nights !== 1 ? 's' : ''}
  </span>
</div>

<table>
  <thead><tr>
    <th style="text-align:left;padding:8px;border-bottom:2px solid #1E2A3A;font-size:11px;letter-spacing:1px">DESCRIPTION</th>
    <th style="text-align:right;padding:8px;border-bottom:2px solid #1E2A3A;font-size:11px;letter-spacing:1px">AMOUNT</th>
  </tr></thead>
  <tbody>${lineRows}</tbody>
  <tfoot>
    <tr><td style="padding:10px 8px;font-weight:600">Accommodation Sub-Total</td>
        <td style="padding:10px 8px;text-align:right">${fmt(Number(bill.accommodationTotal))}</td></tr>
    <tr><td style="padding:6px 8px;color:#888">Room Service Sub-Total</td>
        <td style="padding:6px 8px;text-align:right;color:#888">${fmt(Number(bill.roomServiceTotal))}</td></tr>
    <tr style="border-top:2px solid #1E2A3A">
      <td style="padding:12px 8px;font-size:15px;font-weight:bold">GRAND TOTAL</td>
      <td style="padding:12px 8px;text-align:right" class="total">${fmt(Number(bill.grandTotal))}</td>
    </tr>
  </tfoot>
</table>

<div class="footer">
  Thank you for staying with us!<br>
  Reservation #${reservationId.slice(-8).toUpperCase()}<br>
  Generated: ${new Date().toLocaleString()}
</div>
</body></html>`;
  }

  // ─── GDPR: Export all guest data as ZIP ──────────────────────────────────────

  async exportGuestData(guestId: string, res: import('express').Response) {
    const user = await this.prisma.user.findUnique({
      where: { id: guestId },
      include: {
        guestProfile: true,
        reservations: { include: { room: { select: { roomNumber: true, type: true } } } },
        orders: { include: { orderItems: { include: { menuItem: { select: { name: true } } } } } },
        loyaltyTransactions: true,
        walletTransactions: true,
        barTabs: true,
      },
    });
    if (!user) throw new NotFoundException('Guest not found');

    const exportData = {
      exportedAt: new Date().toISOString(),
      profile: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
        guestProfile: user.guestProfile,
      },
      reservations: user.reservations,
      orders: user.orders,
      loyaltyTransactions: user.loyaltyTransactions,
      walletTransactions: user.walletTransactions,
      barTabs: user.barTabs,
    };

    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="gdpr-export-${guestId.slice(0, 8)}.zip"`);

    const archive = archiver('zip', { zlib: { level: 9 } });
    archive.pipe(res);
    archive.append(JSON.stringify(exportData, null, 2), { name: 'guest-data.json' });
    await archive.finalize();
  }

  // ─── GDPR: Anonymise PII (right to erasure) ──────────────────────────────────

  async anonymiseGuest(guestId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: guestId } });
    if (!user) throw new NotFoundException('Guest not found');

    const anon = `anon_${guestId.slice(0, 8)}`;

    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: guestId },
        data: {
          name: anon,
          email: `${anon}@deleted.invalid`,
          passwordHash: await bcrypt.hash(randomBytes(32).toString('hex'), 10),
          fcmToken: null,
          status: 'deleted',
        },
      }),
      this.prisma.guestProfile.updateMany({
        where: { userId: guestId },
        data: {
          phone: null,
          dietaryPreferences: [],
          roomPreferences: [],
          communicationPrefs: [],
        },
      }),
    ]);

    return { message: 'PII anonymised successfully', id: guestId };
  }
}
