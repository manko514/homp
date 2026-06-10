import { IsDateString } from 'class-validator';

export class CreateRunDto {
  @IsDateString()
  periodStart: string;

  @IsDateString()
  periodEnd: string;
}
