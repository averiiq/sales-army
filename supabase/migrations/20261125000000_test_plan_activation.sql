-- ============================================================================
-- 20261125000000_test_plan_activation.sql
--
-- TESTING ONLY: lets an agency owner activate a paid plan from the app
-- WITHOUT payment, while no payment server (Razorpay via web-admin) is set up.
--
--   * Controlled by general_settings.allowTestPlanActivation (Web Admin →
--     Settings → "Allow test plan activation"). Turn it OFF before real
--     customers use the app; the RPC then refuses every call.
--   * The plan change happens server-side, so the database stays the single
--     source of truth (the app cannot write plan columns itself).
--   * Owner / distributor of their own agency only. Suspended or cancelled
--     agencies cannot reactivate themselves.
--
-- Requires 20261124000000_plan_entitlements.sql (platform_plan_tier,
-- plan_limit). Idempotent.
-- ============================================================================
BEGIN;

-- The switch is NOT turned on here (absent = OFF). Razorpay checkout runs on
-- the Supabase Edge Function "platform"; enable test activation only
-- temporarily from Web Admin → Settings when needed. Re-running this file
-- never re-enables it.

-- Governance guard: still blocks plan / status / limit writes from the app,
-- except inside the trusted RPC below (which sets a transaction-local flag).
CREATE OR REPLACE FUNCTION public.protect_tenant_governance() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_setting('salesarmy.trusted_plan_change', true) = 'on' THEN
    RETURN NEW;
  END IF;
  IF auth.role() = 'authenticated' AND NOT public.is_super_admin() AND
    (NEW.tenant_id, NEW.owner_uid, NEW.plan_id, NEW.subscription_status, NEW.subscription_end_date,
     NEW.is_active, NEW.max_users, NEW.max_shops)
    IS DISTINCT FROM
    (OLD.tenant_id, OLD.owner_uid, OLD.plan_id, OLD.subscription_status, OLD.subscription_end_date,
     OLD.is_active, OLD.max_users, OLD.max_shops)
  THEN
    RAISE EXCEPTION 'Subscription and ownership fields are server-managed';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS protect_tenant_governance ON public.tenants;
CREATE TRIGGER protect_tenant_governance BEFORE UPDATE ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.protect_tenant_governance();

CREATE OR REPLACE FUNCTION public.activate_plan_for_testing(p_plan text, p_yearly boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_tenant text := public.get_auth_tenant_id();
  v_settings jsonb;
  v_tier jsonb;
  v_row public.tenants;
  v_days int := CASE WHEN p_yearly THEN 365 ELSE 30 END;
  v_base timestamptz;
  v_expiry timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Sign in required';
  END IF;
  IF v_tenant IS NULL OR COALESCE(public.get_auth_role(), '') NOT IN ('owner', 'distributor') THEN
    RAISE EXCEPTION 'Only the agency owner can change the plan';
  END IF;

  SELECT data INTO v_settings FROM public.platform_settings WHERE id = 'general_settings';
  IF COALESCE((v_settings->>'allowTestPlanActivation')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_ACTIVATION_DISABLED: Online payment is not set up yet. Please contact SalesArmy to activate your plan.';
  END IF;

  v_tier := public.platform_plan_tier(p_plan);
  IF v_tier IS NULL THEN
    RAISE EXCEPTION 'Unknown plan "%"', p_plan;
  END IF;
  IF (v_tier->>'isActive') = 'false' THEN
    RAISE EXCEPTION 'This plan is not available';
  END IF;

  SELECT * INTO v_row FROM public.tenants WHERE tenant_id = v_tenant FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Agency not found';
  END IF;
  IF COALESCE(v_row.subscription_status, '') IN ('suspended', 'cancelled', 'paused') OR v_row.is_active IS FALSE THEN
    RAISE EXCEPTION 'This agency is suspended. Please contact SalesArmy support.';
  END IF;

  -- Extend from the current end date when renewing the same active plan.
  v_base := CASE
    WHEN v_row.plan_id = p_plan AND v_row.subscription_status = 'active'
         AND v_row.subscription_end_date IS NOT NULL AND v_row.subscription_end_date > now()
      THEN v_row.subscription_end_date
    ELSE now()
  END;
  v_expiry := v_base + make_interval(days => v_days);

  PERFORM set_config('salesarmy.trusted_plan_change', 'on', true);
  UPDATE public.tenants
     SET plan_id = p_plan,
         subscription_status = 'active',
         subscription_start_date = now(),
         subscription_end_date = v_expiry,
         is_active = true,
         max_users = public.plan_limit(v_tier, 'maxStaff', public.plan_limit(v_tier, 'maxUsers', 1)),
         max_shops = public.plan_limit(v_tier, 'maxShops', 200),
         updated_at = now()
   WHERE tenant_id = v_tenant;
  PERFORM set_config('salesarmy.trusted_plan_change', 'off', true);

  RETURN jsonb_build_object(
    'tenantId', v_tenant,
    'planId', p_plan,
    'status', 'active',
    'expiresAt', v_expiry,
    'testActivation', true
  );
END $$;

REVOKE ALL ON FUNCTION public.activate_plan_for_testing(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activate_plan_for_testing(text, boolean) TO authenticated;

COMMIT;
