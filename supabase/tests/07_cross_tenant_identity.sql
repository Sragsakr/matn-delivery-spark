-- =====================================================================
-- 07 — Phase 3.1 cross-tenant identity and role escalation regression
--
-- One auth.uid() is a member of tenant A (tenant_admin) and tenant B
-- (contributor), and is not a member of tenant C at all.
--
-- Wrapped in a transaction and rolled back: nothing is persisted.
-- =====================================================================
BEGIN;

DO $$
DECLARE
  ta uuid; tb uuid; tc uuid;
  org_a uuid; org_b uuid; org_c uuid;
  pa uuid; pb uuid; pc uuid;
  team_a uuid; team_b uuid;
  ua uuid; ub uuid; uc uuid; other_a uuid;
  shared_auth uuid := '33333333-3333-4333-8333-333333333301';
  outsider_auth uuid := '33333333-3333-4333-8333-333333333302';
BEGIN
  INSERT INTO public.core_tenants (slug, name_en, name_ar, is_demo)
    VALUES ('t31-a','T A','أ', true) RETURNING id INTO ta;
  INSERT INTO public.core_tenants (slug, name_en, name_ar, is_demo)
    VALUES ('t31-b','T B','ب', true) RETURNING id INTO tb;
  INSERT INTO public.core_tenants (slug, name_en, name_ar, is_demo)
    VALUES ('t31-c','T C','ج', true) RETURNING id INTO tc;

  INSERT INTO public.core_organizations (tenant_id, azure_organization_name, base_url, name_en, name_ar)
    VALUES (ta,'o-a','https://dev.azure.invalid/a','OA','أ') RETURNING id INTO org_a;
  INSERT INTO public.core_organizations (tenant_id, azure_organization_name, base_url, name_en, name_ar)
    VALUES (tb,'o-b','https://dev.azure.invalid/b','OB','ب') RETURNING id INTO org_b;
  INSERT INTO public.core_organizations (tenant_id, azure_organization_name, base_url, name_en, name_ar)
    VALUES (tc,'o-c','https://dev.azure.invalid/c','OC','ج') RETURNING id INTO org_c;

  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (ta, org_a,'pa','PA','PA','أ') RETURNING id INTO pa;
  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (tb, org_b,'pb','PB','PB','ب') RETURNING id INTO pb;
  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (tc, org_c,'pc','PC','PC','ج') RETURNING id INTO pc;

  INSERT INTO public.core_teams (tenant_id, organization_id, project_id, azure_team_id, azure_team_name, name_en, name_ar)
    VALUES (ta, org_a, pa,'ta','TA','TA','ف أ') RETURNING id INTO team_a;
  INSERT INTO public.core_teams (tenant_id, organization_id, project_id, azure_team_id, azure_team_name, name_en, name_ar)
    VALUES (tb, org_b, pb,'tb','TB','TB','ف ب') RETURNING id INTO team_b;

  -- SAME auth.uid() in two tenants, different roles
  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name)
    VALUES (ta, shared_auth, 'dual@example.invalid','Dual A') RETURNING id INTO ua;
  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name)
    VALUES (tb, shared_auth, 'dual@example.invalid','Dual B') RETURNING id INTO ub;
  -- an unrelated tenant-C member, and a second tenant-A user
  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name)
    VALUES (tc, outsider_auth, 'out@example.invalid','Outsider') RETURNING id INTO uc;
  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name)
    VALUES (ta, '33333333-3333-4333-8333-333333333303', 'other@example.invalid','Other A')
    RETURNING id INTO other_a;

  INSERT INTO public.core_user_roles (tenant_id, user_id, role) VALUES
    (ta, ua, 'tenant_admin'),
    (tb, ub, 'contributor'),
    (tc, uc, 'tenant_admin'),
    (ta, other_a, 'contributor');

  INSERT INTO public.core_tenant_retention_settings (tenant_id, rule_key, retention_days, minimum_days) VALUES
    (ta,'audit_events',730,730), (tb,'audit_events',730,730), (tc,'audit_events',730,730);

  PERFORM public.write_audit_event(ta, ua, 'test.a', 'core_tenants', ta);
  PERFORM public.write_audit_event(tb, ub, 'test.b', 'core_tenants', tb);
  PERFORM public.write_audit_event(tc, uc, 'test.c', 'core_tenants', tc);

  INSERT INTO public.intel_copilot_answers (tenant_id, asked_by_user_id, question, answer, model_name)
    VALUES (ta, ua, 'q-a', 'a-a', 'test-model'),
           (ta, other_a, 'q-a2', 'a-a2', 'test-model'),
           (tb, ub, 'q-b', 'a-b', 'test-model'),
           (tc, uc, 'q-c', 'a-c', 'test-model');

  PERFORM set_config('t31.a', ta::text, true);
  PERFORM set_config('t31.b', tb::text, true);
  PERFORM set_config('t31.c', tc::text, true);
  PERFORM set_config('t31.ua', ua::text, true);
  PERFORM set_config('t31.ub', ub::text, true);
  PERFORM set_config('t31.pb', pb::text, true);
  PERFORM set_config('t31.team_b', team_b::text, true);
END $$;

-- --------------------------------------------------------------- checks
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"33333333-3333-4333-8333-333333333301","role":"authenticated"}';

-- 7.1 / 7.4 / 7.5 tenant-scoped identity resolution
DO $$
DECLARE ta uuid := current_setting('t31.a')::uuid;
        tb uuid := current_setting('t31.b')::uuid;
        tc uuid := current_setting('t31.c')::uuid;
        ua uuid := current_setting('t31.ua')::uuid;
        ub uuid := current_setting('t31.ub')::uuid;
