BEGIN;
CREATE TABLE public.client_mutations (
  tenant_id varchar(64) NOT NULL REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
  mutation_id text NOT NULL, status text NOT NULL DEFAULT 'COMMITTED', response_payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(tenant_id, mutation_id)
);
ALTER TABLE public.client_mutations ENABLE ROW LEVEL SECURITY;
CREATE POLICY mutation_read ON public.client_mutations FOR SELECT TO authenticated
USING (public.is_super_admin() OR tenant_id=public.get_auth_tenant_id());

CREATE OR REPLACE FUNCTION public.assert_sales_access(p_tenant text) RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$ BEGIN
  IF auth.role()='service_role' THEN RETURN; END IF;
  IF NOT public.is_super_admin() AND (auth.uid() IS NULL OR p_tenant IS DISTINCT FROM public.get_auth_tenant_id()
    OR COALESCE(public.get_auth_role(),'') NOT IN ('owner','distributor','sales_person','salesman','accountant','delivery_agent','delivery','manager','store_manager'))
  THEN RAISE EXCEPTION 'Unauthorized tenant operation'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE tenant_id=p_tenant AND is_active AND subscription_status NOT IN ('suspended','cancelled','paused')
    AND (subscription_end_date IS NULL OR subscription_end_date>now()))
  THEN RAISE EXCEPTION 'Tenant is inactive'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.sync_save_order(p_tenant text,p_mutation text,p_order jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE existing jsonb; oid text; order_uuid uuid; item jsonb; qty integer; price numeric; rate numeric;
  subtotal numeric:=0; tax numeric:=0; result jsonb;
BEGIN
  PERFORM public.assert_sales_access(p_tenant);
  PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant || ':' || p_mutation,0));
  SELECT response_payload INTO existing FROM public.client_mutations WHERE tenant_id=p_tenant AND mutation_id=p_mutation;
  IF FOUND THEN RETURN existing; END IF;
  oid:=COALESCE(p_order->>'orderId',p_order->>'order_id',p_mutation);
  IF jsonb_typeof(p_order->'items') IS DISTINCT FROM 'array' OR jsonb_array_length(p_order->'items')=0 THEN RAISE EXCEPTION 'Order items required'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.shops WHERE tenant_id=p_tenant AND shop_id=p_order->>'shopId') THEN RAISE EXCEPTION 'Shop not found'; END IF;
  FOR item IN SELECT * FROM jsonb_array_elements(p_order->'items') LOOP
    qty:=(item->>'quantity')::integer; price:=(item->>'unitPrice')::numeric; rate:=COALESCE((item->>'gstRate')::numeric,0);
    IF qty IS NULL OR qty<=0 OR price IS NULL OR price<0 OR rate<0 OR rate>100 THEN RAISE EXCEPTION 'Invalid order item'; END IF;
    subtotal:=subtotal+round(qty*price,2); tax:=tax+round(qty*price*rate/100,2);
  END LOOP;
  INSERT INTO public.orders(order_id,tenant_id,shop_id,subtotal,total_gst,grand_total,status,notes,client_mutation_id)
  VALUES(oid,p_tenant,p_order->>'shopId',subtotal,tax,subtotal+tax,'confirmed',p_order->>'notes',NULL)
  RETURNING id INTO order_uuid;
  FOR item IN SELECT * FROM jsonb_array_elements(p_order->'items') LOOP
    qty:=(item->>'quantity')::integer; price:=(item->>'unitPrice')::numeric; rate:=COALESCE((item->>'gstRate')::numeric,0);
    INSERT INTO public.order_items(order_id,product_id,product_name,quantity,unit_price,gst_rate,taxable_amount,gst_amount,total)
    VALUES(order_uuid,item->>'productId',item->>'productName',qty,price,rate,round(qty*price,2),round(qty*price*rate/100,2),round(qty*price,2)+round(qty*price*rate/100,2));
  END LOOP;
  result:=jsonb_build_object('orderId',oid,'status','COMMITTED');
  INSERT INTO public.client_mutations(tenant_id,mutation_id,response_payload) VALUES(p_tenant,p_mutation,result);
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.sync_ledger_entry(p_tenant text,p_mutation text,p_shop text,p_entry jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE previous numeric; debit numeric; credit numeric; balance numeric; existing jsonb; result jsonb;
BEGIN
  -- Called only by the trusted backend, after validating the business operation.
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted backend required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant || ':' || p_mutation,0));
  SELECT response_payload INTO existing FROM public.client_mutations WHERE tenant_id=p_tenant AND mutation_id=p_mutation;
  IF FOUND THEN RETURN existing; END IF;
  debit:=COALESCE((p_entry->>'debit')::numeric,0); credit:=COALESCE((p_entry->>'credit')::numeric,0);
  IF debit<0 OR credit<0 OR (debit>0)=(credit>0) THEN RAISE EXCEPTION 'Invalid debit/credit'; END IF;
  SELECT current_outstanding INTO previous FROM public.shops WHERE tenant_id=p_tenant AND shop_id=p_shop FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shop not found'; END IF;
  balance:=round(previous+debit-credit,2);
  UPDATE public.shops SET current_outstanding=balance,updated_at=now() WHERE tenant_id=p_tenant AND shop_id=p_shop;
  INSERT INTO public.ledger_entries(entry_id,tenant_id,shop_id,transaction_type,debit,credit,balance_after,description)
  VALUES(p_entry->>'entryId',p_tenant,p_shop,p_entry->>'type',debit,credit,balance,p_entry->>'description');
  result:=jsonb_build_object('new_balance',balance);
  INSERT INTO public.client_mutations(tenant_id,mutation_id,response_payload) VALUES(p_tenant,p_mutation,result);
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sync_save_order(text,text,jsonb),public.sync_ledger_entry(text,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.sync_save_order(text,text,jsonb) TO authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.sync_ledger_entry(text,text,text,jsonb) TO service_role;
COMMIT;
