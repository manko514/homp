import { IsOptional, IsDateString, IsEnum, IsString } from 'class-validator';
import { ReservationStatus } from '@prisma/client';

export class QueryReservationsDto {
  @IsOptional()
  @IsEnum(ReservationStatus)
  status?: ReservationStatus;

  @IsOptional()
  @IsDateString()
  from?: string;

  @IsOptional()
  @IsDateString()
  to?: string;

  @IsOptional()
  @IsString()
  roomId?: string;
}
