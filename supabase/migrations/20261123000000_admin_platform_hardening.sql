-- ============================================================================
-- 20261123000000_admin_platform_hardening.sql
--
-- Security + correctness fixes found in the 2026-11-23 admin/backend audit.
-- Idempotent: safe to run whether or not 20261113000000 applied cleanly.
--
--   1. Profile authority comes ONLY from app_metadata (server-controlled).
--      user_metadata is user-editable (supabase.auth.updateUser) and was used
--      to self-promote to super_admin / hop tenants. Trigger now fires on
--      INSERT only, and never rewrites role/tenant of an existing profile.
--   2. Billing RPCs no longer run for anonymous callers (anon key is public).
--   3. RLS policies from 20261113 rebuilt with correct types; platform
--      settings readable only for published rows + the caller's own tenant.
--   4. protect_shop_balance no longer silently cancels DELETEs.
--   5. Coupons moved to an admin-only settings row (were publicly readable).
--   6. Admin audit log table, platform stats + integrity report RPCs,
--      manual checkout settlement RPC.
--
-- After applying, review who holds super_admin:
--   SELECT id, email, role, tenant_id FROM public.profiles WHERE role = 'super_admin';
-- ============================================================================
BEGIN;

-- ----------------------------------------------------------------------------
-- 1. PROFILE PROVISIONING
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_role text := NULLIF(NEW.raw_app_meta_data->>'role', '');
  v_tenant text := NULLIF(NEW.raw_app_meta_data->>'tenant_id', '');
BEGIN
  -- Self-registered users become owners of no agency; they create one via
  -- onboard_agency_owner(). Staff/admin roles are only ever set by the
  -- trusted backend through app_metadata.
  IF v_role IS NULL OR v_role NOT IN ('super_admin','owner','distributor','sales_person','accountant','delivery_agent','manager') THEN
    v_role := 'owner';
  END IF;
  IF v_tenant IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.tenants WHERE tenant_id = v_tenant) THEN
    v_tenant := NULL;
  END IF;

  INSERT INTO public.profiles (id, name, email, phone, role, tenant_id, account_status, is_active)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'name', ''), NULLIF(NEW.raw_user_meta_data->>'full_name', ''), split_part(NEW.email, '@', 1), 'User'),
    NEW.email, NEW.phone, v_role, v_tenant, 'active', true
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Keep profile e-mail in sync without touching authority columns.
CREATE OR REPLACE FUNCTION public.sync_profile_email() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.profiles SET email = NEW.email, updated_at = now() WHERE id = NEW.id;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_auth_user_email_changed ON auth.users;
CREATE TRIGGER on_auth_user_email_changed
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW WHEN (OLD.email IS DISTINCT FROM NEW.email)
  EXECUTE FUNCTION public.sync_profile_email();

