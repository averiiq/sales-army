-- ============================================================================
-- ⚠️  LEGACY — DO NOT RUN ON ANY NEW ENVIRONMENT ⚠️
-- ============================================================================
-- This file predates the hardened RLS introduced in
-- `migrations/20261026000000_secure_access.sql` and earlier siblings. Running
-- it from scratch would re-open permissive policies that grant full read/write
-- to the `anon` role on every operational table.
--
-- Bootstrap a new Supabase project by running the files under
-- `supabase/migrations/` in filename order via the Supabase CLI or SQL editor.
-- Keep this file around only as a historical reference for existing
-- environments that were already bootstrapped from it, so they can be audited
-- against the hardened policies.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. EXTENSIONS & PREREQUISITES
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. TENANTS & SUBSCRIPTIONS
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(64) UNIQUE NOT NULL,
    business_name VARCHAR(255) NOT NULL,
    legal_name VARCHAR(255),
    owner_uid UUID,
    contact_person VARCHAR(150),
    mobile VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    gstin VARCHAR(20),
    pan VARCHAR(20),
    fssai VARCHAR(30),
    address TEXT,
    warehouse_address TEXT,
    territory VARCHAR(150) DEFAULT 'Main Market',
    state VARCHAR(100) DEFAULT 'Delhi',
    city VARCHAR(100) DEFAULT 'New Delhi',
    pincode VARCHAR(10),
    bank_name VARCHAR(150),
    bank_account_no VARCHAR(50),
    bank_ifsc VARCHAR(20),
    logo_url TEXT,
    plan_id VARCHAR(50) DEFAULT 'grow',
    subscription_status VARCHAR(30) DEFAULT 'active', -- 'trial', 'active', 'freemium', 'suspended', 'expired'
    subscription_start_date TIMESTAMPTZ DEFAULT NOW(),
    subscription_end_date TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '1 year'),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tenants_tenant_id ON public.tenants(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenants_subscription_status ON public.tenants(subscription_status);

-- ============================================================================
-- 2. USERS & PROFILES (Linked to auth.users)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id VARCHAR(64) REFERENCES public.tenants(tenant_id) ON DELETE SET NULL,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    photo_url TEXT,
    role VARCHAR(50) NOT NULL DEFAULT 'sales_person', -- 'super_admin', 'owner', 'distributor', 'accountant', 'sales_person', 'delivery_agent', 'manager'
    account_status VARCHAR(30) DEFAULT 'active', -- 'active', 'inactive', 'suspended'
    territory VARCHAR(150),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles(tenant_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- ============================================================================
-- 3. PRODUCT CATEGORIES
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, name)
);

CREATE INDEX IF NOT EXISTS idx_categories_tenant ON public.categories(tenant_id);

-- ============================================================================
-- 4. PRODUCTS & INVENTORY
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    variant VARCHAR(100),
    sku VARCHAR(100),
    barcode VARCHAR(100),
    hsn_sac VARCHAR(20),
    base_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    selling_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gst_rate NUMERIC(5, 2) NOT NULL DEFAULT 18.00,
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    low_stock_threshold INTEGER NOT NULL DEFAULT 10,
    unit VARCHAR(30) DEFAULT 'PCS',
    image_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_products_tenant ON public.products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_products_sku ON public.products(tenant_id, sku);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON public.products(tenant_id, barcode);

-- ============================================================================
-- 5. SHOPS / RETAIL PARTIES
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    shop_name VARCHAR(255) NOT NULL,
    owner_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    whatsapp VARCHAR(20),
    business_type VARCHAR(100) DEFAULT 'Retail Kirana',
    category VARCHAR(100) DEFAULT 'General Store',
    address TEXT NOT NULL,
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    gstin VARCHAR(20),
    territory VARCHAR(150) DEFAULT 'Main Market',
    visit_frequency VARCHAR(50) DEFAULT 'weekly',
    credit_limit NUMERIC(12, 2) DEFAULT 25000.00,
    current_outstanding NUMERIC(12, 2) DEFAULT 0.00,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, shop_id)
);

CREATE INDEX IF NOT EXISTS idx_shops_tenant ON public.shops(tenant_id);
CREATE INDEX IF NOT EXISTS idx_shops_phone ON public.shops(tenant_id, phone);
CREATE INDEX IF NOT EXISTS idx_shops_territory ON public.shops(tenant_id, territory);

