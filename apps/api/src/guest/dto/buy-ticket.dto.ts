import { IsString, IsOptional, IsDateString } from 'class-validator';

export class BuyTicketDto {
  @IsString()
  ticketType: string;

  @IsOptional()
  @IsString()
  guestName?: string;

  @IsOptional()
  @IsDateString()
  validDate?: string; // ISO date — defaults to today
}
