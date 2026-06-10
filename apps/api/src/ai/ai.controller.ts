import { Controller, Post, Get, Body, Req, Res, Query, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { AiService } from './ai.service';
import { ChatDto } from './dto/chat.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  // ─── Streaming Chat — requires auth (staff/admin) or guest token ──────────────
  // No @UseGuards here — guest app can also call this via a simpler check
  @Post('chat')
  async chat(
    @Body() dto: ChatDto,
    @Req() req: any,
    @Res() res: Response,
  ) {
    const tenantId = req.user?.tenantId ?? req.body?.tenantId;
    const userId = req.user?.id ?? null;
    const userRole = req.user?.role ?? undefined;
    if (!tenantId) { res.status(400).json({ message: 'tenantId is required' }); return; }
    await this.aiService.streamChat(tenantId, userId, dto.messages, res, dto.model, userRole);
  }

  /** POST /ai/concierge — guest-facing concierge (always uses hotel guest context) */
  @Post('concierge')
  async concierge(
    @Body() dto: ChatDto,
    @Req() req: any,
    @Res() res: Response,
  ) {
    const tenantId = req.user?.tenantId ?? req.body?.tenantId;
    const userId = req.user?.id ?? null;
    if (!tenantId) { res.status(400).json({ message: 'tenantId is required' }); return; }
    await this.aiService.streamChat(tenantId, userId, dto.messages, res, dto.model);
  }

  // ─── Usage Stats — managers/admins only ───────────────────────────────────────
  @Get('usage')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('MANAGER', 'ADMIN')
  getUsage(
    @Req() req: any,
    @Query('days') days?: string,
  ) {
    return this.aiService.getUsageStats(req.user.tenantId, days ? parseInt(days) : 30);
  }
}
