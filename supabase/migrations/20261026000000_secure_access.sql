-- Apply after both historical migrations or COMPLETE_SUPABASE_SETUP.sql.
-- All historical permissive policies must be removed: PostgreSQL ORs policies.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_auth_role() RETURNS varchar
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT role FROM public.profiles WHERE id = auth.uid() AND is_active AND account_status = 'active' $$;
CREATE OR REPLACE FUNCTION public.get_auth_tenant_id() RETURNS varchar
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT tenant_id FROM public.profiles WHERE id = auth.uid() AND is_active AND account_status = 'active' $$;
CREATE OR REPLACE FUNCTION public.is_super_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT COALESCE(public.get_auth_role() = 'super_admin', false) $$;

-- Never derive authority from user-editable metadata or email addresses.
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles(id, name, email, phone, role, tenant_id, account_status, is_active)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1), 'User'),
    NEW.email, NEW.phone, COALESCE(NEW.raw_app_meta_data->>'role', 'sales_person'),
    NEW.raw_app_meta_data->>'tenant_id', 'active', true)
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, updated_at = now();
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.protect_profile_authority() RETURNS trigger
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF auth.role() = 'authenticated' AND NOT public.is_super_admin() AND
    (NEW.role, NEW.tenant_id, NEW.account_status, NEW.is_active) IS DISTINCT FROM
    (OLD.role, OLD.tenant_id, OLD.account_status, OLD.is_active) THEN
    RAISE EXCEPTION 'Role, membership and account status are administrator-managed';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS protect_profile_authority ON public.profiles;
CREATE TRIGGER protect_profile_authority BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_authority();

CREATE OR REPLACE FUNCTION public.assign_user_role(target_user_id uuid, new_role varchar, new_tenant_id varchar DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_super_admin() THEN RAISE EXCEPTION 'Super Admin required'; END IF;
  IF new_role NOT IN ('super_admin','owner','distributor','sales_person','salesman','accountant','delivery_agent','delivery','manager','store_manager') THEN
    RAISE EXCEPTION 'Invalid role';
  END IF;
  UPDATE public.profiles SET role = new_role, tenant_id = COALESCE(new_tenant_id, tenant_id), updated_at = now()
  WHERE id = target_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'User not found'; END IF;
  RETURN jsonb_build_object('success', true);
END $$;
REVOKE ALL ON FUNCTION public.assign_user_role(uuid,varchar,varchar) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_user_role(uuid,varchar,varchar) TO authenticated;

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), notification_id varchar(64) UNIQUE NOT NULL,
  tenant_id varchar(64) REFERENCES public.tenants(tenant_id) ON DELETE CASCADE,
  target_uid varchar(64), target_role varchar(50), type varchar(50) NOT NULL DEFAULT 'system',
  title varchar(255) NOT NULL, message text NOT NULL, data jsonb DEFAULT '{}',
  is_read boolean DEFAULT false, is_broadcast boolean DEFAULT false,
  created_by varchar(64) DEFAULT 'system', created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS max_users integer DEFAULT 1;
ALTER TABLE public.tenants ADD COLUMN IF NOT EXISTS max_shops integer DEFAULT 200;

