import { Controller, Get, Query, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuditService } from './audit.service';

@UseGuards(JwtAuthGuard)
@Controller('audit')
export class AuditController {
  constructor(private readonly svc: AuditService) {}

  /** GET /audit/logs?resourceType=&eventType=&limit= */
  @Get('logs')
  getLogs(
    @Req() req: any,
    @Query('resourceType') resourceType?: string,
    @Query('eventType') eventType?: string,
    @Query('actorId') actorId?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.getLogs(req.user.tenantId, {
      resourceType,
      eventType,
      actorId,
      from,
      to,
      limit: limit ? Number(limit) : 100,
    });
  }

  /** GET /audit/stats */
  @Get('stats')
  getStats(@Req() req: any) {
    return this.svc.getStats(req.user.tenantId);
  }
}
