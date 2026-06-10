import { Injectable, Logger, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { AuditService } from '../audit/audit.service';
import { PayrollStatus } from '@prisma/client';
import * as PDFDocument from 'pdfkit';
import { Response } from 'express';

// Ghana tax brackets (simplified PAYE)
const TAX_RATE = 0.05;       // 5% income tax
const PENSION_RATE = 0.055;  // 5.5% SSNIT employee contribution
const NHIL_RATE = 0.025;     // 2.5% health levy

@Injectable()
export class PayrollService {
  private readonly logger = new Logger(PayrollService.name);

  constructor(private prisma: PrismaService, private audit: AuditService) {}

  // ─── Create a new payroll run (DRAFT) ────────────────────────────────────
  async createRun(tenantId: string, periodStart: Date, periodEnd: Date) {
    const employees = await this.prisma.employee.findMany({
      where: { tenantId },
      include: {
        user: { select: { id: true, name: true, email: true, role: true } },
        attendance: {
          where: {
            clockIn: { gte: periodStart, lte: periodEnd },
            clockOut: { not: null },
          },
          select: { clockIn: true, clockOut: true },
        },
      },
    });

    if (employees.length === 0) {
      throw new BadRequestException('No employees found for this tenant');
    }

    // Create the run
    const run = await this.prisma.payrollRun.create({
      data: { tenantId, periodStart, periodEnd, status: PayrollStatus.DRAFT },
    });

    // Calculate and create items for each employee
    for (const emp of employees) {
      const basic = Number(emp.basicSalary);
      const rate = Number(emp.overtimeRate) || basic / 160; // hourly rate from monthly

      // Calculate overtime hours (hours > 8/day = overtime)
      let overtimePay = 0;
      for (const shift of emp.attendance) {
        if (!shift.clockOut) continue;
        const hours = (shift.clockOut.getTime() - shift.clockIn.getTime()) / 3_600_000;
        const ot = Math.max(0, hours - 8);
        overtimePay += ot * rate * 1.5;
      }
      overtimePay = Math.round(overtimePay * 100) / 100;

      const gross = basic + overtimePay;
      const tax = Math.round(gross * TAX_RATE * 100) / 100;
      const pension = Math.round(gross * PENSION_RATE * 100) / 100;
      const nhil = Math.round(gross * NHIL_RATE * 100) / 100;
      const deductions = tax + pension + nhil;
      const net = Math.round((gross - deductions) * 100) / 100;

      await this.prisma.payrollItem.create({
        data: {
          payrollRunId: run.id,
          employeeId: emp.id,
          basic,
          overtime: overtimePay,
          deductions,
          net,
        },
      });
    }

    await this.audit.log({ tenantId, actorId: tenantId, eventType: 'CREATE', resourceType: 'payroll_run', resourceId: run.id, diffJson: { periodStart: periodStart.toISOString(), periodEnd: periodEnd.toISOString(), employees: employees.length } });
    return this.getRunWithItems(run.id);
  }

  // ─── Step 1: HR submits for manager approval ──────────────────────────────
  async submitForApproval(tenantId: string, runId: string) {
    const run = await this.findRun(tenantId, runId);
    if (run.status !== PayrollStatus.DRAFT) {
      throw new BadRequestException('Only DRAFT runs can be submitted');
    }
    return this.prisma.payrollRun.update({
      where: { id: runId },
      data: { status: PayrollStatus.PENDING_APPROVAL },
    });
  }

  // ─── Step 2: Manager approves ─────────────────────────────────────────────
  async approveOne(tenantId: string, runId: string, userId: string) {
    const run = await this.findRun(tenantId, runId);
    if (run.status !== PayrollStatus.PENDING_APPROVAL) {
      throw new BadRequestException('Run must be PENDING_APPROVAL');
    }
    return this.prisma.payrollRun.update({
      where: { id: runId },
      data: { status: PayrollStatus.APPROVED, approvedBy: userId },
    });
  }

  // ─── Step 3: Admin disburses (MTN MoMo simulation) ───────────────────────
  async disburse(tenantId: string, runId: string, userId: string) {
    const run = await this.findRun(tenantId, runId);
    if (run.status !== PayrollStatus.APPROVED) {
      throw new BadRequestException('Run must be APPROVED before disbursement');
    }

    // Process each payroll item — simulate MTN MoMo API call
    const results: { employeeId: string; name: string; net: number; txId: string; status: string }[] = [];

    for (const item of run.payrollItems) {
      const emp = await this.prisma.employee.findUnique({
        where: { id: item.employeeId },
        include: { user: { select: { name: true } } },
      });

      // Simulate MTN MoMo disbursement
      const txId = await this.simulateMoMoDisbursement(
        emp?.momoNumber ?? '024XXXXXXX',
        Number(item.net),
        `Payroll ${run.periodStart.toISOString().slice(0, 7)}`,
      );

      await this.prisma.payrollItem.update({
        where: { id: item.id },
        data: { txId },
      });

      results.push({
        employeeId: item.employeeId,
        name: emp?.user.name ?? 'Unknown',
        net: Number(item.net),
        txId,
        status: 'SENT',
      });
    }

    await this.prisma.payrollRun.update({
      where: { id: runId },
      data: {
        status: PayrollStatus.DISBURSED,
        approvedTwoBy: userId,
        disbursedAt: new Date(),
      },
    });

    await this.audit.log({ tenantId, actorId: userId, eventType: 'DISBURSE', resourceType: 'payroll_run', resourceId: runId, diffJson: { disbursed: results.length, totalNet: results.reduce((s, r) => s + r.net, 0) } });
    return { runId, disbursed: results.length, results };
  }

  // ─── MTN MoMo simulation (replace with real API in production) ───────────
  private async simulateMoMoDisbursement(
    phone: string,
    amount: number,
    note: string,
  ): Promise<string> {
    // In production: call MTN MoMo Disbursements API
    // POST https://sandbox.momodeveloper.mtn.com/disbursement/v1_0/transfer
    this.logger.log(`[MoMo] Sending GHS ${amount} to ${phone} — ${note}`);
    const txId = `MOMO-${Date.now()}-${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
    return txId;
  }

  // ─── PDF Payslip ──────────────────────────────────────────────────────────
  async generatePayslipPdf(
    tenantId: string,
    runId: string,
    employeeId: string,
    res: Response,
  ) {
    const run = await this.findRun(tenantId, runId);
    const item = run.payrollItems.find((i) => i.employeeId === employeeId);
    if (!item) throw new NotFoundException('Payroll item not found');

    const emp = await this.prisma.employee.findUnique({
      where: { id: employeeId },
      include: { user: { select: { name: true, email: true, role: true } } },
    });
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { name: true },
    });

    const gross = Number(item.basic) + Number(item.overtime);
    const tax = Math.round(gross * TAX_RATE * 100) / 100;
    const pension = Math.round(gross * PENSION_RATE * 100) / 100;
    const nhil = Math.round(gross * NHIL_RATE * 100) / 100;

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="payslip-${emp?.user.name?.replace(/\s+/g, '-')}-${run.periodStart.toISOString().slice(0, 7)}.pdf"`,
    );

    const doc = new PDFDocument({ margin: 50, size: 'A4' });
    doc.pipe(res);

    // Header
    doc.fontSize(22).font('Helvetica-Bold').text(tenant?.name ?? 'Hotel', 50, 50);
    doc.fontSize(10).font('Helvetica').fillColor('#666').text('PAYSLIP', 50, 78);
    doc.fillColor('#000');

    // Period bar
    doc.rect(50, 95, 495, 28).fill('#1E2A3A');
    doc.fillColor('#fff').fontSize(10).font('Helvetica-Bold')
      .text(
        `Pay Period: ${run.periodStart.toLocaleDateString()} – ${run.periodEnd.toLocaleDateString()}   Status: ${run.status}`,
        58, 103,
      );
    doc.fillColor('#000');

    // Employee details
    doc.moveDown(2);
    const y = 145;
    doc.fontSize(11).font('Helvetica-Bold').text('Employee Details', 50, y);
    doc.moveTo(50, y + 16).lineTo(545, y + 16).strokeColor('#E0E0E0').stroke();

    const detail = (label: string, value: string, yPos: number) => {
      doc.fontSize(10).font('Helvetica-Bold').fillColor('#444').text(label, 50, yPos);
      doc.font('Helvetica').fillColor('#000').text(value, 200, yPos);
    };
    detail('Name', emp?.user.name ?? '-', y + 24);
    detail('Email', emp?.user.email ?? '-', y + 40);
    detail('Role', emp?.user.role ?? '-', y + 56);
    detail('Employee ID', employeeId.slice(0, 8).toUpperCase(), y + 72);
    detail('MTN MoMo Ref', item.txId ?? 'Pending', y + 88);

    // Earnings
    const earningsY = y + 120;
    doc.fontSize(11).font('Helvetica-Bold').text('Earnings', 50, earningsY);
    doc.moveTo(50, earningsY + 16).lineTo(545, earningsY + 16).strokeColor('#E0E0E0').stroke();

    const row = (label: string, amount: number, yPos: number, bold = false) => {
      doc.fontSize(10)
        .font(bold ? 'Helvetica-Bold' : 'Helvetica')
        .text(label, 50, yPos)
        .text(`GHS ${amount.toFixed(2)}`, 450, yPos, { align: 'right', width: 95 });
    };

    row('Basic Salary', Number(item.basic), earningsY + 24);
    row('Overtime Pay', Number(item.overtime), earningsY + 40);
    row('Gross Pay', gross, earningsY + 60, true);

    // Deductions
    const dedY = earningsY + 90;
    doc.fontSize(11).font('Helvetica-Bold').text('Deductions', 50, dedY);
    doc.moveTo(50, dedY + 16).lineTo(545, dedY + 16).strokeColor('#E0E0E0').stroke();

    row('Income Tax (5%)', tax, dedY + 24);
    row('SSNIT Pension (5.5%)', pension, dedY + 40);
    row('NHIL (2.5%)', nhil, dedY + 56);
    row('Total Deductions', Number(item.deductions), dedY + 76, true);

    // Net pay box
    const netY = dedY + 110;
    doc.rect(50, netY, 495, 44).fill('#1E2A3A');
    doc.fillColor('#fff').fontSize(13).font('Helvetica-Bold')
      .text('NET PAY', 58, netY + 14)
      .text(`GHS ${Number(item.net).toFixed(2)}`, 450, netY + 14, { align: 'right', width: 95 });

    // Footer
    doc.fillColor('#999').fontSize(8).font('Helvetica')
      .text(
        `Generated ${new Date().toLocaleString()} · HOMP Payroll Engine · Confidential`,
        50, 750, { align: 'center', width: 495 },
      );

    doc.end();
  }

  // ─── Queries ──────────────────────────────────────────────────────────────
  async listRuns(tenantId: string) {
    return this.prisma.payrollRun.findMany({
      where: { tenantId },
      orderBy: { createdAt: 'desc' },
      include: {
        _count: { select: { payrollItems: true } },
        payrollItems: {
          select: { net: true, basic: true, overtime: true, deductions: true },
        },
      },
    });
  }

  async getRunWithItems(runId: string) {
    return this.prisma.payrollRun.findUnique({
      where: { id: runId },
      include: {
        payrollItems: {
          include: {
            employee: {
              include: { user: { select: { name: true, email: true, role: true } } },
            },
          },
        },
      },
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  private async findRun(tenantId: string, runId: string) {
    const run = await this.prisma.payrollRun.findFirst({
      where: { id: runId, tenantId },
      include: { payrollItems: true },
    });
    if (!run) throw new NotFoundException('Payroll run not found');
    return run;
  }
}
