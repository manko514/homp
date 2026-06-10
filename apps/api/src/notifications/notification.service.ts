import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class NotificationService implements OnModuleInit {
  private readonly logger = new Logger(NotificationService.name);
  private initialized = false;

  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
  ) {}

  onModuleInit() {
    const serviceAccountPath = this.config.get<string>('FCM_SERVICE_ACCOUNT_PATH');
    const projectId = this.config.get<string>('FCM_PROJECT_ID');

    if (!serviceAccountPath && !projectId) {
      this.logger.warn('FCM not configured — push notifications disabled. Set FCM_SERVICE_ACCOUNT_PATH or FCM_PROJECT_ID in .env');
      return;
    }

    try {
      if (!admin.apps.length) {
        if (serviceAccountPath) {
          // eslint-disable-next-line @typescript-eslint/no-var-requires
          const serviceAccount = require(serviceAccountPath);
          admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
        } else {
          // Use Application Default Credentials (Google Cloud environment)
          admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId });
        }
      }
      this.initialized = true;
      this.logger.log('Firebase Admin initialized ✅');
    } catch (err) {
      this.logger.error('Firebase Admin init failed', err);
    }
  }

  // ─── Save FCM Token ───────────────────────────────────────────────────────────

  async saveFcmToken(userId: string, token: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken: token },
    });
  }

  // ─── Send to single user ──────────────────────────────────────────────────────

  async sendToUser(userId: string, title: string, body: string, data?: Record<string, string>) {
    if (!this.initialized) return;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { fcmToken: true },
    });

    if (!user?.fcmToken) return;

    await this.sendToToken(user.fcmToken, title, body, data);
  }

  // ─── Send to role ─────────────────────────────────────────────────────────────

  async sendToRole(tenantId: string, role: string, title: string, body: string, data?: Record<string, string>) {
    if (!this.initialized) return;

    const users = await this.prisma.user.findMany({
      where: { tenantId, role: role as any, status: 'active' },
      select: { fcmToken: true },
    });

    const tokens = users.map((u) => u.fcmToken).filter(Boolean) as string[];
    if (tokens.length === 0) return;

    await this.sendMulticast(tokens, title, body, data);
  }

  // ─── Raw send helpers ─────────────────────────────────────────────────────────

  private async sendToToken(token: string, title: string, body: string, data?: Record<string, string>) {
    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data: data ?? {},
        android: {
          priority: 'high',
          notification: { sound: 'default', channelId: 'homp_default' },
        },
      });
    } catch (err: any) {
      if (err?.code === 'messaging/registration-token-not-registered') {
        // Token stale — clear it
        await this.prisma.user.updateMany({
          where: { fcmToken: token },
          data: { fcmToken: null },
        });
      } else {
        this.logger.error('FCM send error', err);
      }
    }
  }

  private async sendMulticast(tokens: string[], title: string, body: string, data?: Record<string, string>) {
    if (!tokens.length) return;
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: data ?? {},
        android: {
          priority: 'high',
          notification: { sound: 'default', channelId: 'homp_default' },
        },
      });

      // Clean up stale tokens
      const stale: string[] = [];
      response.responses.forEach((res: admin.messaging.SendResponse, i: number) => {
        if (!res.success && res.error?.code === 'messaging/registration-token-not-registered') {
          stale.push(tokens[i]);
        }
      });
      if (stale.length) {
        await this.prisma.user.updateMany({
          where: { fcmToken: { in: stale } },
          data: { fcmToken: null },
        });
      }
    } catch (err) {
      this.logger.error('FCM multicast error', err);
    }
  }
}
