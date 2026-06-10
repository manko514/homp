import { IsString, IsDateString, IsOptional, IsObject } from 'class-validator';

export class CreateReservationDto {
  @IsString()
  roomId: string;

  @IsDateString()
  checkIn: string;

  @IsDateString()
  checkOut: string;

  @IsOptional()
  @IsObject()
  addOns?: Record<string, unknown>;

  @IsOptional()
  @IsString()
  notes?: string;
}
