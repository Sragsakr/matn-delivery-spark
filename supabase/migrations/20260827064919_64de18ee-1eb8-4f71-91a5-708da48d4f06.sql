-- =====================================================================
-- Phase 3.1 migration 16 — explicit demo seed lifecycle
-- Forward-only correction for migration 14, which ended with an
-- unconditional `SELECT public.seed_demo_tenant();`.
-- =====================================================================

-- The deterministic demo identity created by seed_demo_tenant().
-- Removal is matched on id AND slug AND is_demo — never on is_demo alone.
DROP FUNCTION IF EXISTS public.remove_demo_tenant();
CREATE OR REPLACE FUNCTION public.remove_demo_tenant()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _demo_id   uuid := '11111111-1111-4111-8111-111111111111';
  _demo_slug text := 'matn-demo';
  _removed   integer := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.core_tenants
    WHERE id = _demo_id AND slug = _demo_slug AND is_demo = true
  ) THEN
    RETURN 0;
  END IF;

  -- audit rows cascade from the tenant; the append-only guard has to be
  -- lifted for exactly this transaction so the deterministic demo tenant
  -- can be withdrawn in full.
  ALTER TABLE public.aud_audit_events DISABLE TRIGGER append_only;

  -- granted_by_user_id references core_users without a cascade, so scope
  -- rows are withdrawn explicitly before the tenant itself.
  DELETE FROM public.core_user_project_scopes WHERE tenant_id = _demo_id;
  DELETE FROM public.core_user_team_scopes    WHERE tenant_id = _demo_id;
  DELETE FROM public.core_user_roles          WHERE tenant_id = _demo_id;

  DELETE FROM public.core_tenants
   WHERE id = _demo_id AND slug = _demo_slug AND is_demo = true;
  GET DIAGNOSTICS _removed = ROW_COUNT;

  ALTER TABLE public.aud_audit_events ENABLE TRIGGER append_only;
  RETURN _removed;
END;
$$;

REVOKE ALL ON FUNCTION public.remove_demo_tenant() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.remove_demo_tenant() FROM anon;
REVOKE ALL ON FUNCTION public.remove_demo_tenant() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.remove_demo_tenant() TO service_role;

COMMENT ON FUNCTION public.remove_demo_tenant() IS
  'Development-only, service_role-only. Removes the single deterministic demo tenant (id 1111...1111, slug matn-demo, is_demo). Never deletes on is_demo alone.';
COMMENT ON FUNCTION public.seed_demo_tenant() IS
  'Development-only, service_role-only. Must be invoked explicitly; it is never called by a migration. Refuses to run when any non-demo tenant exists.';

-- Undo the automatic seeding performed by migration 14.
SELECT public.remove_demo_tenant();