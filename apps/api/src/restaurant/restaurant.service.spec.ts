import { Test, TestingModule } from '@nestjs/testing';
import { RestaurantService } from './restaurant.service';
import { PrismaService } from '../database/prisma.service';
import { NotificationService } from '../notifications/notification.service';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { OrderStatus, TableStatus } from '@prisma/client';

const mockTable = {
  id: 'table-1',
  tenantId: 't1',
  tableNumber: 1,
  capacity: 4,
  status: TableStatus.AVAILABLE,
  qrCode: 'homp://restaurant/table/t1/1',
  createdAt: new Date(),
};

const mockMenuItems = [
  { id: 'mi-1', tenantId: 't1', name: 'Club Sandwich', category: 'Mains', price: 12.5, available: true },
  { id: 'mi-2', tenantId: 't1', name: 'Orange Juice', category: 'Beverages', price: 5.0, available: true },
];

const mockOrder = {
  id: 'order-1',
  tenantId: 't1',
  tableId: 'table-1',
  waiterId: 'waiter-1',
  status: OrderStatus.PENDING,
  total: 30.0,
  isRoomService: false,
  createdAt: new Date(),
  updatedAt: new Date(),
  orderItems: [
    { id: 'oi-1', qty: 2, unitPrice: 12.5, menuItem: { name: 'Club Sandwich', category: 'Mains' } },
    { id: 'oi-2', qty: 1, unitPrice: 5.0, menuItem: { name: 'Orange Juice', category: 'Beverages' } },
  ],
  table: { tableNumber: 1 },
};

