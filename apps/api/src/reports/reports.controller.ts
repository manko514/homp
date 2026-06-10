import {
  Controller,
  Get,
  Query,
  UseGuards,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Role, User } from '@prisma/client';
import { ReportsService } from './reports.service';

@Controller('reports')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Get('daily-revenue')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.ACCOUNTANT)
  getDailyRevenue(
    @CurrentUser() user: User,
    @Query('date') date?: string,
  ) {
    return this.reportsService.getDailyRevenue(
      user.tenantId,
      date ? new Date(date) : new Date(),
    );
  }

  @Get('daily-revenue/pdf')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.ACCOUNTANT)
  async getDailyRevenuePdf(
    @CurrentUser() user: User,
    @Query('date') date: string | undefined,
    @Res() res: Response,
  ) {
    await this.reportsService.streamDailyRevenuePdf(
      user.tenantId,
      date ? new Date(date) : new Date(),
      res,
    );
  }

  @Get('weekly-revenue')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.ACCOUNTANT)
  getWeeklyRevenue(
    @CurrentUser() user: User,
    @Query('days') days?: string,
  ) {
    return this.reportsService.getWeeklyRevenue(user.tenantId, days ? parseInt(days) : 7);
  }

  @Get('stock')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.BARTENDER)
  getStockReport(@CurrentUser() user: User) {
    return this.reportsService.getStockReport(user.tenantId);
  }

  @Get('executive-summary')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getExecutiveSummary(@CurrentUser() user: User) {
    return this.reportsService.getExecutiveSummary(user.tenantId);
  }

  @Get('stock/pdf')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN, Role.BARTENDER)
  async getStockReportPdf(
    @CurrentUser() user: User,
    @Res() res: Response,
  ) {
    await this.reportsService.streamStockReportPdf(user.tenantId, res);
  }

  @Get('analytics/cohort')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getCohortAnalysis(@CurrentUser() user: User) {
    return this.reportsService.getCohortAnalysis(user.tenantId);
  }

  @Get('analytics/guest-ltv')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getGuestLtv(
    @CurrentUser() user: User,
    @Query('limit') limit?: string,
  ) {
    return this.reportsService.getGuestLtv(user.tenantId, limit ? parseInt(limit) : 50);
  }

  @Get('analytics/channel-attribution')
  @Roles(Role.MANAGER, Role.DIRECTOR, Role.ADMIN)
  getChannelAttribution(@CurrentUser() user: User) {
    return this.reportsService.getChannelAttribution(user.tenantId);
  }
}
