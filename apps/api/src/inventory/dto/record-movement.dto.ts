import { IsString, IsNumber, IsEnum, IsOptional, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { MovementType } from '@prisma/client';

export class RecordMovementDto {
  @IsString()
  stockItemId: string;

  @IsEnum(MovementType)
  movementType: MovementType;

  @IsNumber()
  @Min(0.001)
  @Type(() => Number)
  qty: number;

  @IsOptional()
  @IsString()
  notes?: string;
}
