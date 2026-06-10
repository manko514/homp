-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "Role" ADD VALUE 'GROUP_GM';
ALTER TYPE "Role" ADD VALUE 'GROUP_FINANCE';

-- AlterTable
ALTER TABLE "reservations" ADD COLUMN     "booking_source" TEXT DEFAULT 'direct';

-- AlterTable
ALTER TABLE "tenants" ADD COLUMN     "property_group_id" TEXT;

-- CreateTable
CREATE TABLE "property_groups" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "property_groups_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "tenants" ADD CONSTRAINT "tenants_property_group_id_fkey" FOREIGN KEY ("property_group_id") REFERENCES "property_groups"("id") ON DELETE SET NULL ON UPDATE CASCADE;