DO $$ DECLARE t text; p record; BEGIN
  FOREACH t IN ARRAY ARRAY['tenants','profiles','categories','products','shops','orders','order_items','invoices','payments','ledger_entries','visits','platform_settings','printer_hardware_orders','notifications'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=t LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', p.policyname, t);
    END LOOP;
    EXECUTE format('CREATE POLICY admin_all ON public.%I FOR ALL TO authenticated USING (public.is_super_admin()) WITH CHECK (public.is_super_admin())', t);
  END LOOP;
END $$;

CREATE POLICY tenant_read ON public.tenants FOR SELECT TO authenticated USING (tenant_id = public.get_auth_tenant_id());
CREATE POLICY tenant_update ON public.tenants FOR UPDATE TO authenticated
USING (tenant_id = public.get_auth_tenant_id() AND public.get_auth_role() IN ('owner','distributor'))
WITH CHECK (tenant_id = public.get_auth_tenant_id());
CREATE OR REPLACE FUNCTION public.protect_tenant_governance() RETURNS trigger
LANGUAGE plpgsql SET search_path=public AS $$ BEGIN
  IF auth.role()='authenticated' AND NOT public.is_super_admin() AND
    (NEW.tenant_id,NEW.owner_uid,NEW.plan_id,NEW.subscription_status,NEW.subscription_end_date,NEW.is_active,NEW.max_users,NEW.max_shops)
    IS DISTINCT FROM (OLD.tenant_id,OLD.owner_uid,OLD.plan_id,OLD.subscription_status,OLD.subscription_end_date,OLD.is_active,OLD.max_users,OLD.max_shops)
  THEN RAISE EXCEPTION 'Subscription and ownership fields are server-managed'; END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS protect_tenant_governance ON public.tenants;
CREATE TRIGGER protect_tenant_governance BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION public.protect_tenant_governance();

CREATE POLICY profile_read ON public.profiles FOR SELECT TO authenticated
USING (id=auth.uid() OR tenant_id=public.get_auth_tenant_id());
CREATE POLICY profile_self_update ON public.profiles FOR UPDATE TO authenticated USING (id=auth.uid()) WITH CHECK (id=auth.uid());
CREATE POLICY published_settings ON public.platform_settings FOR SELECT TO anon, authenticated
USING (id IN ('pricing_and_plans','remote_config','broadcast','general_settings'));
CREATE POLICY tenant_settings ON public.platform_settings FOR ALL TO authenticated
USING (id IN ('tenant_profile_' || public.get_auth_tenant_id(), 'gst_billing_' || public.get_auth_tenant_id()))
WITH CHECK (id IN ('tenant_profile_' || public.get_auth_tenant_id(), 'gst_billing_' || public.get_auth_tenant_id()) AND public.get_auth_role() IN ('owner','distributor'));

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['categories','products','shops','orders','invoices','payments','ledger_entries','visits','printer_hardware_orders'] LOOP
    EXECUTE format('CREATE POLICY member_read ON public.%I FOR SELECT TO authenticated USING (tenant_id=public.get_auth_tenant_id())',t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['categories','products'] LOOP
    EXECUTE format('CREATE POLICY inventory_write ON public.%I FOR ALL TO authenticated USING (tenant_id=public.get_auth_tenant_id() AND public.get_auth_role() IN (''owner'',''distributor'',''manager'',''store_manager'')) WITH CHECK (tenant_id=public.get_auth_tenant_id() AND public.get_auth_role() IN (''owner'',''distributor'',''manager'',''store_manager''))',t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['shops','visits'] LOOP
    EXECUTE format('CREATE POLICY sales_write ON public.%I FOR ALL TO authenticated USING (tenant_id=public.get_auth_tenant_id() AND public.get_auth_role() IN (''owner'',''distributor'',''sales_person'',''salesman'')) WITH CHECK (tenant_id=public.get_auth_tenant_id())',t);
  END LOOP;
END $$;
CREATE POLICY order_items_read ON public.order_items FOR SELECT TO authenticated USING
(EXISTS(SELECT 1 FROM public.orders o WHERE o.id=order_items.order_id AND o.tenant_id=public.get_auth_tenant_id()));
CREATE POLICY notification_read ON public.notifications FOR SELECT TO authenticated USING
((tenant_id=public.get_auth_tenant_id() OR is_broadcast) AND (target_uid IS NULL OR target_uid=auth.uid()::text)
AND (target_role IS NULL OR target_role='all' OR target_role=public.get_auth_role()));

-- Remove old client-stored payment credentials from JSON configuration.
UPDATE public.platform_settings SET data = jsonb_set(data, '{paymentGatewayConfig}',
  (data->'paymentGatewayConfig') - 'keySecret' - 'webhookSecret')
WHERE jsonb_typeof(data->'paymentGatewayConfig')='object';
COMMIT;
