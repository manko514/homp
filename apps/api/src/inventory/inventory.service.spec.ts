import { Test, TestingModule } from '@nestjs/testing';
import { InventoryService } from './inventory.service';
import { PrismaService } from '../database/prisma.service';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { MovementType } from '@prisma/client';

const mockStockItem = {
  id: 'stock-1',
  tenantId: 't1',
  name: 'Whiskey',
  unit: 'litre',
  category: 'Spirits',
  currentQty: 5.0,
  reorderLevel: 1.0,
  createdAt: new Date(),
  updatedAt: new Date(),
};

const mockPrisma = {
  stockItem: {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  stockMovement: {
    create: jest.fn(),
    findMany: jest.fn(),
  },
  $transaction: jest.fn(),
};

describe('InventoryService', () => {
  let service: InventoryService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InventoryService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<InventoryService>(InventoryService);
    jest.clearAllMocks();
  });

  // ─── Stock items ─────────────────────────────────────────────────────────────

  describe('getStockItem', () => {
    it('throws NotFoundException for unknown item', async () => {
      mockPrisma.stockItem.findFirst.mockResolvedValue(null);
      await expect(service.getStockItem('t1', 'bad-id')).rejects.toThrow(NotFoundException);
    });

    it('returns item when found', async () => {
      mockPrisma.stockItem.findFirst.mockResolvedValue(mockStockItem);
      const result = await service.getStockItem('t1', 'stock-1');
      expect(result.name).toBe('Whiskey');
    });
  });

  describe('createStockItem', () => {
    it('creates and returns new stock item', async () => {
      mockPrisma.stockItem.create.mockResolvedValue(mockStockItem);
      const result = await service.createStockItem('t1', {
        name: 'Whiskey',
        unit: 'litre',
        category: 'Spirits',
        currentQty: 5.0,
        reorderLevel: 1.0,
      });
      expect(mockPrisma.stockItem.create).toHaveBeenCalledTimes(1);
      expect(result.name).toBe('Whiskey');
    });
  });

  // ─── Movements ────────────────────────────────────────────────────────────────

  describe('recordMovement', () => {
    beforeEach(() => {
      mockPrisma.stockItem.findFirst.mockResolvedValue(mockStockItem);
    });

    it('records STOCK_IN and increments qty', async () => {
      const updatedItem = { ...mockStockItem, currentQty: 7.0 };
      mockPrisma.$transaction.mockResolvedValue([{}, updatedItem]);

      const result = await service.recordMovement('t1', {
        stockItemId: 'stock-1',
        movementType: MovementType.STOCK_IN,
        qty: 2.0,
      });

      expect(result.updatedItem.currentQty).toBe(7.0);
      expect(result.lowStock).toBeNull();
    });

    it('records STOCK_OUT and decrements qty', async () => {
      const updatedItem = { ...mockStockItem, currentQty: 3.0 };
      mockPrisma.$transaction.mockResolvedValue([{}, updatedItem]);

      const result = await service.recordMovement('t1', {
        stockItemId: 'stock-1',
        movementType: MovementType.STOCK_OUT,
        qty: 2.0,
      });

      expect(result.updatedItem.currentQty).toBe(3.0);
    });

    it('throws BadRequestException when removing more than available', async () => {
      mockPrisma.stockItem.findFirst.mockResolvedValue({
        ...mockStockItem,
        currentQty: 0.5,
      });

      await expect(
        service.recordMovement('t1', {
          stockItemId: 'stock-1',
          movementType: MovementType.STOCK_OUT,
          qty: 1.0,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws BadRequestException when wasting more than available', async () => {
      mockPrisma.stockItem.findFirst.mockResolvedValue({
        ...mockStockItem,
        currentQty: 0.1,
      });

      await expect(
        service.recordMovement('t1', {
          stockItemId: 'stock-1',
          movementType: MovementType.WASTE,
          qty: 0.5,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('returns lowStock alert when stock drops to reorderLevel', async () => {
      const updatedItem = { ...mockStockItem, currentQty: 0.8, reorderLevel: 1.0 };
      mockPrisma.$transaction.mockResolvedValue([{}, updatedItem]);

      const result = await service.recordMovement('t1', {
        stockItemId: 'stock-1',
        movementType: MovementType.STOCK_OUT,
        qty: 4.2,
      });

      expect(result.lowStock).not.toBeNull();
      expect(result.lowStock!.name).toBe('Whiskey');
    });

    it('records ADJUSTMENT without checking available qty', async () => {
      const updatedItem = { ...mockStockItem, currentQty: 10.0 };
      mockPrisma.$transaction.mockResolvedValue([{}, updatedItem]);

      const result = await service.recordMovement('t1', {
        stockItemId: 'stock-1',
        movementType: MovementType.ADJUSTMENT,
        qty: 5.0,
        notes: 'Inventory count correction',
      });

      expect(result.updatedItem.currentQty).toBe(10.0);
    });
  });

  // ─── Low stock alerts ─────────────────────────────────────────────────────────

  describe('getLowStockAlerts', () => {
    it('returns items at or below reorderLevel', async () => {
      mockPrisma.stockItem.findMany.mockResolvedValue([
        { ...mockStockItem, currentQty: 0.8, reorderLevel: 1.0 },
        { ...mockStockItem, id: 'stock-2', name: 'Rum', currentQty: 2.0, reorderLevel: 1.0 },
        { ...mockStockItem, id: 'stock-3', name: 'Gin', currentQty: 0.0, reorderLevel: 0.5 },
      ]);

      const alerts = await service.getLowStockAlerts('t1');

      expect(alerts).toHaveLength(2);
      expect(alerts.map((a) => a.name)).toContain('Whiskey');
      expect(alerts.map((a) => a.name)).toContain('Gin');
    });

    it('returns empty array when all stock is above reorderLevel', async () => {
      mockPrisma.stockItem.findMany.mockResolvedValue([
        { ...mockStockItem, currentQty: 5.0, reorderLevel: 1.0 },
      ]);

      const alerts = await service.getLowStockAlerts('t1');
      expect(alerts).toHaveLength(0);
    });
  });
});
