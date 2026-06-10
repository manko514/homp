import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { MovementType } from '@prisma/client';
import { CreateStockItemDto, UpdateStockItemDto } from './dto/create-stock-item.dto';
import { RecordMovementDto } from './dto/record-movement.dto';

const DEDUCTION_TYPES = new Set<MovementType>([MovementType.STOCK_OUT, MovementType.WASTE]);

@Injectable()
export class InventoryService {
  constructor(private prisma: PrismaService) {}

  // ─── Stock items ─────────────────────────────────────────────────────────────

  async getStockItems(tenantId: string) {
    return this.prisma.stockItem.findMany({
      where: { tenantId },
      orderBy: [{ category: 'asc' }, { name: 'asc' }],
    });
  }

  async getStockItem(tenantId: string, id: string) {
    const item = await this.prisma.stockItem.findFirst({
      where: { id, tenantId },
    });
    if (!item) throw new NotFoundException('Stock item not found');
    return item;
  }

  async createStockItem(tenantId: string, dto: CreateStockItemDto) {
    return this.prisma.stockItem.create({
      data: {
        tenantId,
        name: dto.name,
        unit: dto.unit,
        category: dto.category,
        currentQty: dto.currentQty,
        reorderLevel: dto.reorderLevel,
      },
    });
  }

  async updateStockItem(tenantId: string, id: string, dto: UpdateStockItemDto) {
    await this.getStockItem(tenantId, id);
    return this.prisma.stockItem.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.unit !== undefined && { unit: dto.unit }),
        ...(dto.category !== undefined && { category: dto.category }),
        ...(dto.reorderLevel !== undefined && { reorderLevel: dto.reorderLevel }),
      },
    });
  }

  // ─── Movements ────────────────────────────────────────────────────────────────

  async recordMovement(tenantId: string, dto: RecordMovementDto) {
    const item = await this.getStockItem(tenantId, dto.stockItemId);

    if (DEDUCTION_TYPES.has(dto.movementType)) {
      if (Number(item.currentQty) < dto.qty) {
        throw new BadRequestException(
          `Insufficient stock: ${item.currentQty} ${item.unit} available, requested ${dto.qty}`,
        );
      }
    }

    const isDeduction = DEDUCTION_TYPES.has(dto.movementType);

    const [movement, updatedItem] = await this.prisma.$transaction([
      this.prisma.stockMovement.create({
        data: {
          stockItemId: dto.stockItemId,
          movementType: dto.movementType,
          qty: dto.qty,
          referenceType: 'MANUAL',
          notes: dto.notes,
        },
      }),
      this.prisma.stockItem.update({
        where: { id: dto.stockItemId },
        data: {
          currentQty: isDeduction
            ? { decrement: dto.qty }
            : { increment: dto.qty },
        },
      }),
    ]);

    const lowStock =
      Number(updatedItem.currentQty) <= Number(updatedItem.reorderLevel)
        ? {
            stockItemId: updatedItem.id,
            name: updatedItem.name,
            currentQty: Number(updatedItem.currentQty),
            reorderLevel: Number(updatedItem.reorderLevel),
            unit: updatedItem.unit,
          }
        : null;

    return { movement, updatedItem, lowStock };
  }

  async getMovementHistory(
    tenantId: string,
    stockItemId?: string,
    from?: Date,
    to?: Date,
  ) {
    return this.prisma.stockMovement.findMany({
      where: {
        stockItem: { tenantId },
        ...(stockItemId && { stockItemId }),
        ...(from && { createdAt: { gte: from } }),
        ...(to && { createdAt: { lte: to } }),
      },
      include: {
        stockItem: { select: { name: true, unit: true, category: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  // ─── Alerts ───────────────────────────────────────────────────────────────────

  async getLowStockAlerts(tenantId: string) {
    const items = await this.prisma.stockItem.findMany({
      where: { tenantId },
    });

    return items
      .filter((i) => Number(i.currentQty) <= Number(i.reorderLevel))
      .map((i) => ({
        stockItemId: i.id,
        name: i.name,
        category: i.category,
        currentQty: Number(i.currentQty),
        reorderLevel: Number(i.reorderLevel),
        unit: i.unit,
        deficit: Number(i.reorderLevel) - Number(i.currentQty),
      }));
  }
}
