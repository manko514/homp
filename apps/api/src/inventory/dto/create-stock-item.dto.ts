import { IsString, IsNumber, IsOptional, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateStockItemDto {
  @IsString()
  name: string;

  @IsString()
  unit: string;

  @IsString()
  category: string;

  @IsNumber()
  @Min(0)
  @Type(() => Number)
  currentQty: number;

  @IsNumber()
  @Min(0)
  @Type(() => Number)
  reorderLevel: number;
}

export class UpdateStockItemDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  unit?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  reorderLevel?: number;
}
