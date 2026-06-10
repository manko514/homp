import { Controller, Get, Delete, Param, Req, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { GuestService } from './guest.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

@Controller('admin/guests')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('MANAGER', 'ADMIN')
export class AdminGuestController {
  constructor(private readonly guestService: GuestService) {}

  /** GET /admin/guests/:id/export — ZIP of all personal data for this guest (GDPR Art. 15/20) */
  @Get(':id/export')
  async exportGuestData(@Param('id') id: string, @Res() res: Response) {
    return this.guestService.exportGuestData(id, res);
  }

  /** DELETE /admin/guests/:id — anonymise PII (GDPR Art. 17 right to erasure) */
  @Delete(':id')
  anonymiseGuest(@Param('id') id: string) {
    return this.guestService.anonymiseGuest(id);
  }
}
