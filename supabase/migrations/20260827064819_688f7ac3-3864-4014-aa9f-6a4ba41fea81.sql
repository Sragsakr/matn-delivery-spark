-- =====================================================================
-- Phase 3.1 migration 15 — tenant-scoped authorization identity
-- Forward-only correction. Does not edit earlier migrations.
-- =====================================================================

-- 0. A person may legitimately belong to several tenants with the same
--    sign-in account. The global unique index made that impossible and
--    hid the ambiguity that this migration fixes.
DROP INDEX IF EXISTS public.core_users_auth_user_unique;
CREATE UNIQUE INDEX IF NOT EXISTS core_users_tenant_auth_user_unique
  ON public.core_users (tenant_id, auth_user_id);

-- 1. Drop every policy that depends on the ambiguous helpers ------------
DROP POLICY IF EXISTS "own roles or tenant admin" ON public.core_user_roles;
DROP POLICY IF EXISTS "own project scopes or tenant admin" ON public.core_user_project_scopes;
DROP POLICY IF EXISTS "own team scopes or tenant admin" ON public.core_user_team_scopes;
DROP POLICY IF EXISTS "tenant admins read retention settings" ON public.core_tenant_retention_settings;
DROP POLICY IF EXISTS "tenant admins read raw payloads" ON public.az_raw_payloads;
DROP POLICY IF EXISTS "own copilot answers" ON public.intel_copilot_answers;
DROP POLICY IF EXISTS "admins read audit" ON public.aud_audit_events;
DROP POLICY IF EXISTS "member detail capacity read" ON public.core_member_capacity;
DROP POLICY IF EXISTS "member snapshot read" ON public.an_daily_member_snapshots;
DROP POLICY IF EXISTS "scoped kpi value read" ON public.an_kpi_values;
DROP POLICY IF EXISTS "authenticated read kpi catalog" ON public.an_kpi_definitions;
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'ops_sync_connections','ops_sync_runs','ops_sync_cursors','ops_sync_locks',
    'ops_snapshot_job_runs','ops_data_quality_issues'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "tenant admins read operations" ON public.%I', t);
  END LOOP;
END $$;

-- 2. Drop the ambiguous helpers ----------------------------------------
DROP FUNCTION IF EXISTS public.is_platform_admin();
DROP FUNCTION IF EXISTS public.has_role(public.app_role);
DROP FUNCTION IF EXISTS public.current_core_user_id();
-- current_tenant_id() is removed outright: no validated server-side session
-- context exists in Phase 3, so an "active tenant" cannot be trusted.
DROP FUNCTION IF EXISTS public.current_tenant_id();

-- 3. Tenant-scoped identity --------------------------------------------
CREATE OR REPLACE FUNCTION public.current_core_user_id(target_tenant_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.id
  FROM public.core_users u
  WHERE u.auth_user_id = (SELECT auth.uid())
    AND u.tenant_id = target_tenant_id
    AND u.is_active;
$$;

-- Model B: platform_admin is a TENANT-SCOPED role. It confers no authority
-- outside the tenant of the core_users row that holds it. A future global
-- platform identity (model A) would live in a separate table.
CREATE OR REPLACE FUNCTION public.has_role(target_tenant_id uuid, target_role public.app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT target_tenant_id IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM public.core_user_roles r
       JOIN public.core_users u
         ON u.id = r.user_id AND u.tenant_id = r.tenant_id
       WHERE u.auth_user_id = (SELECT auth.uid())
         AND u.is_active
         AND u.tenant_id = target_tenant_id
         AND r.tenant_id = target_tenant_id
         AND r.role = target_role
         AND r.revoked_at IS NULL
     );
$$;

CREATE OR REPLACE FUNCTION public.is_tenant_platform_admin(target_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT public.has_role(target_tenant_id, 'platform_admin'::public.app_role);
$$;

CREATE OR REPLACE FUNCTION public.is_tenant_admin(target_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT public.has_role(target_tenant_id, 'tenant_admin'::public.app_role)
      OR public.has_role(target_tenant_id, 'platform_admin'::public.app_role);
$$;

-- 4. Member-detail rule -------------------------------------------------
-- Documented rule (Phase 3.1):
--   * tenant_admin / platform_admin / delivery_manager / team_lead /
--     qa_release_owner : member detail for teams they can access
--   * executive_viewer : aggregate only, always
--   * contributor / readonly_viewer : aggregate only, EXCEPT their own
--     member record, which they may always read
CREATE OR REPLACE FUNCTION public.is_own_member_record(target_tenant_id uuid, target_member_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.core_users u
    JOIN public.core_members m
      ON m.tenant_id = u.tenant_id AND m.email = u.email
    WHERE u.auth_user_id = (SELECT auth.uid())
      AND u.is_active
      AND u.tenant_id = target_tenant_id
      AND m.id = target_member_id
  );
$$;

CREATE OR REPLACE FUNCTION public.can_view_member_detail(target_tenant_id uuid, target_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.has_team_access(target_tenant_id, target_team_id)
     AND EXISTS (
       SELECT 1
       FROM public.core_user_roles r
       JOIN public.core_users u
         ON u.id = r.user_id AND u.tenant_id = r.tenant_id
       WHERE u.auth_user_id = (SELECT auth.uid())
         AND u.is_active
         AND u.tenant_id = target_tenant_id
         AND r.tenant_id = target_tenant_id
         AND r.revoked_at IS NULL
         AND r.role IN ('platform_admin'::public.app_role,
                        'tenant_admin'::public.app_role,
                        'delivery_manager'::public.app_role,
                        'team_lead'::public.app_role,
                        'qa_release_owner'::public.app_role)
     );
$$;

-- 5. Recreate the policies, tenant-scoped -------------------------------
CREATE POLICY "own roles or tenant admin" ON public.core_user_roles
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (user_id = public.current_core_user_id(tenant_id)
         OR public.is_tenant_admin(tenant_id))
  );

CREATE POLICY "own project scopes or tenant admin" ON public.core_user_project_scopes
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (user_id = public.current_core_user_id(tenant_id)
         OR public.is_tenant_admin(tenant_id))
  );

CREATE POLICY "own team scopes or tenant admin" ON public.core_user_team_scopes
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (user_id = public.current_core_user_id(tenant_id)
         OR public.is_tenant_admin(tenant_id))
  );

CREATE POLICY "tenant admins read retention settings" ON public.core_tenant_retention_settings
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id) AND public.is_tenant_admin(tenant_id)
  );

