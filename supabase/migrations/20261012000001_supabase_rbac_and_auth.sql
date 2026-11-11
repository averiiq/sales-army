-- ============================================================================
-- SalesArmy SaaS - Migration 20261012000001: Supabase RBAC & Authentication
-- ============================================================================
-- This migration implements:
-- 1. Helper security functions: get_auth_role(), get_auth_tenant_id(), is_super_admin()
-- 2. Trigger on auth.users to automatically provision public.profiles
-- 3. Granular Row Level Security (RLS) policies with Role-Based Access Control
-- 4. Multi-Tenant isolation & Super Admin platform oversight
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. RBAC HELPER FUNCTIONS (STABLE & SECURITY DEFINER)
-- ----------------------------------------------------------------------------

-- Extract the active role for the currently authenticated caller
CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS VARCHAR AS $$
DECLARE
    v_role VARCHAR;
BEGIN
    -- 1. Check public.profiles first
    IF auth.uid() IS NOT NULL THEN
        SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid() LIMIT 1;
        IF v_role IS NOT NULL THEN
            RETURN v_role;
        END IF;
    END IF;

    -- 2. Fall back to user_metadata in JWT claim
    v_role := (auth.jwt() -> 'user_metadata' ->> 'role');
    IF v_role IS NOT NULL THEN
        RETURN v_role;
    END IF;

    -- 3. Check if explicit system superadmin email or service role
    IF LOWER(COALESCE(auth.jwt() ->> 'email', '')) = 'superadmin@salesarmy.saas' OR (auth.jwt() ->> 'role') = 'service_role' THEN
        RETURN 'super_admin';
    END IF;

    RETURN 'sales_person';
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Extract the tenant_id for the currently authenticated caller
CREATE OR REPLACE FUNCTION public.get_auth_tenant_id()
RETURNS VARCHAR AS $$
DECLARE
    v_tenant_id VARCHAR;
BEGIN
    IF auth.uid() IS NOT NULL THEN
        SELECT tenant_id INTO v_tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1;
        IF v_tenant_id IS NOT NULL THEN
            RETURN v_tenant_id;
        END IF;
    END IF;

    v_tenant_id := (auth.jwt() -> 'user_metadata' ->> 'tenant_id');
    RETURN v_tenant_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Check if current caller has super_admin privileges or service_role
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
    -- Service role bypasses all RLS
    IF (auth.jwt() ->> 'role') = 'service_role' THEN
        RETURN TRUE;
    END IF;

    IF public.get_auth_role() = 'super_admin' THEN
        RETURN TRUE;
    END IF;

    IF LOWER(COALESCE(auth.jwt() ->> 'email', '')) = 'superadmin@salesarmy.saas' THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Check if current caller is a member of the specified tenant
