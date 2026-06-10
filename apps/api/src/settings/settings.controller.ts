import { Controller, Get, Patch, Body, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '@prisma/client';
import { SettingsService } from './settings.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('settings')
export class SettingsController {
  constructor(private readonly svc: SettingsService) {}

  /** GET /settings — current tenant settings */
  @Get()
  getSettings(@Req() req: any) {
    return this.svc.getSettings(req.user.tenantId);
  }

  /** PATCH /settings — update branding */
  @Patch()
  @Roles(Role.ADMIN, Role.MANAGER)
  updateSettings(@Req() req: any, @Body() body: { name?: string; primaryColor?: string; subdomain?: string; logoUrl?: string }) {
    return this.svc.updateSettings(req.user.tenantId, body);
  }
}
