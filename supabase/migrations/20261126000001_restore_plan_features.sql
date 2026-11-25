-- ============================================================================
-- 20261126000001_restore_plan_features.sql
--
-- Bug fix: 20261124000000_plan_entitlements.sql upgraded stored plans to
-- capabilities v2 as (existing keys ∪ 10 legacy basics). Plans stored before
-- v2 had no capability keys, so EVERY plan — Enterprise included — ended up
-- with only the 10 basics and lost GST billing (invoicing), khata ledger,
-- GST reports, offline sync and all premium features.
--
-- This restores each standard plan's default capabilities (same lists as
-- DEFAULT_TIERS in apps/web-admin/api/catalog.mjs), keeping anything a plan
-- already has. It only touches plans whose feature list is EXACTLY the
-- broken 10-basics set, so re-running it never undoes an admin's later edit.
-- Idempotent.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.plan_default_features(p_plan text) RETURNS text[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE lower(COALESCE(p_plan, ''))
    WHEN 'startup' THEN ARRAY['order_taking', 'estimate_bills', 'invoicing', 'sales_returns', 'collections', 'khata_ledger', 'purchases', 'expenses', 'visits', 'thermal_printer', 'reports', 'gst_reports', 'offline_sync', 'staff_management']
    WHEN 'grow' THEN ARRAY['order_taking', 'estimate_bills', 'invoicing', 'sales_returns', 'collections', 'khata_ledger', 'purchases', 'expenses', 'visits', 'thermal_printer', 'reports', 'gst_reports', 'offline_sync', 'staff_management', 'dynamic_upi_qr', 'live_tracking', 'van_stock', 'bulk_import', 'multi_branch', 'priority_support']
    WHEN 'enterprise' THEN ARRAY['order_taking', 'estimate_bills', 'invoicing', 'sales_returns', 'collections', 'khata_ledger', 'dynamic_upi_qr', 'purchases', 'expenses', 'visits', 'staff_management', 'thermal_printer', 'reports', 'gst_reports', 'offline_sync', 'bulk_import', 'live_tracking', 'van_stock', 'multi_van', 'multi_branch', 'custom_branding', 'custom_tax_slabs', 'admin_customization', 'audit_vault', 'priority_support', 'dedicated_manager']
    ELSE ARRAY[]::text[]
  END
$$;

UPDATE public.platform_settings ps
   SET data = jsonb_set(ps.data, '{plans,tiers}', (
         SELECT COALESCE(jsonb_agg(
           CASE
             WHEN (SELECT array_agg(f ORDER BY f) FROM jsonb_array_elements_text(COALESCE(tier->'allowedFeatures', '[]'::jsonb)) f)
                  = (SELECT array_agg(f ORDER BY f) FROM unnest(public.plan_legacy_features()) f)
              AND cardinality(public.plan_default_features(tier->>'id')) > 0
             THEN tier || jsonb_build_object('allowedFeatures', (
                    SELECT jsonb_agg(DISTINCT f ORDER BY f) FROM (
                      SELECT jsonb_array_elements_text(tier->'allowedFeatures') AS f
                      UNION SELECT unnest(public.plan_default_features(tier->>'id'))
                    ) x))
             ELSE tier
           END ORDER BY ord), '[]'::jsonb)
         FROM jsonb_array_elements(ps.data->'plans'->'tiers') WITH ORDINALITY AS e(tier, ord))),
       updated_at = now()
 WHERE ps.id = 'pricing_and_plans' AND jsonb_typeof(ps.data->'plans'->'tiers') = 'array';

COMMIT;
