import { Controller, Post, Get, Patch, Param, Query, Req, UseGuards } from '@nestjs/common';
import { AnomalyService } from './anomaly.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

@Controller('anomaly')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('MANAGER', 'ADMIN')
export class AnomalyController {
  constructor(private readonly anomalyService: AnomalyService) {}

  /** Manually trigger analysis for today's shift */
  @Post('analyze')
  analyze(@Req() req: any) {
    return this.anomalyService.analyzeShift(req.user.tenantId);
  }

  /** List open (or all) alerts */
  @Get('alerts')
  getAlerts(@Req() req: any, @Query('resolved') resolved?: string) {
    return this.anomalyService.getAlerts(req.user.tenantId, resolved === 'true');
  }

  /** 30-day stats summary */
  @Get('stats')
  getStats(@Req() req: any) {
    return this.anomalyService.getStats(req.user.tenantId);
  }

  /** Mark an alert as resolved */
  @Patch('alerts/:id/resolve')
  resolve(@Req() req: any, @Param('id') id: string) {
    return this.anomalyService.resolveAlert(req.user.tenantId, id);
  }
}