CREATE POLICY "tenant admins read raw payloads" ON public.az_raw_payloads
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id) AND public.is_tenant_admin(tenant_id)
  );

CREATE POLICY "own copilot answers" ON public.intel_copilot_answers
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (asked_by_user_id = public.current_core_user_id(tenant_id)
         OR public.is_tenant_admin(tenant_id))
  );

CREATE POLICY "admins read audit" ON public.aud_audit_events
  FOR SELECT TO authenticated USING (
    tenant_id IS NOT NULL
    AND public.has_tenant_access(tenant_id)
    AND public.is_tenant_admin(tenant_id)
  );

CREATE POLICY "member detail capacity read" ON public.core_member_capacity
  FOR SELECT TO authenticated USING (
    public.is_own_member_record(tenant_id, member_id)
    OR EXISTS (
      SELECT 1 FROM public.core_team_iterations ti
      WHERE ti.id = core_member_capacity.team_iteration_id
        AND ti.tenant_id = core_member_capacity.tenant_id
        AND public.can_view_member_detail(ti.tenant_id, ti.team_id)
    )
  );

CREATE POLICY "member snapshot read" ON public.an_daily_member_snapshots
  FOR SELECT TO authenticated USING (
    public.is_own_member_record(tenant_id, member_id)
    OR public.can_view_member_detail(tenant_id, team_id)
  );

CREATE POLICY "scoped kpi value read" ON public.an_kpi_values
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (project_id IS NULL OR public.has_project_access(tenant_id, project_id))
    AND (member_id IS NULL
         OR public.is_own_member_record(tenant_id, member_id)
         OR (team_id IS NOT NULL AND public.can_view_member_detail(tenant_id, team_id)))
  );

-- Global, tenant-agnostic KPI catalog: explicitly documented platform table.
CREATE POLICY "authenticated read kpi catalog" ON public.an_kpi_definitions
  FOR SELECT TO authenticated USING (true);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'ops_sync_connections','ops_sync_runs','ops_sync_cursors','ops_sync_locks',
    'ops_snapshot_job_runs','ops_data_quality_issues'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY "tenant admins read operations" ON public.%I
         FOR SELECT TO authenticated
         USING (public.has_tenant_access(tenant_id)
                AND public.is_tenant_admin(tenant_id))', t);
  END LOOP;
END $$;

-- 6. Execute grants for the new helpers ---------------------------------
DO $$
DECLARE sig text;
BEGIN
  FOREACH sig IN ARRAY ARRAY[
    'public.current_core_user_id(uuid)',
    'public.has_role(uuid, public.app_role)',
    'public.is_tenant_platform_admin(uuid)',
    'public.is_tenant_admin(uuid)',
    'public.is_own_member_record(uuid, uuid)',
    'public.can_view_member_detail(uuid, uuid)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', sig);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', sig);
  END LOOP;
END $$;

-- 7. Client roles are strictly read-only in Phase 3, and RLS is forced ---
DO $$
DECLARE t record;
BEGIN
  FOR t IN SELECT c.relname
           FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
           WHERE ns.nspname = 'public' AND c.relkind = 'r'
             AND (c.relname LIKE 'core\_%' OR c.relname LIKE 'az\_%'
               OR c.relname LIKE 'an\_%'  OR c.relname LIKE 'intel\_%'
               OR c.relname LIKE 'ops\_%' OR c.relname LIKE 'aud\_%')
  LOOP
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', t.relname);
    EXECUTE format(
      'REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.%I FROM authenticated',
      t.relname);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.relname);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', t.relname);
  END LOOP;
END $$;

COMMENT ON FUNCTION public.has_role(uuid, public.app_role) IS
  'Tenant-scoped role check. A role held in tenant A never authorizes tenant B.';
COMMENT ON FUNCTION public.is_tenant_platform_admin(uuid) IS
  'Phase 3.1 model B: platform_admin is tenant-scoped, not a global identity.';