import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';

@WebSocketGateway({
  namespace: 'restaurant',
  cors: { origin: '*' },
})
export class RestaurantGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(RestaurantGateway.name);

  handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
  }

  // Client joins a tenant room (KDS screen subscribes to its tenant)
  @SubscribeMessage('join-tenant')
  handleJoinTenant(@MessageBody() tenantId: string, @ConnectedSocket() client: Socket) {
    client.join(`tenant:${tenantId}`);
    return { event: 'joined', data: tenantId };
  }

  // Broadcast new order to KDS screens for this tenant
  emitNewOrder(tenantId: string, order: unknown) {
    this.server.to(`tenant:${tenantId}`).emit('order:new', order);
  }

  // Broadcast order status change (e.g. KDS → READY → SERVED)
  emitOrderStatusChange(tenantId: string, orderId: string, status: string, order: unknown) {
    this.server.to(`tenant:${tenantId}`).emit('order:status', { orderId, status, order });
  }
}