-- ============================================================================
-- 6. ORDERS & ORDER ITEMS
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    shop_id VARCHAR(64) NOT NULL,
    sales_person_uid UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    order_date TIMESTAMPTZ DEFAULT NOW(),
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_gst NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(50) DEFAULT 'confirmed', -- 'draft', 'confirmed', 'delivered', 'cancelled'
    notes TEXT,
    client_mutation_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, order_id)
);

CREATE INDEX IF NOT EXISTS idx_orders_tenant ON public.orders(tenant_id);
CREATE INDEX IF NOT EXISTS idx_orders_shop ON public.orders(tenant_id, shop_id);
CREATE INDEX IF NOT EXISTS idx_orders_date ON public.orders(tenant_id, order_date DESC);

CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id VARCHAR(64) NOT NULL,
    product_name VARCHAR(255) NOT NULL,
    sku VARCHAR(100),
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gst_rate NUMERIC(5, 2) NOT NULL DEFAULT 18.00,
    taxable_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gst_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total NUMERIC(12, 2) NOT NULL DEFAULT 0.00
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);

-- ============================================================================
-- 7. INVOICES (GST Tax & Kaccha Estimate Invoices)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id VARCHAR(64) NOT NULL,
    invoice_number VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    order_id VARCHAR(64),
    shop_id VARCHAR(64) NOT NULL,
    invoice_type VARCHAR(30) DEFAULT 'gst', -- 'gst' (Tax Invoice) or 'estimate' (Kaccha Informal Bill)
    invoice_date TIMESTAMPTZ DEFAULT NOW(),
    seller_details JSONB,
    buyer_details JSONB,
    taxable_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    cgst NUMERIC(12, 2) DEFAULT 0.00,
    sgst NUMERIC(12, 2) DEFAULT 0.00,
    igst NUMERIC(12, 2) DEFAULT 0.00,
    total_gst NUMERIC(12, 2) DEFAULT 0.00,
    grand_total NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    amount_paid NUMERIC(12, 2) DEFAULT 0.00,
    amount_due NUMERIC(12, 2) DEFAULT 0.00,
    payment_status VARCHAR(30) DEFAULT 'unpaid', -- 'unpaid', 'partial', 'paid'
    pdf_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, invoice_id)
);

CREATE INDEX IF NOT EXISTS idx_invoices_tenant ON public.invoices(tenant_id);
CREATE INDEX IF NOT EXISTS idx_invoices_shop ON public.invoices(tenant_id, shop_id);
CREATE INDEX IF NOT EXISTS idx_invoices_number ON public.invoices(tenant_id, invoice_number);

-- ============================================================================
-- 8. PAYMENTS & COLLECTIONS
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    shop_id VARCHAR(64) NOT NULL,
    invoice_id VARCHAR(64),
    amount NUMERIC(12, 2) NOT NULL,
    mode VARCHAR(30) NOT NULL DEFAULT 'cash', -- 'cash', 'upi', 'razorpay', 'cheque'
    status VARCHAR(30) DEFAULT 'success', -- 'pending', 'success', 'failed'
    reference VARCHAR(150),
    collected_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    payment_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, payment_id)
);

CREATE INDEX IF NOT EXISTS idx_payments_tenant ON public.payments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_payments_shop ON public.payments(tenant_id, shop_id);

-- ============================================================================
-- 9. DOUBLE-ENTRY KHATA LEDGER
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    shop_id VARCHAR(64) NOT NULL,
    invoice_id VARCHAR(64),
    payment_id VARCHAR(64),
    transaction_type VARCHAR(50) NOT NULL, -- 'invoice', 'payment', 'adjustment', 'reversal'
    debit NUMERIC(12, 2) DEFAULT 0.00,
    credit NUMERIC(12, 2) DEFAULT 0.00,
    balance_after NUMERIC(12, 2) NOT NULL,
    description TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, entry_id)
);

CREATE INDEX IF NOT EXISTS idx_ledger_tenant_shop ON public.ledger_entries(tenant_id, shop_id);
CREATE INDEX IF NOT EXISTS idx_ledger_created_at ON public.ledger_entries(created_at DESC);

-- ============================================================================
-- 10. VISITS (Field Sales Force Automation)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    visit_id VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    shop_id VARCHAR(64) NOT NULL,
    sales_person_uid UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    scheduled_date TIMESTAMPTZ DEFAULT NOW(),
    completed_date TIMESTAMPTZ,
    status VARCHAR(30) DEFAULT 'completed', -- 'upcoming', 'completed', 'missed', 'cancelled'
    purpose VARCHAR(100) DEFAULT 'Order & Collection',
    notes TEXT,
    order_taken BOOLEAN DEFAULT FALSE,
    payment_collected BOOLEAN DEFAULT FALSE,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, visit_id)
);

