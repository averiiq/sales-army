BEGIN;
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS items jsonb NOT NULL DEFAULT '[]';
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;

CREATE OR REPLACE FUNCTION public.record_invoice(p_tenant text,p_invoice jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE inv_id text:=p_invoice->>'invoiceId'; shop text:=p_invoice->>'shopId'; item jsonb;
  qty integer; price numeric; rate numeric; subtotal numeric:=0; gst numeric:=0; balance numeric;
  interstate boolean; total numeric; cgst numeric:=0; sgst numeric:=0;
BEGIN
  PERFORM public.assert_sales_access(p_tenant);
  IF public.get_auth_role() IN ('delivery','delivery_agent','manager','store_manager') THEN RAISE EXCEPTION 'Billing permission required'; END IF;
  IF inv_id IS NULL OR inv_id='' THEN RAISE EXCEPTION 'Invoice ID required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant || ':invoice:' || inv_id,0));
  IF EXISTS(SELECT 1 FROM public.invoices WHERE tenant_id=p_tenant AND invoice_id=inv_id) THEN RETURN jsonb_build_object('invoiceId',inv_id,'replayed',true); END IF;
  SELECT current_outstanding INTO balance FROM public.shops WHERE tenant_id=p_tenant AND shop_id=shop FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shop not found'; END IF;
  IF jsonb_typeof(p_invoice->'items') IS DISTINCT FROM 'array' OR jsonb_array_length(p_invoice->'items')=0 THEN RAISE EXCEPTION 'Invoice items required'; END IF;
  interstate:=COALESCE(p_invoice->'seller'->>'stateCode','27') <> COALESCE(p_invoice->'buyer'->>'stateCode','27');
  FOR item IN SELECT * FROM jsonb_array_elements(p_invoice->'items') LOOP
    qty:=(item->>'quantity')::integer; price:=COALESCE(item->>'unitPrice',item->>'rate')::numeric;
    rate:=CASE WHEN p_invoice->>'invoiceType' IN ('estimate','estimated') THEN 0 ELSE COALESCE((item->>'gstRate')::numeric,0) END;
    IF qty IS NULL OR qty<=0 OR price IS NULL OR price<0 OR rate<0 OR rate>100 THEN RAISE EXCEPTION 'Invalid invoice item'; END IF;
    subtotal:=subtotal+round(qty*price,2);
    IF interstate THEN gst:=gst+round(qty*price*rate/100,2);
    ELSE cgst:=cgst+round(qty*price*rate/200,2); sgst:=sgst+round(qty*price*rate/200,2); END IF;
    UPDATE public.products SET stock_quantity=stock_quantity-qty WHERE tenant_id=p_tenant AND product_id=item->>'productId' AND stock_quantity>=qty;
    IF NOT FOUND THEN RAISE EXCEPTION 'Insufficient stock for %',item->>'productId'; END IF;
  END LOOP;
  total:=subtotal+gst+cgst+sgst;
  INSERT INTO public.invoices(invoice_id,invoice_number,tenant_id,order_id,shop_id,invoice_type,seller_details,buyer_details,items,taxable_amount,cgst,sgst,igst,total_gst,grand_total,amount_due)
  VALUES(inv_id,COALESCE(p_invoice->>'invoiceNumber',inv_id),p_tenant,NULLIF(p_invoice->>'orderId',''),shop,COALESCE(p_invoice->>'invoiceType','gst'),p_invoice->'seller',p_invoice->'buyer',p_invoice->'items',subtotal,cgst,sgst,gst,gst+cgst+sgst,total,total);
  UPDATE public.shops SET current_outstanding=balance+total WHERE tenant_id=p_tenant AND shop_id=shop;
  INSERT INTO public.ledger_entries(entry_id,tenant_id,shop_id,invoice_id,transaction_type,debit,credit,balance_after,description)
  VALUES('INV-' || inv_id,p_tenant,shop,inv_id,'invoice',total,0,balance+total,'Invoice ' || inv_id);
  RETURN jsonb_build_object('invoiceId',inv_id,'grandTotal',total,'balanceAfter',balance+total);
END $$;

CREATE OR REPLACE FUNCTION public.record_payment(p_tenant text,p_payment jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE pid text:=p_payment->>'paymentId'; shop text:=p_payment->>'shopId'; amount numeric:=(p_payment->>'amount')::numeric;
  balance numeric; remaining numeric; allocation numeric; inv record; mode text;
BEGIN
  PERFORM public.assert_sales_access(p_tenant);
  IF public.get_auth_role() IN ('manager','store_manager') THEN RAISE EXCEPTION 'Collection permission required'; END IF;
  IF pid IS NULL OR pid='' OR amount IS NULL OR amount<=0 OR amount::text IN ('NaN','Infinity','-Infinity') THEN RAISE EXCEPTION 'Invalid payment'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant || ':payment:' || pid,0));
  IF EXISTS(SELECT 1 FROM public.payments WHERE tenant_id=p_tenant AND payment_id=pid) THEN RETURN jsonb_build_object('paymentId',pid,'replayed',true); END IF;
  SELECT current_outstanding INTO balance FROM public.shops WHERE tenant_id=p_tenant AND shop_id=shop FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Shop not found'; END IF;
  mode:=lower(COALESCE(p_payment->>'paymentMode',p_payment->>'mode','cash'));
  IF mode='razorpay' AND auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Gateway payments require a verified webhook'; END IF;
  INSERT INTO public.payments(payment_id,tenant_id,shop_id,amount,mode,status,reference,collected_by)
  VALUES(pid,p_tenant,shop,amount,mode,'success',p_payment->>'referenceNumber',auth.uid());
  remaining:=amount;
  FOR inv IN SELECT * FROM public.invoices WHERE tenant_id=p_tenant AND shop_id=shop AND amount_due>0 AND cancelled_at IS NULL ORDER BY invoice_date,id FOR UPDATE LOOP
    EXIT WHEN remaining<=0;
    allocation:=least(remaining,inv.amount_due);
    UPDATE public.invoices SET amount_paid=amount_paid+allocation,amount_due=amount_due-allocation,
      payment_status=CASE WHEN amount_due-allocation=0 THEN 'paid' ELSE 'partial' END WHERE id=inv.id;
    remaining:=remaining-allocation;
  END LOOP;
  UPDATE public.shops SET current_outstanding=balance-amount WHERE tenant_id=p_tenant AND shop_id=shop;
  INSERT INTO public.ledger_entries(entry_id,tenant_id,shop_id,payment_id,transaction_type,debit,credit,balance_after,description)
  VALUES('PAY-' || pid,p_tenant,shop,pid,'payment',0,amount,balance-amount,'Collection ' || pid);
  RETURN jsonb_build_object('paymentId',pid,'balanceAfter',balance-amount);