const mockPrisma = {
  restaurantTable: {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  menuItem: {
    findMany: jest.fn(),
  },
  order: {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    count: jest.fn(),
  },
};

const mockNotifications = {
  sendToRole: jest.fn().mockResolvedValue(undefined),
  sendToUser: jest.fn().mockResolvedValue(undefined),
};

describe('RestaurantService', () => {
  let service: RestaurantService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RestaurantService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: NotificationService, useValue: mockNotifications },
      ],
    }).compile();

    service = module.get<RestaurantService>(RestaurantService);
    jest.clearAllMocks();
  });

  // ─── Table tests ─────────────────────────────────────────────────────────────

  describe('createTable', () => {
    it('throws ConflictException for duplicate table number', async () => {
      mockPrisma.restaurantTable.findUnique.mockResolvedValue(mockTable);
      await expect(
        service.createTable('t1', { tableNumber: 1, capacity: 4 }),
      ).rejects.toThrow(ConflictException);
    });

    it('creates table with QR code', async () => {
      mockPrisma.restaurantTable.findUnique.mockResolvedValue(null);
      mockPrisma.restaurantTable.create.mockResolvedValue(mockTable);
      const result = await service.createTable('t1', { tableNumber: 1, capacity: 4 });
      const createCall = mockPrisma.restaurantTable.create.mock.calls[0][0];
      expect(createCall.data.qrCode).toContain('tableNumber');
      expect(result.tableNumber).toBe(1);
    });
  });

  // ─── Order creation ──────────────────────────────────────────────────────────

  describe('createOrder', () => {
    beforeEach(() => {
      mockPrisma.restaurantTable.findFirst.mockResolvedValue(mockTable);
      mockPrisma.menuItem.findMany.mockResolvedValue(mockMenuItems);
      mockPrisma.restaurantTable.update.mockResolvedValue({ ...mockTable, status: TableStatus.OCCUPIED });
    });

    it('throws BadRequestException when no tableId and not room service', async () => {
      await expect(
        service.createOrder('t1', 'w1', { items: [{ menuItemId: 'mi-1', qty: 1 }] }),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws BadRequestException when items array is empty', async () => {
      await expect(
        service.createOrder('t1', 'w1', { tableId: 'table-1', items: [] }),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws BadRequestException when menu item is invalid', async () => {
      mockPrisma.menuItem.findMany.mockResolvedValue([mockMenuItems[0]]); // only 1 of 2
      await expect(
        service.createOrder('t1', 'w1', {
          tableId: 'table-1',
          items: [
            { menuItemId: 'mi-1', qty: 1 },
            { menuItemId: 'bad-id', qty: 1 },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('calculates order total correctly', async () => {
      mockPrisma.order.create.mockResolvedValue({ ...mockOrder, total: 30.0 });

      await service.createOrder('t1', 'w1', {
        tableId: 'table-1',
        items: [
          { menuItemId: 'mi-1', qty: 2 }, // 2 × 12.50 = 25.00
          { menuItemId: 'mi-2', qty: 1 }, // 1 × 5.00  =  5.00
        ],
      });

      const createCall = mockPrisma.order.create.mock.calls[0][0];
      expect(createCall.data.total).toBe(30.0);
    });

    it('creates order with PENDING status', async () => {
      mockPrisma.menuItem.findMany.mockResolvedValue([mockMenuItems[0]]);
      mockPrisma.order.create.mockResolvedValue(mockOrder);

      const result = await service.createOrder('t1', 'w1', {
        tableId: 'table-1',
        items: [{ menuItemId: 'mi-1', qty: 1 }],
      });

      expect(result.status).toBe(OrderStatus.PENDING);
    });

    it('marks table OCCUPIED after order creation', async () => {
      mockPrisma.menuItem.findMany.mockResolvedValue([mockMenuItems[0]]);
      mockPrisma.order.create.mockResolvedValue(mockOrder);

      await service.createOrder('t1', 'w1', {
        tableId: 'table-1',
        items: [{ menuItemId: 'mi-1', qty: 1 }],
      });

      expect(mockPrisma.restaurantTable.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: { status: TableStatus.OCCUPIED },
        }),
      );
    });
  });

  // ─── Order lifecycle state machine ───────────────────────────────────────────

  describe('updateOrderStatus — state machine', () => {
    const setOrderStatus = (status: OrderStatus) => {
      mockPrisma.order.findFirst.mockResolvedValue({ ...mockOrder, status });
      mockPrisma.order.update.mockResolvedValue({ ...mockOrder, status: Object.values(OrderStatus)[Object.values(OrderStatus).indexOf(status) + 1] });
      mockPrisma.order.count.mockResolvedValue(0);
      mockPrisma.restaurantTable.update.mockResolvedValue(mockTable);
    };

    it('allows PENDING → KDS', async () => {
      setOrderStatus(OrderStatus.PENDING);
      mockPrisma.order.update.mockResolvedValue({ ...mockOrder, status: OrderStatus.KDS });
      const result = await service.updateOrderStatus('t1', 'order-1', { status: OrderStatus.KDS }, 'w1');
      expect(result.status).toBe(OrderStatus.KDS);
    });

    it('allows KDS → READY', async () => {
      setOrderStatus(OrderStatus.KDS);
      mockPrisma.order.update.mockResolvedValue({ ...mockOrder, status: OrderStatus.READY });
      const result = await service.updateOrderStatus('t1', 'order-1', { status: OrderStatus.READY }, 'w1');
      expect(result.status).toBe(OrderStatus.READY);
    });

    it('allows READY → SERVED', async () => {
      setOrderStatus(OrderStatus.READY);
      mockPrisma.order.update.mockResolvedValue({ ...mockOrder, status: OrderStatus.SERVED });
      const result = await service.updateOrderStatus('t1', 'order-1', { status: OrderStatus.SERVED }, 'w1');
      expect(result.status).toBe(OrderStatus.SERVED);
    });

    it('rejects PENDING → SERVED (skipping KDS)', async () => {
      setOrderStatus(OrderStatus.PENDING);
      await expect(
        service.updateOrderStatus('t1', 'order-1', { status: OrderStatus.SERVED }, 'w1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects READY → KDS (backward transition)', async () => {
      setOrderStatus(OrderStatus.READY);
      await expect(
        service.updateOrderStatus('t1', 'order-1', { status: OrderStatus.KDS }, 'w1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects BILLED → any transition', async () => {
      setOrderStatus(OrderStatus.BILLED);
      await expect(
        service.updateOrderStatus('t1', 'order-1', { status: OrderStatus.SERVED }, 'w1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('frees table when last order is billed', async () => {
      mockPrisma.order.findFirst.mockResolvedValue({ ...mockOrder, status: OrderStatus.SERVED });
      mockPrisma.order.update.mockResolvedValue({ ...mockOrder, status: OrderStatus.BILLED });
      mockPrisma.order.count.mockResolvedValue(0); // no other active orders on this table
      mockPrisma.restaurantTable.update.mockResolvedValue({ ...mockTable, status: TableStatus.AVAILABLE });

      await service.updateOrderStatus('t1', 'order-1', { status: OrderStatus.BILLED }, 'w1');

      expect(mockPrisma.restaurantTable.update).toHaveBeenCalledWith(
        expect.objectContaining({ data: { status: TableStatus.AVAILABLE } }),
      );
    });
  });

  // ─── Receipt / billing ───────────────────────────────────────────────────────

  describe('billOrder', () => {
    it('throws BadRequestException when order is not SERVED', async () => {
      mockPrisma.order.findFirst.mockResolvedValue({ ...mockOrder, status: OrderStatus.READY });
      await expect(service.billOrder('t1', 'order-1')).rejects.toThrow(BadRequestException);
    });

    it('generates receipt with correct totals', async () => {
      const servedOrder = {
        ...mockOrder,
        status: OrderStatus.SERVED,
        total: 30.0,
        orderItems: [
          { id: 'oi-1', qty: 2, unitPrice: 12.5, menuItem: { name: 'Club Sandwich', category: 'Mains', price: 12.5 } },
          { id: 'oi-2', qty: 1, unitPrice: 5.0, menuItem: { name: 'Orange Juice', category: 'Beverages', price: 5.0 } },
        ],
      };
      mockPrisma.order.findFirst.mockResolvedValue(servedOrder);
      mockPrisma.order.update.mockResolvedValue({ ...servedOrder, status: OrderStatus.BILLED });

      const { receipt } = await service.billOrder('t1', 'order-1');

      expect(receipt.subtotal).toBe(30.0);
      expect(receipt.tax).toBe(4.8);   // 16% tax
      expect(receipt.total).toBe(34.8);
      expect(receipt.items).toHaveLength(2);
    });
  });
});