CREATE INDEX IF NOT EXISTS idx_visits_tenant ON public.visits(tenant_id);
CREATE INDEX IF NOT EXISTS idx_visits_shop ON public.visits(tenant_id, shop_id);

-- ============================================================================
-- 11. PLATFORM SETTINGS (Global Configuration managed by Web Admin)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.platform_settings (
    id VARCHAR(64) PRIMARY KEY, -- 'pricing_and_plans', 'remote_config', 'broadcast', 'general_settings'
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 12. PRINTER HARDWARE ORDERS (Fulfillment Logistics)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.printer_hardware_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id VARCHAR(64) UNIQUE NOT NULL,
    tenant_id VARCHAR(64) REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    business_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(150),
    phone VARCHAR(20) NOT NULL,
    shipping_address TEXT NOT NULL,
    printer_model VARCHAR(100) DEFAULT '58mm Standard Bluetooth POS Thermal Printer',
    quantity INTEGER DEFAULT 1,
    unit_price NUMERIC(12, 2) DEFAULT 2499.00,
    total_amount NUMERIC(12, 2) DEFAULT 2499.00,
    payment_status VARCHAR(30) DEFAULT 'paid',
    fulfillment_status VARCHAR(30) DEFAULT 'processing', -- 'processing', 'in transit', 'dispatched', 'delivered'
    tracking_number VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 12b. NOTIFICATIONS & IN-APP BROADCASTS
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id VARCHAR(64) UNIQUE NOT NULL,
    tenant_id VARCHAR(64) REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    target_uid VARCHAR(64),
    target_role VARCHAR(50),
    type VARCHAR(50) NOT NULL DEFAULT 'system', -- 'payment_due', 'payment', 'inventory', 'order', 'sync', 'system', 'broadcast'
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT FALSE,
    is_broadcast BOOLEAN DEFAULT FALSE,
    created_by VARCHAR(64) DEFAULT 'system',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_tenant_id ON public.notifications (tenant_id);
CREATE INDEX IF NOT EXISTS idx_notifications_target_uid ON public.notifications (target_uid);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications (created_at DESC);

-- ============================================================================
-- 13. RBAC HELPER FUNCTIONS (STABLE & SECURITY DEFINER)
-- ============================================================================

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

-- ============================================================================
-- 14. AUTHENTICATION TRIGGER (auth.users -> public.profiles)
-- ============================================================================
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

-- Administrative Role Assignment RPC
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

-- ============================================================================
-- 15. AUTOMATIC UPDATED_AT TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tenants_updated_at ON public.tenants;
CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at ON public.products;
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_shops_updated_at ON public.shops;
CREATE TRIGGER trg_shops_updated_at BEFORE UPDATE ON public.shops FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_orders_updated_at ON public.orders;
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_invoices_updated_at ON public.invoices;
CREATE TRIGGER trg_invoices_updated_at BEFORE UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- 16. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS across all tables
ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.printer_hardware_orders ENABLE ROW LEVEL SECURITY;

-- Platform Settings Policies
DROP POLICY IF EXISTS "platform_settings_select" ON public.platform_settings;
DROP POLICY IF EXISTS "platform_settings_write" ON public.platform_settings;
CREATE POLICY "platform_settings_select" ON public.platform_settings FOR SELECT TO public USING (TRUE);
CREATE POLICY "platform_settings_write" ON public.platform_settings FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

-- Tenants Policies
DROP POLICY IF EXISTS "tenants_all_access" ON public.tenants;
CREATE POLICY "tenants_all_access" ON public.tenants FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

-- Profiles Policies
DROP POLICY IF EXISTS "profiles_all_access" ON public.profiles;
CREATE POLICY "profiles_all_access" ON public.profiles FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

-- Products & Categories Policies
DROP POLICY IF EXISTS "products_all_access" ON public.products;
CREATE POLICY "products_all_access" ON public.products FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS "categories_all_access" ON public.categories;
CREATE POLICY "categories_all_access" ON public.categories FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

-- Shops Policies
DROP POLICY IF EXISTS "shops_all_access" ON public.shops;
CREATE POLICY "shops_all_access" ON public.shops FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

-- Orders & Order Items Policies
DROP POLICY IF EXISTS "orders_all_access" ON public.orders;
CREATE POLICY "orders_all_access" ON public.orders FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS "order_items_all_access" ON public.order_items;
CREATE POLICY "order_items_all_access" ON public.order_items FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

-- Invoices, Payments, Ledger Entries Policies
DROP POLICY IF EXISTS "invoices_all_access" ON public.invoices;
CREATE POLICY "invoices_all_access" ON public.invoices FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS "payments_all_access" ON public.payments;
CREATE POLICY "payments_all_access" ON public.payments FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

DROP POLICY IF EXISTS "ledger_all_access" ON public.ledger_entries;
CREATE POLICY "ledger_all_access" ON public.ledger_entries FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

-- Visits Policies
DROP POLICY IF EXISTS "visits_all_access" ON public.visits;
CREATE POLICY "visits_all_access" ON public.visits FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

-- Printer Hardware Orders Policies
DROP POLICY IF EXISTS "printer_hardware_orders_all_access" ON public.printer_hardware_orders;
CREATE POLICY "printer_hardware_orders_all_access" ON public.printer_hardware_orders FOR ALL TO authenticated, anon USING (TRUE) WITH CHECK (TRUE);

-- ============================================================================
-- 17. REALTIME REPLICATION (Instant SSE/Websocket stream to Mobile & Web)
-- ============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.platform_settings;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.tenants;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.shops;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.invoices;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.ledger_entries;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.printer_hardware_orders;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- ============================================================================
-- 18. INITIAL SEED DATA & SYSTEM DEFAULTS
-- ============================================================================

-- A. Default Pricing, Plans, Printers, & Coupons
INSERT INTO public.platform_settings (id, data, updated_at)
VALUES (
    'pricing_and_plans',
    '{
        "plans": {
            "silverPrice": 399,
            "goldPrice": 599,
            "platinumPrice": 899,
            "printerPrice": 2499,
            "planGst": 18,
            "printerGst": 18,
            "tiers": [
                {
                    "id": "startup",
                    "name": "Startup",
                    "badge": "Starter Pass",
                    "monthlyPrice": 399,
                    "yearlyPrice": 3828,
                    "yearlyMonthlyEquivalent": 319,
                    "features": ["Up to 5 Users included", "Up to 200 Retail Shops", "Standard GST Invoicing", "58mm Thermal Printing"],
                    "highlight": false,
                    "maxUsers": 5,
                    "maxShops": 200
                },
                {
                    "id": "grow",
                    "name": "Grow",
                    "badge": "Most Popular",
                    "monthlyPrice": 599,
                    "yearlyPrice": 5748,
                    "yearlyMonthlyEquivalent": 479,
                    "features": ["Up to 15 Users included", "Up to 1,000 Retail Shops", "Dynamic UPI QR on Bills", "Khata Ledgers & PDF Export"],
                    "highlight": true,
                    "maxUsers": 15,
                    "maxShops": 1000
                },
                {
                    "id": "enterprise",
                    "name": "Enterprise",
                    "badge": "Regional Giant",
                    "monthlyPrice": 899,
                    "yearlyPrice": 8628,
                    "yearlyMonthlyEquivalent": 719,
                    "features": ["Unlimited Staff Seats", "Unlimited Store Directory", "Automated Daily Backups", "VIP Dedicated Support"],
                    "highlight": false,
                    "maxUsers": 100,
                    "maxShops": 10000
                }
            ]
        },
        "printerOptions": [
            {
                "id": "printer_58mm_std",
                "name": "58mm Standard Bluetooth POS Thermal Printer",
                "price": 2499,
                "gstRate": 18,
                "paperWidth": "58mm (2-inch)",
                "connectivity": "Bluetooth + USB",
                "description": "Compact wireless receipt printer ideal for mobile delivery vans and quick counter billing.",
                "features": ["Up to 90mm/s speed", "Drop-in paper roll", "1500mAh rechargeable battery", "Android & iOS ready"],
                "isActive": true,
                "isDefault": true
            },
            {
                "id": "printer_80mm_pro",
                "name": "80mm High-Speed Wireless Countertop POS Printer",
                "price": 4299,
                "gstRate": 18,
                "paperWidth": "80mm (3-inch)",
                "connectivity": "Bluetooth + USB + LAN",
                "description": "Full-width heavy-duty billing printer with auto-cutter for high volume agency godowns.",
                "features": ["250mm/s ultra fast print", "Automatic paper cutter", "Wall mountable", "Dual connectivity"],
                "isActive": true,
                "isDefault": false
            }
        ],
        "coupons": [
            {
                "id": "c_1",
                "code": "TRIAL30",
                "type": "trial",
                "title": "30 Days Extended Trial Pass",
                "value": 30,
                "minOrderValue": 0,
                "usedCount": 42,
                "maxUses": 200,
                "validUntil": "2027-12-31",
                "isActive": true,
                "description": "Grants 30 days full premium membership access for new agency onboarding."
            },
            {
                "id": "c_2",
                "code": "TRIAL14",
                "type": "trial",
                "title": "14 Days Free Pass",
                "value": 14,
                "minOrderValue": 0,
                "usedCount": 118,
                "maxUses": 500,
                "validUntil": "2027-12-31",
                "isActive": true,
                "description": "Standard 2-week unrestricted access for demo campaigns."
            },
            {
                "id": "c_3",
                "code": "FLAT100",
                "type": "flat",
                "title": "Flat ₹100 Off",
                "value": 100,
                "minOrderValue": 500,
                "usedCount": 89,
                "maxUses": 1000,
                "validUntil": "2027-12-31",
                "isActive": true,
                "description": "Direct cash deduction on any membership renewal."
            }
        ]
    }'::jsonb,
    NOW()
)
ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = NOW();

