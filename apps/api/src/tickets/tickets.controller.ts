import {
  Controller, Post, Get, Patch, Body, Param, Query,
  UseGuards, Req,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TicketsService } from './tickets.service';
import { PurchaseTicketDto } from './dto/purchase-ticket.dto';

@UseGuards(JwtAuthGuard)
@Controller('tickets')
export class TicketsController {
  constructor(private readonly svc: TicketsService) {}

  /** POST /tickets — issue a new ticket */
  @Post()
  purchase(@Req() req: any, @Body() dto: PurchaseTicketDto) {
    return this.svc.purchase(req.user.tenantId, dto);
  }

  /** POST /tickets/validate — scan QR token at gate */
  @Post('validate')
  validate(@Req() req: any, @Body('qrToken') qrToken: string) {
    return this.svc.validate(req.user.tenantId, qrToken);
  }

  /** GET /tickets?status=&type=&date= */
  @Get()
  list(
    @Req() req: any,
    @Query('status') status?: string,
    @Query('type') type?: string,
    @Query('date') date?: string,
  ) {
    return this.svc.listTickets(req.user.tenantId, status, type, date);
  }

  /** GET /tickets/stats */
  @Get('stats')
  stats(@Req() req: any) {
    return this.svc.getStats(req.user.tenantId);
  }

  /** PATCH /tickets/:id/cancel */
  @Patch(':id/cancel')
  cancel(@Req() req: any, @Param('id') id: string) {
    return this.svc.cancel(req.user.tenantId, id);
  }
}
