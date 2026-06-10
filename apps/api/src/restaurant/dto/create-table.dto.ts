import { IsInt, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateTableDto {
  @IsInt()
  @Min(1)
  @Type(() => Number)
  tableNumber: number;

  @IsInt()
  @Min(1)
  @Type(() => Number)
  capacity: number;
}
