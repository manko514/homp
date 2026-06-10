import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';

export interface AuditEventDto {
  tenantId: string;
  actorId: string;
  eventType: string;       // CREATE | UPDATE | DELETE | LOGIN | APPROVE | DISBURSE | VALIDATE
  resourceType: string;    // reservation | order | ticket | payroll | employee | etc.
  resourceId: string;
  diffJson?: Record<string, unknown>;
}

@Injectable()
export class AuditService {
  constructor(private prisma: PrismaService) {}

  // ─── Append-only log entry ────────────────────────────────────────────────
  async log(event: AuditEventDto) {
    return this.prisma.auditLog.create({
      data: {
        tenantId: event.tenantId,
        actorId: event.actorId,
        eventType: event.eventType,
        resourceType: event.resourceType,
        resourceId: event.resourceId,
        diffJson: (event.diffJson ?? {}) as Prisma.InputJsonValue,
      },
    });
  }

  // ─── Query logs ───────────────────────────────────────────────────────────
  async getLogs(
    tenantId: string,
    opts?: {
      resourceType?: string;
      eventType?: string;
      actorId?: string;
      from?: string;
      to?: string;
      limit?: number;
    },
  ) {
    const where: Record<string, unknown> = { tenantId };

    if (opts?.resourceType) where.resourceType = opts.resourceType;
    if (opts?.eventType) where.eventType = opts.eventType;
    if (opts?.actorId) where.actorId = opts.actorId;
    if (opts?.from || opts?.to) {
      where.createdAt = {
        ...(opts.from ? { gte: new Date(opts.from) } : {}),
        ...(opts.to ? { lte: new Date(opts.to) } : {}),
      };
    }

    const logs = await this.prisma.auditLog.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: opts?.limit ?? 100,
      include: {
        actor: { select: { name: true, email: true, role: true } },
      },
    });

    return logs;
  }

  // ─── Stats ─────────────────────────────────────────────────────────────────
  async getStats(tenantId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [total, todayCount, byType, byResource] = await Promise.all([
      this.prisma.auditLog.count({ where: { tenantId } }),
      this.prisma.auditLog.count({ where: { tenantId, createdAt: { gte: today } } }),
      this.prisma.auditLog.groupBy({
        by: ['eventType'],
        where: { tenantId },
        _count: { id: true },
        orderBy: { _count: { id: 'desc' } },
      }),
      this.prisma.auditLog.groupBy({
        by: ['resourceType'],
        where: { tenantId },
        _count: { id: true },
        orderBy: { _count: { id: 'desc' } },
        take: 8,
      }),
    ]);

    return {
      total,
      todayCount,
      byType: byType.map((b) => ({ eventType: b.eventType, count: b._count.id })),
      byResource: byResource.map((b) => ({ resourceType: b.resourceType, count: b._count.id })),
    };
  }
}
