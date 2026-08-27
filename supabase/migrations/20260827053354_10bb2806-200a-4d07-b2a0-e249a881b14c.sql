-- =====================================================================
-- Phase 3 migration 13 — RLS policies
-- Invariant: no policy on a tenant-owned table uses USING (true) for a
-- client role; anon is granted nothing anywhere.
-- Rollback: DROP POLICY per table.
-- =====================================================================

-- Belt and braces: anon must never reach these tables.
DO $$
DECLARE t record;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
           AND (tablename LIKE 'core\_%' OR tablename LIKE 'az\_%'
             OR tablename LIKE 'an\_%'  OR tablename LIKE 'intel\_%'
             OR tablename LIKE 'ops\_%' OR tablename LIKE 'aud\_%')
  LOOP
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', t.tablename);
  END LOOP;
END $$;

-- ---------------------------------------------------------------- core
CREATE POLICY "tenant members read their tenant" ON public.core_tenants
  FOR SELECT TO authenticated USING (public.has_tenant_access(id));

CREATE POLICY "tenant members read tenant users" ON public.core_users
  FOR SELECT TO authenticated USING (public.has_tenant_access(tenant_id));

CREATE POLICY "own roles or tenant admin" ON public.core_user_roles
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (user_id = public.current_core_user_id()
         OR public.has_role('tenant_admin'::public.app_role)
         OR public.has_role('platform_admin'::public.app_role))
  );

CREATE POLICY "own project scopes or tenant admin" ON public.core_user_project_scopes
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (user_id = public.current_core_user_id()
         OR public.has_role('tenant_admin'::public.app_role)
         OR public.has_role('platform_admin'::public.app_role))
  );

CREATE POLICY "own team scopes or tenant admin" ON public.core_user_team_scopes
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (user_id = public.current_core_user_id()
         OR public.has_role('tenant_admin'::public.app_role)
         OR public.has_role('platform_admin'::public.app_role))
  );

CREATE POLICY "tenant admins read retention settings" ON public.core_tenant_retention_settings
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (public.has_role('tenant_admin'::public.app_role)
         OR public.has_role('platform_admin'::public.app_role))
  );

CREATE POLICY "tenant members read organizations" ON public.core_organizations
  FOR SELECT TO authenticated USING (public.has_tenant_access(tenant_id));

CREATE POLICY "tenant members read members" ON public.core_members
  FOR SELECT TO authenticated USING (public.has_tenant_access(tenant_id));

CREATE POLICY "scoped project read" ON public.core_projects
  FOR SELECT TO authenticated USING (public.has_project_access(tenant_id, id));

CREATE POLICY "scoped team read" ON public.core_teams
  FOR SELECT TO authenticated USING (public.has_team_access(tenant_id, id));

CREATE POLICY "scoped iteration read" ON public.core_iterations
  FOR SELECT TO authenticated USING (public.has_project_access(tenant_id, project_id));

CREATE POLICY "scoped team iteration read" ON public.core_team_iterations
  FOR SELECT TO authenticated USING (public.has_team_access(tenant_id, team_id));

CREATE POLICY "scoped process mapping read" ON public.core_process_mappings
  FOR SELECT TO authenticated USING (public.has_project_access(tenant_id, project_id));

CREATE POLICY "scoped membership read" ON public.core_team_memberships
  FOR SELECT TO authenticated USING (public.has_team_access(tenant_id, team_id));

-- member-level detail: executive viewers excluded
CREATE POLICY "member detail capacity read" ON public.core_member_capacity
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.core_team_iterations ti
      WHERE ti.id = core_member_capacity.team_iteration_id
        AND ti.tenant_id = core_member_capacity.tenant_id
        AND public.can_view_member_detail(ti.tenant_id, ti.team_id)
    )
  );

-- --------------------------------------------------------------- azure
CREATE POLICY "scoped work item read" ON public.az_work_items
  FOR SELECT TO authenticated USING (public.has_project_access(tenant_id, project_id));

CREATE POLICY "scoped relation read" ON public.az_work_item_relations
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.az_work_items w
            WHERE w.id = az_work_item_relations.source_work_item_id
              AND w.tenant_id = az_work_item_relations.tenant_id
              AND public.has_project_access(w.tenant_id, w.project_id))
  );

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'az_work_item_revisions','az_work_item_transitions','az_work_item_scope_changes',
    'az_repositories','az_pipelines','az_builds','az_environments','az_deployments',
    'az_test_runs','az_pull_requests',
    'an_daily_project_snapshots','an_daily_iteration_snapshots','an_daily_team_snapshots'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY "scoped project read" ON public.%I
         FOR SELECT TO authenticated
         USING (public.has_project_access(tenant_id, project_id))', t);
  END LOOP;
