import { Injectable, Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';
import { PrismaService } from '../database/prisma.service';
import type { Response } from 'express';
import PDFDocument = require('pdfkit');

const REPORT_TTL = 3600; // 1 hour

export interface DailyRevenueResult {
  date: string;
  hotel: { revenue: number; checkouts: number };
  restaurant: { revenue: number; orders: number };
  bar: { revenue: number; sales: number };
  totalRevenue: number;
}

@Injectable()
export class ReportsService {
  constructor(
    private prisma: PrismaService,
    @Inject(CACHE_MANAGER) private cache: Cache,
  ) {}

  // ─── Daily Revenue ────────────────────────────────────────────────────────────

  async getDailyRevenue(tenantId: string, date: Date) {
    const start = new Date(date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(date);
    end.setHours(23, 59, 59, 999);

    const key = `report:daily:${tenantId}:${start.toISOString().split('T')[0]}`;
    const cached = await this.cache.get<DailyRevenueResult>(key);
    if (cached) return cached;

    const [reservations, orders, barSales] = await Promise.all([
      this.prisma.reservation.findMany({
        where: {
          tenantId,
          status: 'CHECKED_OUT',
          updatedAt: { gte: start, lte: end },
        },
        select: { totalAmount: true, roomId: true },
      }),
      this.prisma.order.findMany({
        where: {
          tenantId,
          status: 'BILLED',
          updatedAt: { gte: start, lte: end },
        },
        select: { total: true },
      }),
      this.prisma.barSale.findMany({
        where: {
          tenantId,
          createdAt: { gte: start, lte: end },
        },
        include: { drink: { select: { category: true } } },
      }),
    ]);

    const hotelRevenue = reservations.reduce(
      (sum, r) => sum + Number(r.totalAmount ?? 0),
      0,
    );
    const restaurantRevenue = orders.reduce(
      (sum, o) => sum + Number(o.total),
      0,
    );
    const barRevenue = barSales.reduce((sum, s) => sum + Number(s.total), 0);
    const totalRevenue = hotelRevenue + restaurantRevenue + barRevenue;

    const result = {
      date: start.toISOString().split('T')[0],
      hotel: { revenue: hotelRevenue, checkouts: reservations.length },
      restaurant: { revenue: restaurantRevenue, orders: orders.length },
      bar: { revenue: barRevenue, sales: barSales.length },
      totalRevenue,
    };
    await this.cache.set(key, result, REPORT_TTL);
    return result;
  }

  // ─── Weekly Revenue (last N days) ────────────────────────────────────────────

  async getWeeklyRevenue(tenantId: string, days = 7) {
    const results = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const daily = await this.getDailyRevenue(tenantId, d);
      results.push(daily);
    }
    return results;
  }

  // ─── Stock Report ─────────────────────────────────────────────────────────────

  async getStockReport(tenantId: string) {
    const items = await this.prisma.stockItem.findMany({
      where: { tenantId },
      orderBy: [{ category: 'asc' }, { name: 'asc' }],
    });

    const formatted = items.map((i) => ({
      id: i.id,
      name: i.name,
      category: i.category,
      unit: i.unit,
      currentQty: Number(i.currentQty),
      reorderLevel: Number(i.reorderLevel),
      status:
        Number(i.currentQty) <= 0
          ? 'OUT_OF_STOCK'
          : Number(i.currentQty) <= Number(i.reorderLevel)
            ? 'LOW_STOCK'
            : 'OK',
    }));

    const byCategory = formatted.reduce(
      (acc, i) => {
        if (!acc[i.category]) acc[i.category] = [];
        acc[i.category].push(i);
        return acc;
      },
      {} as Record<string, typeof formatted>,
    );

    return {
      generatedAt: new Date().toISOString(),
      totalItems: items.length,
      lowStockCount: formatted.filter((i) => i.status !== 'OK').length,
      byCategory,
      items: formatted,
    };
  }

  // ─── Executive Summary (all modules in one call) ────────────────────────────
  async getExecutiveSummary(tenantId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);

    // Batch 1 — hotel, orders, bar
    const [rooms, todayOrders, todayBarSales, todayTickets, activeTickets] =
      await Promise.all([
        this.prisma.room.findMany({ where: { tenantId }, select: { status: true } }),
        this.prisma.order.aggregate({ where: { tenantId, status: 'BILLED', updatedAt: { gte: today, lt: tomorrow } }, _sum: { total: true }, _count: { id: true } }),
        this.prisma.barSale.aggregate({ where: { tenantId, createdAt: { gte: today, lt: tomorrow } }, _sum: { total: true }, _count: { id: true } }),
        this.prisma.ticket.aggregate({ where: { tenantId, createdAt: { gte: today, lt: tomorrow } }, _sum: { purchasePrice: true }, _count: { id: true } }),
        this.prisma.ticket.count({ where: { tenantId, status: 'ACTIVE' } }),
      ]);

    // Batch 2 — month revenue
    const [mHotel, mRestaurant, mBar, mTickets] = await Promise.all([
      this.prisma.reservation.aggregate({ where: { tenantId, status: 'CHECKED_OUT', updatedAt: { gte: monthStart, lt: tomorrow } }, _sum: { totalAmount: true } }),
      this.prisma.order.aggregate({ where: { tenantId, status: 'BILLED', updatedAt: { gte: monthStart, lt: tomorrow } }, _sum: { total: true } }),
      this.prisma.barSale.aggregate({ where: { tenantId, createdAt: { gte: monthStart, lt: tomorrow } }, _sum: { total: true } }),
      this.prisma.ticket.aggregate({ where: { tenantId, createdAt: { gte: monthStart, lt: tomorrow } }, _sum: { purchasePrice: true } }),
    ]);

    // Batch 3 — hr, alerts, ai, audit
    const [anomalyAlerts, pendingPayroll, totalEmployees, lastForecast, recentAudit, lowStock] =
      await Promise.all([
        this.prisma.anomalyAlert.count({ where: { tenantId, resolved: false } }),
        this.prisma.payrollRun.count({ where: { tenantId, status: { in: ['DRAFT', 'PENDING_APPROVAL'] } } }),
        this.prisma.employee.count({ where: { tenantId } }),
        this.prisma.aiForecast.findFirst({ where: { tenantId }, orderBy: { createdAt: 'desc' }, select: { forecastDate: true, confidence: true, forecastType: true } }),
        this.prisma.auditLog.findMany({ where: { tenantId }, orderBy: { createdAt: 'desc' }, take: 5, include: { actor: { select: { name: true } } } }),
        this.prisma.stockItem.findMany({ where: { tenantId }, select: { name: true, currentQty: true, reorderLevel: true } }),
      ]);

    const occupied = rooms.filter((r) => r.status === 'OCCUPIED').length;
    const occupancy = rooms.length > 0 ? Math.round((occupied / rooms.length) * 100) : 0;

    const monthRevenue =
      Number(mHotel._sum.totalAmount ?? 0) +
      Number(mRestaurant._sum.total ?? 0) +
      Number(mBar._sum.total ?? 0) +
      Number(mTickets._sum.purchasePrice ?? 0);

    const todayRevenue =
      Number(todayOrders._sum.total ?? 0) +
      Number(todayBarSales._sum.total ?? 0) +
      Number(todayTickets._sum.purchasePrice ?? 0);

    const lowStockCount = lowStock.filter((i) => Number(i.currentQty) <= Number(i.reorderLevel)).length;

    return {
      hotel: { total: rooms.length, occupied, available: rooms.length - occupied, occupancy },
      revenue: { today: todayRevenue, thisMonth: monthRevenue },
      restaurant: { ordersToday: todayOrders._count.id, revenueToday: Number(todayOrders._sum.total ?? 0) },
      bar: { salesToday: todayBarSales._count.id, revenueToday: Number(todayBarSales._sum.total ?? 0) },
      tickets: { activeNow: activeTickets, soldToday: todayTickets._count.id, revenueToday: Number(todayTickets._sum.purchasePrice ?? 0) },
      hr: { totalEmployees, pendingPayroll },
      alerts: { anomalies: anomalyAlerts, lowStock: lowStockCount },
      ai: { lastForecast },
      recentActivity: recentAudit.map((a) => ({
        eventType: a.eventType,
        resourceType: a.resourceType,
        actor: a.actor?.name ?? null,
        createdAt: a.createdAt,
      })),
    };
  }

  // ─── Cohort Analysis ─────────────────────────────────────────────────────────
  // Groups first-time guests by check-in month; tracks return stays in later months.

  async getCohortAnalysis(tenantId: string) {
    const reservations = await this.prisma.reservation.findMany({
      where: { tenantId, status: { in: ['CHECKED_IN', 'CHECKED_OUT'] as any } },
      select: { guestId: true, checkIn: true },
      orderBy: { checkIn: 'asc' },
    });

    // First stay per guest
    const firstStay: Record<string, string> = {};
    for (const r of reservations) {
      const month = r.checkIn.toISOString().slice(0, 7); // YYYY-MM
      if (!firstStay[r.guestId]) firstStay[r.guestId] = month;
    }

    // Build cohort map: cohortMonth -> { month0, month1, month2, … }
    const cohorts: Record<string, Record<number, Set<string>>> = {};
    for (const r of reservations) {
      const cohortMonth = firstStay[r.guestId];
      if (!cohorts[cohortMonth]) cohorts[cohortMonth] = {};
      const stayMonth = r.checkIn.toISOString().slice(0, 7);
      const delta = this._monthDelta(cohortMonth, stayMonth);
      if (!cohorts[cohortMonth][delta]) cohorts[cohortMonth][delta] = new Set();
      cohorts[cohortMonth][delta].add(r.guestId);
    }

    const rows = Object.entries(cohorts)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([cohortMonth, periods]) => {
        const cohortSize = periods[0]?.size ?? 0;
        const retention: Record<string, number | null> = {};
        for (let i = 0; i <= 5; i++) {
          retention[`m${i}`] = periods[i] ? Math.round((periods[i].size / cohortSize) * 100) : null;
        }
        return { cohortMonth, cohortSize, retention };
      });

    return { generatedAt: new Date().toISOString(), cohorts: rows };
  }

  private _monthDelta(from: string, to: string): number {
    const [fy, fm] = from.split('-').map(Number);
    const [ty, tm] = to.split('-').map(Number);
    return (ty - fy) * 12 + (tm - fm);
  }

  // ─── Guest Lifetime Value ─────────────────────────────────────────────────────

  async getGuestLtv(tenantId: string, limit = 50) {
    // BarSale has no guestId — LTV covers hotel stays + F&B orders only
    const [reservations, orders] = await Promise.all([
      this.prisma.reservation.findMany({
        where: { tenantId, status: 'CHECKED_OUT' as any },
        select: { guestId: true, totalAmount: true },
      }),
      this.prisma.order.findMany({
        where: { tenantId, status: 'BILLED', guestId: { not: null } },
        select: { guestId: true, total: true },
      }),
    ]);

    const ltv: Record<string, { hotel: number; fnb: number; stays: number }> = {};

    for (const r of reservations) {
      if (!ltv[r.guestId]) ltv[r.guestId] = { hotel: 0, fnb: 0, stays: 0 };
      ltv[r.guestId].hotel += Number(r.totalAmount ?? 0);
      ltv[r.guestId].stays += 1;
    }
    for (const o of orders) {
      if (!o.guestId) continue;
      if (!ltv[o.guestId]) ltv[o.guestId] = { hotel: 0, fnb: 0, stays: 0 };
      ltv[o.guestId].fnb += Number(o.total);
    }

    const guestIds = Object.keys(ltv);
    const users = await this.prisma.user.findMany({
      where: { id: { in: guestIds } },
      select: { id: true, name: true, email: true },
    });
    const userMap = Object.fromEntries(users.map((u) => [u.id, u]));

    const ranked = guestIds
      .map((id) => {
        const v = ltv[id];
        const total = v.hotel + v.fnb;
        return { guestId: id, name: userMap[id]?.name ?? 'Unknown', email: userMap[id]?.email ?? '', total, ...v };
      })
      .sort((a, b) => b.total - a.total)
      .slice(0, limit);

    return { generatedAt: new Date().toISOString(), guests: ranked };
  }

  // ─── Channel Attribution ──────────────────────────────────────────────────────

  async getChannelAttribution(tenantId: string) {
    const reservations = await this.prisma.reservation.findMany({
      where: { tenantId },
      select: { bookingSource: true, totalAmount: true, status: true },
    });

    const channels: Record<string, { bookings: number; revenue: number }> = {};
    for (const r of reservations) {
      const ch = r.bookingSource ?? 'direct';
      if (!channels[ch]) channels[ch] = { bookings: 0, revenue: 0 };
      channels[ch].bookings += 1;
      if (r.status === 'CHECKED_OUT') channels[ch].revenue += Number(r.totalAmount ?? 0);
    }

    const total = Object.values(channels).reduce((s, c) => s + c.bookings, 0);
    const rows = Object.entries(channels)
      .map(([channel, stats]) => ({
        channel,
        bookings: stats.bookings,
        revenue: stats.revenue,
        share: total > 0 ? Math.round((stats.bookings / total) * 100) : 0,
      }))
      .sort((a, b) => b.bookings - a.bookings);

    return { generatedAt: new Date().toISOString(), totalBookings: total, channels: rows };
  }

  // ─── PDF: Daily Revenue ───────────────────────────────────────────────────────

  async streamDailyRevenuePdf(tenantId: string, date: Date, res: Response) {
    const data = await this.getDailyRevenue(tenantId, date);

    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { name: true },
    });

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="revenue-${data.date}.pdf"`,
    );

    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    doc.pipe(res);

    // Header
    doc
      .fontSize(20)
      .font('Helvetica-Bold')
      .text(tenant?.name ?? 'HOMP', 50, 50);
    doc.fontSize(14).font('Helvetica').text(`Daily Revenue Report — ${data.date}`, 50, 78);
    doc.moveTo(50, 105).lineTo(545, 105).stroke();

    // Sections
    let y = 120;

    const section = (label: string, revenue: number, count: number, countLabel: string) => {
      doc.fontSize(12).font('Helvetica-Bold').text(label, 50, y);
      doc.font('Helvetica').fontSize(11);
      doc.text(`Revenue: $${revenue.toFixed(2)}`, 70, y + 18);
      doc.text(`${countLabel}: ${count}`, 70, y + 34);
      y += 60;
    };

    section('Hotel', data.hotel.revenue, data.hotel.checkouts, 'Check-outs');
    section('Restaurant', data.restaurant.revenue, data.restaurant.orders, 'Orders billed');
    section('Bar', data.bar.revenue, data.bar.sales, 'Sales');

    // Total
    doc.moveTo(50, y).lineTo(545, y).stroke();
    y += 10;
    doc
      .fontSize(14)
      .font('Helvetica-Bold')
      .text(`Total Revenue: $${data.totalRevenue.toFixed(2)}`, 50, y);

    doc.end();
  }

  // ─── PDF: Stock Report ────────────────────────────────────────────────────────

  async streamStockReportPdf(tenantId: string, res: Response) {
    const data = await this.getStockReport(tenantId);

    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { name: true },
    });

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="stock-report.pdf"`);

    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    doc.pipe(res);

    // Header
    doc.fontSize(20).font('Helvetica-Bold').text(tenant?.name ?? 'HOMP', 50, 50);
    doc
      .fontSize(14)
      .font('Helvetica')
      .text(`Stock Report — ${new Date().toLocaleDateString()}`, 50, 78);
    doc.moveTo(50, 105).lineTo(545, 105).stroke();

    doc.fontSize(11).font('Helvetica');
    doc.text(`Total items: ${data.totalItems}   |   Low/Out of stock: ${data.lowStockCount}`, 50, 115);

    let y = 140;

    for (const [category, items] of Object.entries(data.byCategory)) {
      if (y > 740) {
        doc.addPage();
        y = 50;
      }

      doc.fontSize(12).font('Helvetica-Bold').text(category, 50, y);
      y += 18;

      for (const item of items) {
        if (y > 750) {
          doc.addPage();
          y = 50;
        }
        const statusSymbol = item.status === 'OK' ? '✓' : item.status === 'LOW_STOCK' ? '⚠' : '✗';
        const color = item.status === 'OK' ? '#000000' : item.status === 'LOW_STOCK' ? '#c07000' : '#cc0000';
        doc
          .fontSize(10)
          .font('Helvetica')
          .fillColor(color)
          .text(
            `${statusSymbol}  ${item.name.padEnd(28)} ${String(item.currentQty).padStart(8)} ${item.unit.padEnd(8)}  (min: ${item.reorderLevel})`,
            70,
            y,
          )
          .fillColor('#000000');
        y += 16;
      }
      y += 8;
    }

    doc.end();
  }
}
