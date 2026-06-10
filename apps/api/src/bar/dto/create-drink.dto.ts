import { IsString, IsNumber, IsOptional, IsArray, ValidateNested, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class RecipeIngredientDto {
  @IsString()
  stockItemId: string;

  @IsNumber()
  @Min(0)
  @Type(() => Number)
  qty: number;
}

export class CreateDrinkDto {
  @IsString()
  name: string;

  @IsString()
  category: string;

  @IsNumber()
  @Min(0)
  @Type(() => Number)
  price: number;

  @IsOptional()
  @IsString()
  photoUrl?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RecipeIngredientDto)
  recipe?: RecipeIngredientDto[];
}
