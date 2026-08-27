-- =====================================================================
-- 05 — Immutability: revisions, finalized snapshots, audit, re-parenting
-- Run as service_role. Wrapped in a transaction and rolled back.
-- =====================================================================
BEGIN;

DO $$
DECLARE
  t uuid; org uuid; p uuid; team uuid; iter uuid; ti uuid; wi uuid; rev_id uuid; snap uuid; ev uuid;
BEGIN
  INSERT INTO public.core_tenants (slug, name_en, name_ar, is_demo)
    VALUES ('test-immut','Immutable','ثبات', true) RETURNING id INTO t;
  INSERT INTO public.core_organizations (tenant_id, azure_organization_name, base_url, name_en, name_ar)
    VALUES (t,'org','https://dev.azure.invalid/o','O','و') RETURNING id INTO org;
  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (t, org,'p','P','P','ب') RETURNING id INTO p;
  INSERT INTO public.core_teams (tenant_id, organization_id, project_id, azure_team_id, azure_team_name, name_en, name_ar)
    VALUES (t, org, p,'tm','TM','TM','ف') RETURNING id INTO team;
  INSERT INTO public.core_iterations (tenant_id, organization_id, project_id, azure_iteration_id, azure_iteration_path, name_en, name_ar)
    VALUES (t, org, p,'it','P\\S1','S1','س1') RETURNING id INTO iter;
  INSERT INTO public.core_team_iterations (tenant_id, organization_id, project_id, team_id, iteration_id)
    VALUES (t, org, p, team, iter) RETURNING id INTO ti;
  INSERT INTO public.az_work_items (tenant_id, organization_id, project_id, azure_work_item_id, title, azure_work_item_type, state)
    VALUES (t, org, p, 7001, 'Item', 'User Story', 'Active') RETURNING id INTO wi;
  INSERT INTO public.az_work_item_revisions (tenant_id, project_id, work_item_id, azure_work_item_id, rev, revised_at, fields)
    VALUES (t, p, wi, 7001, 1, now(), '{}'::jsonb) RETURNING id INTO rev_id;
  INSERT INTO public.an_daily_iteration_snapshots (tenant_id, project_id, team_iteration_id, iteration_id, team_id, snapshot_date, finalized_at)
    VALUES (t, p, ti, iter, team, current_date, now()) RETURNING id INTO snap;
  ev := public.write_audit_event(t, NULL, 'test.event', 'core_tenants', t, 'success'::public.audit_outcome, NULL, '{}'::jsonb);

  -- 5.1 revision update fails
  BEGIN
    UPDATE public.az_work_item_revisions SET rev = 2 WHERE id = rev_id;
    RAISE EXCEPTION 'TEST FAILED 5.1: revision update accepted';
  EXCEPTION WHEN check_violation OR insufficient_privilege THEN RAISE NOTICE 'PASS 5.1 revision update blocked';
  END;

  -- 5.2 revision delete fails
  BEGIN
    DELETE FROM public.az_work_item_revisions WHERE id = rev_id;
    RAISE EXCEPTION 'TEST FAILED 5.2: revision delete accepted';
  EXCEPTION WHEN check_violation OR insufficient_privilege THEN RAISE NOTICE 'PASS 5.2 revision delete blocked';
  END;

  -- 5.3 finalized snapshot update fails
  BEGIN
    UPDATE public.an_daily_iteration_snapshots SET completed_estimate = 5 WHERE id = snap;
    RAISE EXCEPTION 'TEST FAILED 5.3: finalized snapshot update accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS 5.3 finalized snapshot immutable';
  END;

  -- 5.4 audit update fails
  BEGIN
    UPDATE public.aud_audit_events SET action = 'tampered' WHERE id = ev;
    RAISE EXCEPTION 'TEST FAILED 5.4: audit update accepted';
  EXCEPTION WHEN check_violation OR insufficient_privilege THEN RAISE NOTICE 'PASS 5.4 audit update blocked';
  END;

  -- 5.5 audit delete fails
  BEGIN
    DELETE FROM public.aud_audit_events WHERE id = ev;
    RAISE EXCEPTION 'TEST FAILED 5.5: audit delete accepted';
  EXCEPTION WHEN check_violation OR insufficient_privilege THEN RAISE NOTICE 'PASS 5.5 audit delete blocked';
  END;

  -- 5.6 project re-parenting of a team iteration fails
  BEGIN
    UPDATE public.core_team_iterations SET project_id = gen_random_uuid() WHERE id = ti;
    RAISE EXCEPTION 'TEST FAILED 5.6: project re-parenting accepted';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE 'PASS 5.6 project re-parenting blocked';
  END;

  RAISE NOTICE 'SUITE 05 PASSED';
END $$;

ROLLBACK;
