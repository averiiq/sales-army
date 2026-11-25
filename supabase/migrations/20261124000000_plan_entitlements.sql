-- ============================================================================
-- 20261124000000_plan_entitlements.sql
--
-- Removes the free plan and makes plans the single, server-enforced source of
-- what an agency may do.
--
--   1. Helpers that read the admin-managed plan catalog
--      (platform_settings.pricing_and_plans) and general settings
--      (platform_settings.general_settings: defaultPlanId = signup trial plan,
--      defaultTrialDays, trialGracePeriodDays).
--   2. Every new tenant starts on the admin's signup trial plan, whichever
--      signup path created it (onboard_agency_owner RPC, service-role insert,
--      admin API). There is no 'free' / 'freemium' plan any more.
--   3. Existing free / freemium tenants are moved to the signup plan and
--      marked EXPIRED (they must choose a plan).
--   4. Stored plans are upgraded to capabilities v2 so customers keep the
--      features the app never used to lock.
--   5. enforce_plan_entitlements(): BEFORE INSERT guard on shops, products,
--      orders and invoices. Blocks NEW records when the agency is suspended,
--      its plan/trial (+ grace) has ended (read-only), the plan does not
--      include the feature, or a plan limit is reached. Updates to existing
--      rows and payment collection keep working (read-only mode still lets
--      agencies collect dues). Super admins and the service-role backend are
--      never blocked.
--
-- Error messages start with PLAN_EXPIRED:, PLAN_FEATURE:, PLAN_LIMIT: or
-- ACCOUNT_SUSPENDED: so the app can show a friendly upgrade prompt.
-- Idempotent.
-- ============================================================================
BEGIN;

-- ----------------------------------------------------------------------------
-- 1. CATALOG HELPERS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.platform_general_settings() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'defaultPlanId', COALESCE(NULLIF(NULLIF(s.data->>'defaultPlanId', ''), 'free'), 'startup'),
    'defaultTrialDays', GREATEST(1, COALESCE(NULLIF(s.data->>'defaultTrialDays', '')::int, 14)),
    'trialGracePeriodDays', GREATEST(0, COALESCE(NULLIF(s.data->>'trialGracePeriodDays', '')::int, 3))
  )
  FROM (SELECT (SELECT data FROM public.platform_settings WHERE id = 'general_settings') AS data) s;
$$;