-- B. Default Remote Configuration (Feature Flags, Maintenance, Min App Version)
INSERT INTO public.platform_settings (id, data, updated_at)
VALUES (
    'remote_config',
    '{
        "minAppVersion": "1.0.0",
        "enforceUpdate": false,
        "maintenance": {
            "active": false,
            "message": "System under scheduled platform optimization. Services will resume shortly.",
            "eta": "15 mins"
        },
        "featureFlags": {
            "order_taking": true,
            "gst_invoicing": true,
            "collections": true,
            "gps_tracking": true,
            "thermal_printer": true,
            "soundbox_audio": true,
            "staff_management": true,
            "van_stock": true,
            "customer_portal": true,
            "instant_sync": true,
            "purchases": true,
            "expenses": true,
            "reports": true,
            "thermalPrinting": true,
            "dynamicUpi": true,
            "khataLedger": true,
            "vanDeliveryTracking": true,
            "offlineOutbox": true,
            "mockGpsDetection": true,
            "geoFenceStrictEnforcement": false
        }
    }'::jsonb,
    NOW()
)
ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = NOW();

-- C. Default Broadcast Announcement
INSERT INTO public.platform_settings (id, data, updated_at)
VALUES (
    'broadcast',
    '{
        "active": false,
        "title": "Welcome to SalesArmy",
        "message": "Enterprise field sales operations are live and synchronized.",
        "severity": "info",
        "actionText": "OK",
        "actionUrl": "",
        "timestamp": "2026-10-17T00:00:00.000Z"
    }'::jsonb,
    NOW()
)
ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = NOW();

