BEGIN;
CREATE TABLE public.subscription_checkouts (
  id uuid PRIMARY KEY, tenant_id varchar(64) NOT NULL REFERENCES public.tenants(tenant_id),
  user_id uuid NOT NULL REFERENCES auth.users(id), quote jsonb NOT NULL,
  amount integer NOT NULL CHECK(amount>=0), status text NOT NULL DEFAULT 'pending',
  gateway_link_id text UNIQUE, checkout_url text, payment_id text UNIQUE,
  subscription_end_date timestamptz, created_at timestamptz NOT NULL DEFAULT now(), paid_at timestamptz
);
ALTER TABLE public.subscription_checkouts ENABLE ROW LEVEL SECURITY;
CREATE POLICY checkout_read ON public.subscription_checkouts FOR SELECT TO authenticated
USING (public.is_super_admin() OR tenant_id=public.get_auth_tenant_id());

CREATE FUNCTION public.reserve_subscription_checkout(p_id uuid,p_tenant text,p_user uuid,p_quote jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE code text:=p_quote->>'couponCode'; uses integer;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted backend required'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.tenants WHERE tenant_id=p_tenant AND is_active) THEN RAISE EXCEPTION 'Inactive tenant'; END IF;
  IF code IS NOT NULL THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('coupon:' || code,0));
    SELECT count(*) INTO uses FROM public.subscription_checkouts WHERE quote->>'couponCode'=code
      AND (status='paid' OR created_at>now()-interval '30 minutes');
    IF uses >= (p_quote->>'couponLimit')::integer THEN RAISE EXCEPTION 'Coupon usage limit reached'; END IF;
    IF EXISTS(SELECT 1 FROM public.subscription_checkouts WHERE tenant_id=p_tenant AND quote->>'couponCode'=code
      AND (status='paid' OR created_at>now()-interval '30 minutes')) THEN RAISE EXCEPTION 'Coupon already used or reserved by this workspace'; END IF;
  END IF;
  INSERT INTO public.subscription_checkouts(id,tenant_id,user_id,quote,amount) VALUES(p_id,p_tenant,p_user,p_quote,(p_quote->>'amount')::integer);
END $$;

CREATE FUNCTION public.settle_subscription_checkout(p_id uuid,p_link text,p_payment text,p_amount integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE checkout public.subscription_checkouts; expiry timestamptz; tenant public.tenants;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted backend required'; END IF;
  SELECT * INTO checkout FROM public.subscription_checkouts WHERE id=p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Checkout not found'; END IF;
  IF checkout.status='paid' THEN RETURN jsonb_build_object('id',p_id,'status','paid','paymentId',checkout.payment_id,'expiresAt',checkout.subscription_end_date); END IF;
  IF p_amount IS DISTINCT FROM checkout.amount OR (checkout.amount>0 AND (p_link IS DISTINCT FROM checkout.gateway_link_id OR p_link IS NULL OR p_payment IS NULL)) THEN RAISE EXCEPTION 'Payment mismatch'; END IF;
  SELECT * INTO tenant FROM public.tenants WHERE tenant_id=checkout.tenant_id FOR UPDATE;
  expiry:=greatest(now(),COALESCE(tenant.subscription_end_date,now()))+make_interval(days=>(checkout.quote->>'days')::integer);
  UPDATE public.tenants SET plan_id=checkout.quote->>'planId',
    subscription_status=CASE WHEN (checkout.quote->>'trial')::boolean THEN 'trial' ELSE 'active' END,
    subscription_end_date=expiry,max_users=(checkout.quote->>'maxUsers')::integer,max_shops=(checkout.quote->>'maxShops')::integer
    WHERE tenant_id=checkout.tenant_id;
  IF jsonb_array_length(checkout.quote->'hardware')>0 THEN
    INSERT INTO public.printer_hardware_orders(order_id,tenant_id,business_name,contact_person,phone,shipping_address,printer_model,quantity,unit_price,total_amount,payment_status,fulfillment_status)
    VALUES(p_id::text,checkout.tenant_id,tenant.business_name,COALESCE(tenant.contact_person,''),tenant.mobile,
      checkout.quote->>'shippingAddress',(SELECT string_agg(value->>'title',', ') FROM jsonb_array_elements(checkout.quote->'hardware')),
      1,(checkout.quote->>'hardwareAmount')::numeric/100,(checkout.quote->>'hardwareAmount')::numeric/100,'paid','processing');
  END IF;
  UPDATE public.subscription_checkouts SET status='paid',payment_id=p_payment,paid_at=now(),subscription_end_date=expiry WHERE id=p_id;
  RETURN jsonb_build_object('id',p_id,'status','paid','paymentId',p_payment,'expiresAt',expiry);
END $$;
REVOKE ALL ON FUNCTION public.reserve_subscription_checkout(uuid,text,uuid,jsonb),public.settle_subscription_checkout(uuid,text,text,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_subscription_checkout(uuid,text,uuid,jsonb),public.settle_subscription_checkout(uuid,text,text,integer) TO service_role;
COMMIT;
