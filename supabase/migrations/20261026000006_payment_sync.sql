BEGIN;
CREATE FUNCTION public.sync_record_payment(p_tenant text,p_mutation text,p_payment jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE result jsonb;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted backend required'; END IF;
  -- The sync API records offline collections only; gateway settlement has its own verification endpoint.
  IF lower(COALESCE(p_payment->>'paymentMode',p_payment->>'mode','cash'))='razorpay' THEN RAISE EXCEPTION 'Gateway verification required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant || ':' || p_mutation,0));
  SELECT response_payload INTO result FROM public.client_mutations WHERE tenant_id=p_tenant AND mutation_id=p_mutation;
  IF FOUND THEN RETURN result; END IF;
  result:=public.record_payment(p_tenant,p_payment);
  INSERT INTO public.client_mutations(tenant_id,mutation_id,response_payload) VALUES(p_tenant,p_mutation,result);
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.sync_record_payment(text,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sync_record_payment(text,text,jsonb) TO service_role;
COMMIT;