-- ----------------------------------------------------------------------------
-- 2. BILLING RPC ACCESS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assert_sales_access(p_tenant text) RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.role() = 'service_role' THEN RETURN; END IF;
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT public.is_super_admin() AND (
       p_tenant IS DISTINCT FROM public.get_auth_tenant_id()
       OR COALESCE(public.get_auth_role(), '') NOT IN ('owner','distributor','sales_person','salesman','accountant','delivery_agent','delivery','manager','store_manager')
     ) THEN
    RAISE EXCEPTION 'Unauthorized tenant operation';
  END IF;
  -- Freemium guarantee: an expired plan never blocks core selling. Only an
  -- administrator suspension does.
  IF NOT EXISTS (
    SELECT 1 FROM public.tenants
    WHERE tenant_id = p_tenant AND is_active
      AND COALESCE(subscription_status, 'active') NOT IN ('suspended','cancelled','paused')
  ) THEN
    RAISE EXCEPTION 'Tenant is inactive';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.record_invoice(p_tenant text, p_invoice jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  inv_id text := COALESCE(p_invoice->>'invoiceId', p_invoice->>'invoice_id');
  shop text := COALESCE(p_invoice->>'shopId', p_invoice->>'shop_id');
  item jsonb; qty integer; price numeric; rate numeric;
  subtotal numeric := 0; gst numeric := 0; cgst numeric := 0; sgst numeric := 0;
  balance numeric; interstate boolean; total numeric;
BEGIN
  PERFORM public.assert_sales_access(p_tenant);
  IF public.get_auth_role() IN ('delivery','delivery_agent','manager','store_manager') THEN
    RAISE EXCEPTION 'Billing permission required';
  END IF;
  IF inv_id IS NULL OR inv_id = '' THEN RAISE EXCEPTION 'Invoice ID required'; END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant || ':invoice:' || inv_id, 0));
  IF EXISTS (SELECT 1 FROM public.invoices WHERE tenant_id = p_tenant AND invoice_id = inv_id) THEN
    RETURN jsonb_build_object('invoiceId', inv_id, 'replayed', true);
  END IF;

  SELECT current_outstanding INTO balance FROM public.shops WHERE tenant_id = p_tenant AND shop_id = shop FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shop not found'; END IF;
  balance := COALESCE(balance, 0);

  IF jsonb_typeof(p_invoice->'items') IS DISTINCT FROM 'array' OR jsonb_array_length(p_invoice->'items') = 0 THEN
    RAISE EXCEPTION 'Invoice items required';
  END IF;

  interstate := COALESCE(p_invoice->'seller'->>'stateCode', p_invoice->'seller_details'->>'stateCode', '27')
             <> COALESCE(p_invoice->'buyer'->>'stateCode', p_invoice->'buyer_details'->>'stateCode', '27');

  FOR item IN SELECT * FROM jsonb_array_elements(p_invoice->'items') LOOP
    qty := (item->>'quantity')::integer;
    price := COALESCE(item->>'unitPrice', item->>'rate')::numeric;
    rate := CASE WHEN COALESCE(p_invoice->>'invoiceType', p_invoice->>'invoice_type') IN ('estimate','estimated','non_gst','NON_GST') THEN 0
                 ELSE COALESCE((item->>'gstRate')::numeric, 0) END;
    IF qty IS NULL OR qty <= 0 OR price IS NULL OR price < 0 OR rate < 0 OR rate > 100 THEN
      RAISE EXCEPTION 'Invalid invoice item';
    END IF;
    subtotal := subtotal + round(qty * price, 2);
    IF interstate THEN gst := gst + round(qty * price * rate / 100, 2);
    ELSE cgst := cgst + round(qty * price * rate / 200, 2); sgst := sgst + round(qty * price * rate / 200, 2); END IF;
    -- Offline-first: stock never goes negative, oversell is allowed (mobile
    -- reconciles stock from purchases). Unknown products are ignored.
    UPDATE public.products SET stock_quantity = GREATEST(0, stock_quantity - qty)
     WHERE tenant_id = p_tenant AND product_id = COALESCE(item->>'productId', item->>'product_id');
  END LOOP;

  total := subtotal + gst + cgst + sgst;
  INSERT INTO public.invoices (invoice_id, invoice_number, tenant_id, order_id, shop_id, invoice_type,
    seller_details, buyer_details, items, taxable_amount, cgst, sgst, igst, total_gst, grand_total, amount_due)
  VALUES (inv_id, COALESCE(p_invoice->>'invoiceNumber', p_invoice->>'invoice_number', inv_id), p_tenant,
    NULLIF(COALESCE(p_invoice->>'orderId', p_invoice->>'order_id'), ''), shop,
    COALESCE(p_invoice->>'invoiceType', p_invoice->>'invoice_type', 'gst'),
    COALESCE(p_invoice->'seller', p_invoice->'seller_details', '{}'::jsonb),
    COALESCE(p_invoice->'buyer', p_invoice->'buyer_details', '{}'::jsonb),
    p_invoice->'items', subtotal, cgst, sgst, gst, gst + cgst + sgst, total, total);

  UPDATE public.shops SET current_outstanding = balance + total WHERE tenant_id = p_tenant AND shop_id = shop;
  INSERT INTO public.ledger_entries (entry_id, tenant_id, shop_id, invoice_id, transaction_type, debit, credit, balance_after, description)
  VALUES ('INV-' || inv_id, p_tenant, shop, inv_id, 'invoice', total, 0, balance + total, 'Invoice ' || inv_id);

  RETURN jsonb_build_object('invoiceId', inv_id, 'grandTotal', total, 'balanceAfter', balance + total);
END $$;