CREATE OR REPLACE FUNCTION public.is_tenant_member(target_tenant_id VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    IF public.is_super_admin() THEN
        RETURN TRUE;
    END IF;

    IF target_tenant_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN public.get_auth_tenant_id() = target_tenant_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Check if current caller has one of the allowed roles within their tenant
CREATE OR REPLACE FUNCTION public.has_tenant_role(target_tenant_id VARCHAR, allowed_roles TEXT[])
RETURNS BOOLEAN AS $$
BEGIN
    IF public.is_super_admin() THEN
        RETURN TRUE;
    END IF;

    IF NOT public.is_tenant_member(target_tenant_id) THEN
        RETURN FALSE;
    END IF;

    RETURN public.get_auth_role() = ANY(allowed_roles);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 2. AUTOMATIC PROFILE PROVISIONING TRIGGER (auth.users -> public.profiles)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_role VARCHAR;
    v_tenant_id VARCHAR;
    v_name VARCHAR;
BEGIN
    v_role := COALESCE(new.raw_user_meta_data->>'role', 'sales_person');
    v_tenant_id := new.raw_user_meta_data->>'tenant_id';
    v_name := COALESCE(
        new.raw_user_meta_data->>'name',
        new.raw_user_meta_data->>'full_name',
        split_part(new.email, '@', 1)
    );

    IF LOWER(COALESCE(new.email, '')) = 'superadmin@salesarmy.saas' THEN
        v_role := 'super_admin';
    END IF;

    INSERT INTO public.profiles (
        id,
        tenant_id,
        name,
        email,
        phone,
        role,
        account_status,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        new.id,
        v_tenant_id,
        v_name,
        new.email,
        new.phone,
        v_role,
        'active',
        TRUE,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        name = COALESCE(EXCLUDED.name, public.profiles.name),
        role = COALESCE(EXCLUDED.role, public.profiles.role),
        tenant_id = COALESCE(EXCLUDED.tenant_id, public.profiles.tenant_id),
        updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ----------------------------------------------------------------------------
-- 3. ADMINISTRATIVE ROLE ASSIGNMENT RPC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assign_user_role(
    target_user_id UUID,
    new_role VARCHAR,
    new_tenant_id VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_caller_tenant VARCHAR;
BEGIN
    v_caller_role := public.get_auth_role();
    v_caller_tenant := public.get_auth_tenant_id();

    -- Authorization check: Super Admin can assign any role/tenant.
    -- Tenant Owner can only assign roles within their own tenant (excluding super_admin).
    IF NOT public.is_super_admin() THEN
        IF v_caller_role NOT IN ('owner', 'distributor') THEN
            RAISE EXCEPTION 'Access Denied: Only Super Admin or Agency Owner can assign roles';
        END IF;

        IF new_role = 'super_admin' THEN
            RAISE EXCEPTION 'Access Denied: Cannot grant Super Admin privileges';
        END IF;

        IF new_tenant_id IS NOT NULL AND new_tenant_id <> v_caller_tenant THEN
            RAISE EXCEPTION 'Access Denied: Cannot assign user to different tenant';
        END IF;
    END IF;

    UPDATE public.profiles
    SET
        role = new_role,
        tenant_id = COALESCE(new_tenant_id, tenant_id),
        updated_at = NOW()
    WHERE id = target_user_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', target_user_id,
        'role', new_role,
        'tenant_id', COALESCE(new_tenant_id, v_caller_tenant)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 4. GRANULAR ROW LEVEL SECURITY (RLS) POLICIES
-- ----------------------------------------------------------------------------

-- A. PLATFORM SETTINGS
ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "platform_settings_select" ON public.platform_settings;
DROP POLICY IF EXISTS "platform_settings_write" ON public.platform_settings;

CREATE POLICY "platform_settings_select"
    ON public.platform_settings FOR SELECT
    TO public
    USING (TRUE);

CREATE POLICY "platform_settings_write"
    ON public.platform_settings FOR ALL
    TO authenticated, anon
    USING (public.is_super_admin() OR auth.uid() IS NULL)
    WITH CHECK (public.is_super_admin() OR auth.uid() IS NULL);


-- B. TENANTS
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tenants_select_rbac" ON public.tenants;
DROP POLICY IF EXISTS "tenants_insert_rbac" ON public.tenants;
DROP POLICY IF EXISTS "tenants_update_rbac" ON public.tenants;
DROP POLICY IF EXISTS "tenants_delete_rbac" ON public.tenants;

CREATE POLICY "tenants_select_rbac"
    ON public.tenants FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "tenants_insert_rbac"
    ON public.tenants FOR INSERT
    TO public
    WITH CHECK (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR public.get_auth_role() IN ('owner', 'distributor')
    );

CREATE POLICY "tenants_update_rbac"
    ON public.tenants FOR UPDATE
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (tenant_id = public.get_auth_tenant_id() AND public.get_auth_role() IN ('owner', 'distributor'))
    );

CREATE POLICY "tenants_delete_rbac"
    ON public.tenants FOR DELETE
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
    );


-- C. PROFILES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_select_rbac" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_rbac" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_rbac" ON public.profiles;
DROP POLICY IF EXISTS "profiles_delete_rbac" ON public.profiles;

CREATE POLICY "profiles_select_rbac"
    ON public.profiles FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR id = auth.uid()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "profiles_insert_rbac"
    ON public.profiles FOR INSERT
    TO public
    WITH CHECK (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR id = auth.uid()
        OR (tenant_id = public.get_auth_tenant_id() AND public.get_auth_role() IN ('owner', 'distributor'))
    );

CREATE POLICY "profiles_update_rbac"
    ON public.profiles FOR UPDATE
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR id = auth.uid()
        OR (tenant_id = public.get_auth_tenant_id() AND public.get_auth_role() IN ('owner', 'distributor'))
    );

CREATE POLICY "profiles_delete_rbac"
    ON public.profiles FOR DELETE
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (tenant_id = public.get_auth_tenant_id() AND public.get_auth_role() IN ('owner', 'distributor'))
    );


-- D. PRODUCTS & CATEGORIES
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "products_select_rbac" ON public.products;
DROP POLICY IF EXISTS "products_write_rbac" ON public.products;
DROP POLICY IF EXISTS "categories_select_rbac" ON public.categories;
DROP POLICY IF EXISTS "categories_write_rbac" ON public.categories;

CREATE POLICY "products_select_rbac"
    ON public.products FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "products_write_rbac"
    ON public.products FOR ALL
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (
            tenant_id = public.get_auth_tenant_id()
            AND public.get_auth_role() IN ('owner', 'distributor', 'manager', 'store_manager')
        )
    );

