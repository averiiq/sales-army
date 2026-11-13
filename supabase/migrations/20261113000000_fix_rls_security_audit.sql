-- Migration: Fix RLS security vulnerabilities found in audit
-- Date: 2026-11-13
-- Issues: Remove auth.uid() IS NULL (anon write access), fix order_items tenant isolation

-- ============================================================
-- 1. Drop all policies that allow unauthenticated (anon) writes
-- ============================================================

-- Tenants
DROP POLICY IF EXISTS "tenants_select_rbac" ON public.tenants;
DROP POLICY IF EXISTS "tenants_insert_rbac" ON public.tenants;
DROP POLICY IF EXISTS "tenants_update_rbac" ON public.tenants;
DROP POLICY IF EXISTS "tenants_delete_rbac" ON public.tenants;

CREATE POLICY "tenants_select_rbac" ON public.tenants FOR SELECT TO authenticated
  USING (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id());

CREATE POLICY "tenants_insert_rbac" ON public.tenants FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR public.get_auth_role() IN ('owner', 'distributor'));

CREATE POLICY "tenants_update_rbac" ON public.tenants FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR (tenant_id = public.get_auth_tenant_id() AND public.get_auth_role() IN ('owner', 'distributor')));

CREATE POLICY "tenants_delete_rbac" ON public.tenants FOR DELETE TO authenticated
  USING (public.is_super_admin());

-- Profiles
DROP POLICY IF EXISTS "profiles_select_rbac" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_rbac" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_rbac" ON public.profiles;

CREATE POLICY "profiles_select_rbac" ON public.profiles FOR SELECT TO authenticated
  USING (public.is_super_admin() OR tenant_id = public.get_auth_tenant_id() OR id = auth.uid()::text);

CREATE POLICY "profiles_insert_rbac" ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR id = auth.uid()::text);

CREATE POLICY "profiles_update_rbac" ON public.profiles FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR id = auth.uid()::text OR (tenant_id = public.get_auth_tenant_id() AND public.get_auth_role() IN ('owner', 'distributor')));

-- Platform settings — super admin only
DROP POLICY IF EXISTS "platform_settings_read" ON public.platform_settings;
DROP POLICY IF EXISTS "platform_settings_write" ON public.platform_settings;

CREATE POLICY "platform_settings_read" ON public.platform_settings FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "platform_settings_write" ON public.platform_settings FOR ALL TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- ============================================================
-- 2. Fix order_items — add tenant isolation via join to orders
-- ============================================================

DROP POLICY IF EXISTS "order_items_select_rbac" ON public.order_items;
DROP POLICY IF EXISTS "order_items_write_rbac" ON public.order_items;
DROP POLICY IF EXISTS "order_items_read" ON public.order_items;

CREATE POLICY "order_items_select_tenant" ON public.order_items FOR SELECT TO authenticated
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.order_id = order_items.order_id
        AND o.tenant_id = public.get_auth_tenant_id()
    )
  );

CREATE POLICY "order_items_write_tenant" ON public.order_items FOR ALL TO authenticated
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.order_id = order_items.order_id
        AND o.tenant_id = public.get_auth_tenant_id()
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.order_id = order_items.order_id
        AND o.tenant_id = public.get_auth_tenant_id()
    )
  );

-- ============================================================
-- 3. Fix financial_guards trigger to use auth.role() instead of current_user
-- ============================================================

CREATE OR REPLACE FUNCTION public.protect_shop_balance()
RETURNS TRIGGER AS $$
BEGIN
  -- Only enforce for authenticated users, not service role
  IF (SELECT auth.role()) = 'authenticated' THEN
    IF OLD.current_outstanding IS DISTINCT FROM NEW.current_outstanding THEN
      -- Allow the change but ensure it's been properly computed
      IF NEW.current_outstanding < 0 THEN
        NEW.current_outstanding := 0;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