REVOKE ALL ON FUNCTION public.record_invoice(text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.record_payment(text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancel_invoice(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sync_save_order(text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_invoice(text, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_payment(text, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancel_invoice(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sync_save_order(text, text, jsonb) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 3. RLS POLICIES (rebuild the ones 20261113 attempted, with correct types)
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "tenants_insert_rbac" ON public.tenants;   -- agencies are created via onboard_agency_owner / backend
DROP POLICY IF EXISTS "tenants_select_rbac" ON public.tenants;
DROP POLICY IF EXISTS "tenants_update_rbac" ON public.tenants;
DROP POLICY IF EXISTS "tenants_delete_rbac" ON public.tenants;
CREATE POLICY "tenants_select_rbac" ON public.tenants FOR SELECT TO authenticated
  USING (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id());
CREATE POLICY "tenants_update_rbac" ON public.tenants FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR (tenant_id = public.get_auth_tenant_id() AND public.get_auth_role() IN ('owner','distributor')))
  WITH CHECK (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id());
CREATE POLICY "tenants_delete_rbac" ON public.tenants FOR DELETE TO authenticated
  USING (public.is_super_admin());

DROP POLICY IF EXISTS "profiles_select_rbac" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_rbac" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_rbac" ON public.profiles;
CREATE POLICY "profiles_select_rbac" ON public.profiles FOR SELECT TO authenticated
  USING (public.is_super_admin() OR id = auth.uid() OR tenant_id = public.get_auth_tenant_id());
CREATE POLICY "profiles_insert_rbac" ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR id = auth.uid());
-- protect_profile_authority still blocks role / tenant / status changes by non-admins.
CREATE POLICY "profiles_update_rbac" ON public.profiles FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR id = auth.uid() OR (tenant_id = public.get_auth_tenant_id() AND public.get_auth_role() IN ('owner','distributor')))
  WITH CHECK (public.is_super_admin() OR id = auth.uid() OR tenant_id = public.get_auth_tenant_id());

DROP POLICY IF EXISTS "order_items_select_tenant" ON public.order_items;
DROP POLICY IF EXISTS "order_items_write_tenant" ON public.order_items;
CREATE POLICY "order_items_select_tenant" ON public.order_items FOR SELECT TO authenticated
  USING (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_items.order_id AND o.tenant_id = public.get_auth_tenant_id()));
CREATE POLICY "order_items_write_tenant" ON public.order_items FOR ALL TO authenticated
  USING (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_items.order_id AND o.tenant_id = public.get_auth_tenant_id()))
  WITH CHECK (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_items.order_id AND o.tenant_id = public.get_auth_tenant_id()));

-- Platform settings: published rows for everyone, own-tenant rows for members,
-- everything else (coupons, gateway_config, other tenants) admin only.
DROP POLICY IF EXISTS "platform_settings_read" ON public.platform_settings;
DROP POLICY IF EXISTS "platform_settings_write" ON public.platform_settings;
DROP POLICY IF EXISTS "public_gateway_metadata" ON public.platform_settings;
DROP POLICY IF EXISTS "published_settings" ON public.platform_settings;
CREATE POLICY "published_settings" ON public.platform_settings FOR SELECT TO anon, authenticated
  USING (id IN ('pricing_and_plans','remote_config','broadcast','general_settings'));
CREATE POLICY "platform_settings_write" ON public.platform_settings FOR ALL TO authenticated
  USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());
-- (tenant_settings and admin_all from 20261026000000 remain in force.)

-- ----------------------------------------------------------------------------
-- 4. SHOP BALANCE GUARD
-- ----------------------------------------------------------------------------
-- The mobile client still writes current_outstanding directly, so balances
-- are clamped (not blocked). The previous version returned NEW for DELETE,
-- which is NULL and silently cancelled every shop delete and tenant cascade.
CREATE OR REPLACE FUNCTION public.protect_shop_balance() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF current_user = 'authenticated' AND NOT public.is_super_admin()
       AND EXISTS (SELECT 1 FROM public.invoices WHERE tenant_id = OLD.tenant_id AND shop_id = OLD.shop_id AND cancelled_at IS NULL AND amount_due > 0) THEN
      RAISE EXCEPTION 'A shop with unpaid invoices cannot be deleted';
    END IF;
    RETURN OLD;
  END IF;
  IF NEW.current_outstanding IS NULL OR NEW.current_outstanding < 0 THEN
    NEW.current_outstanding := GREATEST(COALESCE(NEW.current_outstanding, 0), 0);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS protect_shop_balance ON public.shops;