CREATE POLICY "categories_select_rbac"
    ON public.categories FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "categories_write_rbac"
    ON public.categories FOR ALL
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (
            tenant_id = public.get_auth_tenant_id()
            AND public.get_auth_role() IN ('owner', 'distributor', 'manager', 'store_manager')
        )
    );


-- E. SHOPS & RETAIL PARTIES
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "shops_select_rbac" ON public.shops;
DROP POLICY IF EXISTS "shops_write_rbac" ON public.shops;

CREATE POLICY "shops_select_rbac"
    ON public.shops FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "shops_write_rbac"
    ON public.shops FOR ALL
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (
            tenant_id = public.get_auth_tenant_id()
            AND public.get_auth_role() IN ('owner', 'distributor', 'sales_person', 'manager')
        )
    );


-- F. ORDERS & ORDER ITEMS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "orders_select_rbac" ON public.orders;
DROP POLICY IF EXISTS "orders_write_rbac" ON public.orders;
DROP POLICY IF EXISTS "order_items_select_rbac" ON public.order_items;
DROP POLICY IF EXISTS "order_items_write_rbac" ON public.order_items;

CREATE POLICY "orders_select_rbac"
    ON public.orders FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "orders_write_rbac"
    ON public.orders FOR ALL
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (
            tenant_id = public.get_auth_tenant_id()
            AND public.get_auth_role() IN ('owner', 'distributor', 'sales_person', 'manager', 'delivery_agent', 'accountant')
        )
    );

CREATE POLICY "order_items_select_rbac"
    ON public.order_items FOR SELECT
    TO public
    USING (TRUE);

CREATE POLICY "order_items_write_rbac"
    ON public.order_items FOR ALL
    TO public
    USING (TRUE);


-- G. INVOICES, PAYMENTS, & KHATA LEDGER
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "invoices_select_rbac" ON public.invoices;
DROP POLICY IF EXISTS "invoices_write_rbac" ON public.invoices;
DROP POLICY IF EXISTS "payments_select_rbac" ON public.payments;
DROP POLICY IF EXISTS "payments_write_rbac" ON public.payments;
DROP POLICY IF EXISTS "ledger_select_rbac" ON public.ledger_entries;
DROP POLICY IF EXISTS "ledger_write_rbac" ON public.ledger_entries;

CREATE POLICY "invoices_select_rbac"
    ON public.invoices FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "invoices_write_rbac"
    ON public.invoices FOR ALL
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (
            tenant_id = public.get_auth_tenant_id()
            AND public.get_auth_role() IN ('owner', 'distributor', 'accountant', 'sales_person')
        )
    );

CREATE POLICY "payments_select_rbac"
    ON public.payments FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "payments_write_rbac"
    ON public.payments FOR ALL
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (
            tenant_id = public.get_auth_tenant_id()
            AND public.get_auth_role() IN ('owner', 'distributor', 'accountant', 'sales_person', 'delivery_agent')
        )
    );

CREATE POLICY "ledger_select_rbac"
    ON public.ledger_entries FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "ledger_write_rbac"
    ON public.ledger_entries FOR ALL
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (
            tenant_id = public.get_auth_tenant_id()
            AND public.get_auth_role() IN ('owner', 'distributor', 'accountant')
        )
    );


-- H. VISITS & REMINDERS
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "visits_select_rbac" ON public.visits;
DROP POLICY IF EXISTS "visits_write_rbac" ON public.visits;

CREATE POLICY "visits_select_rbac"
    ON public.visits FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "visits_write_rbac"
    ON public.visits FOR ALL
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (
            tenant_id = public.get_auth_tenant_id()
            AND public.get_auth_role() IN ('owner', 'distributor', 'sales_person')
        )
    );


-- I. PRINTER HARDWARE ORDERS
ALTER TABLE public.printer_hardware_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "printer_orders_select_rbac" ON public.printer_hardware_orders;
DROP POLICY IF EXISTS "printer_orders_write_rbac" ON public.printer_hardware_orders;

CREATE POLICY "printer_orders_select_rbac"
    ON public.printer_hardware_orders FOR SELECT
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR tenant_id = public.get_auth_tenant_id()
    );

CREATE POLICY "printer_orders_write_rbac"
    ON public.printer_hardware_orders FOR ALL
    TO public
    USING (
        auth.uid() IS NULL
        OR public.is_super_admin()
        OR (
            tenant_id = public.get_auth_tenant_id()
            AND public.get_auth_role() IN ('owner', 'distributor')
        )
    );
