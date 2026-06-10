import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { MovementType } from '@prisma/client';
import { CreateDrinkDto } from './dto/create-drink.dto';
import { RecordSaleDto } from './dto/record-sale.dto';
import { LogWasteDto } from './dto/log-waste.dto';

export interface ReorderAlert {
  stockItemId: string;
  name: string;
  currentQty: number;
  reorderLevel: number;
  unit: string;
}

@Injectable()
export class BarService {
  constructor(private prisma: PrismaService) {}

  // ─── Drinks ──────────────────────────────────────────────────────────────────

  async getDrinks(tenantId: string) {
    return this.prisma.drink.findMany({
      where: { tenantId },
      orderBy: [{ category: 'asc' }, { name: 'asc' }],
    });
  }

  async getDrink(tenantId: string, drinkId: string) {
    const drink = await this.prisma.drink.findFirst({
      where: { id: drinkId, tenantId },
    });
    if (!drink) throw new NotFoundException('Drink not found');
    return drink;
  }

  async createDrink(tenantId: string, dto: CreateDrinkDto) {
    if (dto.recipe && dto.recipe.length > 0) {
      await this.validateRecipeIngredients(tenantId, dto.recipe.map((r) => r.stockItemId));
    }

    return this.prisma.drink.create({
      data: {
        tenantId,
        name: dto.name,
        category: dto.category,
        price: dto.price,
        photoUrl: dto.photoUrl,
        recipe: dto.recipe ? (dto.recipe as object) : [],
      },
    });
  }

  async toggleDrinkAvailability(tenantId: string, drinkId: string) {
    const drink = await this.getDrink(tenantId, drinkId);
    return this.prisma.drink.update({
      where: { id: drinkId },
      data: { available: !drink.available },
    });
  }

  // ─── Sales ───────────────────────────────────────────────────────────────────

