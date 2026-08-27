-- =====================================================================
-- 01 — Tenant isolation (constraint level, run as service_role)
-- Expected: 23503 foreign_key_violation on every cross-tenant attempt.
-- Self-cleaning: fixtures are removed at the end.
-- =====================================================================
DO $$
DECLARE
  ta uuid; tb uuid;
  org_a uuid; org_b uuid;
  proj_a uuid; proj_b uuid;
  team_a uuid;
  iter_b uuid;
BEGIN
  INSERT INTO public.core_tenants (slug, name_en, name_ar, is_demo)
    VALUES ('test-a','Test A','اختبار أ', true) RETURNING id INTO ta;
  INSERT INTO public.core_tenants (slug, name_en, name_ar, is_demo)
    VALUES ('test-b','Test B','اختبار ب', true) RETURNING id INTO tb;

  INSERT INTO public.core_organizations (tenant_id, azure_organization_name, base_url, name_en, name_ar)
    VALUES (ta,'org-a','https://dev.azure.invalid/a','A','أ') RETURNING id INTO org_a;
  INSERT INTO public.core_organizations (tenant_id, azure_organization_name, base_url, name_en, name_ar)
    VALUES (tb,'org-b','https://dev.azure.invalid/b','B','ب') RETURNING id INTO org_b;

  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (ta, org_a, 'p-a', 'PA','PA','ب أ') RETURNING id INTO proj_a;
  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (tb, org_b, 'p-b', 'PB','PB','ب ب') RETURNING id INTO proj_b;

  INSERT INTO public.core_teams (tenant_id, organization_id, project_id, azure_team_id, azure_team_name, name_en, name_ar)
    VALUES (ta, org_a, proj_a, 't-a','TA','TA','ف أ') RETURNING id INTO team_a;
  INSERT INTO public.core_iterations (tenant_id, organization_id, project_id, azure_iteration_id, azure_iteration_path, name_en, name_ar)
    VALUES (tb, org_b, proj_b, 'i-b','PB\\S1','S1','س1') RETURNING id INTO iter_b;

  -- 1.1 cross-tenant team: tenant A team pointing at tenant B project
  BEGIN
    INSERT INTO public.core_teams (tenant_id, organization_id, project_id, azure_team_id, azure_team_name, name_en, name_ar)
      VALUES (ta, org_a, proj_b, 't-x','TX','TX','ف س');
    RAISE EXCEPTION 'TEST FAILED 1.1: cross-tenant team was accepted';
  EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'PASS 1.1 cross-tenant team -> 23503';
  END;

  -- 1.2 cross-tenant team iteration
  BEGIN
    INSERT INTO public.core_team_iterations (tenant_id, organization_id, project_id, team_id, iteration_id)
      VALUES (ta, org_a, proj_a, team_a, iter_b);
    RAISE EXCEPTION 'TEST FAILED 1.2: cross-tenant team iteration was accepted';
  EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'PASS 1.2 cross-tenant team iteration -> 23503';
  END;

  -- 1.3 cross-tenant scope grant
  BEGIN
    INSERT INTO public.core_user_project_scopes (tenant_id, user_id, project_id)
      VALUES (ta, gen_random_uuid(), proj_b);
    RAISE EXCEPTION 'TEST FAILED 1.3: cross-tenant scope grant was accepted';
  EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'PASS 1.3 cross-tenant scope grant -> 23503';
  END;

  -- 1.4 tenant re-parenting must fail (immutability trigger, 23514)
  BEGIN
    UPDATE public.core_teams SET tenant_id = tb WHERE id = team_a;
    RAISE EXCEPTION 'TEST FAILED 1.4: tenant re-parenting was accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS 1.4 tenant re-parenting rejected';
  END;

  DELETE FROM public.core_tenants WHERE id IN (ta, tb);
  RAISE NOTICE 'SUITE 01 PASSED';
END $$;
