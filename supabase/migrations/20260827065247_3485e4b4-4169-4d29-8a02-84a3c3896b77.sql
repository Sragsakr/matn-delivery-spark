-- =====================================================================
-- Phase 3.1 migration 18 — CI fixture cleanup, service_role only.
-- Only removes tenants flagged is_demo with the reserved 'ci-' slug
-- prefix; a real tenant can never match.
-- =====================================================================
CREATE OR REPLACE FUNCTION public.purge_ci_tenant(_tenant_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE _removed integer := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.core_tenants
    WHERE id = _tenant_id AND is_demo = true AND slug LIKE 'ci-%'
  ) THEN
    RAISE EXCEPTION 'not a CI fixture tenant' USING ERRCODE = '42501';
  END IF;

  ALTER TABLE public.aud_audit_events DISABLE TRIGGER append_only;
  DELETE FROM public.core_user_project_scopes WHERE tenant_id = _tenant_id;
  DELETE FROM public.core_user_team_scopes    WHERE tenant_id = _tenant_id;
  DELETE FROM public.core_user_roles          WHERE tenant_id = _tenant_id;
  DELETE FROM public.core_tenants WHERE id = _tenant_id;
  GET DIAGNOSTICS _removed = ROW_COUNT;
  ALTER TABLE public.aud_audit_events ENABLE TRIGGER append_only;
  RETURN _removed;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_ci_tenant(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.purge_ci_tenant(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.purge_ci_tenant(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.purge_ci_tenant(uuid) TO service_role;

COMMENT ON FUNCTION public.purge_ci_tenant(uuid) IS
  'Test-only, service_role-only cleanup for is_demo tenants with a ci- slug prefix.';