BEGIN
  IF public.current_core_user_id(ta) IS DISTINCT FROM ua THEN
    RAISE EXCEPTION 'TEST FAILED 7.4: current_core_user_id(A) resolved wrong identity';
  END IF;
  IF public.current_core_user_id(tb) IS DISTINCT FROM ub THEN
    RAISE EXCEPTION 'TEST FAILED 7.5: current_core_user_id(B) resolved wrong identity';
  END IF;
  IF public.current_core_user_id(tc) IS NOT NULL THEN
    RAISE EXCEPTION 'TEST FAILED 7.6a: non-member resolved an identity in tenant C';
  END IF;
  RAISE NOTICE 'PASS 7.1/7.4/7.5 identity is resolved per tenant, never across tenants';
END $$;

-- 7.2 / 7.3 role escalation must not cross tenants
DO $$
DECLARE ta uuid := current_setting('t31.a')::uuid;
        tb uuid := current_setting('t31.b')::uuid;
        tc uuid := current_setting('t31.c')::uuid;
BEGIN
  IF NOT public.has_role(ta, 'tenant_admin'::public.app_role) THEN
    RAISE EXCEPTION 'TEST FAILED 7.2: tenant_admin in A not recognised';
  END IF;
  IF public.has_role(tb, 'tenant_admin'::public.app_role) THEN
    RAISE EXCEPTION 'TEST FAILED 7.3: tenant_admin in A leaked into tenant B';
  END IF;
  IF public.is_tenant_admin(tb) THEN
    RAISE EXCEPTION 'TEST FAILED 7.3b: is_tenant_admin(B) true for a contributor';
  END IF;
  IF public.has_role(tc, 'tenant_admin'::public.app_role)
     OR public.has_tenant_access(tc)
     OR public.has_project_access(tc, tc) THEN
    RAISE EXCEPTION 'TEST FAILED 7.6b: non-member has access to tenant C';
  END IF;
  RAISE NOTICE 'PASS 7.2/7.3/7.6 no cross-tenant role escalation, no access to tenant C';
END $$;

-- 7.8 tenant visibility: exactly the two tenants of membership, never C
DO $$
DECLARE n int; tc uuid := current_setting('t31.c')::uuid;
BEGIN
  SELECT count(*) INTO n FROM public.core_tenants;
  IF n <> 2 THEN RAISE EXCEPTION 'TEST FAILED 7.8: sees % tenants, expected 2', n; END IF;
  SELECT count(*) INTO n FROM public.core_tenants WHERE id = tc;
  IF n <> 0 THEN RAISE EXCEPTION 'TEST FAILED 7.8b: tenant C is visible'; END IF;
  RAISE NOTICE 'PASS 7.8 tenant admin isolation across two tenants proven';
END $$;

-- 7.9 per-table authorization across tenants
DO $$
DECLARE n int;
        ta uuid := current_setting('t31.a')::uuid;
        tb uuid := current_setting('t31.b')::uuid;
BEGIN
  -- roles: admin in A sees both A rows; contributor in B sees only its own
  SELECT count(*) INTO n FROM public.core_user_roles WHERE tenant_id = ta;
  IF n <> 2 THEN RAISE EXCEPTION 'TEST FAILED 7.9a: admin sees % role rows in A, expected 2', n; END IF;
  SELECT count(*) INTO n FROM public.core_user_roles WHERE tenant_id = tb;
  IF n <> 1 THEN RAISE EXCEPTION 'TEST FAILED 7.9b: contributor sees % role rows in B, expected 1 (own)', n; END IF;

  -- retention settings: tenant A only
  SELECT count(*) INTO n FROM public.core_tenant_retention_settings;
  IF n <> 1 THEN RAISE EXCEPTION 'TEST FAILED 7.9c: sees % retention rows, expected 1', n; END IF;

  -- audit: tenant A only
  SELECT count(*) INTO n FROM public.aud_audit_events;
  IF n <> 1 THEN RAISE EXCEPTION 'TEST FAILED 7.9d: sees % audit rows, expected 1', n; END IF;

  -- copilot answers: both A rows (admin) + own B row = 3
  SELECT count(*) INTO n FROM public.intel_copilot_answers;
  IF n <> 3 THEN RAISE EXCEPTION 'TEST FAILED 7.9e: sees % copilot rows, expected 3', n; END IF;

  -- scopes: none granted, none visible
  SELECT count(*) INTO n FROM public.core_user_project_scopes;
  IF n <> 0 THEN RAISE EXCEPTION 'TEST FAILED 7.9f: sees % project scopes, expected 0', n; END IF;
  RAISE NOTICE 'PASS 7.9 roles/scopes/retention/audit/intelligence are tenant-scoped';
END $$;

RESET ROLE;

-- 7.7 grants never cross tenants
DO $$
DECLARE ta uuid := current_setting('t31.a')::uuid;
        ua uuid := current_setting('t31.ua')::uuid;
        pb uuid := current_setting('t31.pb')::uuid;
        team_b uuid := current_setting('t31.team_b')::uuid;
        ub uuid := current_setting('t31.ub')::uuid;
BEGIN
  BEGIN
    PERFORM public.grant_project_scope(ta, ua, pb, ua);
    RAISE EXCEPTION 'TEST FAILED 7.7a: project in tenant B granted under tenant A';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS 7.7a cross-tenant project grant rejected';
  END;
  BEGIN
    PERFORM public.grant_team_scope(ta, ub, team_b, ua);
    RAISE EXCEPTION 'TEST FAILED 7.7b: tenant B user/team granted under tenant A';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'PASS 7.7b cross-tenant team grant rejected';
  END;
END $$;

DO $$ BEGIN RAISE NOTICE 'SUITE 07 PASSED'; END $$;

ROLLBACK;
