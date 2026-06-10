-- AlterTable
ALTER TABLE "guest_profiles" ADD COLUMN     "communication_prefs" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- CreateTable
CREATE TABLE "bar_tabs" (
    "id" TEXT NOT NULL,
    "tenant_id" TEXT NOT NULL,
    "guest_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "items" JSONB NOT NULL DEFAULT '[]',
    "total" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "bar_tabs_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "bar_tabs" ADD CONSTRAINT "bar_tabs_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bar_tabs" ADD CONSTRAINT "bar_tabs_guest_id_fkey" FOREIGN KEY ("guest_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
