import { Controller, Post, Get, Req, UseGuards } from '@nestjs/common';
import { ForecastService } from './forecast.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

@Controller('forecast')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('MANAGER', 'ADMIN')
export class ForecastController {
  constructor(private readonly forecastService: ForecastService) {}

  /** Manually trigger a forecast run (no need to wait for 2 AM cron) */
  @Post('run')
  runForecast(@Req() req: any) {
    return this.forecastService.generateForecast(req.user.tenantId);
  }

  /** Latest stored forecast */
  @Get('latest')
  getLatest(@Req() req: any) {
    return this.forecastService.getLatestForecast(req.user.tenantId);
  }

  /** Last 10 forecast runs */
  @Get('history')
  getHistory(@Req() req: any) {
    return this.forecastService.getForecastHistory(req.user.tenantId);
  }
}
