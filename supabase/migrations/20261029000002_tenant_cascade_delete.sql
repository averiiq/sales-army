-- ============================================================================
-- 20261029000002_tenant_cascade_delete.sql
--
-- Deleting a tenant from the admin UI previously left orphan rows in
-- `profiles / orders / shops / products / invoices / payments / ledger_entries
-- / visits / reminders / expenses / purchases / printer_hardware_orders`.
--
-- Rewrite the FK constraints so a tenant delete cascades through every child
-- table. Idempotent against existing environments: drops the constraint by
-- name if present, then re-adds with ON DELETE CASCADE.
-- ============================================================================

DO $$
DECLARE
  tbl TEXT;
  tbls TEXT[] := ARRAY[
    'profiles',
    'orders', 'order_items',
    'shops',
    'products',
    'invoices',
    'payments',
    'ledger_entries',
    'visits',
    'reminders',
    'expenses',
    'purchases',
    'printer_hardware_orders'
  ];
BEGIN
  FOREACH tbl IN ARRAY tbls LOOP
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name=tbl) THEN
      RAISE NOTICE 'Skipping % — table does not exist in this environment', tbl;
      CONTINUE;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name=tbl AND column_name='tenant_id'
    ) THEN
      RAISE NOTICE 'Skipping % — no tenant_id column', tbl;
      CONTINUE;
    END IF;

    -- Drop whatever FK the column currently has (any name) and re-add with
    -- ON DELETE CASCADE.
    EXECUTE (
      SELECT string_agg(format('ALTER TABLE public.%I DROP CONSTRAINT %I;', tbl, con.conname), E'\n')
      FROM pg_constraint con
      JOIN pg_class rel ON rel.oid = con.conrelid
      JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
      WHERE nsp.nspname='public'
        AND rel.relname=tbl
        AND con.contype='f'
        AND EXISTS (
          SELECT 1 FROM unnest(con.conkey) ck
          JOIN pg_attribute att ON att.attrelid=rel.oid AND att.attnum=ck
          WHERE att.attname='tenant_id'
        )
    );

    EXECUTE format(
      'ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (tenant_id) REFERENCES public.tenants(tenant_id) ON DELETE CASCADE',
      tbl,
      tbl || '_tenant_id_fkey'
    );

    RAISE NOTICE 'Rewired FK on %', tbl;
  END LOOP;
END $$;
