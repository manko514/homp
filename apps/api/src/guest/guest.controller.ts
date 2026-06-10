import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  ParseIntPipe,
  ValidationPipe,
  UseGuards,
  Req,
  Query,
  Res,
} from '@nestjs/common';
import { Response } from 'express';
import { GuestService } from './guest.service';
import { PlaceGuestOrderDto } from './dto/place-guest-order.dto';
import { BuyTicketDto } from './dto/buy-ticket.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

// No @UseGuards — public endpoints for anonymous guests
@Controller('guest')
export class GuestController {
  constructor(private readonly guestService: GuestService) {}

  // ─── Guest Auth (public) ──────────────────────────────────────────────────────

  @Post(':tenantId/register')
  registerGuest(
    @Param('tenantId') tenantId: string,
    @Body(ValidationPipe) dto: { name: string; email: string; password: string; phone?: string },
  ) {
    return this.guestService.registerGuest(tenantId, dto);
  }

  @Post(':tenantId/social')
  socialLogin(
    @Param('tenantId') tenantId: string,
    @Body() dto: { provider: 'google' | 'apple'; idToken: string },
  ) {
    return this.guestService.socialLoginGuest(tenantId, dto.provider, dto.idToken);
  }

  @Post(':tenantId/login')
  loginGuest(
    @Param('tenantId') tenantId: string,
    @Body(ValidationPipe) dto: { email?: string; phone?: string; password: string },
  ) {
    return this.guestService.loginGuest(tenantId, dto);
  }

