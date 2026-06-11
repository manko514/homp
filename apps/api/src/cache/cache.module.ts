import { Global, Module } from '@nestjs/common';
import { CacheModule } from '@nestjs/cache-manager';
import { ConfigService } from '@nestjs/config';
import { redisStore } from 'cache-manager-ioredis-yet';
import IoRedis from 'ioredis';

@Global()
@Module({
  imports: [
    CacheModule.registerAsync({
      isGlobal: true,
      useFactory: async (config: ConfigService) => {
        const redisUrl = config.get<string>('REDIS_URL');
        if (redisUrl) {
          try {
            // ioredis accepts a connection URL string in its constructor
            const client = new IoRedis(redisUrl, { lazyConnect: true, enableOfflineQueue: false });
            await client.connect();
            return { store: await redisStore({ client } as any) };
          } catch {
            // Redis unavailable — fall through to in-memory
          }
        }
        // In-memory cache fallback (no Redis required in dev)
        return { ttl: 60 };
      },
      inject: [ConfigService],
    }),
  ],
  exports: [CacheModule],
})
export class AppCacheModule {}
