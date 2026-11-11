BEGIN;
-- A bridge save either commits every affected record or rolls back entirely.
CREATE FUNCTION public.admin_apply_changes(p_jobs jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE job jsonb; row_data jsonb; tbl text; conflict_key text; cols text; updates text;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE EXCEPTION 'Trusted backend required'; END IF;
  FOR job IN SELECT * FROM jsonb_array_elements(p_jobs) LOOP
    tbl:=job->>'table';
    conflict_key:=CASE tbl WHEN 'platform_settings' THEN 'id' WHEN 'tenants' THEN 'tenant_id'
      WHEN 'profiles' THEN 'id' WHEN 'printer_hardware_orders' THEN 'order_id' WHEN 'orders' THEN 'tenant_id,order_id' END;
    IF conflict_key IS NULL THEN RAISE EXCEPTION 'Unsupported admin table'; END IF;
    FOR row_data IN SELECT * FROM jsonb_array_elements(job->'rows') LOOP
      SELECT string_agg(format('%I',key),','),string_agg(format('%I=EXCLUDED.%I',key,key),',') INTO cols,updates FROM jsonb_object_keys(row_data) key;
      EXECUTE format('INSERT INTO public.%I(%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I,$1) ON CONFLICT (%s) DO UPDATE SET %s',tbl,cols,cols,tbl,conflict_key,updates) USING row_data;
    END LOOP;
  END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.admin_apply_changes(jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.admin_apply_changes(jsonb) TO service_role;
COMMIT;