-- D. Default General Platform Branding & UPI Settings
INSERT INTO public.platform_settings (id, data, updated_at)
VALUES (
    'general_settings',
    '{
        "supportPhone": "+91 80000 99999",
        "supportEmail": "support@salesarmy.in",
        "companyName": "SalesArmy Enterprise Technologies Pvt Ltd",
        "cin": "U72900MH2024PTC123456",
        "gstin": "27AABCS9999P1Z8",
        "upiVpa": "salesarmy@hdfcbank",
        "currency": "INR",
        "maintenanceMode": false
    }'::jsonb,
    NOW()
)
ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = NOW();

-- E. Seed Default Primary Tenants
INSERT INTO public.tenants (
    tenant_id,
    business_name,
    legal_name,
    contact_person,
    mobile,
    email,
    city,
    state,
    plan_id,
    subscription_status,
    subscription_end_date,
    is_active
) VALUES 
(
    'platform_tenant',
    'Selxo FMCG Distributions Pvt Ltd',
    'Selxo FMCG Distributions Private Limited',
    'Somesh Verma',
    '+91 9876543210',
    'somesh@distributor.in',
    'Mumbai',
    'Maharashtra',
    'grow',
    'active',
    NOW() + INTERVAL '1 year',
    TRUE
),
(
    'tenant_shree_ganesh_traders',
    'Shree Ganesh FMCG Distributors',
    'Shree Ganesh Traders & FMCG Hub',
    'Vikram Malhotra',
    '+91 9820123456',
    'distributor@salesarmy.com',
    'New Delhi',
    'Delhi',
    'enterprise',
    'active',
    NOW() + INTERVAL '1 year',
    TRUE
)
ON CONFLICT (tenant_id) DO UPDATE SET
    business_name = EXCLUDED.business_name,
    subscription_status = EXCLUDED.subscription_status,
    is_active = EXCLUDED.is_active;

