import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { OrderStatus, TableStatus } from '@prisma/client';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderStatusDto } from './dto/update-order-status.dto';
import { CreateTableDto } from './dto/create-table.dto';
import { NotificationService } from '../notifications/notification.service';

// Valid order status transitions
const ALLOWED_TRANSITIONS: Partial<Record<OrderStatus, OrderStatus[]>> = {
  [OrderStatus.PENDING]: [OrderStatus.KDS, OrderStatus.CANCELLED],
  [OrderStatus.KDS]: [OrderStatus.READY, OrderStatus.CANCELLED],
  [OrderStatus.READY]: [OrderStatus.SERVED],
  [OrderStatus.SERVED]: [OrderStatus.BILLED],
};

@Injectable()
export class RestaurantService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationService,
  ) {}

  // ─── Tables ──────────────────────────────────────────────────────────────────

  async getTables(tenantId: string) {
    return this.prisma.restaurantTable.findMany({
      where: { tenantId },
      include: {
        orders: {
          where: { status: { notIn: [OrderStatus.BILLED, OrderStatus.CANCELLED] } },
          select: { id: true, status: true, createdAt: true },
        },
      },
      orderBy: { tableNumber: 'asc' },
    });
  }

  async getTable(tenantId: string, tableId: string) {
    const table = await this.prisma.restaurantTable.findFirst({
      where: { id: tableId, tenantId },
    });
    if (!table) throw new NotFoundException('Table not found');
    return table;
  }

  async createTable(tenantId: string, dto: CreateTableDto) {
    const existing = await this.prisma.restaurantTable.findUnique({
      where: { tenantId_tableNumber: { tenantId, tableNumber: dto.tableNumber } },
    });
    if (existing) throw new ConflictException(`Table ${dto.tableNumber} already exists`);

    // JSON QR payload — readable by the guest app scanner
    const qrCode = JSON.stringify({ tenantId, tableNumber: dto.tableNumber });

    return this.prisma.restaurantTable.create({
      data: { tenantId, tableNumber: dto.tableNumber, capacity: dto.capacity, qrCode },
    });
  }

  async getTableByQr(tenantId: string, tableNumber: number) {
    const table = await this.prisma.restaurantTable.findUnique({
      where: { tenantId_tableNumber: { tenantId, tableNumber } },
    });
    if (!table) throw new NotFoundException('Table not found');
    return table;
  }

  // ─── Menu ────────────────────────────────────────────────────────────────────

  async getMenu(tenantId: string) {
    return this.prisma.menuItem.findMany({
      where: { tenantId, available: true },
      orderBy: [{ category: 'asc' }, { name: 'asc' }],
    });
  }

  // ─── Orders ──────────────────────────────────────────────────────────────────

  async getOrders(tenantId: string, status?: OrderStatus) {
    return this.prisma.order.findMany({
      where: {
        tenantId,
        ...(status && { status }),
      },
      include: {
        orderItems: {
          include: { menuItem: { select: { name: true, category: true } } },
        },
        table: { select: { tableNumber: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getOrder(tenantId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, tenantId },
      include: {
        orderItems: {
          include: { menuItem: { select: { name: true, category: true, price: true } } },
        },
        table: { select: { tableNumber: true } },
      },
    });
    if (!order) throw new NotFoundException('Order not found');
    return order;
  }

  async getKdsOrders(tenantId: string) {
    return this.prisma.order.findMany({
      where: {
        tenantId,
        status: { in: [OrderStatus.PENDING, OrderStatus.KDS] },
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

  async createOrder(tenantId: string, waiterId: string | null, dto: CreateOrderDto) {
    if (!dto.tableId && !dto.isRoomService) {
      throw new BadRequestException('Order must have a tableId or be a room service order');
    }

    if (dto.tableId) {
      await this.getTable(tenantId, dto.tableId);
    }

    if (!dto.items || dto.items.length === 0) {
      throw new BadRequestException('Order must contain at least one item');
    }

    // Resolve menu items and calculate total
    const menuItems = await this.prisma.menuItem.findMany({
      where: {
        tenantId,
        id: { in: dto.items.map((i) => i.menuItemId) },
        available: true,
      },
    });

    if (menuItems.length !== dto.items.length) {
      throw new BadRequestException('One or more menu items are invalid or unavailable');
    }

    const menuMap = new Map(menuItems.map((m) => [m.id, m]));

    const orderItemsData = dto.items.map((item) => {
      const menuItem = menuMap.get(item.menuItemId)!;
      return {
        menuItemId: item.menuItemId,
        qty: item.qty,
        unitPrice: menuItem.price,
        modifiers: (item.modifiers ?? {}) as object,
      };
    });

    const total = orderItemsData.reduce(
      (sum, item) => sum + Number(item.unitPrice) * item.qty,
      0,
    );

    const order = await this.prisma.order.create({
      data: {
        tenantId,
        tableId: dto.tableId ?? null,
        waiterId: waiterId ?? null,
        isRoomService: dto.isRoomService ?? false,
        status: OrderStatus.PENDING,
        total,
        orderItems: { create: orderItemsData },
      },
      include: {
        orderItems: {
          include: { menuItem: { select: { name: true, category: true } } },
        },
        table: { select: { tableNumber: true } },
      },
    });

    // Mark table as occupied
    if (dto.tableId) {
      await this.prisma.restaurantTable.update({
        where: { id: dto.tableId },
        data: { status: TableStatus.OCCUPIED },
      });
    }

    return order;
  }

  async updateOrderStatus(
    tenantId: string,
    orderId: string,
    dto: UpdateOrderStatusDto,
    actorId: string,
  ) {
    const order = await this.getOrder(tenantId, orderId);
    this.assertTransition(order.status, dto.status);

    const updated = await this.prisma.order.update({
      where: { id: orderId },
      data: { status: dto.status },
      include: {
        orderItems: {
          include: { menuItem: { select: { name: true } } },
        },
        table: { select: { tableNumber: true } },
      },
    });

    // Free the table when order is billed
    if (dto.status === OrderStatus.BILLED && order.tableId) {
      const activeOrders = await this.prisma.order.count({
        where: {
          tenantId,
          tableId: order.tableId,
          status: { notIn: [OrderStatus.BILLED, OrderStatus.CANCELLED] },
          id: { not: orderId },
        },
      });

      if (activeOrders === 0) {
        await this.prisma.restaurantTable.update({
          where: { id: order.tableId },
          data: { status: TableStatus.AVAILABLE },
        });
      }
    }

    // Push notifications on key transitions
    const tableLabel = updated.table ? `Table ${updated.table.tableNumber}` : 'Room service';
    if (dto.status === OrderStatus.READY) {
      // Notify waiter: order ready to serve
      this.notifications.sendToRole(
        tenantId, 'WAITER',
        '🍽️ Order Ready!',
        `${tableLabel} — pick up now`,
        { orderId, type: 'ORDER_READY' },
      ).catch(() => {});

      // Also notify the guest directly (room service or table scan)
      const guestId = (updated as any).guestId as string | undefined;
      if (guestId) {
        const label = updated.table ? `Table ${updated.table.tableNumber}` : 'your room';
        this.notifications.sendToUser(
          guestId,
          '🍴 Your Order is Ready!',
          `Your order is on its way to ${label}.`,
          { type: 'order_ready', id: orderId },
        ).catch(() => {});
      }
    } else if (dto.status === OrderStatus.SERVED) {
      // Notify guest: order delivered to table or room
      const guestId = (updated as any).guestId as string | undefined;
      if (guestId) {
        const deliveredTo = updated.table
          ? `Table ${updated.table.tableNumber}`
          : 'your room';
        this.notifications.sendToUser(
          guestId,
          '🍽️ Your Order Has Been Delivered!',
          updated.isRoomService
            ? 'Your room service order has been delivered. Enjoy!'
            : `Your order has been served at ${deliveredTo}.`,
          { type: 'order_served', id: orderId },
        ).catch(() => {});
      }
    } else if (dto.status === OrderStatus.BILLED) {
      // Notify guest: bill ready
      const guestId = (updated as any).guestId as string | undefined;
      if (guestId) {
        this.notifications.sendToUser(
          guestId,
          '🧾 Your Bill is Ready',
          `Total: $${Number(updated.total).toFixed(2)} at ${tableLabel}. Tap to view.`,
          { type: 'bill_ready', id: orderId },
        ).catch(() => {});
      }
    } else if (dto.status === OrderStatus.KDS) {
      // Notify kitchen was sent (optional — for manager dashboards)
    }

    return updated;
  }

  async billOrder(tenantId: string, orderId: string) {
    const order = await this.getOrder(tenantId, orderId);

    if (order.status !== OrderStatus.SERVED) {
      throw new BadRequestException('Order must be SERVED before billing');
    }

    const updated = await this.prisma.order.update({
      where: { id: orderId },
      data: { status: OrderStatus.BILLED },
      include: { orderItems: { include: { menuItem: true } } },
    });

    const receipt = this.buildReceipt(updated);

    // Push: bill ready
    const guestId = (updated as any).guestId as string | undefined;
    if (guestId) {
      this.notifications.sendToUser(
        guestId,
        '🧾 Your Bill is Ready',
        `Total: $${Number(updated.total).toFixed(2)}. Tap to review your receipt.`,
        { type: 'bill_ready', id: orderId },
      ).catch(() => {});
    }

    return { order: updated, receipt };
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  private assertTransition(current: OrderStatus, next: OrderStatus) {
    const allowed = ALLOWED_TRANSITIONS[current] ?? [];
    if (!allowed.includes(next)) {
      throw new BadRequestException(
        `Cannot transition order from ${current} to ${next}`,
      );
    }
  }

  private buildReceipt(order: {
    id: string;
    total: unknown;
    createdAt: Date;
    orderItems: Array<{
      qty: number;
      unitPrice: unknown;
      menuItem: { name: string };
    }>;
  }) {
    return {
      orderId: order.id,
      items: order.orderItems.map((i) => ({
        name: i.menuItem.name,
        qty: i.qty,
        unitPrice: Number(i.unitPrice),
        lineTotal: Number(i.unitPrice) * i.qty,
      })),
      subtotal: Number(order.total),
      tax: Math.round(Number(order.total) * 0.16 * 100) / 100,
      total: Math.round(Number(order.total) * 1.16 * 100) / 100,
      generatedAt: new Date(),
    };
  }
}