  // ─── Guest Profile (auth required) ───────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Get('me')
  getMyProfile(@Req() req: any) {
    return this.guestService.getMyProfile(req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me')
  updateMyProfile(
    @Req() req: any,
    @Body() dto: { name?: string; phone?: string; dietaryPreferences?: string[]; roomPreferences?: string[] },
  ) {
    return this.guestService.updateMyProfile(req.user.id, dto);
  }

  // ─── Loyalty (auth required) ──────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Get('loyalty')
  getLoyaltyHistory(@Req() req: any) {
    return this.guestService.getLoyaltyHistory(req.user.id);
  }

  // ─── Wallet ────────────────────────────────────────────────────────────────────

  @Get('wallet')
  @UseGuards(JwtAuthGuard)
  getWallet(@Req() req: any) {
    return this.guestService.getWallet(req.user.id);
  }

  @Post('wallet/topup')
  @UseGuards(JwtAuthGuard)
  topUpWallet(@Req() req: any, @Body() body: { amount: number; method: string; tenantId: string }) {
    return this.guestService.topUpWallet(req.user.id, body.tenantId, body.amount, body.method);
  }

  @Post('wallet/debit')
  @UseGuards(JwtAuthGuard)
  debitWallet(@Req() req: any, @Body() body: { amount: number; tenantId: string; note?: string }) {
    return this.guestService.debitWallet(req.user.id, body.tenantId, body.amount, body.note ?? 'Bill payment');
  }

  // ─── FCM Token ────────────────────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Post('fcm-token')
  saveFcmToken(@Req() req: any, @Body() body: { token: string }) {
    return this.guestService.saveFcmToken(req.user.id, body.token);
  }

  // ─── Room Availability (public) ───────────────────────────────────────────────

  @Get(':tenantId/rooms')
  getAvailableRooms(
    @Param('tenantId') tenantId: string,
    @Query('checkIn') checkIn?: string,
    @Query('checkOut') checkOut?: string,
  ) {
    return this.guestService.getAvailableRooms(tenantId, checkIn, checkOut);
  }

  @Get(':tenantId/rooms/busy-dates')
  getBusyDates(@Param('tenantId') tenantId: string) {
    return this.guestService.getBusyDates(tenantId);
  }

  // ─── Bookings (auth required) ─────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Post(':tenantId/bookings')
  createBooking(
    @Param('tenantId') tenantId: string,
    @Req() req: any,
    @Body() dto: { roomId: string; checkIn: string; checkOut: string; addOns?: Record<string, unknown>; notes?: string },
  ) {
    return this.guestService.createBooking(tenantId, req.user.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('bookings')
  getMyBookings(@Req() req: any) {
    return this.guestService.getMyBookings(req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Post('bookings/:id/checkin')
  checkIn(@Param('id') id: string, @Req() req: any) {
    return this.guestService.checkIn(id, req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Get('bookings/:id/bill')
  getBill(@Param('id') id: string, @Req() req: any) {
    return this.guestService.getBill(id, req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Post('bookings/:id/checkout')
  checkOut(@Param('id') id: string, @Req() req: any) {
    return this.guestService.checkOut(id, req.user.id);
  }

  // ─── Re-Book ─────────────────────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Post('bookings/:id/rebook')
  rebookReservation(
    @Param('id') id: string,
    @Req() req: any,
    @Body() dto: { checkIn: string; checkOut: string },
  ) {
    return this.guestService.rebookReservation(id, req.user.id, dto);
  }

  // ─── Receipt ─────────────────────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Get('bookings/:id/receipt')
  async getReceipt(
    @Param('id') id: string,
    @Req() req: any,
    @Res() res: Response,
  ) {
    const html = await this.guestService.getReceiptHtml(id, req.user.id);
    res.setHeader('Content-Type', 'text/html');
    res.send(html);
  }

  // ─── Bar Tab ─────────────────────────────────────────────────────────────────

  @UseGuards(JwtAuthGuard)
  @Post(':tenantId/bar-tab/open')
  openBarTab(@Param('tenantId') tenantId: string, @Req() req: any) {
    return this.guestService.openBarTab(tenantId, req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Get('bar-tab')
  getBarTab(@Req() req: any) {
    return this.guestService.getBarTab(req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Post('bar-tab/add')
  addToBarTab(
    @Req() req: any,
    @Body() dto: { drinkId: string; qty: number },
  ) {
    return this.guestService.addToBarTab(req.user.id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('bar-tab/close')
  closeBarTab(@Req() req: any) {
    return this.guestService.closeBarTab(req.user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Get('bar-tab/history')
  getBarTabHistory(@Req() req: any) {
    return this.guestService.getBarTabHistory(req.user.id);
  }

  // ─── Table Lookup ─────────────────────────────────────────────────────────────

  @Get(':tenantId/table/:tableNumber')
  getTable(
    @Param('tenantId') tenantId: string,
    @Param('tableNumber', ParseIntPipe) tableNumber: number,
  ) {
    return this.guestService.getTableByNumber(tenantId, tableNumber);
  }

  // ─── Menu & Drinks ────────────────────────────────────────────────────────────

  @Get(':tenantId/menu')
  getMenu(@Param('tenantId') tenantId: string) {
    return this.guestService.getMenu(tenantId);
  }

  @Get(':tenantId/drinks')
  getDrinks(@Param('tenantId') tenantId: string) {
    return this.guestService.getDrinks(tenantId);
  }

  // ─── Orders ───────────────────────────────────────────────────────────────────

  @Post(':tenantId/orders')
  placeOrder(
    @Param('tenantId') tenantId: string,
    @Body(ValidationPipe) dto: PlaceGuestOrderDto,
  ) {
    return this.guestService.placeOrder(tenantId, dto);
  }

  @Get('orders/:orderId/status')
  trackOrder(@Param('orderId') orderId: string) {
    return this.guestService.trackOrder(orderId);
  }

  // ─── Ticketing ────────────────────────────────────────────────────────────────

  @Get('ticket-catalog')
  getTicketCatalog() {
    return this.guestService.getTicketCatalog();
  }

  @Post(':tenantId/tickets')
  buyTicket(
    @Param('tenantId') tenantId: string,
    @Body(ValidationPipe) dto: BuyTicketDto,
    @Req() req: any,
  ) {
    return this.guestService.buyTicket(tenantId, dto, req.user?.id);
  }

  @Get('tickets/:qrToken')
  getTicket(@Param('qrToken') qrToken: string) {
    return this.guestService.getTicketByToken(qrToken);
  }

  @Post('tickets/:qrToken/validate')
  validateTicket(@Param('qrToken') qrToken: string) {
    return this.guestService.validateTicket(qrToken);
  }
}
