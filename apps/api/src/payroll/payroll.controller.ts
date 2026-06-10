import {
  Controller, Get, Post, Patch, Param, Body, Req, Res, UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { PayrollService } from './payroll.service';
import { CreateRunDto } from './dto/create-run.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';

@Controller('payroll')
@UseGuards(JwtAuthGuard, RolesGuard)
export class PayrollController {
  constructor(private readonly payrollService: PayrollService) {}

  // ─── HR_MANAGER / ADMIN: create run ──────────────────────────────────────
  @Post('runs')
  @Roles('HR_MANAGER', 'ADMIN')
  createRun(@Req() req: any, @Body() dto: CreateRunDto) {
    return this.payrollService.createRun(
      req.user.tenantId,
      new Date(dto.periodStart),
      new Date(dto.periodEnd),
    );
  }

  // ─── List all runs ─────────────────────────────────────────────────────────
  @Get('runs')
  @Roles('HR_MANAGER', 'MANAGER', 'ADMIN')
  listRuns(@Req() req: any) {
    return this.payrollService.listRuns(req.user.tenantId);
  }

  // ─── Get single run with items ─────────────────────────────────────────────
  @Get('runs/:id')
  @Roles('HR_MANAGER', 'MANAGER', 'ADMIN')
  getRun(@Param('id') id: string) {
    return this.payrollService.getRunWithItems(id);
  }

  // ─── Step 1: Submit for approval ───────────────────────────────────────────
  @Patch('runs/:id/submit')
  @Roles('HR_MANAGER', 'ADMIN')
  submit(@Req() req: any, @Param('id') id: string) {
    return this.payrollService.submitForApproval(req.user.tenantId, id);
  }

  // ─── Step 2: Manager approves ──────────────────────────────────────────────
  @Patch('runs/:id/approve')
  @Roles('MANAGER', 'ADMIN')
  approve(@Req() req: any, @Param('id') id: string) {
    return this.payrollService.approveOne(req.user.tenantId, id, req.user.id);
  }

  // ─── Step 3: Admin disburses via MoMo ─────────────────────────────────────
  @Patch('runs/:id/disburse')
  @Roles('ADMIN')
  disburse(@Req() req: any, @Param('id') id: string) {
    return this.payrollService.disburse(req.user.tenantId, id, req.user.id);
  }

  // ─── Download PDF payslip ──────────────────────────────────────────────────
  @Get('runs/:runId/payslip/:employeeId')
  @Roles('HR_MANAGER', 'MANAGER', 'ADMIN')
  async payslip(
    @Req() req: any,
    @Param('runId') runId: string,
    @Param('employeeId') employeeId: string,
    @Res() res: Response,
  ) {
    await this.payrollService.generatePayslipPdf(
      req.user.tenantId,
      runId,
      employeeId,
      res,
    );
  }
}
