-- ============================================================================
-- 20261029000001_missing_fk_indexes.sql
--
-- Adds composite / FK indexes that the mobile + admin workloads already query
-- on but which were missing from the initial schema. Each index is wrapped in
-- `IF NOT EXISTS` so the migration is idempotent against environments that
-- added some of them manually.
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_payments_invoice_id
  ON public.payments(invoice_id);

CREATE INDEX IF NOT EXISTS idx_payments_collected_by
  ON public.payments(collected_by);

CREATE INDEX IF NOT EXISTS idx_payments_tenant_date
  ON public.payments(tenant_id, payment_date DESC);

CREATE INDEX IF NOT EXISTS idx_orders_sales_person
  ON public.orders(sales_person_uid);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_invoice
  ON public.ledger_entries(invoice_id);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_payment
  ON public.ledger_entries(payment_id);

CREATE INDEX IF NOT EXISTS idx_ledger_entries_tenant_date
  ON public.ledger_entries(tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_subscription_checkouts_tenant
  ON public.subscription_checkouts(tenant_id);

CREATE INDEX IF NOT EXISTS idx_subscription_checkouts_user
  ON public.subscription_checkouts(user_id);

CREATE INDEX IF NOT EXISTS idx_expenses_tenant_date
  ON public.expenses(tenant_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_purchases_tenant
  ON public.purchases(tenant_id);
