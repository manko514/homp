import { IsNumber, IsOptional } from 'class-validator';

export class ClockInDto {
  @IsOptional()
  @IsNumber()
  lat?: number;

  @IsOptional()
  @IsNumber()
  lng?: number;
}
