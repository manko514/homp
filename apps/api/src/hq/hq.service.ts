import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class HqService {
  constructor(private prisma: PrismaService) {}

  // ─── List all property groups ─────────────────────────────────────────────────
  async listGroups() {
    return this.prisma.propertyGroup.findMany({
      include: { tenants: { select: { id: true, name: true, subdomain: true } } },
      orderBy: { createdAt: 'asc' },
    });
  }

  // ─── Cross-property KPI aggregate for one group ───────────────────────────────
  async getGroupKpis(groupId: string) {
    const group = await this.prisma.propertyGroup.findUnique({
      where: { id: groupId },
      include: { tenants: { select: { id: true, name: true } } },
    });
    if (!group) return null;

    const tenantIds = group.tenants.map((t) => t.id);
    const since30 = new Date();
    since30.setDate(since30.getDate() - 30);

    const [reservations, orders, barSales, employees, anomalies] = await Promise.all([
      this.prisma.reservation.findMany({
        where: { tenantId: { in: tenantIds }, createdAt: { gte: since30 } },
        select: { tenantId: true, totalAmount: true, status: true },
      }),
      this.prisma.order.findMany({
        where: { tenantId: { in: tenantIds }, createdAt: { gte: since30 }, status: { not: 'CANCELLED' } },
        select: { tenantId: true, total: true },
      }),
      this.prisma.barSale.findMany({
        where: { tenantId: { in: tenantIds }, createdAt: { gte: since30 } },
        select: { tenantId: true, total: true },
      }),
      this.prisma.employee.count({ where: { tenantId: { in: tenantIds } } }),
      this.prisma.anomalyAlert.count({ where: { tenantId: { in: tenantIds }, resolved: false } }),
    ]);

    // Aggregate per property
    const byProperty = group.tenants.map((t) => {
      const res = reservations.filter((r) => r.tenantId === t.id);
      const ord = orders.filter((o) => o.tenantId === t.id);
      const bar = barSales.filter((b) => b.tenantId === t.id);

      const hotelRevenue = res.filter((r) => r.status === 'CHECKED_OUT').reduce((s, r) => s + Number(r.totalAmount ?? 0), 0);
      const fbnRevenue = ord.reduce((s, o) => s + Number(o.total), 0);
      const barRevenue = bar.reduce((s, b) => s + Number(b.total), 0);
      const totalRevenue = hotelRevenue + fbnRevenue + barRevenue;
      const occupancy = res.length > 0 ? Math.round((res.filter((r) => r.status === 'CHECKED_IN' || r.status === 'CHECKED_OUT').length / res.length) * 100) : 0;

      return {
        tenantId: t.id,
        name: t.name,
        revenue30d: totalRevenue,
        hotelRevenue,
        fbnRevenue,
        barRevenue,
        reservations: res.length,
        occupancyRate: occupancy,
      };
    });

    const totalRevenue30d = byProperty.reduce((s, p) => s + p.revenue30d, 0);

    return {
      groupId,
      groupName: group.name,
      properties: byProperty.length,
      totalRevenue30d,
      totalEmployees: employees,
      openAnomalyAlerts: anomalies,
      byProperty,
    };
  }

  // ─── Consolidated P&L across all groups ──────────────────────────────────────
  async getConsolidatedPL() {
    const groups = await this.prisma.propertyGroup.findMany({
      include: { tenants: { select: { id: true, name: true } } },
    });

    const results = await Promise.all(groups.map((g) => this.getGroupKpis(g.id)));
    return {
      generatedAt: new Date().toISOString(),
      groups: results,
      grandTotalRevenue30d: results.reduce((s, g) => s + (g?.totalRevenue30d ?? 0), 0),
    };
  }
}
