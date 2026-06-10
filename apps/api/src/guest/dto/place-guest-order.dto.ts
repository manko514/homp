import {
  IsString,
  IsOptional,
  IsArray,
  ValidateNested,
  IsInt,
  IsBoolean,
  Min,
  IsNumber,
} from 'class-validator';
import { Type } from 'class-transformer';

export class GuestOrderItemDto {
  @IsString()
  menuItemId: string;

  @IsInt()
  @Min(1)
  @Type(() => Number)
  qty: number;

  @IsOptional()
  modifiers?: Record<string, unknown>;
}

export class GuestDrinkItemDto {
  @IsString()
  drinkId: string;

  @IsString()
  name: string;

  @IsInt()
  @Min(1)
  @Type(() => Number)
  qty: number;

  @IsNumber()
  price: number;
}

export class PlaceGuestOrderDto {
  @IsOptional()
  @IsString()
  tableId?: string;

  @IsOptional()
  @IsBoolean()
  isRoomService?: boolean;

  @IsOptional()
  @IsString()
  roomNumber?: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => GuestOrderItemDto)
  items?: GuestOrderItemDto[];

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => GuestDrinkItemDto)
  drinkItems?: GuestDrinkItemDto[];
}
