import { Controller, Post, Body, Req, UseGuards } from '@nestjs/common';
import { NotificationService } from './notification.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { IsString, IsOptional } from 'class-validator';

class SaveTokenDto {
  @IsString()
  token: string;
}

class CampaignDto {
  @IsString()
  title: string;

  @IsString()
  body: string;

  @IsOptional()
  @IsString()
  role?: string; // default: GUEST
}

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationController {
  constructor(private readonly notificationService: NotificationService) {}

  @Post('token')
  saveToken(@Req() req: any, @Body() dto: SaveTokenDto) {
    return this.notificationService.saveFcmToken(req.user.id, dto.token);
  }

  /** POST /notifications/campaign — admin/manager sends a promotional push
   *  to all guests (or a specific role) in their tenant. */
  @Post('campaign')
  @UseGuards(RolesGuard)
  @Roles('ADMIN', 'MANAGER')
  async sendCampaign(@Req() req: any, @Body() dto: CampaignDto) {
    const tenantId = req.user.tenantId as string;
    const role     = dto.role ?? 'GUEST';
    await this.notificationService.sendToRole(
      tenantId,
      role,
      dto.title,
      dto.body,
      { type: 'offer' },
    );
    return { ok: true, message: `Campaign sent to all ${role}s in tenant` };
  }
}
