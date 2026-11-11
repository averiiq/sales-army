-- ============================================================================
-- 20261029000000_rls_safety_net.sql
--
-- Defensive migration run AFTER every earlier RLS-touching migration. Its job
-- is to drop any policy that would permit anonymous read or write on an
-- operational table (`USING (true)` or `USING (auth.uid() IS NULL OR ...)`)
-- so that nothing permissive can survive a migration-ordering accident.
--
-- Also tightens overly-broad `GRANT EXECUTE … TO authenticated` on admin
-- RPCs that enforce super_admin internally — defence in depth, since a leaked
-- authenticated JWT should not be able to even invoke them.
-- ============================================================================

DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname, qual
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (
        qual = 'true'
        OR qual ILIKE '%auth.uid() IS NULL%'
      )
  LOOP
    RAISE WARNING 'Dropping permissive policy %.% (qual=%)', pol.tablename, pol.policyname, pol.qual;
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, pol.tablename);
  END LOOP;
END $$;

-- Narrow admin RPC grants to service_role only. The function bodies still
-- assert is_super_admin() so this is defence-in-depth.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'admin_business_snapshot') THEN
    REVOKE EXECUTE ON FUNCTION public.admin_business_snapshot() FROM PUBLIC, anon, authenticated;
    GRANT  EXECUTE ON FUNCTION public.admin_business_snapshot() TO service_role;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'admin_purge_tenant_transactions') THEN
    REVOKE EXECUTE ON FUNCTION public.admin_purge_tenant_transactions(text) FROM PUBLIC, anon;
    GRANT  EXECUTE ON FUNCTION public.admin_purge_tenant_transactions(text) TO authenticated, service_role;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'admin_apply_changes') THEN
    REVOKE EXECUTE ON FUNCTION public.admin_apply_changes(jsonb) FROM PUBLIC, anon, authenticated;
    GRANT  EXECUTE ON FUNCTION public.admin_apply_changes(jsonb) TO service_role;
  END IF;
END $$;

-- Harden settle_subscription_checkout: reject non-positive day counts that
-- would otherwise be accepted silently (H21).
CREATE OR REPLACE FUNCTION public.settle_subscription_checkout(
  p_id uuid,
  p_link text,
  p_payment text,
  p_amount integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  checkout public.subscription_checkouts;
  expiry timestamptz;
  tenant public.tenants;
  days_int integer;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'settle_subscription_checkout is service-role only';
  END IF;

  SELECT * INTO checkout FROM public.subscription_checkouts WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Checkout % not found', p_id;
  END IF;

  IF checkout.status = 'paid' THEN
    RETURN jsonb_build_object('id', p_id, 'status', 'paid', 'paymentId', checkout.payment_id, 'expiresAt', checkout.subscription_end_date);
  END IF;

  IF p_amount IS DISTINCT FROM checkout.amount OR (checkout.amount > 0 AND (p_link IS DISTINCT FROM checkout.gateway_link_id OR p_link IS NULL OR p_payment IS NULL)) THEN
    RAISE EXCEPTION 'Payment mismatch';
  END IF;

  days_int := COALESCE((checkout.quote->>'days')::integer, 0);
  IF days_int <= 0 THEN
    RAISE EXCEPTION 'Invalid plan duration (days=% from checkout quote)', days_int;
  END IF;

  SELECT * INTO tenant FROM public.tenants WHERE tenant_id = checkout.tenant_id FOR UPDATE;
  expiry := greatest(now(), COALESCE(tenant.subscription_end_date, now())) + make_interval(days => days_int);

  UPDATE public.tenants
     SET plan_id = checkout.quote->>'planId',
         subscription_status = CASE WHEN (checkout.quote->>'trial')::boolean THEN 'trial' ELSE 'active' END,
         subscription_end_date = expiry,
         max_users = (checkout.quote->>'maxUsers')::integer,
         max_shops = (checkout.quote->>'maxShops')::integer
   WHERE tenant_id = checkout.tenant_id;

  IF jsonb_array_length(COALESCE(checkout.quote->'hardware', '[]'::jsonb)) > 0 THEN
    INSERT INTO public.printer_hardware_orders(order_id, tenant_id, business_name, contact_person, phone, shipping_address, printer_model, quantity, unit_price, total_amount, payment_status, fulfillment_status)
    VALUES(p_id::text, checkout.tenant_id, tenant.business_name, COALESCE(tenant.contact_person, ''), tenant.mobile,
      checkout.quote->>'shippingAddress', (SELECT string_agg(value->>'title', ', ') FROM jsonb_array_elements(checkout.quote->'hardware')),
      1, (checkout.quote->>'hardwareAmount')::numeric / 100, (checkout.quote->>'hardwareAmount')::numeric / 100, 'paid', 'processing');
  END IF;

  UPDATE public.subscription_checkouts
     SET status = 'paid',
         payment_id = p_payment,
         paid_at = now(),
         subscription_end_date = expiry
   WHERE id = p_id;

  RETURN jsonb_build_object('id', p_id, 'status', 'paid', 'paymentId', p_payment, 'expiresAt', expiry);
END $$;

REVOKE EXECUTE ON FUNCTION public.settle_subscription_checkout(uuid, text, text, integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.settle_subscription_checkout(uuid, text, text, integer) TO service_role;