  async getSales(tenantId: string, from?: Date, to?: Date) {
    return this.prisma.barSale.findMany({
      where: {
        tenantId,
        ...(from && { createdAt: { gte: from } }),
        ...(to && { createdAt: { lte: to } }),
      },
      include: {
        drink: { select: { name: true, category: true } },
        bartender: { select: { name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async recordSale(tenantId: string, bartenderId: string, dto: RecordSaleDto) {
    const drink = await this.getDrink(tenantId, dto.drinkId);

    if (!drink.available) {
      throw new BadRequestException(`${drink.name} is currently unavailable`);
    }

    const recipe = (drink.recipe as Array<{ stockItemId: string; qty: number }>) ?? [];
    const reorderAlerts: ReorderAlert[] = [];

    // Deduct ingredients from stock for qty sold + waste
    const totalQty = dto.qty + (dto.wasteQty ?? 0);

    if (recipe.length > 0) {
      reorderAlerts.push(...(await this.deductRecipeIngredients(tenantId, recipe, totalQty, dto.drinkId)));
    }

    const total = Number(drink.price) * dto.qty;

    const sale = await this.prisma.barSale.create({
      data: {
        tenantId,
        drinkId: dto.drinkId,
        qty: dto.qty,
        bartenderId,
        total,
        wasteQty: dto.wasteQty ?? 0,
      },
      include: {
        drink: { select: { name: true, category: true } },
      },
    });

    return { sale, reorderAlerts };
  }

  // ─── Waste log ───────────────────────────────────────────────────────────────

  async logWaste(tenantId: string, bartenderId: string, dto: LogWasteDto) {
    const stockItem = await this.prisma.stockItem.findFirst({
      where: { id: dto.stockItemId, tenantId },
    });
    if (!stockItem) throw new NotFoundException('Stock item not found');

    if (Number(stockItem.currentQty) < dto.qty) {
      throw new BadRequestException(
        `Insufficient stock: ${stockItem.currentQty} ${stockItem.unit} available`,
      );
    }

    const [movement, updatedStock] = await this.prisma.$transaction([
      this.prisma.stockMovement.create({
        data: {
          stockItemId: dto.stockItemId,
          movementType: MovementType.WASTE,
          qty: dto.qty,
          referenceType: 'BAR_WASTE',
          notes: dto.reason,
        },
      }),
      this.prisma.stockItem.update({
        where: { id: dto.stockItemId },
        data: { currentQty: { decrement: dto.qty } },
      }),
    ]);

    const reorderAlert =
      Number(updatedStock.currentQty) <= Number(updatedStock.reorderLevel)
        ? {
            stockItemId: updatedStock.id,
            name: updatedStock.name,
            currentQty: Number(updatedStock.currentQty),
            reorderLevel: Number(updatedStock.reorderLevel),
            unit: updatedStock.unit,
          }
        : null;

    return { movement, reorderAlert };
  }

  // ─── Bottle log ───────────────────────────────────────────────────────────────

  async getBottleLog(tenantId: string) {
    return this.prisma.stockMovement.findMany({
      where: {
        stockItem: { tenantId, category: { in: ['Spirits', 'Wine', 'Beer', 'Beverages'] } },
      },
      include: {
        stockItem: { select: { name: true, unit: true, category: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  // ─── Shift summary ────────────────────────────────────────────────────────────

  async getShiftSummary(tenantId: string, bartenderId: string, shiftStart: Date) {
    const sales = await this.prisma.barSale.findMany({
      where: { tenantId, bartenderId, createdAt: { gte: shiftStart } },
      include: { drink: { select: { name: true, category: true } } },
    });

    const totalRevenue = sales.reduce((sum, s) => sum + Number(s.total), 0);
    const totalDrinks = sales.reduce((sum, s) => sum + s.qty, 0);
    const totalWaste = sales.reduce((sum, s) => sum + s.wasteQty, 0);

    const byCategory = sales.reduce(
      (acc, s) => {
        const cat = s.drink.category;
        acc[cat] = (acc[cat] ?? 0) + Number(s.total);
        return acc;
      },
      {} as Record<string, number>,
    );

    return { totalRevenue, totalDrinks, totalWaste, byCategory, saleCount: sales.length };
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  private async validateRecipeIngredients(tenantId: string, stockItemIds: string[]) {
    const items = await this.prisma.stockItem.findMany({
      where: { id: { in: stockItemIds }, tenantId },
    });
    if (items.length !== stockItemIds.length) {
      throw new BadRequestException('One or more recipe ingredients are invalid stock items');
    }
  }

  private async deductRecipeIngredients(
    tenantId: string,
    recipe: Array<{ stockItemId: string; qty: number }>,
    multiplier: number,
    referenceId: string,
  ): Promise<ReorderAlert[]> {
    const stockItemIds = recipe.map((r) => r.stockItemId);
    const stockItems = await this.prisma.stockItem.findMany({
      where: { id: { in: stockItemIds }, tenantId },
    });

    const stockMap = new Map(stockItems.map((s) => [s.id, s]));
    const reorderAlerts: ReorderAlert[] = [];

    // Validate sufficient stock before deducting anything
    for (const ingredient of recipe) {
      const item = stockMap.get(ingredient.stockItemId);
      if (!item) throw new NotFoundException(`Stock item ${ingredient.stockItemId} not found`);

      const required = ingredient.qty * multiplier;
      if (Number(item.currentQty) < required) {
        throw new BadRequestException(
          `Insufficient stock for ${item.name}: need ${required} ${item.unit}, have ${item.currentQty}`,
        );
      }
    }

    // Deduct all ingredients in a transaction
    await this.prisma.$transaction(
      recipe.flatMap((ingredient) => {
        const deductQty = ingredient.qty * multiplier;
        return [
          this.prisma.stockItem.update({
            where: { id: ingredient.stockItemId },
            data: { currentQty: { decrement: deductQty } },
          }),
          this.prisma.stockMovement.create({
            data: {
              stockItemId: ingredient.stockItemId,
              movementType: MovementType.STOCK_OUT,
              qty: deductQty,
              referenceType: 'BAR_SALE',
              referenceId,
            },
          }),
        ];
      }),
    );

    // Check reorder levels after deduction
    const updatedItems = await this.prisma.stockItem.findMany({
      where: { id: { in: stockItemIds } },
    });

    for (const item of updatedItems) {
      if (Number(item.currentQty) <= Number(item.reorderLevel)) {
        reorderAlerts.push({
          stockItemId: item.id,
          name: item.name,
          currentQty: Number(item.currentQty),
          reorderLevel: Number(item.reorderLevel),
          unit: item.unit,
        });
      }
    }

    return reorderAlerts;
  }
}
