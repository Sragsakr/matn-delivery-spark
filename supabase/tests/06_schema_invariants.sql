-- =====================================================================
-- 06 — Schema invariants. Read-only assertions over the catalog.
-- Phase 3.1 corrections: strict search_path, missing-tenant_id detection,
-- namespace-qualified catalog joins, forced RLS, client write privileges.
-- =====================================================================
DO $$
DECLARE r record; n int; msg text := '';
BEGIN
  -- 6.1 every tenant-owned table has tenant_id NOT NULL
  -- (ops_cron_nonces and aud_audit_events intentionally allow platform rows)
  FOR r IN
    SELECT c.relname
    FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'tenant_id'
    WHERE ns.nspname = 'public' AND c.relkind = 'r' AND NOT a.attnotnull
      AND c.relname NOT IN ('ops_cron_nonces','aud_audit_events')
  LOOP msg := msg || format('tenant_id nullable on %s; ', r.relname); END LOOP;
  IF msg <> '' THEN RAISE EXCEPTION 'TEST FAILED 6.1: %', msg; END IF;
  RAISE NOTICE 'PASS 6.1 tenant_id is NOT NULL everywhere it exists';

  -- 6.2 every table carrying tenant_id has RLS enabled
  msg := '';
  FOR r IN
    SELECT c.relname
    FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'tenant_id'
    WHERE ns.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity
  LOOP msg := msg || r.relname || '; '; END LOOP;
  IF msg <> '' THEN RAISE EXCEPTION 'TEST FAILED 6.2 RLS disabled on: %', msg; END IF;
  RAISE NOTICE 'PASS 6.2 RLS enabled on every tenant table';

  -- 6.3 anon holds no privilege on any prefixed table.
  --     Catalog join is namespace-qualified: relname alone is ambiguous.
  SELECT count(*) INTO n
  FROM information_schema.role_table_grants g
  JOIN pg_namespace ns ON ns.nspname = g.table_schema
  JOIN pg_class c ON c.relname = g.table_name AND c.relnamespace = ns.oid
  WHERE g.table_schema = 'public' AND g.grantee = 'anon'
    AND (c.relname LIKE 'core\_%' OR c.relname LIKE 'az\_%'
      OR c.relname LIKE 'an\_%'  OR c.relname LIKE 'intel\_%'
      OR c.relname LIKE 'ops\_%' OR c.relname LIKE 'aud\_%');
  IF n > 0 THEN RAISE EXCEPTION 'TEST FAILED 6.3: anon holds % grants', n; END IF;
  RAISE NOTICE 'PASS 6.3 anon has no access to tenant tables';

  -- 6.4 SECURITY DEFINER functions must pin an EMPTY search_path.
  --     `search_path=public` is NOT accepted; all references are qualified.
  msg := '';
  FOR r IN
    SELECT p.proname
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
    WHERE ns.nspname = 'public' AND p.prosecdef
      AND NOT EXISTS (
        SELECT 1 FROM unnest(COALESCE(p.proconfig,'{}')) cfg
        WHERE cfg IN ('search_path=', 'search_path=""'))
  LOOP msg := msg || r.proname || '; '; END LOOP;
  IF msg <> '' THEN RAISE EXCEPTION 'TEST FAILED 6.4 unsafe search_path: %', msg; END IF;
  RAISE NOTICE 'PASS 6.4 all SECURITY DEFINER functions pin an empty search_path';

  -- 6.5 privileged functions are service_role only
  msg := '';
  FOR r IN
    SELECT p.proname
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
    WHERE ns.nspname = 'public'
      AND p.proname IN ('grant_project_scope','grant_team_scope','seed_demo_tenant',
                        'remove_demo_tenant','purge_ci_tenant','write_audit_event')
      AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
  LOOP msg := msg || r.proname || '; '; END LOOP;
  IF msg <> '' THEN RAISE EXCEPTION 'TEST FAILED 6.5 privileged functions exposed: %', msg; END IF;
  RAISE NOTICE 'PASS 6.5 privileged functions restricted to service_role';

  -- 6.6 project-scoped references travel with project_id
  SELECT count(*) INTO n FROM pg_constraint WHERE conname = 'core_team_iterations_team_fk';
  IF n <> 1 THEN RAISE EXCEPTION 'TEST FAILED 6.6: composite team FK missing'; END IF;
  RAISE NOTICE 'PASS 6.6 project-composite FKs present';

  -- 6.7 global KPI catalog is fully seeded
  SELECT count(*) INTO n FROM public.an_kpi_definitions WHERE calculation_version = 1;
  IF n < 34 THEN RAISE EXCEPTION 'TEST FAILED 6.7: only % KPI definitions seeded', n; END IF;
  RAISE NOTICE 'PASS 6.7 global KPI catalog seeded (% rows)', n;

  -- 6.8 no prefixed table may LACK tenant_id unless explicitly allowlisted.
  --     Allowlist = documented global/platform tables.
  msg := '';
  FOR r IN
    SELECT c.relname
    FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
    WHERE ns.nspname = 'public' AND c.relkind = 'r'
      AND (c.relname LIKE 'core\_%' OR c.relname LIKE 'az\_%'
        OR c.relname LIKE 'an\_%'  OR c.relname LIKE 'intel\_%'
        OR c.relname LIKE 'ops\_%' OR c.relname LIKE 'aud\_%')
      AND NOT EXISTS (SELECT 1 FROM pg_attribute a
                      WHERE a.attrelid = c.oid AND a.attname = 'tenant_id' AND a.attnum > 0)
      AND c.relname NOT IN ('core_tenants','an_kpi_definitions')
  LOOP msg := msg || r.relname || '; '; END LOOP;
  IF msg <> '' THEN RAISE EXCEPTION 'TEST FAILED 6.8 tenant_id missing on: %', msg; END IF;
  RAISE NOTICE 'PASS 6.8 every non-allowlisted prefixed table carries tenant_id';

  -- 6.9 RLS is both ENABLED and FORCED on every protected table
  msg := '';
  FOR r IN
    SELECT c.relname
    FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
    WHERE ns.nspname = 'public' AND c.relkind = 'r'
      AND (c.relname LIKE 'core\_%' OR c.relname LIKE 'az\_%'
        OR c.relname LIKE 'an\_%'  OR c.relname LIKE 'intel\_%'
        OR c.relname LIKE 'ops\_%' OR c.relname LIKE 'aud\_%')
      AND NOT (c.relrowsecurity AND c.relforcerowsecurity)
  LOOP msg := msg || r.relname || '; '; END LOOP;
  IF msg <> '' THEN RAISE EXCEPTION 'TEST FAILED 6.9 RLS not enabled+forced on: %', msg; END IF;
  RAISE NOTICE 'PASS 6.9 RLS enabled and forced on every protected table';

  -- 6.10 client roles are read-only: no write/DDL-adjacent privileges.
  msg := '';
  FOR r IN
    SELECT g.grantee, g.table_name, g.privilege_type
    FROM information_schema.role_table_grants g
    JOIN pg_namespace ns ON ns.nspname = g.table_schema
    JOIN pg_class c ON c.relname = g.table_name AND c.relnamespace = ns.oid
    WHERE g.table_schema = 'public'
      AND g.grantee IN ('anon','authenticated')
      AND g.privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER')
      AND (c.relname LIKE 'core\_%' OR c.relname LIKE 'az\_%'
        OR c.relname LIKE 'an\_%'  OR c.relname LIKE 'intel\_%'
        OR c.relname LIKE 'ops\_%' OR c.relname LIKE 'aud\_%')
  LOOP msg := msg || format('%s:%s:%s; ', r.grantee, r.table_name, r.privilege_type); END LOOP;
  IF msg <> '' THEN RAISE EXCEPTION 'TEST FAILED 6.10 client write privileges: %', msg; END IF;
  RAISE NOTICE 'PASS 6.10 anon and authenticated hold no write privileges';

  -- 6.11 the ambiguous Phase 3 helpers no longer exist
  SELECT count(*) INTO n
  FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
  WHERE ns.nspname = 'public'
    AND (p.proname = 'current_tenant_id'
      OR (p.proname = 'current_core_user_id' AND p.pronargs = 0)
      OR (p.proname = 'has_role' AND p.pronargs = 1)
      OR (p.proname = 'is_platform_admin' AND p.pronargs = 0));
  IF n > 0 THEN RAISE EXCEPTION 'TEST FAILED 6.11: % ambiguous helper(s) still present', n; END IF;
  RAISE NOTICE 'PASS 6.11 ambiguous tenant-identity helpers removed';

  -- 6.12 no demo tenant may exist in a clean database
  SELECT count(*) INTO n FROM public.core_tenants WHERE is_demo = true;
  IF n > 0 THEN RAISE NOTICE 'NOTE 6.12: % demo tenant(s) present (expected only in development)', n;
  ELSE RAISE NOTICE 'PASS 6.12 no demo tenant present'; END IF;

  RAISE NOTICE 'SUITE 06 PASSED';
END $$;
