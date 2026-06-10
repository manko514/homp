import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../database/prisma.service';
import { AiService } from '../ai/ai.service';
import { NotificationService } from '../notifications/notification.service';

@Injectable()
export class AnomalyService {
  private readonly logger = new Logger(AnomalyService.name);

  constructor(
    private prisma: PrismaService,
    private aiService: AiService,
    private notifications: NotificationService,
  ) {}

  // ─── Post-shift cron: runs at 11 PM every day ─────────────────────────────
  @Cron('0 23 * * *')
  async runNightlyAnalysis() {
    this.logger.log('Running nightly anomaly analysis…');
    const tenants = await this.prisma.tenant.findMany({ select: { id: true, name: true } });
    for (const tenant of tenants) {
      try {
        await this.analyzeShift(tenant.id);
        this.logger.log(`Anomaly scan complete for: ${tenant.name}`);
      } catch (err) {
        this.logger.error(`Anomaly scan failed for ${tenant.name}`, err);
      }
    }
  }

  // ─── Core: gather today's data → Claude → store alerts ────────────────────
  async analyzeShift(tenantId: string, date?: Date) {
    const shiftDate = date ?? new Date();
    const dayStart = new Date(shiftDate);
    dayStart.setHours(0, 0, 0, 0);
    const dayEnd = new Date(shiftDate);
    dayEnd.setHours(23, 59, 59, 999);

    // 30-day baseline window
    const baselineStart = new Date(dayStart);
    baselineStart.setDate(baselineStart.getDate() - 30);

    const [todayOrders, todayBarSales, baselineOrders, baselineBarSales] =
      await Promise.all([
        this.prisma.order.findMany({
          where: { tenantId, createdAt: { gte: dayStart, lte: dayEnd } },
          select: { id: true, total: true, status: true, createdAt: true },
        }),

        this.prisma.barSale.findMany({
          where: { tenantId, createdAt: { gte: dayStart, lte: dayEnd } },
          select: { id: true, total: true, qty: true, createdAt: true },
        }),

        this.prisma.order.aggregate({
          where: {
            tenantId,
            createdAt: { gte: baselineStart, lt: dayStart },
            status: { not: 'CANCELLED' },
          },
          _avg: { total: true },
          _count: true,
          _sum: { total: true },
        }),

        this.prisma.barSale.aggregate({
          where: { tenantId, createdAt: { gte: baselineStart, lt: dayStart } },
          _avg: { total: true },
          _count: true,
          _sum: { total: true },
        }),
      ]);

    // ── Compute today's metrics ───────────────────────────────────────────────
    const cancelledOrders = todayOrders.filter((o) => o.status === 'CANCELLED').length;
    const completedOrders = todayOrders.filter((o) => o.status !== 'CANCELLED');
    const todayOrderRevenue = completedOrders.reduce((s, o) => s + Number(o.total), 0);

    const avgHistoricalOrderRevenue =
      baselineOrders._count > 0
        ? Number(baselineOrders._sum.total ?? 0) / 30
        : 0;

    const todayBarRevenue = todayBarSales.reduce((s, sale) => s + Number(sale.total), 0);
    const avgHistoricalBarRevenue =
      baselineBarSales._count > 0
        ? Number(baselineBarSales._sum.total ?? 0) / 30
        : 0;

    const shiftSummary = {
      date: shiftDate.toISOString().split('T')[0],
      orders: {
        total: todayOrders.length,
        cancelled: cancelledOrders,
        cancellationRate: todayOrders.length
          ? Math.round((cancelledOrders / todayOrders.length) * 100)
          : 0,
        revenue: todayOrderRevenue.toFixed(2),
        avgHistoricalDailyRevenue: avgHistoricalOrderRevenue.toFixed(2),
        variancePercent: avgHistoricalOrderRevenue
          ? Math.round(
              ((todayOrderRevenue - avgHistoricalOrderRevenue) / avgHistoricalOrderRevenue) * 100,
            )
          : 0,
      },
      barSales: {
        total: todayBarSales.length,
        revenue: todayBarRevenue.toFixed(2),
        avgHistoricalDailyRevenue: avgHistoricalBarRevenue.toFixed(2),
        variancePercent: avgHistoricalBarRevenue
          ? Math.round(
              ((todayBarRevenue - avgHistoricalBarRevenue) / avgHistoricalBarRevenue) * 100,
            )
          : 0,
      },
    };

    // ── Ask Claude to flag anomalies ──────────────────────────────────────────
    const systemPrompt =
      'You are a hotel fraud and anomaly detection analyst. Return ONLY valid JSON — no markdown, no explanation.';

    const userPrompt = `Analyse this hotel shift data and identify any fraud indicators or operational anomalies.

SHIFT DATA:
${JSON.stringify(shiftSummary, null, 2)}

Flag any anomalies you find. If nothing is suspicious, return an empty anomalies array.
Return exactly this JSON:
{
  "riskScore": 0,
  "overallAssessment": "1-sentence verdict",
  "anomalies": [
    {
      "severity": "LOW|MEDIUM|HIGH|CRITICAL",
      "category": "bar|restaurant|hotel|staff",
      "title": "short title",
      "description": "what was detected and why it is suspicious"
    }
  ]
}`;

    const raw = await this.aiService.complete(tenantId, systemPrompt, userPrompt, 'fraud');

    let analysis: { riskScore: number; overallAssessment: string; anomalies: any[] };
    try {
      const match = raw.match(/\{[\s\S]*\}/);
      analysis = JSON.parse(match ? match[0] : raw);
    } catch {
      analysis = { riskScore: 0, overallAssessment: 'Parse error', anomalies: [] };
    }

    // ── Persist each flagged anomaly ──────────────────────────────────────────
    const alerts: any[] = [];
    for (const anomaly of analysis.anomalies ?? []) {
      const alert = await this.prisma.anomalyAlert.create({
        data: {
          tenantId,
          shiftDate: dayStart,
          severity: anomaly.severity ?? 'LOW',
          category: anomaly.category ?? 'restaurant',
          title: anomaly.title ?? 'Unknown anomaly',
          description: anomaly.description ?? '',
          dataJson: { ...shiftSummary, riskScore: analysis.riskScore },
        },
      });
      alerts.push(alert);
    }

    // ── Notify managers for HIGH / CRITICAL alerts ────────────────────────────
    const highPriorityAlerts = alerts.filter((a) =>
      a.severity === 'HIGH' || a.severity === 'CRITICAL',
    );
    if (highPriorityAlerts.length > 0) {
      const managers = await this.prisma.user.findMany({
        where: { tenantId, role: { in: ['MANAGER', 'ADMIN'] as any }, fcmToken: { not: null } },
        select: { id: true },
      });
      for (const mgr of managers) {
        await this.notifications
          .sendToUser(
            mgr.id,
            `⚠️ ${highPriorityAlerts.length} anomaly alert${highPriorityAlerts.length > 1 ? 's' : ''} flagged`,
            highPriorityAlerts[0].title,
            { type: 'anomaly', count: String(highPriorityAlerts.length) },
          )
          .catch(() => {});
      }
    }

    return {
      riskScore: analysis.riskScore,
      overallAssessment: analysis.overallAssessment,
      alertsCreated: alerts.length,
      alerts,
    };
  }

  // ─── Queries ──────────────────────────────────────────────────────────────
  async getAlerts(tenantId: string, includeResolved = false) {
    return this.prisma.anomalyAlert.findMany({
      where: {
        tenantId,
        ...(includeResolved ? {} : { resolved: false }),
      },
      orderBy: [{ severity: 'desc' }, { createdAt: 'desc' }],
      take: 50,
    });
  }

  async resolveAlert(tenantId: string, alertId: string) {
    return this.prisma.anomalyAlert.update({
      where: { id: alertId, tenantId },
      data: { resolved: true, resolvedAt: new Date() },
    });
  }

  async getStats(tenantId: string) {
    const since = new Date();
    since.setDate(since.getDate() - 30);

    const [openAlerts, bySeverity] = await Promise.all([
      this.prisma.anomalyAlert.count({ where: { tenantId, resolved: false } }),
      this.prisma.anomalyAlert.groupBy({
        by: ['severity'],
        where: { tenantId, createdAt: { gte: since } },
        _count: true,
      }),
    ]);

    return { openAlerts, bySeverity };
  }
}
