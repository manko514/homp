import { IsString, IsInt, IsNumber, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class LogWasteDto {
  @IsString()
  stockItemId: string;

  @IsNumber()
  @Min(0)
  @Type(() => Number)
  qty: number;

  @IsString()
  reason: string;
}
