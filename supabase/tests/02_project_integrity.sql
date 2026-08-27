-- =====================================================================
-- 02 — Same-project structural integrity (run as service_role)
-- Expected: 23503 for cross-project references, 23514 for CHECK breaches.
-- =====================================================================
DO $$
DECLARE
  t uuid; org uuid; pa uuid; pb uuid;
  team_a uuid; team_b uuid; iter_b uuid; ti_b uuid; kpi_def uuid;
BEGIN
  INSERT INTO public.core_tenants (slug, name_en, name_ar, is_demo)
    VALUES ('test-proj','Test Proj','اختبار', true) RETURNING id INTO t;
  INSERT INTO public.core_organizations (tenant_id, azure_organization_name, base_url, name_en, name_ar)
    VALUES (t,'org','https://dev.azure.invalid/o','O','و') RETURNING id INTO org;
  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (t, org, 'pa','PA','PA','أ') RETURNING id INTO pa;
  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (t, org, 'pb','PB','PB','ب') RETURNING id INTO pb;
  INSERT INTO public.core_teams (tenant_id, organization_id, project_id, azure_team_id, azure_team_name, name_en, name_ar)
    VALUES (t, org, pa, 'ta','TA','TA','ف أ') RETURNING id INTO team_a;
  INSERT INTO public.core_teams (tenant_id, organization_id, project_id, azure_team_id, azure_team_name, name_en, name_ar)
    VALUES (t, org, pb, 'tb','TB','TB','ف ب') RETURNING id INTO team_b;
  INSERT INTO public.core_iterations (tenant_id, organization_id, project_id, azure_iteration_id, azure_iteration_path, name_en, name_ar)
    VALUES (t, org, pb, 'ib','PB\\S1','S1','س1') RETURNING id INTO iter_b;
  INSERT INTO public.core_team_iterations (tenant_id, organization_id, project_id, team_id, iteration_id)
    VALUES (t, org, pb, team_b, iter_b) RETURNING id INTO ti_b;
  SELECT id INTO kpi_def FROM public.an_kpi_definitions WHERE kpi_id = 'velocity' LIMIT 1;

  -- 2.1 team from project A + iteration from project B
  BEGIN
    INSERT INTO public.core_team_iterations (tenant_id, organization_id, project_id, team_id, iteration_id)
      VALUES (t, org, pa, team_a, iter_b);
    RAISE EXCEPTION 'TEST FAILED 2.1';
  EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'PASS 2.1 cross-project team iteration -> 23503';
  END;

  -- 2.2 KPI override with project A and team of project B
  BEGIN
    INSERT INTO public.an_kpi_configuration_overrides (tenant_id, kpi_definition_id, kpi_id, project_id, team_id)
      VALUES (t, kpi_def, 'velocity', pa, team_b);
    RAISE EXCEPTION 'TEST FAILED 2.2';
  EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'PASS 2.2 cross-project KPI override -> 23503';
  END;

  -- 2.3 KPI override with team but no project
  BEGIN
    INSERT INTO public.an_kpi_configuration_overrides (tenant_id, kpi_definition_id, kpi_id, team_id)
      VALUES (t, kpi_def, 'velocity', team_b);
    RAISE EXCEPTION 'TEST FAILED 2.3';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS 2.3 team without project -> 23514';
  END;

  -- 2.4 process mapping with project A and team of project B
  BEGIN
    INSERT INTO public.core_process_mappings (tenant_id, project_id, team_id)
      VALUES (t, pa, team_b);
    RAISE EXCEPTION 'TEST FAILED 2.4';
  EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'PASS 2.4 cross-project process mapping -> 23503';
  END;

  -- 2.5 work item in project A referencing iteration of project B
  BEGIN
    INSERT INTO public.az_work_items (tenant_id, organization_id, project_id, iteration_id,
      azure_work_item_id, title, azure_work_item_type, state)
      VALUES (t, org, pa, iter_b, 9001, 'X', 'User Story', 'Active');
    RAISE EXCEPTION 'TEST FAILED 2.5';
  EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'PASS 2.5 cross-project work item -> 23503';
  END;

  -- 2.6 snapshot in project A referencing team iteration of project B
  BEGIN
    INSERT INTO public.an_daily_iteration_snapshots
      (tenant_id, project_id, team_iteration_id, iteration_id, team_id, snapshot_date)
      VALUES (t, pa, ti_b, iter_b, team_a, current_date);
    RAISE EXCEPTION 'TEST FAILED 2.6';
  EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'PASS 2.6 cross-project snapshot -> 23503';
  END;

  -- 2.7 sentinel uuid can never be a real project id
  BEGIN
    INSERT INTO public.core_projects (id, tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
      VALUES ('00000000-0000-0000-0000-000000000000', t, org, 'ps','PS','PS','س');
    RAISE EXCEPTION 'TEST FAILED 2.7';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS 2.7 sentinel project id rejected -> 23514';
  END;

  DELETE FROM public.core_tenants WHERE id = t;
  RAISE NOTICE 'SUITE 02 PASSED';
END $$;
