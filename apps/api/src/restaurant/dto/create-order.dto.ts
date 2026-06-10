import { IsString, IsOptional, IsArray, ValidateNested, IsInt, IsBoolean, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class OrderItemDto {
  @IsString()
  menuItemId: string;

  @IsInt()
  @Min(1)
  @Type(() => Number)
  qty: number;

  @IsOptional()
  modifiers?: Record<string, unknown>;
}

export class CreateOrderDto {
  @IsOptional()
  @IsString()
  tableId?: string;

  @IsOptional()
  @IsBoolean()
  isRoomService?: boolean;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => OrderItemDto)
  items: OrderItemDto[];

  @IsOptional()
  @IsString()
  notes?: string;
}
