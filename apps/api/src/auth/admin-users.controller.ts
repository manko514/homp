import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  UseGuards,
  ParseUUIDPipe,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { PrismaService } from '../database/prisma.service';
import { AuditService } from '../audit/audit.service';
import { Role, User } from '@prisma/client';

const VALID_ROLES: string[] = Object.values(Role);

@Controller('admin/users')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('MANAGER', 'ADMIN')
export class AdminUsersController {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
  ) {}

  /** GET /admin/users — list all users in this tenant */
  @Get()
  listUsers(@CurrentUser() actor: User) {
    return this.prisma.user.findMany({
      where: { tenantId: actor.tenantId },
      select: { id: true, name: true, email: true, role: true, status: true, createdAt: true },
      orderBy: { name: 'asc' },
    });
  }

  /** PATCH /admin/users/:id/role — change a user's role (logged to audit trail) */
  @Patch(':id/role')
  async changeRole(
    @CurrentUser() actor: User,
    @Param('id', ParseUUIDPipe) targetId: string,
    @Body('role') newRole: string,
  ) {
    if (!newRole || !VALID_ROLES.includes(newRole)) {
      throw new BadRequestException(`Invalid role. Valid roles: ${VALID_ROLES.join(', ')}`);
    }

    const target = await this.prisma.user.findFirst({
      where: { id: targetId, tenantId: actor.tenantId },
      select: { id: true, name: true, role: true },
    });
    if (!target) throw new NotFoundException('User not found in this tenant');

    const previousRole = target.role;

    const updated = await this.prisma.user.update({
      where: { id: targetId },
      data: { role: newRole as Role },
      select: { id: true, name: true, email: true, role: true },
    });

    // Immutable audit trail for compliance
    await this.audit.log({
      tenantId: actor.tenantId,
      actorId: actor.id,
      eventType: 'ROLE_CHANGED',
      resourceType: 'user',
      resourceId: targetId,
      diffJson: {
        previousRole,
        newRole,
        targetName: target.name,
        changedBy: actor.name,
      },
    });

    return updated;
  }

  /** GET /admin/users/:id/role-history — full role change history for a user */
  @Get(':id/role-history')
  async getRoleHistory(
    @CurrentUser() actor: User,
    @Param('id', ParseUUIDPipe) targetId: string,
  ) {
    const target = await this.prisma.user.findFirst({
      where: { id: targetId, tenantId: actor.tenantId },
      select: { id: true, name: true, role: true },
    });
    if (!target) throw new NotFoundException('User not found in this tenant');

    const history = await this.prisma.auditLog.findMany({
      where: {
        tenantId: actor.tenantId,
        eventType: 'ROLE_CHANGED',
        resourceType: 'user',
        resourceId: targetId,
      },
      include: { actor: { select: { name: true, email: true } } },
      orderBy: { createdAt: 'desc' },
    });

    return { user: target, history };
  }
}
