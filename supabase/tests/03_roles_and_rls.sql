-- =====================================================================
-- 03 — Roles and RLS behaviour
-- Runs as service_role to build fixtures, then impersonates `authenticated`
-- with a JWT claim so RLS is evaluated exactly as it is for a browser user.
-- Wrap in a transaction and ROLLBACK: nothing is persisted.
-- =====================================================================
BEGIN;

DO $$
DECLARE
  t uuid; org uuid; pa uuid; pb uuid; team_a uuid; iter_a uuid; ti_a uuid;
  member_a uuid;
  admin_u uuid; dm_u uuid; exec_u uuid; lead_u uuid;
  auth_admin uuid := '22222222-2222-4222-8222-2222222222a1';
  auth_dm    uuid := '22222222-2222-4222-8222-2222222222a2';
  auth_exec  uuid := '22222222-2222-4222-8222-2222222222a3';
  auth_lead  uuid := '22222222-2222-4222-8222-2222222222a4';
BEGIN
  INSERT INTO public.core_tenants (slug, name_en, name_ar, is_demo)
    VALUES ('test-rls','RLS','صلاحيات', true) RETURNING id INTO t;
  INSERT INTO public.core_organizations (tenant_id, azure_organization_name, base_url, name_en, name_ar)
    VALUES (t,'org','https://dev.azure.invalid/o','O','و') RETURNING id INTO org;
  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (t, org,'pa','PA','PA','أ') RETURNING id INTO pa;
  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (t, org,'pb','PB','PB','ب') RETURNING id INTO pb;
  INSERT INTO public.core_teams (tenant_id, organization_id, project_id, azure_team_id, azure_team_name, name_en, name_ar)
    VALUES (t, org, pa,'ta','TA','TA','ف') RETURNING id INTO team_a;
  INSERT INTO public.core_iterations (tenant_id, organization_id, project_id, azure_iteration_id, azure_iteration_path, name_en, name_ar)
    VALUES (t, org, pa,'ia','PA\\S1','S1','س1') RETURNING id INTO iter_a;
  INSERT INTO public.core_team_iterations (tenant_id, organization_id, project_id, team_id, iteration_id, is_current)
    VALUES (t, org, pa, team_a, iter_a, true) RETURNING id INTO ti_a;
  INSERT INTO public.core_members (tenant_id, organization_id, azure_descriptor, display_name)
    VALUES (t, org, 'd1', 'Member One') RETURNING id INTO member_a;
  INSERT INTO public.an_daily_member_snapshots (tenant_id, project_id, team_id, member_id, snapshot_date, utilization)
    VALUES (t, pa, team_a, member_a, current_date, 0.8);

  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name)
    VALUES (t, auth_admin, 'a@example.invalid','Admin') RETURNING id INTO admin_u;
  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name)
    VALUES (t, auth_dm, 'dm@example.invalid','DM') RETURNING id INTO dm_u;
  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name)
    VALUES (t, auth_exec, 'ex@example.invalid','Exec') RETURNING id INTO exec_u;
  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name)
    VALUES (t, auth_lead, 'tl@example.invalid','Lead') RETURNING id INTO lead_u;

  INSERT INTO public.core_user_roles (tenant_id, user_id, role) VALUES
    (t, admin_u,'tenant_admin'), (t, dm_u,'delivery_manager'),
    (t, exec_u,'executive_viewer'), (t, lead_u,'team_lead');

  -- Delivery manager: project A only. Team lead: team A only. Expired grant for exec.
  INSERT INTO public.core_user_project_scopes (tenant_id, user_id, project_id, granted_by_user_id)
    VALUES (t, dm_u, pa, admin_u);
  INSERT INTO public.core_user_team_scopes (tenant_id, user_id, team_id, granted_by_user_id)
    VALUES (t, lead_u, team_a, admin_u);

  PERFORM set_config('test.tenant', t::text, true);
  PERFORM set_config('test.project_b', pb::text, true);
  PERFORM set_config('test.team_a', team_a::text, true);
END $$;

-- ---------------------------------------------------------------- checks
SET LOCAL ROLE authenticated;

