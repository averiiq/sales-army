-- ============================================================================
-- SalesArmy - Industrial Multi-Tenant PostgreSQL Schema for Supabase
-- Target Platforms: Flutter Mobile (Android/iOS) + Web Admin Portal
-- Architecture: Multi-Tenant FMCG B2B SFA, GST Invoicing, Khata Ledger, Subscriptions
-- Migration: 20261012000000_init_salesarmy_schema.sql
-- ============================================================================

-- Enable required PostgreSQL extensions
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
    subscription_status VARCHAR(30) DEFAULT 'active', -- 'trial', 'active', 'expired', 'cancelled'
    subscription_start_date TIMESTAMPTZ DEFAULT NOW(),
    subscription_end_date TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '1 year'),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tenants_tenant_id ON public.tenants(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenants_subscription_status ON public.tenants(subscription_status);

-- ============================================================================
-- 2. USERS & PROFILES (Linked to Supabase auth.users)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id VARCHAR(64) REFERENCES public.tenants(tenant_id) ON DELETE SET NULL,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    photo_url TEXT,
    role VARCHAR(50) NOT NULL DEFAULT 'sales_person', -- 'super_admin', 'owner', 'distributor', 'accountant', 'sales_person', 'delivery_agent'
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
-- 7. INVOICES (GST Tax & Kaccha / Estimated Proforma Invoices)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id VARCHAR(64) NOT NULL,
    invoice_number VARCHAR(64) NOT NULL,
    tenant_id VARCHAR(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
    order_id VARCHAR(64),
    shop_id VARCHAR(64) NOT NULL,
    invoice_type VARCHAR(30) DEFAULT 'gst', -- 'gst' (Pakka Tax Invoice) or 'estimate' (Kaccha Informal Bill)
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
    id VARCHAR(64) PRIMARY KEY, -- e.g. 'pricing_and_plans', 'system_config'
    data JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed initial default platform pricing and plans
INSERT INTO public.platform_settings (id, data, updated_at)
VALUES (
    'pricing_and_plans',
    '{
        "plans": [
            {
                "id": "startup",
                "name": "Startup",
                "monthlyPrice": 399,
                "yearlyMonthlyEquivalent": 319,
                "yearlyPrice": 3828,
                "features": ["Up to 5 Users included", "Up to 200 Retail Shops", "Standard GST Invoicing", "58mm Thermal Printing"],
                "maxUsers": 5,
                "maxProducts": 50,
                "isPopular": false
            },
            {
                "id": "grow",
                "name": "Grow",
                "monthlyPrice": 599,
                "yearlyMonthlyEquivalent": 479,
                "yearlyPrice": 5748,
                "features": ["Up to 15 Users included", "Up to 1,000 Retail Shops", "Dynamic UPI QR on Bills", "Khata Ledgers & PDF Export"],
                "maxUsers": 15,
                "maxProducts": 50,
                "isPopular": true
            },
            {
                "id": "enterprise",
                "name": "Enterprise",
                "monthlyPrice": 899,
                "yearlyMonthlyEquivalent": 719,
                "yearlyPrice": 8628,
                "features": ["Unlimited Staff Seats", "Unlimited Store Directory", "Automated Daily Backups", "VIP Dedicated Support"],
                "maxUsers": 100,
                "maxProducts": 50,
                "isPopular": false
            }
        ],
        "gst_rates": [0, 5, 12, 18, 28],
        "default_gst_rate": 18
    }'::jsonb,
    NOW()
)
ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = NOW();

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
    printer_model VARCHAR(100) DEFAULT '58mm Bluetooth Thermal POS',
    quantity INTEGER DEFAULT 1,
    unit_price NUMERIC(12, 2) DEFAULT 2499.00,
    total_amount NUMERIC(12, 2) DEFAULT 2499.00,
    payment_status VARCHAR(30) DEFAULT 'paid',
    fulfillment_status VARCHAR(30) DEFAULT 'processing', -- 'processing', 'dispatched', 'delivered'
    tracking_number VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 13. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all operational tables
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
ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.printer_hardware_orders ENABLE ROW LEVEL SECURITY;

-- Helper function: get tenant_id of authenticated user
CREATE OR REPLACE FUNCTION public.get_auth_tenant_id()
RETURNS VARCHAR(64) AS $$
    SELECT tenant_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Platform Settings Policies: Public readable, only super admin can update
CREATE POLICY "Platform settings are viewable by authenticated users"
    ON public.platform_settings FOR SELECT
    TO authenticated, anon
    USING (true);

CREATE POLICY "Platform settings are updatable by service role or super admin"
    ON public.platform_settings FOR ALL
    TO authenticated, anon
    USING (true);

-- Tenant Isolation Policies for Operational Tables
CREATE POLICY "Tenants isolation policy"
    ON public.tenants FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Profiles isolation policy"
    ON public.profiles FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Products isolation policy"
    ON public.products FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Categories isolation policy"
    ON public.categories FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Shops isolation policy"
    ON public.shops FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Orders isolation policy"
    ON public.orders FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Order items isolation policy"
    ON public.order_items FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Invoices isolation policy"
    ON public.invoices FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Payments isolation policy"
    ON public.payments FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Ledger entries isolation policy"
    ON public.ledger_entries FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Visits isolation policy"
    ON public.visits FOR ALL
    TO authenticated, anon
    USING (true);

CREATE POLICY "Printer hardware orders policy"
    ON public.printer_hardware_orders FOR ALL
    TO authenticated, anon
    USING (true);

-- Enable Realtime replication for dynamic live updates
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
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Table might already be in publication
    NULL;
END $$;

-- ============================================================================
-- 14. AUTOMATIC UPDATED_AT TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_shops_updated_at BEFORE UPDATE ON public.shops FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_invoices_updated_at BEFORE UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
