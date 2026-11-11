-- ==============================================================================
-- Migration: 20261103000001_fix_handle_new_user_default_role.sql
-- Fix handle_new_user trigger so new agency registrations get role 'owner' by default
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_role VARCHAR;
  v_tenant_id VARCHAR;
  v_name VARCHAR;
BEGIN
  v_role := COALESCE(
    NEW.raw_app_meta_data->>'role',
    NEW.raw_user_meta_data->>'role',
    'owner'
  );
  v_tenant_id := COALESCE(
    NEW.raw_app_meta_data->>'tenant_id',
    NEW.raw_user_meta_data->>'tenant_id'
  );
  v_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    split_part(NEW.email, '@', 1),
    'User'
  );

  INSERT INTO public.profiles(id, name, email, phone, role, tenant_id, account_status, is_active)
  VALUES (
    NEW.id,
    v_name,
    NEW.email,
    NEW.phone,
    v_role,
    v_tenant_id,
    'active',
    true
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    role = CASE
      WHEN public.profiles.role IS NULL OR public.profiles.role = 'sales_person'
      THEN EXCLUDED.role
      ELSE public.profiles.role
    END,
    tenant_id = COALESCE(EXCLUDED.tenant_id, public.profiles.tenant_id),
    updated_at = now();

  RETURN NEW;
END $$;

