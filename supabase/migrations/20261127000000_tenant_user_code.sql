-- ============================================================================
-- 20261127000000_tenant_user_code.sql
--
-- Short, human-friendly Unique User ID per agency: SA-USR-1001, SA-USR-1002 ...
-- Shown identically in the mobile app (Profile → User ID) and the Web Admin
-- (Agencies + Users lists). tenant_id stays the internal key; user_code is
-- display/search only. Every new agency gets one automatically (column
-- default), existing agencies are backfilled oldest-first. Idempotent.
-- ============================================================================
BEGIN;

CREATE SEQUENCE IF NOT EXISTS public.tenant_user_code_seq START WITH 1001;

ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS user_code text;

-- Backfill existing agencies in signup order (only those still missing a code).
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT tenant_id FROM public.tenants WHERE user_code IS NULL ORDER BY created_at NULLS LAST, tenant_id LOOP
    UPDATE public.tenants
       SET user_code = 'SA-USR-' || lpad(nextval('public.tenant_user_code_seq')::text, 4, '0')
     WHERE tenant_id = r.tenant_id;
  END LOOP;
END $$;

ALTER TABLE public.tenants
  ALTER COLUMN user_code SET DEFAULT 'SA-USR-' || lpad(nextval('public.tenant_user_code_seq')::text, 4, '0'),
  ALTER COLUMN user_code SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tenants_user_code_key') THEN
    ALTER TABLE public.tenants ADD CONSTRAINT tenants_user_code_key UNIQUE (user_code);
  END IF;
END $$;

-- The code is assigned by the database and never changed by clients.
CREATE OR REPLACE FUNCTION public.protect_tenant_user_code() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.user_code IS DISTINCT FROM OLD.user_code AND auth.role() = 'authenticated' THEN
    NEW.user_code := OLD.user_code;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_protect_tenant_user_code ON public.tenants;
CREATE TRIGGER trg_protect_tenant_user_code
  BEFORE UPDATE OF user_code ON public.tenants
  FOR EACH ROW EXECUTE FUNCTION public.protect_tenant_user_code();

COMMIT;