-- F. Seed Demo Retail Shops
INSERT INTO public.shops (
    shop_id,
    tenant_id,
    shop_name,
    owner_name,
    phone,
    whatsapp,
    business_type,
    category,
    address,
    city,
    state,
    gstin,
    credit_limit,
    current_outstanding,
    is_active
) VALUES 
(
    'SHP-LIVE-TEST-01',
    'platform_tenant',
    'Shree Ganesh Supermarket',
    'Ganesh Shinde',
    '+91 9819001122',
    '+91 9819001122',
    'Supermarket',
    'Supermarket',
    'Station Road, Bandra West',
    'Mumbai',
    'Maharashtra',
    '27ABCDE1234F1Z5',
    50000.00,
    12500.00,
    TRUE
),
(
    'SHP-002',
    'platform_tenant',
    'Balaji Daily Provisions',
    'Mahesh Sharma',
    '+91 9820054321',
    '+91 9820054321',
    'Retail Kirana',
    'General Store',
    'Sector 17, Vashi',
    'Navi Mumbai',
    'Maharashtra',
    '27BCDFG2345G2Z6',
    35000.00,
    4200.00,
    TRUE
)
ON CONFLICT (tenant_id, shop_id) DO UPDATE SET
    shop_name = EXCLUDED.shop_name,
    current_outstanding = EXCLUDED.current_outstanding;

-- G. Seed Demo Products & Inventory SKUs
INSERT INTO public.products (
    product_id,
    tenant_id,
    name,
    variant,
    sku,
    barcode,
    hsn_sac,
    base_price,
    selling_price,
    gst_rate,
    stock_quantity,
    low_stock_threshold,
    unit,
    is_active
) VALUES 
(
    'PROD-LIVE-TEST-01',
    'platform_tenant',
    'Fortune Sunflower Refined Oil 1L',
    '1 Litre Pouch',
    'SKU-OIL-1L-001',
    '890103000001',
    '1512',
    120.00,
    135.00,
    5.00,
    240,
    25,
    'POUCH',
    TRUE
),
(
    'PROD-TEA-002',
    'platform_tenant',
    'Tata Tea Gold 500g',
    '500g Carton',
    'SKU-TEA-500G',
    '890103000002',
    '0902',
    280.00,
    310.00,
    5.00,
    150,
    20,
    'BOX',
    TRUE
)
ON CONFLICT (tenant_id, product_id) DO UPDATE SET
    selling_price = EXCLUDED.selling_price,
    stock_quantity = EXCLUDED.stock_quantity;

-- H. Seed Sample Hardware Printer Orders
INSERT INTO public.printer_hardware_orders (
    order_id,
    tenant_id,
    business_name,
    contact_person,
    phone,
    shipping_address,
    printer_model,
    quantity,
    unit_price,
    total_amount,
    payment_status,
    fulfillment_status,
    tracking_number
) VALUES 
(
    'PO-98214',
    'platform_tenant',
    'Selxo FMCG Distributions',
    'Rajesh Sharma',
    '+91 9820123456',
    'Godown 4B, APMC Market Yard, Vashi, Navi Mumbai 400703',
    '58mm Standard Bluetooth POS Thermal Printer',
    1,
    2499.00,
    2499.00,
    'paid',
    'dispatched',
    'BD-84729103'
)
ON CONFLICT (order_id) DO UPDATE SET
    fulfillment_status = EXCLUDED.fulfillment_status,
    tracking_number = EXCLUDED.tracking_number;

-- ============================================================================
-- ✅ VERIFICATION QUERY: Run this to confirm successful setup
-- ============================================================================
SELECT 
    'tenants' AS table_name, count(*) AS total_rows FROM public.tenants
UNION ALL
SELECT 'platform_settings', count(*) FROM public.platform_settings
UNION ALL
SELECT 'products', count(*) FROM public.products
UNION ALL
SELECT 'shops', count(*) FROM public.shops
UNION ALL
SELECT 'orders', count(*) FROM public.orders
UNION ALL
SELECT 'invoices', count(*) FROM public.invoices
UNION ALL
SELECT 'printer_hardware_orders', count(*) FROM public.printer_hardware_orders;
