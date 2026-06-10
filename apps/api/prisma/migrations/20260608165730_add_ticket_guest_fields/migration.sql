-- AlterTable
ALTER TABLE "tickets" ADD COLUMN     "guest_name" TEXT,
ALTER COLUMN "guest_id" DROP NOT NULL;
