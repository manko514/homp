import { IsString, IsInt, IsOptional, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class RecordSaleDto {
  @IsString()
  drinkId: string;

  @IsInt()
  @Min(1)
  @Type(() => Number)
  qty: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Type(() => Number)
  wasteQty?: number;
}
