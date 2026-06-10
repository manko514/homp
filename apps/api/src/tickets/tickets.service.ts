import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../database/prisma.service';
import { AuditService } from '../audit/audit.service';
import { PurchaseTicketDto } from './dto/purchase-ticket.dto';
import { randomUUID } from 'crypto';

const TICKET_PRICES: Record<string, number> = {
  DAY_PASS: 50,
  POOL_ONLY: 30,
  GYM: 25,
  EVENT: 75,
  VIP: 150,
};

@Injectable()
export class TicketsService {
  private readonly logger = new Logger(TicketsService.name);

  constructor(private prisma: PrismaService, private audit: AuditService) {}

  // ─── Purchase / Issue a ticket ────────────────────────────────────────────
  async purchase(tenantId: string, dto: PurchaseTicketDto) {
    const qrToken = `HOMP-${randomUUID().replace(/-/g, '').toUpperCase().slice(0, 16)}`;

    const ticket = await this.prisma.ticket.create({
      data: {
        tenantId,
        guestName: dto.guestName,
        guestId: dto.guestId,
        ticketType: dto.ticketType,
        qrToken,
        validFrom: new Date(dto.validFrom),
        validUntil: new Date(dto.validUntil),
        scheduledDate: dto.scheduledDate ? new Date(dto.scheduledDate) : null,
        purchasePrice: dto.purchasePrice,
        status: 'ACTIVE',
      },
    });

    this.logger.log(`Ticket issued: ${qrToken} for ${dto.guestName ?? 'Walk-in'} (${dto.ticketType})`);
    await this.audit.log({ tenantId, actorId: tenantId, eventType: 'CREATE', resourceType: 'ticket', resourceId: ticket.id, diffJson: { ticketType: dto.ticketType, guestName: dto.guestName, price: dto.purchasePrice } });
    return ticket;
  }

  // ─── Validate QR at gate ──────────────────────────────────────────────────
  async validate(tenantId: string, qrToken: string) {
    const ticket = await this.prisma.ticket.findFirst({
      where: { tenantId, qrToken },
    });

    if (!ticket) throw new NotFoundException('Ticket not found');

    if (ticket.status === 'USED') {
      return { valid: false, reason: 'Ticket already used', ticket };
    }
    if (ticket.status === 'CANCELLED') {
      return { valid: false, reason: 'Ticket has been cancelled', ticket };
    }
    if (ticket.status === 'EXPIRED') {
      return { valid: false, reason: 'Ticket has expired', ticket };
    }

    const now = new Date();
    if (now > ticket.validUntil) {
      await this.prisma.ticket.update({
        where: { id: ticket.id },
        data: { status: 'EXPIRED' },
      });
      return { valid: false, reason: 'Ticket has expired', ticket };
    }
    if (now < ticket.validFrom) {
      return { valid: false, reason: `Ticket not valid until ${ticket.validFrom.toLocaleString()}`, ticket };
    }

    // Mark as used
    const updated = await this.prisma.ticket.update({
      where: { id: ticket.id },
      data: { status: 'USED', usedAt: now },
    });

    this.logger.log(`Ticket validated: ${qrToken}`);
    await this.audit.log({ tenantId, actorId: tenantId, eventType: 'VALIDATE', resourceType: 'ticket', resourceId: updated.id, diffJson: { qrToken, guestName: updated.guestName } });
    return { valid: true, reason: 'Entry granted', ticket: updated };
  }

  // ─── List tickets ──────────────────────────────────────────────────────────
  async listTickets(tenantId: string, status?: string, type?: string, date?: string) {
    const where: Record<string, unknown> = { tenantId };
    if (status) where.status = status;
    if (type) where.ticketType = type;
    if (date) {
      const d = new Date(date);
      const nextDay = new Date(d);
      nextDay.setDate(nextDay.getDate() + 1);
      where.createdAt = { gte: d, lt: nextDay };
    }

    return this.prisma.ticket.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  // ─── Stats ─────────────────────────────────────────────────────────────────
  async getStats(tenantId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const [total, active, usedToday, byType, revenue, revenueToday] = await Promise.all([
      this.prisma.ticket.count({ where: { tenantId } }),
      this.prisma.ticket.count({ where: { tenantId, status: 'ACTIVE' } }),
      this.prisma.ticket.count({
        where: { tenantId, status: 'USED', usedAt: { gte: today, lt: tomorrow } },
      }),
      this.prisma.ticket.groupBy({
        by: ['ticketType'],
        where: { tenantId },
        _count: { id: true },
        _sum: { purchasePrice: true },
      }),
      this.prisma.ticket.aggregate({
        where: { tenantId },
        _sum: { purchasePrice: true },
      }),
      this.prisma.ticket.aggregate({
        where: { tenantId, createdAt: { gte: today, lt: tomorrow } },
        _sum: { purchasePrice: true },
      }),
    ]);

    return {
      total,
      active,
      usedToday,
      revenue: Number(revenue._sum.purchasePrice ?? 0),
      revenueToday: Number(revenueToday._sum.purchasePrice ?? 0),
      byType: byType.map((b) => ({
        type: b.ticketType,
        count: b._count.id,
        revenue: Number(b._sum.purchasePrice ?? 0),
      })),
      defaultPrices: TICKET_PRICES,
    };
  }

  // ─── Cancel ticket ─────────────────────────────────────────────────────────
  async cancel(tenantId: string, id: string) {
    const ticket = await this.prisma.ticket.findFirst({ where: { id, tenantId } });
    if (!ticket) throw new NotFoundException('Ticket not found');
    if (ticket.status === 'USED') throw new BadRequestException('Cannot cancel a used ticket');

    return this.prisma.ticket.update({
      where: { id },
      data: { status: 'CANCELLED' },
    });
  }

  // ─── Nightly expiry cron ───────────────────────────────────────────────────
  @Cron('0 * * * *') // every hour
  async expireOverdue() {
    const result = await this.prisma.ticket.updateMany({
      where: {
        status: 'ACTIVE',
        validUntil: { lt: new Date() },
      },
      data: { status: 'EXPIRED' },
    });
    if (result.count > 0) {
      this.logger.log(`Expired ${result.count} tickets`);
    }
  }
}
