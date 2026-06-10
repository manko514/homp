import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../database/prisma.service';
import { AiService } from '../ai/ai.service';

@Injectable()
export class ForecastService {
  private readonly logger = new Logger(ForecastService.name);

  constructor(
    private prisma: PrismaService,
    private aiService: AiService,
  ) {}

  // ─── Nightly cron — 2 AM every day ───────────────────────────────────────────
  @Cron('0 2 * * *')
  async runNightlyForecast() {
    this.logger.log('Starting nightly forecast run…');
    const tenants = await this.prisma.tenant.findMany({
      select: { id: true, name: true },
    });
    for (const tenant of tenants) {
      try {
        await this.generateForecast(tenant.id);
        this.logger.log(`Forecast generated for: ${tenant.name}`);
      } catch (err) {
        this.logger.error(`Forecast failed for ${tenant.name}`, err);
      }
    }
  }

  // ─── Core: gather 90-day data → Claude → store ───────────────────────────────
  async generateForecast(tenantId: string) {
    const since = new Date();
    since.setDate(since.getDate() - 90);

    const [orders, barSales, reservations] = await Promise.all([
      this.prisma.order.findMany({
        where: { tenantId, createdAt: { gte: since } },
        select: { total: true, createdAt: true, status: true },
      }),
      this.prisma.barSale.findMany({
        where: { tenantId, createdAt: { gte: since } },
        select: { total: true, createdAt: true },
      }),
      this.prisma.reservation.findMany({
        where: { tenantId, checkIn: { gte: since } },
        select: { checkIn: true, totalAmount: true, status: true },
      }),
    ]);

    // ── Aggregate by calendar day ─────────────────────────────────────────────
    type DayData = { revenue: number; orders: number; reservations: number };
    const daily: Record<string, DayData> = {};

    const ensureDay = (d: string) => {
      if (!daily[d]) daily[d] = { revenue: 0, orders: 0, reservations: 0 };
    };

    for (const o of orders) {
      const d = o.createdAt.toISOString().split('T')[0];
      ensureDay(d);
      if (o.status !== 'CANCELLED') {
        daily[d].revenue += Number(o.total);
        daily[d].orders += 1;
      }
    }

    for (const s of barSales) {
      const d = s.createdAt.toISOString().split('T')[0];
      ensureDay(d);
      daily[d].revenue += Number(s.total);
    }

    for (const r of reservations) {
      const d = r.checkIn.toISOString().split('T')[0];
      ensureDay(d);
      if (r.status !== 'CANCELLED') {
        daily[d].revenue += Number(r.totalAmount ?? 0);
        daily[d].reservations += 1;
      }
    }

    const history = Object.entries(daily)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, data]) => ({ date, ...data }));

    // ── Ask Claude for a 30-day forecast ─────────────────────────────────────
    const systemPrompt =
      'You are a hospitality revenue analyst. Return ONLY valid JSON — no markdown, no explanation.';

    const userPrompt = `Analyse this 90-day hotel performance history and produce a 30-day forward forecast.

HISTORY:
${JSON.stringify(history, null, 2)}

Return exactly this JSON structure:
{
  "summary": "2-sentence trend analysis",
  "totalForecastedRevenue": 0.00,
  "avgDailyRevenue": 0.00,
  "trend": "upward|downward|stable",
  "confidence": 0.75,
  "recommendations": ["string", "string", "string"],
  "dailyForecasts": [
    { "date": "YYYY-MM-DD", "revenue": 0.00, "orders": 0, "reservations": 0 }
  ]
}`;

    const raw = await this.aiService.complete(
      tenantId,
      systemPrompt,
      userPrompt,
      'forecast',
    );

    // ── Parse Claude's JSON ───────────────────────────────────────────────────
    let forecastData: any;
    try {
      const match = raw.match(/\{[\s\S]*\}/);
      forecastData = JSON.parse(match ? match[0] : raw);
    } catch {
      forecastData = { raw, parseError: 'Could not parse JSON from Claude' };
    }

    // ── Persist ───────────────────────────────────────────────────────────────
    return this.prisma.aiForecast.create({
      data: {
        tenantId,
        forecastDate: new Date(),
        forecastType: 'revenue_30d',
        dataJson: forecastData,
        confidence: forecastData.confidence ?? 0.70,
      },
    });
  }

  // ─── Queries ──────────────────────────────────────────────────────────────────
  async getLatestForecast(tenantId: string) {
    return this.prisma.aiForecast.findFirst({
      where: { tenantId, forecastType: 'revenue_30d' },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getForecastHistory(tenantId: string) {
    return this.prisma.aiForecast.findMany({
      where: { tenantId },
      orderBy: { createdAt: 'desc' },
      take: 10,
      select: {
        id: true,
        forecastType: true,
        forecastDate: true,
        confidence: true,
        createdAt: true,
      },
    });
  }
}
