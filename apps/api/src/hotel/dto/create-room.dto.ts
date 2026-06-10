import { IsString, IsInt, IsNumber, IsOptional, IsArray, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateRoomDto {
  @IsString()
  roomNumber: string;

  @IsString()
  type: string;

  @IsInt()
  @Min(1)
  @Type(() => Number)
  floor: number;

  @IsNumber()
  @Min(0)
  @Type(() => Number)
  baseRate: number;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  amenities?: string[];

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  photos?: string[];
}