END $$;

CREATE OR REPLACE FUNCTION public.cancel_invoice(p_tenant text,p_invoice_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE inv public.invoices; item jsonb; balance numeric;
BEGIN
  PERFORM public.assert_sales_access(p_tenant);
  IF NOT public.is_super_admin() AND public.get_auth_role() NOT IN ('owner','distributor','accountant') THEN RAISE EXCEPTION 'Cancellation permission required'; END IF;
  SELECT * INTO inv FROM public.invoices WHERE tenant_id=p_tenant AND invoice_id=p_invoice_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Invoice not found'; END IF;
  IF inv.cancelled_at IS NOT NULL THEN RETURN; END IF;
  UPDATE public.shops SET current_outstanding=current_outstanding-inv.grand_total WHERE tenant_id=p_tenant AND shop_id=inv.shop_id RETURNING current_outstanding INTO balance;
  FOR item IN SELECT * FROM jsonb_array_elements(inv.items) LOOP
    UPDATE public.products SET stock_quantity=stock_quantity+(item->>'quantity')::integer WHERE tenant_id=p_tenant AND product_id=item->>'productId';
  END LOOP;
  UPDATE public.invoices SET cancelled_at=now(),amount_due=0,payment_status='cancelled' WHERE id=inv.id;
  INSERT INTO public.ledger_entries(entry_id,tenant_id,shop_id,invoice_id,transaction_type,debit,credit,balance_after,description)
  VALUES('CANCEL-' || inv.invoice_id,p_tenant,inv.shop_id,inv.invoice_id,'reversal',0,inv.grand_total,balance,'Invoice cancelled');
END $$;
REVOKE ALL ON FUNCTION public.record_invoice(text,jsonb),public.record_payment(text,jsonb),public.cancel_invoice(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.record_invoice(text,jsonb),public.record_payment(text,jsonb),public.cancel_invoice(text,text) TO authenticated,service_role;
CREATE POLICY order_status_update ON public.orders FOR UPDATE TO authenticated USING (tenant_id=public.get_auth_tenant_id()) WITH CHECK (tenant_id=public.get_auth_tenant_id());
CREATE FUNCTION public.protect_order_contents() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
  IF current_user='authenticated' AND NOT public.is_super_admin() AND (to_jsonb(NEW)-'status'-'updated_at') IS DISTINCT FROM (to_jsonb(OLD)-'status'-'updated_at') THEN RAISE EXCEPTION 'Order contents are immutable'; END IF;
  IF NEW.status NOT IN ('pending','confirmed','processing','dispatched','delivered','completed','cancelled','draft') THEN RAISE EXCEPTION 'Invalid order status'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER protect_order_contents BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.protect_order_contents();
COMMIT;
