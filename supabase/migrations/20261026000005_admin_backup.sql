BEGIN;
CREATE FUNCTION public.admin_business_snapshot() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $$
DECLARE tbl text; rows jsonb; result jsonb:='{}';
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' AND NOT public.is_super_admin() THEN RAISE EXCEPTION 'Administrator required'; END IF;
  FOREACH tbl IN ARRAY ARRAY['tenants','profiles','categories','products','shops','orders','order_items','invoices','payments','ledger_entries','visits','platform_settings','printer_hardware_orders','notifications','client_mutations','subscription_checkouts'] LOOP
    EXECUTE format('SELECT COALESCE(jsonb_agg(to_jsonb(t)),''[]''::jsonb) FROM public.%I t',tbl) INTO rows;
    result:=result || jsonb_build_object(tbl,rows);
  END LOOP;
  RETURN jsonb_build_object('exportedAt',now(),'formatVersion',1,'tables',result);
END $$;
REVOKE ALL ON FUNCTION public.admin_business_snapshot() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.admin_business_snapshot() TO authenticated,service_role;
COMMIT;