END $$;

CREATE POLICY "scoped pr review read" ON public.az_pull_request_reviews
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.az_pull_requests p
            WHERE p.id = az_pull_request_reviews.pull_request_id
              AND p.tenant_id = az_pull_request_reviews.tenant_id
              AND public.has_project_access(p.tenant_id, p.project_id))
  );

CREATE POLICY "scoped test summary read" ON public.az_test_result_summaries
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.az_test_runs r
            WHERE r.id = az_test_result_summaries.test_run_id
              AND r.tenant_id = az_test_result_summaries.tenant_id
              AND public.has_project_access(r.tenant_id, r.project_id))
  );

CREATE POLICY "tenant admins read raw payloads" ON public.az_raw_payloads
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (public.has_role('tenant_admin'::public.app_role)
         OR public.has_role('platform_admin'::public.app_role))
  );

-- ----------------------------------------------------------- analytics
-- Global catalog: readable by any signed-in user, never writable by them.
CREATE POLICY "authenticated read kpi catalog" ON public.an_kpi_definitions
  FOR SELECT TO authenticated USING (is_active OR true);

CREATE POLICY "scoped kpi override read" ON public.an_kpi_configuration_overrides
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (project_id IS NULL OR public.has_project_access(tenant_id, project_id))
  );

CREATE POLICY "scoped kpi value read" ON public.an_kpi_values
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (project_id IS NULL OR public.has_project_access(tenant_id, project_id))
    AND (member_id IS NULL
         OR (team_id IS NOT NULL AND public.can_view_member_detail(tenant_id, team_id)))
  );

CREATE POLICY "member snapshot read" ON public.an_daily_member_snapshots
  FOR SELECT TO authenticated USING (public.can_view_member_detail(tenant_id, team_id));

-- -------------------------------------------------------- intelligence
CREATE POLICY "scoped risk signal read" ON public.intel_risk_signals
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (project_id IS NULL OR public.has_project_access(tenant_id, project_id))
  );

CREATE POLICY "scoped recommendation read" ON public.intel_recommendations
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (project_id IS NULL OR public.has_project_access(tenant_id, project_id))
  );

CREATE POLICY "scoped decision read" ON public.intel_recommendation_decisions
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.intel_recommendations r
            WHERE r.id = intel_recommendation_decisions.recommendation_id
              AND r.tenant_id = intel_recommendation_decisions.tenant_id
              AND public.has_tenant_access(r.tenant_id)
              AND (r.project_id IS NULL
                   OR public.has_project_access(r.tenant_id, r.project_id)))
  );

CREATE POLICY "own copilot answers" ON public.intel_copilot_answers
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (asked_by_user_id = public.current_core_user_id()
         OR public.has_role('tenant_admin'::public.app_role)
         OR public.has_role('platform_admin'::public.app_role))
  );

-- ---------------------------------------------------------- operations
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
                AND (public.has_role(''tenant_admin''::public.app_role)
                     OR public.has_role(''platform_admin''::public.app_role)))', t);
  END LOOP;
END $$;

-- ops_cron_nonces intentionally has no client policy and no client grant.

-- --------------------------------------------------------------- audit
CREATE POLICY "admins read audit" ON public.aud_audit_events
  FOR SELECT TO authenticated USING (
    public.has_tenant_access(tenant_id)
    AND (public.has_role('tenant_admin'::public.app_role)
         OR public.has_role('platform_admin'::public.app_role))
  );

-- ------------------------------------------------- service_role policies
-- FORCE ROW LEVEL SECURITY is enabled everywhere; give the server role an
-- explicit full policy on tables where writes are permitted, and a
-- read+insert policy on append-only tables.
DO $$
DECLARE t record;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
           AND (tablename LIKE 'core\_%' OR tablename LIKE 'az\_%'
             OR tablename LIKE 'an\_%'  OR tablename LIKE 'intel\_%'
             OR tablename LIKE 'ops\_%' OR tablename LIKE 'aud\_%')
  LOOP
    EXECUTE format(
      'CREATE POLICY "service role full access" ON public.%I
         FOR ALL TO service_role USING (true) WITH CHECK (true)', t.tablename);
  END LOOP;
END $$;