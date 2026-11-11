BEGIN;

-- ============================================================================
-- SalesArmy - Supabase Business Workflow Migration
-- Adds tables: expenses, purchases, reminders, feedback
-- Adds RPC: admin_purge_tenant_transactions
-- ============================================================================

-- 1. EXPENSES TABLE
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    category VARCHAR(100) NOT NULL DEFAULT 'General',
    amount NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    payment_mode VARCHAR(50) NOT NULL DEFAULT 'Cash',
    title VARCHAR(255) NOT NULL,
    notes TEXT,
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_tenant_expense UNIQUE (tenant_id, expense_id)
);
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "expenses_tenant_isolation" ON public.expenses FOR ALL TO authenticated
USING (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id())
WITH CHECK (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id());

-- 2. PURCHASES TABLE
CREATE TABLE IF NOT EXISTS public.purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_id VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    supplier_name VARCHAR(255) NOT NULL,
    total_amount NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    items JSONB NOT NULL DEFAULT '[]',
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_tenant_purchase UNIQUE (tenant_id, purchase_id)
);
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "purchases_tenant_isolation" ON public.purchases FOR ALL TO authenticated
USING (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id())
WITH CHECK (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id());

-- 3. REMINDERS TABLE
CREATE TABLE IF NOT EXISTS public.reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reminder_id VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    shop_id VARCHAR(64),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    due_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_tenant_reminder UNIQUE (tenant_id, reminder_id)
);
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reminders_tenant_isolation" ON public.reminders FOR ALL TO authenticated
USING (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id())
WITH CHECK (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id());

-- 4. FEEDBACK TABLE
CREATE TABLE IF NOT EXISTS public.feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(64) REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    user_id UUID,
    rating INTEGER NOT NULL DEFAULT 5,
    category VARCHAR(50) DEFAULT 'general',
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY "feedback_insert_policy" ON public.feedback FOR INSERT TO authenticated
WITH CHECK (tenant_id IS NULL OR tenant_id = public.get_auth_tenant_id());
CREATE POLICY "feedback_select_policy" ON public.feedback FOR SELECT TO authenticated
USING (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id());

-- 5. TRANSACTIONAL PURGE RPC
CREATE OR REPLACE FUNCTION public.admin_purge_tenant_transactions(p_tenant text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  PERFORM public.assert_sales_access(p_tenant);
  IF NOT public.is_super_admin() AND public.get_auth_role() NOT IN ('owner', 'distributor') THEN
    RAISE EXCEPTION 'Account reset requires Owner or Super Admin privileges';
  END IF;

  DELETE FROM public.ledger_entries WHERE tenant_id = p_tenant;
  DELETE FROM public.payments WHERE tenant_id = p_tenant;
  DELETE FROM public.order_items WHERE order_id IN (SELECT id FROM public.orders WHERE tenant_id = p_tenant);
  DELETE FROM public.orders WHERE tenant_id = p_tenant;
  DELETE FROM public.invoices WHERE tenant_id = p_tenant;
  DELETE FROM public.visits WHERE tenant_id = p_tenant;
  DELETE FROM public.expenses WHERE tenant_id = p_tenant;
  DELETE FROM public.purchases WHERE tenant_id = p_tenant;
  DELETE FROM public.reminders WHERE tenant_id = p_tenant;
  UPDATE public.shops SET current_outstanding = 0.00, updated_at = NOW() WHERE tenant_id = p_tenant;
END $$;
REVOKE ALL ON FUNCTION public.admin_purge_tenant_transactions(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_purge_tenant_transactions(text) TO authenticated, service_role;

COMMIT;
