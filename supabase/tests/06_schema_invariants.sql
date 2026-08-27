-- =====================================================================
-- 06 — Schema invariants. Read-only assertions over the catalog.
-- =====================================================================
DO $$
DECLARE r record; n int; msg text := '';
BEGIN
  -- 6.1 every tenant-owned table has tenant_id NOT NULL
  FOR r IN
    SELECT c.relname
    FROM pg_class c JOIN pg_namespace ns ON ns.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'tenant_id'
    WHERE ns.nspname = 'public' AND c.relkind = 'r' AND NOT a.attnotnull
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

  -- 6.3 anon holds no privilege on any tenant table
  SELECT count(*) INTO n
  FROM information_schema.role_table_grants g
  JOIN pg_class c ON c.relname = g.table_name
  JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'tenant_id'
  WHERE g.table_schema = 'public' AND g.grantee = 'anon';
  IF n > 0 THEN RAISE EXCEPTION 'TEST FAILED 6.3: anon holds % grants on tenant tables', n; END IF;
  RAISE NOTICE 'PASS 6.3 anon has no access to tenant tables';

  -- 6.4 no SECURITY DEFINER function has an unsafe search_path
  msg := '';
  FOR r IN
    SELECT p.proname, p.proconfig
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
    WHERE ns.nspname = 'public' AND p.prosecdef
      AND NOT COALESCE(
        EXISTS (SELECT 1 FROM unnest(COALESCE(p.proconfig,'{}')) cfg
                WHERE cfg IN ('search_path=', 'search_path=""', 'search_path=public')), false)
  LOOP msg := msg || r.proname || '; '; END LOOP;
  IF msg <> '' THEN RAISE EXCEPTION 'TEST FAILED 6.4 unsafe search_path: %', msg; END IF;
  RAISE NOTICE 'PASS 6.4 all SECURITY DEFINER functions pin search_path';

  -- 6.5 privileged grant/seed functions are not executable by PUBLIC/anon/authenticated
  msg := '';
  FOR r IN
    SELECT p.proname
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
    WHERE ns.nspname = 'public'
      AND p.proname IN ('grant_project_scope','grant_team_scope','seed_demo_tenant','remove_demo_tenant')
      AND (has_function_privilege('anon', p.oid, 'EXECUTE')
        OR has_function_privilege('authenticated', p.oid, 'EXECUTE'))
  LOOP msg := msg || r.proname || '; '; END LOOP;
  IF msg <> '' THEN RAISE EXCEPTION 'TEST FAILED 6.5 privileged functions exposed: %', msg; END IF;
  RAISE NOTICE 'PASS 6.5 privileged functions restricted to service_role';

  -- 6.6 project-scoped team/iteration references travel with project_id
  SELECT count(*) INTO n
  FROM pg_constraint
  WHERE conname = 'core_team_iterations_team_project_fkey';
  IF n <> 1 THEN RAISE EXCEPTION 'TEST FAILED 6.6: composite team FK missing'; END IF;
  RAISE NOTICE 'PASS 6.6 project-composite FKs present';

  -- 6.7 global KPI catalog is fully seeded and readable
  SELECT count(*) INTO n FROM public.an_kpi_definitions WHERE calculation_version = 1;
  IF n < 34 THEN RAISE EXCEPTION 'TEST FAILED 6.7: only % KPI definitions seeded', n; END IF;
  RAISE NOTICE 'PASS 6.7 global KPI catalog seeded (% rows)', n;

  RAISE NOTICE 'SUITE 06 PASSED';
END $$;
