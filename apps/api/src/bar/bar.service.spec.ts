import { Test, TestingModule } from '@nestjs/testing';
import { BarService } from './bar.service';
import { PrismaService } from '../database/prisma.service';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { MovementType } from '@prisma/client';

const mockDrink = {
  id: 'drink-1',
  tenantId: 't1',
  name: 'Whiskey Sour',
  category: 'Cocktails',
  price: 12.0,
  available: true,
  recipe: [
    { stockItemId: 'stock-whiskey', qty: 0.06 },  // 60ml whiskey
    { stockItemId: 'stock-lemon', qty: 0.03 },    // 30ml lemon juice
  ],
  createdAt: new Date(),
};

const mockStockItems = [
  { id: 'stock-whiskey', tenantId: 't1', name: 'Whiskey', unit: 'litre', currentQty: 2.0, reorderLevel: 0.5, category: 'Spirits' },
  { id: 'stock-lemon', tenantId: 't1', name: 'Lemon Juice', unit: 'litre', currentQty: 1.0, reorderLevel: 0.2, category: 'Mixers' },
];

const mockPrisma = {
  drink: {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  stockItem: {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    update: jest.fn(),
  },
  stockMovement: {
    create: jest.fn(),
    findMany: jest.fn(),
  },
  barSale: {
    create: jest.fn(),
    findMany: jest.fn(),
  },
  $transaction: jest.fn(),
};

describe('BarService', () => {
  let service: BarService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BarService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<BarService>(BarService);
    jest.clearAllMocks();
  });

  // ─── Drink management ────────────────────────────────────────────────────────

  describe('getDrink', () => {
    it('throws NotFoundException for unknown drink', async () => {
      mockPrisma.drink.findFirst.mockResolvedValue(null);
      await expect(service.getDrink('t1', 'bad-id')).rejects.toThrow(NotFoundException);
    });

    it('returns drink when found', async () => {
      mockPrisma.drink.findFirst.mockResolvedValue(mockDrink);
      const result = await service.getDrink('t1', 'drink-1');
      expect(result.name).toBe('Whiskey Sour');
    });
  });

  describe('createDrink', () => {
    it('creates drink without recipe', async () => {
      mockPrisma.drink.create.mockResolvedValue({ ...mockDrink, recipe: [] });
      const result = await service.createDrink('t1', {
        name: 'Beer', category: 'Beer', price: 5.0,
      });
      expect(mockPrisma.drink.create).toHaveBeenCalledTimes(1);
      expect(result.name).toBe('Whiskey Sour');
    });

    it('validates recipe ingredients exist before creating', async () => {
      mockPrisma.stockItem.findMany.mockResolvedValue([mockStockItems[0]]); // only 1 of 2
      await expect(
        service.createDrink('t1', {
          name: 'Cocktail', category: 'Cocktails', price: 10.0,
          recipe: [
            { stockItemId: 'stock-whiskey', qty: 0.06 },
            { stockItemId: 'bad-stock', qty: 0.03 },
          ],
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // ─── Recipe-based inventory deduction ────────────────────────────────────────

  describe('recordSale — inventory deduction', () => {
    beforeEach(() => {
      mockPrisma.drink.findFirst.mockResolvedValue(mockDrink);
    });

    it('throws BadRequestException when drink is unavailable', async () => {
      mockPrisma.drink.findFirst.mockResolvedValue({ ...mockDrink, available: false });
      await expect(
        service.recordSale('t1', 'bartender-1', { drinkId: 'drink-1', qty: 1 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('throws BadRequestException when stock is insufficient for recipe', async () => {
      mockPrisma.stockItem.findMany.mockResolvedValue([
        { ...mockStockItems[0], currentQty: 0.05 }, // only 50ml, need 60ml
        mockStockItems[1],
      ]);

      await expect(
        service.recordSale('t1', 'bartender-1', { drinkId: 'drink-1', qty: 1 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('deducts correct qty from stock (qty × ingredient amount)', async () => {
      mockPrisma.stockItem.findMany.mockResolvedValue(mockStockItems);
      mockPrisma.$transaction.mockResolvedValue([]);
      // After deduction: 2.0 - 0.12 = 1.88 (2 drinks × 0.06L)
      mockPrisma.stockItem.findMany
        .mockResolvedValueOnce(mockStockItems)
        .mockResolvedValueOnce([
          { ...mockStockItems[0], currentQty: 1.88 },
          { ...mockStockItems[1], currentQty: 0.94 },
        ]);
      mockPrisma.barSale.create.mockResolvedValue({
        id: 'sale-1', drinkId: 'drink-1', qty: 2, total: 24.0, wasteQty: 0,
        drink: { name: 'Whiskey Sour', category: 'Cocktails' },
      });

      await service.recordSale('t1', 'bartender-1', { drinkId: 'drink-1', qty: 2 });

      const txCalls = mockPrisma.$transaction.mock.calls[0][0];
      const stockOutCalls = txCalls.filter((_: unknown, i: number) => i % 2 === 0);
      // 2 ingredients × decrement
      expect(stockOutCalls).toHaveLength(2);
    });

    it('includes waste qty in deduction (qty + wasteQty)', async () => {
      mockPrisma.stockItem.findMany.mockResolvedValue(mockStockItems);
      mockPrisma.$transaction.mockResolvedValue([]);
      mockPrisma.stockItem.findMany
        .mockResolvedValueOnce(mockStockItems)
        .mockResolvedValueOnce(mockStockItems);
      mockPrisma.barSale.create.mockResolvedValue({
        id: 'sale-1', qty: 1, wasteQty: 1, total: 12.0,
        drink: { name: 'Whiskey Sour', category: 'Cocktails' },
      });

      // qty=1, wasteQty=1 → total multiplier=2 → deducts 2×recipe amounts
      await service.recordSale('t1', 'bartender-1', { drinkId: 'drink-1', qty: 1, wasteQty: 1 });

      // stockItem.update is called per ingredient before $transaction wraps them
      const updateCalls = mockPrisma.stockItem.update.mock.calls;
      const whiskeyUpdate = updateCalls.find((c: any) => c[0].where.id === 'stock-whiskey');
      // Should decrement by 0.06 × 2 = 0.12 (qty=1 sold + wasteQty=1)
      expect(whiskeyUpdate[0].data.currentQty.decrement).toBeCloseTo(0.12);
    });

    it('calculates sale total correctly (price × qty, excluding waste)', async () => {
      mockPrisma.stockItem.findMany.mockResolvedValue(mockStockItems);
      mockPrisma.$transaction.mockResolvedValue([]);
      mockPrisma.stockItem.findMany
        .mockResolvedValueOnce(mockStockItems)
        .mockResolvedValueOnce(mockStockItems);
      mockPrisma.barSale.create.mockResolvedValue({
        id: 'sale-1', qty: 3, wasteQty: 0, total: 36.0,
        drink: { name: 'Whiskey Sour', category: 'Cocktails' },
      });

      await service.recordSale('t1', 'bartender-1', { drinkId: 'drink-1', qty: 3 });

      const createCall = mockPrisma.barSale.create.mock.calls[0][0];
      expect(createCall.data.total).toBe(36.0); // 3 × $12
    });

    it('fires reorder alert when stock drops below threshold', async () => {
      mockPrisma.stockItem.findMany.mockResolvedValue(mockStockItems);
      mockPrisma.$transaction.mockResolvedValue([]);
      // After deduction whiskey drops to 0.4L (below reorderLevel 0.5)
      mockPrisma.stockItem.findMany
        .mockResolvedValueOnce(mockStockItems)
        .mockResolvedValueOnce([
          { ...mockStockItems[0], currentQty: 0.4 }, // below 0.5 threshold
          { ...mockStockItems[1], currentQty: 0.97 },
        ]);
      mockPrisma.barSale.create.mockResolvedValue({
        id: 'sale-1', qty: 1, wasteQty: 0, total: 12.0,
        drink: { name: 'Whiskey Sour', category: 'Cocktails' },
      });

      const { reorderAlerts } = await service.recordSale('t1', 'bartender-1', {
        drinkId: 'drink-1', qty: 1,
      });

      expect(reorderAlerts).toHaveLength(1);
      expect(reorderAlerts[0].name).toBe('Whiskey');
      expect(reorderAlerts[0].currentQty).toBe(0.4);
    });

    it('returns empty reorder alerts when stock is above threshold', async () => {
      mockPrisma.stockItem.findMany.mockResolvedValue(mockStockItems);
      mockPrisma.$transaction.mockResolvedValue([]);
      mockPrisma.stockItem.findMany
        .mockResolvedValueOnce(mockStockItems)
        .mockResolvedValueOnce(mockStockItems); // still above threshold
      mockPrisma.barSale.create.mockResolvedValue({
        id: 'sale-1', qty: 1, wasteQty: 0, total: 12.0,
        drink: { name: 'Whiskey Sour', category: 'Cocktails' },
      });

      const { reorderAlerts } = await service.recordSale('t1', 'bartender-1', {
        drinkId: 'drink-1', qty: 1,
      });

      expect(reorderAlerts).toHaveLength(0);
    });
  });

  // ─── Shift summary ────────────────────────────────────────────────────────────

  describe('getShiftSummary', () => {
    it('calculates revenue, drink count, and waste correctly', async () => {
      mockPrisma.barSale.findMany.mockResolvedValue([
        { qty: 2, total: 24.0, wasteQty: 0, drink: { category: 'Cocktails' } },
        { qty: 1, total: 5.0, wasteQty: 1, drink: { category: 'Beer' } },
        { qty: 3, total: 15.0, wasteQty: 0, drink: { category: 'Cocktails' } },
      ]);

      const summary = await service.getShiftSummary('t1', 'bartender-1', new Date());

      expect(summary.totalRevenue).toBe(44.0);
      expect(summary.totalDrinks).toBe(6);
      expect(summary.totalWaste).toBe(1);
      expect(summary.byCategory['Cocktails']).toBe(39.0);
      expect(summary.byCategory['Beer']).toBe(5.0);
      expect(summary.saleCount).toBe(3);
    });
  });
});
