-- ============================================================================
-- 20261126000002_fix_plan_entitlement_trigger.sql
--
-- Critical fix: enforce_plan_entitlements() (from 20261124000000) referenced
-- NEW.product_id / NEW.shop_id / ... in shared conditions. PL/pgSQL does not
-- short-circuit those, so EVERY end-user insert into shops, products, orders
-- and invoices failed with "record new has no field ...". The app kept the
-- records on the phone only, so reinstalling the app lost them.
-- Each table's checks now live in its own branch. Idempotent.
-- ============================================================================
BEGIN;

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

COMMIT;
