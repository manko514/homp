import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../database/prisma.service';
import { AiService } from '../ai/ai.service';

@Injectable()
export class InventoryAiService {
  private readonly logger = new Logger(InventoryAiService.name);

  constructor(
    private prisma: PrismaService,
    private aiService: AiService,
  ) {}

  // ─── Weekly cron: every Monday at 6 AM ────────────────────────────────────
  @Cron('0 6 * * 1')
  async runWeeklyPrediction() {
    this.logger.log('Running weekly inventory prediction…');
    const tenants = await this.prisma.tenant.findMany({ select: { id: true, name: true } });
    for (const tenant of tenants) {
      try {
        await this.predict(tenant.id);
        this.logger.log(`Inventory prediction done for: ${tenant.name}`);
      } catch (err) {
        this.logger.error(`Inventory prediction failed for ${tenant.name}`, err);
      }
    }
  }

  // ─── Core: stock levels + 30-day usage → Claude → purchase orders ─────────
  async predict(tenantId: string) {
    const since = new Date();
    since.setDate(since.getDate() - 30);

    // Get all stock items with recent movement history
    const stockItems = await this.prisma.stockItem.findMany({
      where: { tenantId },
      include: {
        stockMovements: {
          where: { createdAt: { gte: since } },
          select: { movementType: true, qty: true, createdAt: true },
          orderBy: { createdAt: 'desc' },
        },
      },
    });

    if (stockItems.length === 0) {
      return { message: 'No stock items found', ordersCreated: 0, orders: [] };
    }

    // ── Summarise each item's usage ───────────────────────────────────────────
    const itemSummaries = stockItems.map((item) => {
      const consumed = item.stockMovements
        .filter((m) => m.movementType === 'STOCK_OUT' || m.movementType === 'WASTE')
        .reduce((s, m) => s + Number(m.qty), 0);

      const received = item.stockMovements
        .filter((m) => m.movementType === 'STOCK_IN')
        .reduce((s, m) => s + Number(m.qty), 0);

      const dailyUsage = consumed / 30;
      const daysRemaining = dailyUsage > 0 ? Number(item.currentQty) / dailyUsage : 999;

      return {
        id: item.id,
        name: item.name,
        category: item.category,
        unit: item.unit,
        currentQty: Number(item.currentQty),
        reorderLevel: Number(item.reorderLevel),
        belowReorder: Number(item.currentQty) <= Number(item.reorderLevel),
        consumed30d: consumed,
        received30d: received,
        avgDailyUsage: Math.round(dailyUsage * 100) / 100,
        daysRemaining: Math.round(daysRemaining),
      };
    });

    // ── Ask Claude which items to order and how much ──────────────────────────
    const systemPrompt =
      'You are a hotel inventory manager. Return ONLY valid JSON — no markdown, no explanation.';

    const userPrompt = `Analyse the hotel stock levels and 30-day usage data below.
Recommend purchase orders for items that need restocking in the next 2 weeks.

STOCK DATA:
${JSON.stringify(itemSummaries, null, 2)}

Rules:
- Order items that are below reorder level OR have fewer than 7 days remaining
- Order enough for 30 days of usage
- Prioritise CRITICAL items (below reorder level) first

Return exactly this JSON:
{
  "summary": "1-sentence overview of inventory health",
  "orders": [
    {
      "stockItemId": "uuid",
      "itemName": "name",
      "currentQty": 0,
      "reorderQty": 0,
      "unit": "kg|L|pcs|etc",
      "reason": "why this needs to be ordered",
      "priority": "CRITICAL|HIGH|MEDIUM"
    }
  ]
}`;

    const raw = await this.aiService.complete(tenantId, systemPrompt, userPrompt, 'inventory');

    let analysis: { summary: string; orders: any[] };
    try {
      const match = raw.match(/\{[\s\S]*\}/);
      analysis = JSON.parse(match ? match[0] : raw);
    } catch {
      analysis = { summary: 'Parse error', orders: [] };
    }

    // ── Delete old PENDING orders and create fresh ones ───────────────────────
    await this.prisma.purchaseOrder.deleteMany({
      where: { tenantId, status: 'PENDING', aiGenerated: true },
    });

    const created: any[] = [];
    for (const order of analysis.orders ?? []) {
      // Verify stockItemId exists in this tenant
      const item = stockItems.find((s) => s.id === order.stockItemId);
      if (!item) continue;

      const po = await this.prisma.purchaseOrder.create({
        data: {
          tenantId,
          stockItemId: item.id,
          itemName: order.itemName ?? item.name,
          currentQty: order.currentQty ?? item.currentQty,
          reorderQty: order.reorderQty ?? item.reorderLevel,
          unit: order.unit ?? item.unit,
          reason: order.reason ?? 'Below reorder level',
          status: 'PENDING',
          aiGenerated: true,
        },
      });
      created.push(po);
    }

    return {
      summary: analysis.summary,
      ordersCreated: created.length,
      orders: created,
    };
  }

  // ─── Queries ──────────────────────────────────────────────────────────────
  async getPurchaseOrders(tenantId: string, status?: string) {
    return this.prisma.purchaseOrder.findMany({
      where: { tenantId, ...(status ? { status } : {}) },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async updateOrderStatus(tenantId: string, orderId: string, status: 'APPROVED' | 'DISMISSED') {
    return this.prisma.purchaseOrder.update({
      where: { id: orderId, tenantId },
      data: { status },
    });
  }

  async getStockAlerts(tenantId: string) {
    const items = await this.prisma.stockItem.findMany({
      where: { tenantId },
      select: {
        id: true, name: true, category: true, unit: true,
        currentQty: true, reorderLevel: true,
      },
    });
    const belowReorder = items.filter(
      (i) => Number(i.currentQty) <= Number(i.reorderLevel),
    );
    return { total: items.length, belowReorder, belowReorderCount: belowReorder.length };
  }
}
