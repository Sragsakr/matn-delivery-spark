-- =====================================================================
-- Phase 3.1 migration 17 — dblink, restricted to service_role.
-- Purpose: the scope-grant concurrency suite must open two genuinely
-- parallel transactions. No application code uses dblink.
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA extensions;

DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT n.nspname, pr.proname,
           pg_get_function_identity_arguments(pr.oid) AS args
    FROM pg_proc pr
    JOIN pg_namespace n ON n.oid = pr.pronamespace
    JOIN pg_depend d ON d.objid = pr.oid AND d.deptype = 'e'
    JOIN pg_extension e ON e.oid = d.refobjid AND e.extname = 'dblink'
  LOOP
    -- some dblink entry points are superuser-owned and already restricted;
    -- tighten the ones this role owns and skip the rest.
    BEGIN
      EXECUTE format('REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC', p.nspname, p.proname, p.args);
      EXECUTE format('REVOKE ALL ON FUNCTION %I.%I(%s) FROM anon', p.nspname, p.proname, p.args);
      EXECUTE format('REVOKE ALL ON FUNCTION %I.%I(%s) FROM authenticated', p.nspname, p.proname, p.args);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %I.%I(%s) TO service_role', p.nspname, p.proname, p.args);
    EXCEPTION WHEN insufficient_privilege THEN
      RAISE NOTICE 'skipping superuser-owned dblink function %', p.proname;
    END;
  END LOOP;
END $$;