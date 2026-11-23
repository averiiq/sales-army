-- Migration: onboard_agency_owner
-- Date: 2026-11-22
--
-- Lets a signed-in user who does NOT yet belong to any agency create their
-- own agency and become its owner — without the service-role key in the app.
-- Used by Google sign-up (the auth user already exists) and by email sign-up.
--
-- Safety:
--   * Caller must be authenticated (auth.uid()).
--   * Works only while the caller's profile has no tenant_id, so it can never
--     be used to hop into, or re-point, an existing agency.
--   * The tenant id is generated server-side; the client cannot choose it.
--   * Runs as SECURITY DEFINER so it may set profiles.tenant_id, which the
--     protect_profile_authority trigger otherwise blocks for end users.

BEGIN;

-- Enforce the authority guard on direct client writes (which run as the
-- `authenticated` DB role) but let trusted SECURITY DEFINER functions such as
-- onboard_agency_owner perform their controlled update. Previously the check
-- used auth.role(), which is the JWT claim and stays 'authenticated' even
-- inside definer functions, so no RPC could ever assign a tenant.
CREATE OR REPLACE FUNCTION public.protect_profile_authority() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_user = 'authenticated' AND NOT public.is_super_admin() AND
    (NEW.role, NEW.tenant_id, NEW.account_status, NEW.is_active) IS DISTINCT FROM
    (OLD.role, OLD.tenant_id, OLD.account_status, OLD.is_active) THEN
    RAISE EXCEPTION 'Role, membership and account status are administrator-managed';
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.onboard_agency_owner(
  p_business_name text,
  p_contact_person text,
  p_mobile text,
  p_city text,
  p_gstin text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_profile public.profiles;
  v_email text;
  v_slug text;
  v_tenant_id text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Sign in required';
  END IF;
  IF COALESCE(trim(p_business_name), '') = '' OR COALESCE(trim(p_contact_person), '') = ''
     OR COALESCE(trim(p_mobile), '') = '' OR COALESCE(trim(p_city), '') = '' THEN
    RAISE EXCEPTION 'Agency name, owner name, mobile and city are required';
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

  -- Ensure a profile row exists (handle_new_user normally creates it).
  INSERT INTO public.profiles (id, name, email, role, account_status, is_active)
  VALUES (v_uid, trim(p_contact_person), v_email, 'owner', 'active', true)
  ON CONFLICT (id) DO NOTHING;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_uid FOR UPDATE;
  IF v_profile.tenant_id IS NOT NULL THEN
    RAISE EXCEPTION 'This account already belongs to an agency';
  END IF;

  v_slug := left(regexp_replace(lower(trim(p_business_name)), '[^a-z0-9]+', '_', 'g'), 24);
  v_tenant_id := 'tenant_' || v_slug || '_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);

  INSERT INTO public.tenants (tenant_id, business_name, contact_person, email, mobile, city, gstin,
                              plan_id, subscription_status, is_active)
  VALUES (v_tenant_id, trim(p_business_name), trim(p_contact_person), v_email, trim(p_mobile), trim(p_city),
          NULLIF(upper(trim(COALESCE(p_gstin, ''))), ''), 'free', 'freemium', true);

  UPDATE public.profiles
     SET tenant_id = v_tenant_id,
         role = 'owner',
         name = COALESCE(NULLIF(trim(p_contact_person), ''), name),
         phone = COALESCE(NULLIF(trim(p_mobile), ''), phone),
         account_status = 'active',
         is_active = true,
         updated_at = now()
   WHERE id = v_uid;

  RETURN jsonb_build_object('tenant_id', v_tenant_id, 'uid', v_uid);
END $$;

REVOKE ALL ON FUNCTION public.onboard_agency_owner(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.onboard_agency_owner(text, text, text, text, text) TO authenticated;

COMMIT;