-- The plan tier JSON for a plan id, or NULL when the plan does not exist.
CREATE OR REPLACE FUNCTION public.platform_plan_tier(p_plan text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT tier
  FROM public.platform_settings ps,
       LATERAL jsonb_array_elements(
         CASE WHEN jsonb_typeof(ps.data->'plans'->'tiers') = 'array' THEN ps.data->'plans'->'tiers'
              WHEN jsonb_typeof(ps.data->'tiers') = 'array' THEN ps.data->'tiers'
              ELSE '[]'::jsonb END) AS tier
  WHERE ps.id = 'pricing_and_plans' AND tier->>'id' = p_plan
  LIMIT 1;
$$;

-- Capabilities the app did not lock before v2 (granted to un-upgraded plans).
CREATE OR REPLACE FUNCTION public.plan_legacy_features() RETURNS text[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT ARRAY['order_taking','estimate_bills','sales_returns','collections','purchases',
               'expenses','visits','staff_management','thermal_printer','reports'];
$$;

CREATE OR REPLACE FUNCTION public.plan_has_feature(p_tier jsonb, p_key text) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_tier IS NULL THEN true  -- unknown plan: limits fall back to tenant columns, features open
    WHEN COALESCE(p_tier->'allowedFeatures', '[]'::jsonb) ? p_key THEN true
    WHEN COALESCE(NULLIF(p_tier->>'featuresVersion', '')::int, 1) < 2 AND p_key = ANY(public.plan_legacy_features()) THEN true
    ELSE false
  END;
$$;

-- Plan limit (0 / missing = unlimited).
CREATE OR REPLACE FUNCTION public.plan_limit(p_tier jsonb, p_key text, p_fallback integer DEFAULT 0) RETURNS integer
LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(NULLIF(p_tier->>p_key, '')::numeric::int, p_fallback, 0);
$$;

-- 'ok' | 'expired' | 'suspended' for a tenant (trial grace applied).
CREATE OR REPLACE FUNCTION public.tenant_access_state(p_tenant text) RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE t public.tenants; grace int;
BEGIN
  SELECT * INTO t FROM public.tenants WHERE tenant_id = p_tenant;
  IF NOT FOUND THEN RETURN 'suspended'; END IF;
  IF t.is_active IS FALSE OR COALESCE(t.subscription_status, '') IN ('suspended','cancelled','paused') THEN
    RETURN 'suspended';
  END IF;
  IF COALESCE(t.subscription_status, '') IN ('expired','free','freemium') THEN RETURN 'expired'; END IF;
  IF t.subscription_end_date IS NOT NULL THEN
    grace := CASE WHEN t.subscription_status = 'trial'
                  THEN (public.platform_general_settings()->>'trialGracePeriodDays')::int ELSE 0 END;
    IF now() > t.subscription_end_date + make_interval(days => grace) THEN RETURN 'expired'; END IF;
  END IF;
  RETURN 'ok';
END $$;

-- ----------------------------------------------------------------------------
-- 2. SIGNUP TRIAL FOR EVERY NEW TENANT
-- ----------------------------------------------------------------------------
-- No column defaults that silently grant a plan (the original schema gave
-- every insert 'grow' for a year).
ALTER TABLE public.tenants ALTER COLUMN plan_id DROP DEFAULT;
ALTER TABLE public.tenants ALTER COLUMN subscription_end_date DROP DEFAULT;
ALTER TABLE public.tenants ALTER COLUMN subscription_status SET DEFAULT 'trial';

CREATE OR REPLACE FUNCTION public.apply_signup_trial() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s jsonb; tier jsonb; plan text; days int;
BEGIN
  IF COALESCE(NEW.plan_id, '') IN ('', 'free')
     OR COALESCE(NEW.subscription_status, '') IN ('', 'free', 'freemium') THEN
    s := public.platform_general_settings();
    plan := s->>'defaultPlanId';
    tier := public.platform_plan_tier(plan);
    days := (s->>'defaultTrialDays')::int;
    NEW.plan_id := plan;
    NEW.subscription_status := 'trial';
    NEW.subscription_start_date := COALESCE(NEW.subscription_start_date, now());
    NEW.subscription_end_date := now() + make_interval(days => days);
    NEW.max_users := public.plan_limit(tier, 'maxStaff', public.plan_limit(tier, 'maxUsers', 1));
    NEW.max_shops := public.plan_limit(tier, 'maxShops', 200);
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS apply_signup_trial ON public.tenants;
CREATE TRIGGER apply_signup_trial BEFORE INSERT ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.apply_signup_trial();

-- onboard_agency_owner: plan columns left empty -> apply_signup_trial fills them.
CREATE OR REPLACE FUNCTION public.onboard_agency_owner(
  p_business_name text,
  p_contact_person text,
  p_mobile text,
  p_city text,
  p_gstin text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_profile public.profiles;
  v_email text;
  v_slug text;
  v_tenant_id text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Sign in required';
  END IF;
  IF COALESCE(trim(p_business_name), '') = '' OR COALESCE(trim(p_contact_person), '') = ''
     OR COALESCE(trim(p_mobile), '') = '' OR COALESCE(trim(p_city), '') = '' THEN
    RAISE EXCEPTION 'Agency name, owner name, mobile and city are required';
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

  INSERT INTO public.profiles (id, name, email, role, account_status, is_active)
  VALUES (v_uid, trim(p_contact_person), v_email, 'owner', 'active', true)
  ON CONFLICT (id) DO NOTHING;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_uid FOR UPDATE;
  IF v_profile.tenant_id IS NOT NULL THEN
    RAISE EXCEPTION 'This account already belongs to an agency';
  END IF;

  v_slug := left(regexp_replace(lower(trim(p_business_name)), '[^a-z0-9]+', '_', 'g'), 24);
  v_tenant_id := 'tenant_' || v_slug || '_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);

  INSERT INTO public.tenants (tenant_id, business_name, contact_person, email, mobile, city, gstin,
                              plan_id, subscription_status, is_active)
  VALUES (v_tenant_id, trim(p_business_name), trim(p_contact_person), v_email, trim(p_mobile), trim(p_city),
          NULLIF(upper(trim(COALESCE(p_gstin, ''))), ''), NULL, NULL, true);

  UPDATE public.profiles
     SET tenant_id = v_tenant_id,
         role = 'owner',
         name = COALESCE(NULLIF(trim(p_contact_person), ''), name),
         phone = COALESCE(NULLIF(trim(p_mobile), ''), phone),
         account_status = 'active',
         is_active = true,
         updated_at = now()
   WHERE id = v_uid;

  RETURN jsonb_build_object('tenant_id', v_tenant_id, 'uid', v_uid);
END $$;

REVOKE ALL ON FUNCTION public.onboard_agency_owner(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.onboard_agency_owner(text, text, text, text, text) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. EXISTING FREE / FREEMIUM TENANTS -> signup plan, EXPIRED
-- ----------------------------------------------------------------------------
UPDATE public.tenants t
   SET plan_id = g.plan,
       subscription_status = 'expired',
       subscription_end_date = now(),
       max_users = public.plan_limit(public.platform_plan_tier(g.plan), 'maxStaff',
                     public.plan_limit(public.platform_plan_tier(g.plan), 'maxUsers', 1)),
       max_shops = public.plan_limit(public.platform_plan_tier(g.plan), 'maxShops', 200),
       updated_at = now()
  FROM (SELECT public.platform_general_settings()->>'defaultPlanId' AS plan) g
 WHERE COALESCE(t.plan_id, '') IN ('', 'free')
    OR COALESCE(t.subscription_status, '') IN ('free', 'freemium');

-- general_settings must never point signups at the old free plan.
UPDATE public.platform_settings
   SET data = jsonb_set(data, '{defaultPlanId}', '"startup"'), updated_at = now()
 WHERE id = 'general_settings' AND COALESCE(data->>'defaultPlanId', '') IN ('', 'free');

-- ----------------------------------------------------------------------------
-- 4. UPGRADE STORED PLANS TO CAPABILITIES v2
-- ----------------------------------------------------------------------------
UPDATE public.platform_settings ps
   SET data = jsonb_set(ps.data, '{plans,tiers}', (
         SELECT COALESCE(jsonb_agg(
           CASE WHEN COALESCE(NULLIF(tier->>'featuresVersion', '')::int, 1) >= 2 THEN tier
           ELSE tier
             || jsonb_build_object(
                  'featuresVersion', 2,
                  'maxStaff', COALESCE(tier->'maxStaff', tier->'maxUsers', '1'::jsonb),
                  'allowedFeatures', (
                    SELECT COALESCE(jsonb_agg(DISTINCT f), '[]'::jsonb) FROM (
                      SELECT jsonb_array_elements_text(COALESCE(tier->'allowedFeatures', '[]'::jsonb)) AS f
                      UNION SELECT unnest(public.plan_legacy_features())
                      -- Pre-v2 plans carry no capability keys: start from the
                      -- plan's defaults (see 20261126000001_restore_plan_features).
                      UNION SELECT unnest(CASE lower(COALESCE(tier->>'id', ''))
                        WHEN 'startup' THEN ARRAY['order_taking','estimate_bills','invoicing','sales_returns','collections','khata_ledger','purchases','expenses','visits','thermal_printer','reports','gst_reports','offline_sync','staff_management']
                        WHEN 'grow' THEN ARRAY['order_taking','estimate_bills','invoicing','sales_returns','collections','khata_ledger','purchases','expenses','visits','thermal_printer','reports','gst_reports','offline_sync','staff_management','dynamic_upi_qr','live_tracking','van_stock','bulk_import','multi_branch','priority_support']
                        WHEN 'enterprise' THEN ARRAY['order_taking','estimate_bills','invoicing','sales_returns','collections','khata_ledger','dynamic_upi_qr','purchases','expenses','visits','staff_management','thermal_printer','reports','gst_reports','offline_sync','bulk_import','live_tracking','van_stock','multi_van','multi_branch','custom_branding','custom_tax_slabs','admin_customization','audit_vault','priority_support','dedicated_manager']
                        ELSE ARRAY[]::text[] END)
                    ) x))
           END ORDER BY ord), '[]'::jsonb)
         FROM jsonb_array_elements(ps.data->'plans'->'tiers') WITH ORDINALITY AS e(tier, ord))),
       updated_at = now()
 WHERE ps.id = 'pricing_and_plans' AND jsonb_typeof(ps.data->'plans'->'tiers') = 'array';

-- ----------------------------------------------------------------------------
-- 5. SERVER-SIDE ENTITLEMENT GUARD
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_plan_entitlements() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  t public.tenants;
  tier jsonb;
  state text;
  cap int;
  used int;
  feature text;
  is_estimate boolean;
BEGIN
  -- Only end-user writes are policed (also inside SECURITY DEFINER RPCs, where
  -- the JWT role stays 'authenticated'). Backend / admins are never blocked.
  IF auth.role() IS DISTINCT FROM 'authenticated' OR public.is_super_admin() THEN
    RETURN NEW;
  END IF;

  -- Upserts of rows that already exist are edits, not new records.
  -- NOTE: each NEW.<column> must only be referenced inside its own table's
  -- branch — PL/pgSQL does not short-circuit `TG_TABLE_NAME = 'x' AND NEW.col`,
  -- so a shared condition fails with "record new has no field ..." and
  -- rejected every insert (see 20261126000002_fix_plan_entitlement_trigger).
  IF TG_TABLE_NAME = 'shops' THEN
    IF EXISTS (SELECT 1 FROM public.shops WHERE tenant_id = NEW.tenant_id AND shop_id = NEW.shop_id) THEN RETURN NEW; END IF;
  ELSIF TG_TABLE_NAME = 'products' THEN
    IF EXISTS (SELECT 1 FROM public.products WHERE tenant_id = NEW.tenant_id AND product_id = NEW.product_id) THEN RETURN NEW; END IF;
  ELSIF TG_TABLE_NAME = 'orders' THEN
    IF EXISTS (SELECT 1 FROM public.orders WHERE tenant_id = NEW.tenant_id AND order_id = NEW.order_id) THEN RETURN NEW; END IF;
  ELSIF TG_TABLE_NAME = 'invoices' THEN
    IF EXISTS (SELECT 1 FROM public.invoices WHERE tenant_id = NEW.tenant_id AND invoice_id = NEW.invoice_id) THEN RETURN NEW; END IF;
  END IF;

  state := public.tenant_access_state(NEW.tenant_id);
  IF state = 'suspended' THEN
    RAISE EXCEPTION 'ACCOUNT_SUSPENDED: This agency account is suspended. Contact SalesArmy support.';
  END IF;
  IF state = 'expired' THEN
    RAISE EXCEPTION 'PLAN_EXPIRED: Your plan has ended. The app is read-only until you renew from Plan & Pricing.';
  END IF;

  SELECT * INTO t FROM public.tenants WHERE tenant_id = NEW.tenant_id;
  tier := public.platform_plan_tier(t.plan_id);

  IF TG_TABLE_NAME = 'shops' THEN
    cap := public.plan_limit(tier, 'maxShops', COALESCE(t.max_shops, 0));
    IF cap > 0 THEN
      SELECT count(*) INTO used FROM public.shops WHERE tenant_id = NEW.tenant_id;
      IF used >= cap THEN
        RAISE EXCEPTION 'PLAN_LIMIT: Your plan allows % parties. Upgrade to add more.', cap;
      END IF;
    END IF;

  ELSIF TG_TABLE_NAME = 'products' THEN
    cap := public.plan_limit(tier, 'maxProducts', 0);
    IF cap > 0 THEN
      SELECT count(*) INTO used FROM public.products WHERE tenant_id = NEW.tenant_id;
      IF used >= cap THEN
        RAISE EXCEPTION 'PLAN_LIMIT: Your plan allows % products. Upgrade to add more.', cap;
      END IF;
    END IF;

  ELSIF TG_TABLE_NAME = 'orders' THEN
    IF NOT public.plan_has_feature(tier, 'order_taking') THEN
      RAISE EXCEPTION 'PLAN_FEATURE: Order taking is not included in your plan.';
    END IF;
    cap := public.plan_limit(tier, 'maxOrdersPerMonth', 0);
    IF cap > 0 THEN
      SELECT count(*) INTO used FROM public.orders
       WHERE tenant_id = NEW.tenant_id
         AND COALESCE(order_date, created_at) >= date_trunc('month', now())
         AND COALESCE(status, '') <> 'cancelled';
      IF used >= cap THEN
        RAISE EXCEPTION 'PLAN_LIMIT: Your plan allows % orders per month. Upgrade to take more orders.', cap;
      END IF;
    END IF;

  ELSIF TG_TABLE_NAME = 'invoices' THEN
    is_estimate := lower(COALESCE(NEW.invoice_type, '')) IN ('estimate', 'estimated', 'non_gst', 'kaccha');
    feature := CASE WHEN is_estimate THEN 'estimate_bills' ELSE 'invoicing' END;
    IF NOT public.plan_has_feature(tier, feature) THEN
      RAISE EXCEPTION 'PLAN_FEATURE: % is not included in your plan.',
        CASE WHEN is_estimate THEN 'Kaccha / estimate billing' ELSE 'GST tax invoicing' END;
    END IF;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS enforce_plan_entitlements ON public.shops;
CREATE TRIGGER enforce_plan_entitlements BEFORE INSERT ON public.shops
  FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_entitlements();
DROP TRIGGER IF EXISTS enforce_plan_entitlements ON public.products;
CREATE TRIGGER enforce_plan_entitlements BEFORE INSERT ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_entitlements();
DROP TRIGGER IF EXISTS enforce_plan_entitlements ON public.orders;
CREATE TRIGGER enforce_plan_entitlements BEFORE INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_entitlements();
DROP TRIGGER IF EXISTS enforce_plan_entitlements ON public.invoices;
CREATE TRIGGER enforce_plan_entitlements BEFORE INSERT ON public.invoices
  FOR EACH ROW EXECUTE FUNCTION public.enforce_plan_entitlements();

-- ----------------------------------------------------------------------------
-- 6. PER-ACCOUNT PRODUCT CATEGORIES & UNITS (platform_settings row
--    tenant_catalog_<tenant_id>): every member can read, owners / store
--    managers can write. Profile + GST rows keep their existing rule.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS tenant_settings ON public.platform_settings;
CREATE POLICY tenant_settings ON public.platform_settings FOR ALL TO authenticated
USING (id IN ('tenant_profile_' || public.get_auth_tenant_id(),
              'gst_billing_' || public.get_auth_tenant_id(),
              'tenant_catalog_' || public.get_auth_tenant_id()))
WITH CHECK (
  (id IN ('tenant_profile_' || public.get_auth_tenant_id(), 'gst_billing_' || public.get_auth_tenant_id())
     AND public.get_auth_role() IN ('owner','distributor'))
  OR (id = 'tenant_catalog_' || public.get_auth_tenant_id()
     AND public.get_auth_role() IN ('owner','distributor','manager','store_manager'))
);

REVOKE ALL ON FUNCTION public.tenant_access_state(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tenant_access_state(text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.platform_plan_tier(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_plan_tier(text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.platform_general_settings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.platform_general_settings() TO authenticated, service_role;

COMMIT;
