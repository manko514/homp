import { Controller, Get, Query, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { FinanceService } from './finance.service';

@UseGuards(JwtAuthGuard)
@Controller('finance')
export class FinanceController {
  constructor(private readonly svc: FinanceService) {}

  /** GET /finance/pl?month=2026-06 */
  @Get('pl')
  getMonthlyPL(@Req() req: any, @Query('month') month?: string) {
    const m = month ?? new Date().toISOString().slice(0, 7);
    return this.svc.getMonthlyPL(req.user.tenantId, m);
  }

  /** GET /finance/trend?month=2026-06 — daily breakdown */
  @Get('trend')
  getDailyTrend(@Req() req: any, @Query('month') month?: string) {
    const m = month ?? new Date().toISOString().slice(0, 7);
    return this.svc.getDailyTrend(req.user.tenantId, m);
  }

  /** GET /finance/comparison — current vs last month */
  @Get('comparison')
  getComparison(@Req() req: any) {
    return this.svc.getComparison(req.user.tenantId);
  }
}