CREATE TRIGGER protect_shop_balance BEFORE INSERT OR UPDATE OR DELETE ON public.shops
  FOR EACH ROW EXECUTE FUNCTION public.protect_shop_balance();

-- ----------------------------------------------------------------------------
-- 5. COUPONS: move out of the public pricing row
-- ----------------------------------------------------------------------------
INSERT INTO public.platform_settings (id, data, updated_at)
SELECT 'coupons', jsonb_build_object('coupons', COALESCE(data->'coupons', '[]'::jsonb)), now()
FROM public.platform_settings WHERE id = 'pricing_and_plans'
ON CONFLICT (id) DO NOTHING;
UPDATE public.platform_settings SET data = data - 'coupons' WHERE id = 'pricing_and_plans' AND data ? 'coupons';

-- Hardware fulfilment tracking fields used by the admin console.
ALTER TABLE public.printer_hardware_orders ADD COLUMN IF NOT EXISTS courier_name text;
ALTER TABLE public.printer_hardware_orders ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS items jsonb NOT NULL DEFAULT '[]';

-- ----------------------------------------------------------------------------
-- 6. ADMIN AUDIT LOG
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id bigserial PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  category text NOT NULL DEFAULT 'ADMIN',
  action text NOT NULL,
  details text NOT NULL DEFAULT '',
  actor_id uuid,
  actor_email text,
  ip text,
  status text NOT NULL DEFAULT 'success',
  target text
);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created ON public.admin_audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_category ON public.admin_audit_logs (category, created_at DESC);
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS admin_audit_read ON public.admin_audit_logs;
CREATE POLICY admin_audit_read ON public.admin_audit_logs FOR SELECT TO authenticated USING (public.is_super_admin());
-- Inserts happen only through the service-role backend; no UPDATE/DELETE policy (append-only).

-- ----------------------------------------------------------------------------
-- 7. ADMIN RPCs (service role only)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_platform_stats() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE result jsonb;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted backend required'; END IF;
  SELECT COALESCE(jsonb_object_agg(t.tenant_id, jsonb_build_object(
    'orders', COALESCE(o.cnt, 0),
    'orderValue', COALESCE(o.total, 0),
    'invoiced', COALESCE(i.total, 0),
    'collected', COALESCE(p.total, 0),
    'outstanding', COALESCE(s.outstanding, 0),
    'shops', COALESCE(s.cnt, 0),
    'users', COALESCE(u.cnt, 0),
    'lastOrderAt', o.last_at
  )), '{}'::jsonb) INTO result
  FROM public.tenants t
  LEFT JOIN (SELECT tenant_id, count(*) cnt, sum(grand_total) total, max(order_date) last_at FROM public.orders WHERE status <> 'cancelled' GROUP BY tenant_id) o ON o.tenant_id = t.tenant_id
  LEFT JOIN (SELECT tenant_id, sum(grand_total) total FROM public.invoices WHERE cancelled_at IS NULL GROUP BY tenant_id) i ON i.tenant_id = t.tenant_id
  LEFT JOIN (SELECT tenant_id, sum(amount) total FROM public.payments WHERE status = 'success' GROUP BY tenant_id) p ON p.tenant_id = t.tenant_id
  LEFT JOIN (SELECT tenant_id, count(*) cnt, sum(current_outstanding) outstanding FROM public.shops GROUP BY tenant_id) s ON s.tenant_id = t.tenant_id
  LEFT JOIN (SELECT tenant_id, count(*) cnt FROM public.profiles GROUP BY tenant_id) u ON u.tenant_id = t.tenant_id;
  RETURN result;
END $$;

