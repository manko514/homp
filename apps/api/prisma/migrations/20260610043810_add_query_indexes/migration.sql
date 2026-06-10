-- CreateIndex
CREATE INDEX "anomaly_alerts_tenant_id_resolved_idx" ON "anomaly_alerts"("tenant_id", "resolved");

-- CreateIndex
CREATE INDEX "anomaly_alerts_tenant_id_created_at_idx" ON "anomaly_alerts"("tenant_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_logs_tenant_id_created_at_idx" ON "audit_logs"("tenant_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_logs_tenant_id_event_type_idx" ON "audit_logs"("tenant_id", "event_type");

-- CreateIndex
CREATE INDEX "audit_logs_tenant_id_resource_type_idx" ON "audit_logs"("tenant_id", "resource_type");

-- CreateIndex
CREATE INDEX "bar_sales_tenant_id_created_at_idx" ON "bar_sales"("tenant_id", "created_at");

-- CreateIndex
CREATE INDEX "orders_tenant_id_status_idx" ON "orders"("tenant_id", "status");

-- CreateIndex
CREATE INDEX "orders_tenant_id_created_at_idx" ON "orders"("tenant_id", "created_at");

-- CreateIndex
CREATE INDEX "reservations_tenant_id_status_idx" ON "reservations"("tenant_id", "status");

-- CreateIndex
CREATE INDEX "reservations_tenant_id_check_in_idx" ON "reservations"("tenant_id", "check_in");

-- CreateIndex
CREATE INDEX "reservations_tenant_id_guest_id_idx" ON "reservations"("tenant_id", "guest_id");

-- CreateIndex
CREATE INDEX "tickets_tenant_id_status_idx" ON "tickets"("tenant_id", "status");

-- CreateIndex
CREATE INDEX "tickets_tenant_id_created_at_idx" ON "tickets"("tenant_id", "created_at");
