-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "drink_items" JSONB,
ADD COLUMN     "notes" TEXT,
ADD COLUMN     "room_number" TEXT;