-- Ledger integrity: shops whose cached balance differs from their ledger.
CREATE OR REPLACE FUNCTION public.admin_integrity_report() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE drift jsonb; counts jsonb;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted backend required'; END IF;
  SELECT COALESCE(jsonb_agg(x ORDER BY abs(x.difference) DESC), '[]'::jsonb) INTO drift FROM (
    SELECT s.tenant_id, s.shop_id, s.shop_name, s.current_outstanding AS cached,
           COALESCE(l.balance, 0) AS ledger, round(s.current_outstanding - COALESCE(l.balance, 0), 2) AS difference
    FROM public.shops s
    LEFT JOIN (SELECT tenant_id, shop_id, sum(COALESCE(debit,0) - COALESCE(credit,0)) balance FROM public.ledger_entries GROUP BY tenant_id, shop_id) l
      ON l.tenant_id = s.tenant_id AND l.shop_id = s.shop_id
    WHERE abs(s.current_outstanding - COALESCE(l.balance, 0)) >= 0.01
    LIMIT 200
  ) x;
  SELECT jsonb_build_object(
    'tenants', (SELECT count(*) FROM public.tenants),
    'profiles', (SELECT count(*) FROM public.profiles),
    'orphanProfiles', (SELECT count(*) FROM public.profiles p WHERE p.tenant_id IS NULL AND p.role <> 'super_admin'),
    'shops', (SELECT count(*) FROM public.shops),
    'orders', (SELECT count(*) FROM public.orders),
    'invoices', (SELECT count(*) FROM public.invoices),
    'payments', (SELECT count(*) FROM public.payments),
    'ledger_entries', (SELECT count(*) FROM public.ledger_entries),
    'printer_hardware_orders', (SELECT count(*) FROM public.printer_hardware_orders),
    'subscription_checkouts', (SELECT count(*) FROM public.subscription_checkouts)
  ) INTO counts;
  RETURN jsonb_build_object('counts', counts, 'ledgerDrift', drift, 'checkedAt', now());
END $$;

-- Manual settlement for an offline payment (bank transfer / UPI outside the
-- gateway). Records the reference and extends the subscription.
CREATE OR REPLACE FUNCTION public.admin_settle_checkout_manual(p_id uuid, p_reference text, p_mode text DEFAULT 'manual')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE checkout public.subscription_checkouts; tenant public.tenants; expiry timestamptz; days_int integer;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted backend required'; END IF;
  IF COALESCE(trim(p_reference), '') = '' THEN RAISE EXCEPTION 'Payment reference required'; END IF;
  SELECT * INTO checkout FROM public.subscription_checkouts WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Checkout not found'; END IF;
  IF checkout.status = 'paid' THEN
    RETURN jsonb_build_object('id', p_id, 'status', 'paid', 'expiresAt', checkout.subscription_end_date, 'replayed', true);
  END IF;
  days_int := COALESCE((checkout.quote->>'days')::integer, 0);
  IF days_int <= 0 THEN RAISE EXCEPTION 'Invalid plan duration'; END IF;
  SELECT * INTO tenant FROM public.tenants WHERE tenant_id = checkout.tenant_id FOR UPDATE;
  expiry := greatest(now(), COALESCE(tenant.subscription_end_date, now())) + make_interval(days => days_int);
  UPDATE public.tenants SET plan_id = checkout.quote->>'planId',
    subscription_status = CASE WHEN (checkout.quote->>'trial')::boolean THEN 'trial' ELSE 'active' END,
    subscription_end_date = expiry, is_active = true,
    max_users = (checkout.quote->>'maxUsers')::integer, max_shops = (checkout.quote->>'maxShops')::integer
  WHERE tenant_id = checkout.tenant_id;
  IF jsonb_array_length(COALESCE(checkout.quote->'hardware', '[]'::jsonb)) > 0 THEN
    INSERT INTO public.printer_hardware_orders(order_id, tenant_id, business_name, contact_person, phone, shipping_address, printer_model, quantity, unit_price, total_amount, payment_status, fulfillment_status)
    VALUES (p_id::text, checkout.tenant_id, tenant.business_name, COALESCE(tenant.contact_person, ''), tenant.mobile,
      checkout.quote->>'shippingAddress', (SELECT string_agg(value->>'title', ', ') FROM jsonb_array_elements(checkout.quote->'hardware')),
      1, (checkout.quote->>'hardwareAmount')::numeric / 100, (checkout.quote->>'hardwareAmount')::numeric / 100, 'paid', 'processing')
    ON CONFLICT (order_id) DO NOTHING;
  END IF;
  UPDATE public.subscription_checkouts
     SET status = 'paid', payment_id = left(COALESCE(p_mode, 'manual') || ':' || trim(p_reference), 120), paid_at = now(), subscription_end_date = expiry
   WHERE id = p_id;
  RETURN jsonb_build_object('id', p_id, 'status', 'paid', 'expiresAt', expiry);
END $$;

REVOKE ALL ON FUNCTION public.admin_platform_stats() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_integrity_report() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_settle_checkout_manual(uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_platform_stats() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_integrity_report() TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_settle_checkout_manual(uuid, text, text) TO service_role;

COMMIT;
