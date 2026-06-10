import { IsString, IsOptional, IsDateString, IsNumber, Min } from 'class-validator';

export class PurchaseTicketDto {
  @IsOptional()
  @IsString()
  guestName?: string;

  @IsOptional()
  @IsString()
  guestId?: string;

  @IsString()
  ticketType: string; // DAY_PASS | POOL_ONLY | GYM | EVENT | VIP

  @IsDateString()
  validFrom: string;

  @IsDateString()
  validUntil: string;

  @IsOptional()
  @IsDateString()
  scheduledDate?: string;

  @IsNumber()
  @Min(0)
  purchasePrice: number;
}
