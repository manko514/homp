import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Anthropic from '@anthropic-ai/sdk';
import { Response } from 'express';
import { PrismaService } from '../database/prisma.service';
import { NotificationService } from '../notifications/notification.service';

// Pricing per million tokens (claude-sonnet-4-5 as of 2025)
const PRICING: Record<string, { input: number; output: number }> = {
  'claude-sonnet-4-5':     { input: 3.0,  output: 15.0 },
  'claude-haiku-3-5':      { input: 0.8,  output: 4.0  },
  'claude-opus-4':         { input: 15.0, output: 75.0 },
  'claude-sonnet-4-6':     { input: 3.0,  output: 15.0 },
};
const DEFAULT_MODEL = 'claude-sonnet-4-5';

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);
  private client: Anthropic;

  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
    private notifications: NotificationService,
  ) {
    this.client = new Anthropic({
      apiKey: this.config.get<string>('ANTHROPIC_API_KEY'),
    });
  }

  // ─── Hotel Context Builder ────────────────────────────────────────────────────

  private async buildHotelContext(tenantId: string, userId?: string | null): Promise<string> {
    // Base queries run unconditionally
    const baseQueries = Promise.all([
      this.prisma.tenant.findUnique({ where: { id: tenantId }, select: { name: true } }),
      this.prisma.room.count({ where: { tenantId } }),
      this.prisma.menuItem.findMany({
        where: { tenantId, available: true },
        select: { name: true, category: true, price: true },
        take: 30,
      }),
      this.prisma.drink.findMany({
        where: { tenantId, available: true },
        select: { name: true, category: true, price: true },
        take: 20,
      }),
    ]);

    // Guest-specific queries — only when logged in
    const guestQueries = userId
      ? Promise.all([
          this.prisma.user.findUnique({
            where: { id: userId },
            select: { name: true },
          }),
          this.prisma.reservation.findFirst({
            where: { guestId: userId, tenantId, status: { in: ['CONFIRMED', 'CHECKED_IN'] as any } },
            select: {
              id: true,
              status: true,
              checkIn: true,
              checkOut: true,
              room: { select: { roomNumber: true, type: true, floor: true } },
            },
            orderBy: { checkIn: 'asc' },
          }),
        ])
      : Promise.resolve([null, null]);

    const [[tenant, roomCount, menuItems, drinks], [guestProfile, activeBooking]] =
      await Promise.all([baseQueries, guestQueries]);

    const menuSummary = (menuItems as any[])
      .map((m) => `${m.name} (${m.category}) - $${Number(m.price).toFixed(2)}`)
      .join('; ');
    const drinkSummary = (drinks as any[])
      .map((d) => `${d.name} (${d.category}) - $${Number(d.price).toFixed(2)}`)
      .join('; ');

    // Today's specials = first 3 available menu items (rotate by day-of-week for variety)
    const dow = new Date().getDay(); // 0-6
    const specialStart = (dow * 3) % Math.max((menuItems as any[]).length, 1);
    const specials = (menuItems as any[])
      .slice(specialStart, specialStart + 3)
      .map((m) => `${m.name} - $${Number(m.price).toFixed(2)}`)
      .join(', ') || 'Ask staff for today\'s specials';

    // Guest section
    const guestName = (guestProfile as any)?.name ?? null;
    const guestSection = guestName
      ? `CURRENT GUEST: ${guestName} (personalise your greeting)`
      : `CURRENT GUEST: Anonymous (not logged in)`;

    // Active reservation
    const booking = activeBooking as any;
    const bookingSection = booking
      ? `ACTIVE RESERVATION:
  - Room: ${booking.room?.roomNumber ?? '—'} (${booking.room?.type ?? '—'}), Floor ${booking.room?.floor ?? '—'}
  - Status: ${booking.status}
  - Check-in:  ${new Date(booking.checkIn).toDateString()}
  - Check-out: ${new Date(booking.checkOut).toDateString()}`
      : `ACTIVE RESERVATION: None`;

    return `You are the AI concierge for ${(tenant as any)?.name ?? 'this hotel'}.
Be warm, professional, and concise. Address the guest by name if known.

${guestSection}
${bookingSection}

HOTEL INFO:
- ${roomCount} rooms total
- Check-in: 3:00 PM | Check-out: 12:00 PM
- Pool: 7 AM – 10 PM | Gym: 24 hours | Spa: 9 AM – 8 PM | Business centre: 8 AM – 8 PM
- Restaurant: Breakfast 7–10 AM, Lunch 12–3 PM, Dinner 6–10 PM
- Room service: Available 24 hours
- Restaurant menu: ${menuSummary || 'Ask staff for the menu'}
- Bar & drinks: ${drinkSummary || 'Ask staff for available drinks'}
- TODAY'S SPECIALS: ${specials}

CAPABILITIES:
- Answer any hotel questions (amenities, hours, directions, local attractions)
- Help guests browse the menu and confirm food/drink orders
- Assist with room service requests
- Provide check-in, check-out, and reservation information

ACTION INTENTS:
When a guest explicitly asks you to place an order OR book a table, output a JSON block (triple-backtick tagged "json") with the intent, followed by a brief friendly confirmation in plain text.

Order intent format:
\`\`\`json
{"intent":"place_order","items":[{"name":"Club Sandwich","qty":1},{"name":"Orange Juice","qty":2}],"room":"204","isRoomService":true,"notes":""}
\`\`\`

Table booking intent format:
\`\`\`json
{"intent":"book_table","partySize":2,"time":"19:00","date":"today","notes":"window seat preferred"}
\`\`\`

RULES for intents:
- Only emit a JSON block when you have enough information (what the guest wants AND where to deliver / when).
- If you need clarification (room number, party size, time), ASK FIRST — do not guess.
- Never invent menu items — only use items listed in the HOTEL INFO section above.
- Keep the human-readable reply below the JSON block warm and brief (1-2 sentences).`;
  }

  // ─── Management Assistant Context (spec template) ────────────────────────────

  private async buildManagementContext(
    tenantId: string,
    userRole: string,
  ): Promise<string> {
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { name: true },
    });
    const currency = this.config.get<string>('HOTEL_CURRENCY') ?? 'USD';
    const today = new Date().toDateString();
    return `You are HOMP AI, the management assistant for ${tenant?.name ?? 'this property'}. Today is ${today}. Currency: ${currency}. The user is a ${userRole}. Answer concisely using the operational data provided. Return JSON when asked for structured data.`;
  }

  // ─── Streaming Chat (SSE) ─────────────────────────────────────────────────────

  async streamChat(
    tenantId: string,
    userId: string | null,
    messages: Array<{ role: 'user' | 'assistant'; content: string }>,
    res: Response,
    model = DEFAULT_MODEL,
    userRole?: string,
  ) {
    const startMs = Date.now();
    const isStaffRole = userRole && ['MANAGER', 'ADMIN', 'DIRECTOR', 'HR_MANAGER', 'ACCOUNTANT'].includes(userRole);
    const systemPrompt = isStaffRole
      ? await this.buildManagementContext(tenantId, userRole!)
      : await this.buildHotelContext(tenantId, userId);

    // Set SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders();

    let inputTokens = 0;
    let outputTokens = 0;
    let fullText = '';

    try {
      const stream = await this.client.messages.stream({
        model,
        max_tokens: 1024,
        system: systemPrompt,
        messages,
      });

      for await (const chunk of stream) {
        if (chunk.type === 'content_block_delta' && chunk.delta.type === 'text_delta') {
          const text = chunk.delta.text;
          fullText += text;
          res.write(`data: ${JSON.stringify({ type: 'text', text })}\n\n`);
        }
        if (chunk.type === 'message_delta' && chunk.usage) {
          outputTokens = chunk.usage.output_tokens;
        }
        if (chunk.type === 'message_start' && chunk.message.usage) {
          inputTokens = chunk.message.usage.input_tokens;
        }
      }

      // Send done event
      res.write(`data: ${JSON.stringify({ type: 'done', inputTokens, outputTokens })}\n\n`);
      res.end();

      // Push notification: concierge reply (only when the app is backgrounded)
      if (userId && fullText) {
        const preview = fullText.length > 100 ? fullText.substring(0, 97) + '...' : fullText;
        this.notifications.sendToUser(
          userId,
          '💬 Your AI Concierge Has Replied',
          preview,
          { type: 'concierge' },
        ).catch(() => {});
      }

    } catch (err: any) {
      this.logger.error('Anthropic stream error', err);
      res.write(`data: ${JSON.stringify({ type: 'error', message: err.message ?? 'AI error' })}\n\n`);
      res.end();
    } finally {
      // Log usage
      const durationMs = Date.now() - startMs;
      await this.logUsage(tenantId, userId, 'chat', model, inputTokens, outputTokens, durationMs);
    }
  }

  // ─── Single completion (for crons / background jobs) ─────────────────────────

  async complete(
    tenantId: string,
    systemPrompt: string,
    userPrompt: string,
    feature: string,
    model = DEFAULT_MODEL,
  ): Promise<string> {
    const startMs = Date.now();

    const response = await this.client.messages.create({
      model,
      max_tokens: 4096,
      system: systemPrompt,
      messages: [{ role: 'user', content: userPrompt }],
    });

    const text = response.content
      .filter((b) => b.type === 'text')
      .map((b) => (b as any).text)
      .join('');

    const durationMs = Date.now() - startMs;
    await this.logUsage(
      tenantId,
      null,
      feature,
      model,
      response.usage.input_tokens,
      response.usage.output_tokens,
      durationMs,
    );

    return text;
  }

  // ─── Usage Logging ────────────────────────────────────────────────────────────

  private async logUsage(
    tenantId: string,
    userId: string | null,
    feature: string,
    model: string,
    inputTokens: number,
    outputTokens: number,
    durationMs: number,
  ) {
    try {
      const pricing = PRICING[model] ?? PRICING[DEFAULT_MODEL];
      const costUsd =
        (inputTokens * pricing.input + outputTokens * pricing.output) / 1_000_000;

      await this.prisma.aiUsageLog.create({
        data: {
          tenantId,
          userId: userId ?? null,
          feature,
          model,
          inputTokens,
          outputTokens,
          costUsd,
          durationMs,
        },
      });
    } catch (err) {
      this.logger.warn('Failed to log AI usage', err);
    }
  }

  // ─── Usage Stats ──────────────────────────────────────────────────────────────

  async getUsageStats(tenantId: string, days = 30) {
    const since = new Date();
    since.setDate(since.getDate() - days);

    const [logs, totals] = await Promise.all([
      this.prisma.aiUsageLog.findMany({
        where: { tenantId, createdAt: { gte: since } },
        orderBy: { createdAt: 'desc' },
        take: 100,
        select: {
          feature: true,
          model: true,
          inputTokens: true,
          outputTokens: true,
          costUsd: true,
          durationMs: true,
          createdAt: true,
        },
      }),
      this.prisma.aiUsageLog.aggregate({
        where: { tenantId, createdAt: { gte: since } },
        _sum: { inputTokens: true, outputTokens: true, costUsd: true },
        _count: true,
        _avg: { durationMs: true },
      }),
    ]);

    return {
      period: `${days} days`,
      totalRequests: totals._count,
      totalInputTokens: totals._sum.inputTokens ?? 0,
      totalOutputTokens: totals._sum.outputTokens ?? 0,
      totalCostUsd: Number(totals._sum.costUsd ?? 0).toFixed(4),
      avgDurationMs: Math.round(totals._avg.durationMs ?? 0),
      logs,
    };
  }
}
