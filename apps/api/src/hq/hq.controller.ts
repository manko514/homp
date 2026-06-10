import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { HqService } from './hq.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

@Controller('hq')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN', 'GROUP_GM', 'GROUP_FINANCE')
export class HqController {
  constructor(private readonly hqService: HqService) {}

  @Get('groups')
  listGroups() {
    return this.hqService.listGroups();
  }

  @Get('groups/:id/kpis')
  getGroupKpis(@Param('id') id: string) {
    return this.hqService.getGroupKpis(id);
  }

  @Get('consolidated')
  getConsolidatedPL() {
    return this.hqService.getConsolidatedPL();
  }
}
