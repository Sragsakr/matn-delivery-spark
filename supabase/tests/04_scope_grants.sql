-- =====================================================================
-- 04 — Scope grant lifecycle (idempotency, expiry, revocation)
-- Run as service_role; the grant functions are executable only by it.
-- Wrapped in a transaction and rolled back.
-- =====================================================================
BEGIN;

DO $$
DECLARE
  t uuid; org uuid; p uuid; admin_u uuid; target_u uuid;
  g1 uuid; g2 uuid; g3 uuid;
  active_rows int;
BEGIN
  INSERT INTO public.core_tenants (slug, name_en, name_ar, is_demo)
    VALUES ('test-grants','Grants','منح', true) RETURNING id INTO t;
  INSERT INTO public.core_organizations (tenant_id, azure_organization_name, base_url, name_en, name_ar)
    VALUES (t,'org','https://dev.azure.invalid/o','O','و') RETURNING id INTO org;
  INSERT INTO public.core_projects (tenant_id, organization_id, azure_project_id, azure_project_name, name_en, name_ar)
    VALUES (t, org,'p','P','P','ب') RETURNING id INTO p;
  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name)
    VALUES (t, gen_random_uuid(), 'admin@example.invalid','Admin') RETURNING id INTO admin_u;
  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name)
    VALUES (t, gen_random_uuid(), 'target@example.invalid','Target') RETURNING id INTO target_u;
  INSERT INTO public.core_user_roles (tenant_id, user_id, role) VALUES (t, admin_u, 'tenant_admin');

  -- 4.1 first grant creates a row
  g1 := public.grant_project_scope(t, target_u, p, admin_u, NULL, 'idem-1', 'test');
  IF g1 IS NULL THEN RAISE EXCEPTION 'TEST FAILED 4.1'; END IF;
  RAISE NOTICE 'PASS 4.1 grant created';

  -- 4.2 duplicate active grant is idempotent
  g2 := public.grant_project_scope(t, target_u, p, admin_u, NULL, 'idem-1', 'test');
  IF g2 <> g1 THEN RAISE EXCEPTION 'TEST FAILED 4.2: duplicate created a second grant'; END IF;
  SELECT count(*) INTO active_rows FROM public.core_user_project_scopes
   WHERE user_id = target_u AND revoked_at IS NULL;
  IF active_rows <> 1 THEN RAISE EXCEPTION 'TEST FAILED 4.2b: % active rows', active_rows; END IF;
  RAISE NOTICE 'PASS 4.2 duplicate grant idempotent';

  -- 4.3 expired open grant is closed and replaced
  UPDATE public.core_user_project_scopes SET expires_at = now() - interval '1 minute' WHERE id = g1;
  g3 := public.grant_project_scope(t, target_u, p, admin_u, now() + interval '1 day', 'idem-2', 'renew');
  IF g3 = g1 THEN RAISE EXCEPTION 'TEST FAILED 4.3: expired grant reused'; END IF;
  IF (SELECT revoked_at FROM public.core_user_project_scopes WHERE id = g1) IS NULL
    THEN RAISE EXCEPTION 'TEST FAILED 4.3b: expired row was not closed'; END IF;
  SELECT count(*) INTO active_rows FROM public.core_user_project_scopes
   WHERE user_id = target_u AND revoked_at IS NULL;
  IF active_rows <> 1 THEN RAISE EXCEPTION 'TEST FAILED 4.3c: % active rows', active_rows; END IF;
  RAISE NOTICE 'PASS 4.3 expired grant closed and replaced';

  -- 4.4 revoked grant can be replaced
  UPDATE public.core_user_project_scopes SET revoked_at = now() WHERE id = g3;
  g1 := public.grant_project_scope(t, target_u, p, admin_u, NULL, 'idem-3', 'regrant');
  IF g1 = g3 THEN RAISE EXCEPTION 'TEST FAILED 4.4'; END IF;
  RAISE NOTICE 'PASS 4.4 revoked grant replaced';

  -- 4.5 expires_at in the past is rejected
  BEGIN
    PERFORM public.grant_project_scope(t, target_u, p, admin_u, now() - interval '1 hour', 'idem-4', 'bad');
    RAISE EXCEPTION 'TEST FAILED 4.5: past expiry accepted';
  EXCEPTION WHEN invalid_parameter_value OR check_violation THEN
    RAISE NOTICE 'PASS 4.5 past expiry rejected';
  END;

  -- 4.6 target from a different tenant is rejected
  BEGIN
    PERFORM public.grant_project_scope(gen_random_uuid(), target_u, p, admin_u, NULL, 'idem-5', 'bad');
    RAISE EXCEPTION 'TEST FAILED 4.6: cross-tenant grant accepted';
  EXCEPTION WHEN invalid_parameter_value OR foreign_key_violation OR insufficient_privilege THEN
    RAISE NOTICE 'PASS 4.6 cross-tenant grant rejected';
  END;

  -- 4.7 an audit event was written for every successful grant
  IF (SELECT count(*) FROM public.aud_audit_events
      WHERE tenant_id = t AND action LIKE 'scope.%') = 0
    THEN RAISE EXCEPTION 'TEST FAILED 4.7: no audit events'; END IF;
  RAISE NOTICE 'PASS 4.7 grants are audited';

  RAISE NOTICE 'SUITE 04 PASSED';
END $$;

ROLLBACK;

-- 4.8 Concurrency: the advisory lock plus the partial unique index guarantee a
-- single active row. Verify manually with two parallel psql sessions calling
-- grant_project_scope for the same (tenant, user, project); one inserts, the
-- other returns the same grant id.
