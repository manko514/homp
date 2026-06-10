import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class FinanceService {
  constructor(private prisma: PrismaService) {}

  // ─── Parse month string "YYYY-MM" → date range ───────────────────────────
  private monthRange(month: string): { start: Date; end: Date } {
    const [y, m] = month.split('-').map(Number);
    const start = new Date(y, m - 1, 1);
    const end = new Date(y, m, 0, 23, 59, 59, 999); // last day of month
    return { start, end };
  }

  // ─── Monthly P&L ──────────────────────────────────────────────────────────
  async getMonthlyPL(tenantId: string, month: string) {
    const { start, end } = this.monthRange(month);

    const [hotelRev, restaurantRev, barRev, ticketRev, payrollExp] = await Promise.all([
      // Hotel revenue: checked-out reservations
      this.prisma.reservation.aggregate({
        where: { tenantId, status: 'CHECKED_OUT', updatedAt: { gte: start, lte: end } },
        _sum: { totalAmount: true },
        _count: { id: true },
      }),
      // Restaurant revenue: billed orders
      this.prisma.order.aggregate({
        where: { tenantId, status: 'BILLED', updatedAt: { gte: start, lte: end } },
        _sum: { total: true },
        _count: { id: true },
      }),
      // Bar revenue: all bar sales
      this.prisma.barSale.aggregate({
        where: { tenantId, createdAt: { gte: start, lte: end } },
        _sum: { total: true },
        _count: { id: true },
      }),
      // Ticket revenue
      this.prisma.ticket.aggregate({
        where: { tenantId, createdAt: { gte: start, lte: end }, status: { in: ['USED', 'ACTIVE', 'EXPIRED'] } },
        _sum: { purchasePrice: true },
        _count: { id: true },
      }),
      // Payroll expense: disbursed runs in period
      this.prisma.payrollItem.aggregate({
        where: {
          payrollRun: {
            tenantId,
            status: 'DISBURSED',
            disbursedAt: { gte: start, lte: end },
          },
        },
        _sum: { net: true },
      }),
    ]);

    const hotel = Number(hotelRev._sum.totalAmount ?? 0);
    const restaurant = Number(restaurantRev._sum.total ?? 0);
    const bar = Number(barRev._sum.total ?? 0);
    const tickets = Number(ticketRev._sum.purchasePrice ?? 0);
    const totalRevenue = hotel + restaurant + bar + tickets;

    const payroll = Number(payrollExp._sum.net ?? 0);
    const totalExpenses = payroll; // extend with more expense categories later
    const grossProfit = totalRevenue - totalExpenses;
    const margin = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0;

    return {
      month,
      revenue: {
        hotel: { amount: hotel, count: hotelRev._count.id },
        restaurant: { amount: restaurant, count: restaurantRev._count.id },
        bar: { amount: bar, count: barRev._count.id },
        tickets: { amount: tickets, count: ticketRev._count.id },
        total: totalRevenue,
      },
      expenses: {
        payroll: { amount: payroll },
        total: totalExpenses,
      },
      grossProfit,
      margin: Math.round(margin * 10) / 10,
    };
  }

  // ─── Daily revenue trend (last N days or specific month) ─────────────────
  async getDailyTrend(tenantId: string, month: string) {
    const { start, end } = this.monthRange(month);
    const days: { date: string; hotel: number; restaurant: number; bar: number; tickets: number; total: number }[] = [];

    const cursor = new Date(start);
    while (cursor <= end && cursor <= new Date()) {
      const dayStart = new Date(cursor);
      dayStart.setHours(0, 0, 0, 0);
      const dayEnd = new Date(cursor);
      dayEnd.setHours(23, 59, 59, 999);

      const [h, r, b, t] = await Promise.all([
        this.prisma.reservation.aggregate({
          where: { tenantId, status: 'CHECKED_OUT', updatedAt: { gte: dayStart, lte: dayEnd } },
          _sum: { totalAmount: true },
        }),
        this.prisma.order.aggregate({
          where: { tenantId, status: 'BILLED', updatedAt: { gte: dayStart, lte: dayEnd } },
          _sum: { total: true },
        }),
        this.prisma.barSale.aggregate({
          where: { tenantId, createdAt: { gte: dayStart, lte: dayEnd } },
          _sum: { total: true },
        }),
        this.prisma.ticket.aggregate({
          where: { tenantId, createdAt: { gte: dayStart, lte: dayEnd }, status: { in: ['USED', 'ACTIVE', 'EXPIRED'] } },
          _sum: { purchasePrice: true },
        }),
      ]);

      const hotel = Number(h._sum.totalAmount ?? 0);
      const restaurant = Number(r._sum.total ?? 0);
      const bar = Number(b._sum.total ?? 0);
      const tickets = Number(t._sum.purchasePrice ?? 0);

      days.push({
        date: cursor.toISOString().slice(0, 10),
        hotel,
        restaurant,
        bar,
        tickets,
        total: hotel + restaurant + bar + tickets,
      });

      cursor.setDate(cursor.getDate() + 1);
    }

    return days;
  }

  // ─── Revenue summary: current month vs last month ─────────────────────────
  async getComparison(tenantId: string) {
    const now = new Date();
    const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const lastMonthDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lastMonth = `${lastMonthDate.getFullYear()}-${String(lastMonthDate.getMonth() + 1).padStart(2, '0')}`;

    const [current, last] = await Promise.all([
      this.getMonthlyPL(tenantId, currentMonth),
      this.getMonthlyPL(tenantId, lastMonth),
    ]);

    const revenueChange = last.revenue.total > 0
      ? ((current.revenue.total - last.revenue.total) / last.revenue.total) * 100
      : 0;

    return { current, last, revenueChange: Math.round(revenueChange * 10) / 10 };
  }
}
