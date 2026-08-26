-- =====================================================================
-- MATN Delivery Intelligence — Phase 3 migration 01
-- Extensions and shared enums
-- Rollback: DROP TYPE ... (see supabase/migrations/README.md)
-- =====================================================================

-- pgcrypto: digest()/hmac() used by generated scope_hash columns and by
-- future signed-trigger verification. gen_random_uuid() is core in PG13+,
-- but digest() is not.
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- citext: case-insensitive identity fields (tenant slug, user email,
-- Azure descriptors) must not allow duplicate rows differing only by case.
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;

DO $$
BEGIN
  -- authorization -----------------------------------------------------
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'app_role' AND n.nspname = 'public') THEN
    CREATE TYPE public.app_role AS ENUM (
      'platform_admin','tenant_admin','executive_viewer','delivery_manager',
      'team_lead','contributor','qa_release_owner','readonly_viewer');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'scope_target' AND n.nspname = 'public') THEN
    CREATE TYPE public.scope_target AS ENUM ('project','team');
  END IF;

  -- source lifecycle ---------------------------------------------------
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'source_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.source_status AS ENUM ('active','deleted','inaccessible','unknown');
  END IF;

  -- delivery domain ----------------------------------------------------
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'iteration_phase' AND n.nspname = 'public') THEN
    CREATE TYPE public.iteration_phase AS ENUM ('future','current','completed','undated');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'work_item_alias' AND n.nspname = 'public') THEN
    CREATE TYPE public.work_item_alias AS ENUM (
      'epic','feature','story','requirement','issue','bug','task','testCase','custom');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'state_category' AND n.nspname = 'public') THEN
    CREATE TYPE public.state_category AS ENUM (
      'proposed','inProgress','resolved','completed','removed','unknown');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'severity_level' AND n.nspname = 'public') THEN
    CREATE TYPE public.severity_level AS ENUM ('critical','high','medium','low','unknown');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'health_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.health_status AS ENUM ('good','watch','risk','critical','unknown');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'process_template_kind' AND n.nspname = 'public') THEN
    CREATE TYPE public.process_template_kind AS ENUM ('agile','scrum','cmmi','basic','custom');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'rollup_mode' AND n.nspname = 'public') THEN
    CREATE TYPE public.rollup_mode AS ENUM ('leaf_only','parent_only','process_mapping','story_level');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'bug_handling_mode' AND n.nspname = 'public') THEN
    CREATE TYPE public.bug_handling_mode AS ENUM ('as_requirement','as_task','excluded');
  END IF;

  -- engineering --------------------------------------------------------
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'pull_request_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.pull_request_status AS ENUM ('active','abandoned','completed','notSet','unknown');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'review_vote' AND n.nspname = 'public') THEN
    CREATE TYPE public.review_vote AS ENUM (
      'approved','approvedWithSuggestions','noVote','waitingForAuthor','rejected');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'run_result' AND n.nspname = 'public') THEN
    CREATE TYPE public.run_result AS ENUM (
      'succeeded','partiallySucceeded','failed','canceled','none','unknown');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'run_state' AND n.nspname = 'public') THEN
    CREATE TYPE public.run_state AS ENUM (
      'notStarted','inProgress','completed','canceling','postponed','unknown');
  END IF;

  -- analytics / intelligence -------------------------------------------
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'kpi_direction' AND n.nspname = 'public') THEN
    CREATE TYPE public.kpi_direction AS ENUM ('higherIsBetter','lowerIsBetter','targetBand');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'kpi_scope_level' AND n.nspname = 'public') THEN
    CREATE TYPE public.kpi_scope_level AS ENUM ('global','tenant','project','team');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'risk_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.risk_status AS ENUM ('open','mitigating','resolved','dismissed');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'recommendation_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.recommendation_status AS ENUM ('proposed','accepted','rejected','deferred','completed');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'content_origin' AND n.nspname = 'public') THEN
    CREATE TYPE public.content_origin AS ENUM ('deterministic','ai_generated','human');
  END IF;

  -- operations / audit ---------------------------------------------------
  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'sync_auth_mode' AND n.nspname = 'public') THEN
    CREATE TYPE public.sync_auth_mode AS ENUM ('pat','oauth','managed_identity','none');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'connection_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.connection_status AS ENUM ('unconfigured','pending','connected','error','disabled');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'sync_run_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.sync_run_status AS ENUM ('queued','running','succeeded','partial','failed','skipped');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'issue_status' AND n.nspname = 'public') THEN
    CREATE TYPE public.issue_status AS ENUM ('open','acknowledged','resolved','ignored');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'actor_type' AND n.nspname = 'public') THEN
    CREATE TYPE public.actor_type AS ENUM ('user','service','system','scheduler');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                 WHERE t.typname = 'audit_outcome' AND n.nspname = 'public') THEN
    CREATE TYPE public.audit_outcome AS ENUM ('success','failure','denied','noop');
  END IF;
END $$;