-- 3.1 Delivery manager sees only project A
SET LOCAL request.jwt.claims = '{"sub":"22222222-2222-4222-8222-2222222222a2","role":"authenticated"}';
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.core_projects;
  IF n <> 1 THEN RAISE EXCEPTION 'TEST FAILED 3.1: delivery manager sees % projects', n; END IF;
  RAISE NOTICE 'PASS 3.1 delivery manager is project-limited';
END $$;

-- 3.2 Delivery manager cannot assign themselves a role
DO $$
BEGIN
  BEGIN
    INSERT INTO public.core_user_roles (tenant_id, user_id, role)
      SELECT tenant_id, id, 'tenant_admin' FROM public.core_users LIMIT 1;
    RAISE EXCEPTION 'TEST FAILED 3.2: self role assignment succeeded';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS 3.2 self role assignment denied';
  END;
END $$;

-- 3.3 Delivery manager cannot grant themselves scope
DO $$
BEGIN
  BEGIN
    INSERT INTO public.core_user_project_scopes (tenant_id, user_id, project_id)
      SELECT tenant_id, id, id FROM public.core_users LIMIT 1;
    RAISE EXCEPTION 'TEST FAILED 3.3: self scope grant succeeded';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS 3.3 self scope grant denied';
  END;
END $$;

-- 3.4 Team lead sees only team A
SET LOCAL request.jwt.claims = '{"sub":"22222222-2222-4222-8222-2222222222a4","role":"authenticated"}';
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.core_teams;
  IF n <> 1 THEN RAISE EXCEPTION 'TEST FAILED 3.4: team lead sees % teams', n; END IF;
  RAISE NOTICE 'PASS 3.4 team lead is team-limited';
END $$;

-- 3.5 Executive viewer cannot read member-level snapshots
SET LOCAL request.jwt.claims = '{"sub":"22222222-2222-4222-8222-2222222222a3","role":"authenticated"}';
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.an_daily_member_snapshots;
  IF n <> 0 THEN RAISE EXCEPTION 'TEST FAILED 3.5: executive viewer read % member rows', n; END IF;
  SELECT count(*) INTO n FROM public.core_projects;
  IF n <> 2 THEN RAISE EXCEPTION 'TEST FAILED 3.5b: executive viewer should see the whole tenant'; END IF;
  RAISE NOTICE 'PASS 3.5 executive viewer is aggregate-only';
END $$;

-- 3.6 Tenant admin is tenant-limited (no rows from other tenants exist for them)
SET LOCAL request.jwt.claims = '{"sub":"22222222-2222-4222-8222-2222222222a1","role":"authenticated"}';
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM public.core_tenants;
  IF n <> 1 THEN RAISE EXCEPTION 'TEST FAILED 3.6: tenant admin sees % tenants', n; END IF;
  RAISE NOTICE 'PASS 3.6 tenant admin is tenant-limited';
END $$;

-- 3.7 Unauthorized callers cannot execute the privileged grant functions
DO $$
BEGIN
  BEGIN
    PERFORM public.grant_project_scope(
      gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid());
    RAISE EXCEPTION 'TEST FAILED 3.7: authenticated executed grant_project_scope';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS 3.7 grant function not executable by authenticated';
  END;
END $$;

RESET ROLE;

-- 3.8 Expired scope denies access immediately
DO $$
DECLARE n int; dm uuid;
BEGIN
  SELECT id INTO dm FROM public.core_users WHERE email = 'dm@example.invalid';
  UPDATE public.core_user_project_scopes SET expires_at = now() - interval '1 second'
   WHERE user_id = dm;
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims',
    '{"sub":"22222222-2222-4222-8222-2222222222a2","role":"authenticated"}', true);
  SELECT count(*) INTO n FROM public.core_projects;
  RESET ROLE;
  IF n <> 0 THEN RAISE EXCEPTION 'TEST FAILED 3.8: expired scope still grants % projects', n; END IF;
  RAISE NOTICE 'PASS 3.8 expired scope denies immediately';
END $$;

DO $$ BEGIN RAISE NOTICE 'SUITE 03 PASSED'; END $$;

ROLLBACK;
