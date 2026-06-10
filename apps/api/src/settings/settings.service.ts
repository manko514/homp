import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class SettingsService {
  constructor(private prisma: PrismaService) {}

  async getSettings(tenantId: string) {
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { id: true, name: true, subdomain: true, logoUrl: true, primaryColor: true, createdAt: true },
    });
    if (!tenant) throw new NotFoundException('Tenant not found');
    return tenant;
  }

  async updateSettings(tenantId: string, data: { name?: string; primaryColor?: string; subdomain?: string; logoUrl?: string }) {
    return this.prisma.tenant.update({
      where: { id: tenantId },
      data: {
        ...(data.name ? { name: data.name } : {}),
        ...(data.primaryColor ? { primaryColor: data.primaryColor } : {}),
        ...(data.logoUrl !== undefined ? { logoUrl: data.logoUrl } : {}),
      },
      select: { id: true, name: true, subdomain: true, logoUrl: true, primaryColor: true },
    });
  }
}
