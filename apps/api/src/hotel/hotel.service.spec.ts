import { Test, TestingModule } from '@nestjs/testing';
import { HotelService } from './hotel.service';
import { PrismaService } from '../database/prisma.service';
import { AuditService } from '../audit/audit.service';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { ReservationStatus, RoomStatus } from '@prisma/client';

const mockCache = { get: jest.fn().mockResolvedValue(null), set: jest.fn(), del: jest.fn() };
const mockAudit = { log: jest.fn().mockResolvedValue(undefined) };

const tomorrow = () => {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d;
};
const dayAfter = (d: Date, n = 1) => {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r;
};

const mockRoom = {
  id: 'room-1',
  tenantId: 't1',
  roomNumber: '101',
  type: 'Standard',
  floor: 1,
  status: RoomStatus.AVAILABLE,
  baseRate: 100,
  amenities: [],
  photos: [],
  createdAt: new Date(),
};

const mockPrisma = {
  room: {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  reservation: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  $transaction: jest.fn(),
};

describe('HotelService', () => {
  let service: HotelService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HotelService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: CACHE_MANAGER, useValue: mockCache },
        { provide: AuditService, useValue: mockAudit },
      ],
    }).compile();

    service = module.get<HotelService>(HotelService);
    jest.clearAllMocks();
  });

  // ─── Room tests ─────────────────────────────────────────────────────────────

  describe('getRoom', () => {
    it('throws NotFoundException when room does not exist', async () => {
      mockPrisma.room.findFirst.mockResolvedValue(null);
      await expect(service.getRoom('t1', 'bad-id')).rejects.toThrow(NotFoundException);
    });

    it('returns room when found', async () => {
      mockPrisma.room.findFirst.mockResolvedValue(mockRoom);
      const result = await service.getRoom('t1', 'room-1');
      expect(result.roomNumber).toBe('101');
    });
  });

  describe('createRoom', () => {
    it('throws ConflictException when room number already exists', async () => {
      mockPrisma.room.findUnique.mockResolvedValue(mockRoom);
      await expect(
        service.createRoom('t1', { roomNumber: '101', type: 'Standard', floor: 1, baseRate: 100 }),
      ).rejects.toThrow(ConflictException);
    });

    it('creates room when number is unique', async () => {
      mockPrisma.room.findUnique.mockResolvedValue(null);
      mockPrisma.room.create.mockResolvedValue(mockRoom);
      const result = await service.createRoom('t1', { roomNumber: '101', type: 'Standard', floor: 1, baseRate: 100 });
      expect(result.roomNumber).toBe('101');
      expect(mockPrisma.room.create).toHaveBeenCalledTimes(1);
    });
  });

  // ─── Conflict detection ──────────────────────────────────────────────────────

  describe('createReservation — conflict detection', () => {
    const checkIn = tomorrow();
    const checkOut = dayAfter(checkIn, 3);

    beforeEach(() => {
      mockPrisma.room.findFirst.mockResolvedValue(mockRoom);
    });

    it('throws BadRequestException when checkOut is before checkIn', async () => {
      await expect(
        service.createReservation('t1', 'guest-1', {
          roomId: 'room-1',
          checkIn: checkOut.toISOString(),
          checkOut: checkIn.toISOString(),
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws ConflictException when room is already booked for overlapping dates', async () => {
      mockPrisma.reservation.findFirst.mockResolvedValue({
        id: 'existing',
        checkIn: checkIn,
        checkOut: checkOut,
      });

      await expect(
        service.createReservation('t1', 'guest-2', {
          roomId: 'room-1',
          checkIn: checkIn.toISOString(),
          checkOut: checkOut.toISOString(),
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('creates reservation when no overlap exists', async () => {
      mockPrisma.reservation.findFirst.mockResolvedValue(null);
      mockPrisma.reservation.create.mockResolvedValue({
        id: 'new-res',
        roomId: 'room-1',
        checkIn,
        checkOut,
        totalAmount: 300,
        status: ReservationStatus.PENDING,
      });

      const result = await service.createReservation('t1', 'guest-1', {
        roomId: 'room-1',
        checkIn: checkIn.toISOString(),
        checkOut: checkOut.toISOString(),
      });

      expect(result.status).toBe(ReservationStatus.PENDING);
      expect(mockPrisma.reservation.create).toHaveBeenCalledTimes(1);
    });

    it('calculates total amount correctly (nights × rate)', async () => {
      mockPrisma.reservation.findFirst.mockResolvedValue(null);
      mockPrisma.reservation.create.mockResolvedValue({ id: 'r1', totalAmount: 300 });

      await service.createReservation('t1', 'guest-1', {
        roomId: 'room-1',
        checkIn: checkIn.toISOString(),
        checkOut: checkOut.toISOString(), // 3 nights × $100 = $300
      });

      const createCall = mockPrisma.reservation.create.mock.calls[0][0];
      expect(Number(createCall.data.totalAmount)).toBe(300);
    });

    it('throws ConflictException when room is OUT_OF_ORDER', async () => {
      mockPrisma.room.findFirst.mockResolvedValue({
        ...mockRoom,
        status: RoomStatus.OUT_OF_ORDER,
      });

      await expect(
        service.createReservation('t1', 'guest-1', {
          roomId: 'room-1',
          checkIn: checkIn.toISOString(),
          checkOut: checkOut.toISOString(),
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ─── State machine ───────────────────────────────────────────────────────────

  describe('check-in / check-out state machine', () => {
    it('allows check-in from CONFIRMED status', async () => {
      const reservation = {
        id: 'res-1',
        tenantId: 't1',
        roomId: 'room-1',
        status: ReservationStatus.CONFIRMED,
        checkIn: tomorrow(),
        checkOut: dayAfter(tomorrow(), 2),
        totalAmount: 200,
        addOns: {},
        guest: { id: 'g1', name: 'Alice', email: 'a@a.com' },
        room: { id: 'room-1' },
      };

      mockPrisma.reservation.findFirst.mockResolvedValue(reservation);
      mockPrisma.$transaction.mockResolvedValue([
        { ...reservation, status: ReservationStatus.CHECKED_IN },
        { ...mockRoom, status: RoomStatus.OCCUPIED },
      ]);

      const result = await service.checkIn('t1', 'res-1', 'actor-1');
      expect(result.status).toBe(ReservationStatus.CHECKED_IN);
    });

    it('rejects check-in from PENDING status', async () => {
      mockPrisma.reservation.findFirst.mockResolvedValue({
        id: 'res-1',
        tenantId: 't1',
        roomId: 'room-1',
        status: ReservationStatus.PENDING,
        checkIn: tomorrow(),
        checkOut: dayAfter(tomorrow(), 2),
        totalAmount: 200,
        addOns: {},
        guest: {},
        room: {},
      });

      await expect(service.checkIn('t1', 'res-1', 'actor-1')).rejects.toThrow(BadRequestException);
    });

    it('allows check-out from CHECKED_IN and sets room to CLEANING', async () => {
      const checkIn = tomorrow();
      const checkOut = dayAfter(checkIn, 2);
      const reservation = {
        id: 'res-1',
        tenantId: 't1',
        roomId: 'room-1',
        status: ReservationStatus.CHECKED_IN,
        checkIn,
        checkOut,
        totalAmount: 200,
        addOns: {},
        guest: { id: 'g1', name: 'Alice', email: 'a@a.com' },
        room: { id: 'room-1' },
      };

      mockPrisma.reservation.findFirst.mockResolvedValue(reservation);
      mockPrisma.$transaction.mockResolvedValue([
        { ...reservation, status: ReservationStatus.CHECKED_OUT },
        { ...mockRoom, status: RoomStatus.CLEANING },
      ]);

      const result = await service.checkOut('t1', 'res-1', 'actor-1');
      expect(result.reservation.status).toBe(ReservationStatus.CHECKED_OUT);
      expect(result.invoice).toHaveProperty('total');
      expect(result.invoice.nights).toBe(2);
    });

    it('rejects check-out from CONFIRMED status', async () => {
      mockPrisma.reservation.findFirst.mockResolvedValue({
        id: 'res-1',
        tenantId: 't1',
        roomId: 'room-1',
        status: ReservationStatus.CONFIRMED,
        checkIn: tomorrow(),
        checkOut: dayAfter(tomorrow(), 2),
        totalAmount: 200,
        addOns: {},
        guest: {},
        room: {},
      });

      await expect(service.checkOut('t1', 'res-1', 'actor-1')).rejects.toThrow(BadRequestException);
    });

    it('rejects invalid transition from CHECKED_OUT', async () => {
      mockPrisma.reservation.findFirst.mockResolvedValue({
        id: 'res-1',
        tenantId: 't1',
        roomId: 'room-1',
        status: ReservationStatus.CHECKED_OUT,
        checkIn: tomorrow(),
        checkOut: dayAfter(tomorrow(), 2),
        totalAmount: 200,
        addOns: {},
        guest: {},
        room: {},
      });

      await expect(service.cancelReservation('t1', 'res-1', 'actor-1')).rejects.toThrow(BadRequestException);
    });
  });

  // ─── Billing ─────────────────────────────────────────────────────────────────

  describe('billing calculation', () => {
    it('computes correct night count for checkout invoice', async () => {
      const checkIn = tomorrow();
      const checkOut = dayAfter(checkIn, 5); // 5 nights
      const reservation = {
        id: 'r1',
        tenantId: 't1',
        roomId: 'room-1',
        status: ReservationStatus.CHECKED_IN,
        checkIn,
        checkOut,
        totalAmount: 500,
        addOns: {},
        guest: { id: 'g1', name: 'Bob', email: 'b@b.com' },
        room: {},
      };

      mockPrisma.reservation.findFirst.mockResolvedValue(reservation);
      mockPrisma.$transaction.mockResolvedValue([
        { ...reservation, status: ReservationStatus.CHECKED_OUT },
        mockRoom,
      ]);

      const { invoice } = await service.checkOut('t1', 'r1', 'actor-1');
      expect(invoice.nights).toBe(5);
      expect(invoice.total).toBe(500);
    });
  });
});
