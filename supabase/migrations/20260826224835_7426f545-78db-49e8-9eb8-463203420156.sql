-- =====================================================================
-- Phase 3 migration 10 — operations and synchronization metadata
-- No secrets are stored: ops_sync_connections keeps a secret_ref only.
-- Rollback: DROP TABLE ops_* CASCADE;
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.ops_sync_connections (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  organization_id    uuid NOT NULL,
  auth_mode          public.sync_auth_mode NOT NULL DEFAULT 'none',
  secret_ref         text,
  status             public.connection_status NOT NULL DEFAULT 'unconfigured',
  status_message     text,
  configuration      jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_verified_at   timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ops_sync_connections_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT ops_sync_connections_natural_key UNIQUE (tenant_id, organization_id),
  CONSTRAINT ops_sync_connections_org_fk FOREIGN KEY (tenant_id, organization_id)
    REFERENCES public.core_organizations (tenant_id, id) ON DELETE CASCADE,
  -- secret_ref is a pointer (e.g. vault key name), never a credential value
  CONSTRAINT ops_sync_connections_secret_ref_is_reference
    CHECK (secret_ref IS NULL OR (length(secret_ref) <= 128 AND secret_ref ~ '^[A-Za-z0-9_.:-]+$'))
);

CREATE TABLE IF NOT EXISTS public.ops_sync_runs (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL,
  connection_id    uuid NOT NULL,
  organization_id  uuid NOT NULL,
  project_id       uuid,
  trigger_kind     text NOT NULL DEFAULT 'manual'
                   CHECK (trigger_kind IN ('manual','scheduled','backfill','webhook')),
  status           public.sync_run_status NOT NULL DEFAULT 'queued',
  entity_kinds     text[] NOT NULL DEFAULT '{}',
  started_at       timestamptz,
  finished_at      timestamptz,
  finalized_at     timestamptz,
  items_read       bigint NOT NULL DEFAULT 0,
  items_written    bigint NOT NULL DEFAULT 0,
  error_count      integer NOT NULL DEFAULT 0,
  correlation_id   uuid,
  idempotency_key  text,
  details          jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ops_sync_runs_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT ops_sync_runs_connection_fk FOREIGN KEY (tenant_id, connection_id)
    REFERENCES public.ops_sync_connections (tenant_id, id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ops_sync_runs_recent_idx
  ON public.ops_sync_runs (tenant_id, started_at DESC);

CREATE TABLE IF NOT EXISTS public.ops_sync_cursors (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL,
  connection_id  uuid NOT NULL,
  entity_kind    text NOT NULL,
  project_id     uuid,
  watermark_at   timestamptz,
  watermark_token text,
  last_run_id    uuid,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ops_sync_cursors_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT ops_sync_cursors_connection_fk FOREIGN KEY (tenant_id, connection_id)
    REFERENCES public.ops_sync_connections (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT ops_sync_cursors_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE
);
-- Documented decision: NULLS NOT DISTINCT so the org-wide cursor (project_id NULL)
-- collides with itself instead of accumulating duplicates.
ALTER TABLE public.ops_sync_cursors
  DROP CONSTRAINT IF EXISTS ops_sync_cursors_natural_key;
ALTER TABLE public.ops_sync_cursors
  ADD CONSTRAINT ops_sync_cursors_natural_key
  UNIQUE NULLS NOT DISTINCT (tenant_id, connection_id, entity_kind, project_id);

CREATE TABLE IF NOT EXISTS public.ops_sync_locks (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL,
  organization_id  uuid NOT NULL,
  run_id           uuid,
  acquired_at      timestamptz NOT NULL DEFAULT now(),
  expires_at       timestamptz NOT NULL,
  released_at      timestamptz,
  holder           text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ops_sync_locks_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT ops_sync_locks_org_fk FOREIGN KEY (tenant_id, organization_id)
    REFERENCES public.core_organizations (tenant_id, id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS ops_sync_locks_one_active
  ON public.ops_sync_locks (tenant_id, organization_id) WHERE released_at IS NULL;

CREATE TABLE IF NOT EXISTS public.ops_cron_nonces (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid,
  nonce           text NOT NULL UNIQUE,
  idempotency_key text,
  purpose         text NOT NULL,
  seen_at         timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ops_cron_nonces_tenant_fk FOREIGN KEY (tenant_id)
    REFERENCES public.core_tenants (id) ON DELETE CASCADE
);
ALTER TABLE public.ops_cron_nonces
  DROP CONSTRAINT IF EXISTS ops_cron_nonces_idempotency_key;
ALTER TABLE public.ops_cron_nonces
  ADD CONSTRAINT ops_cron_nonces_idempotency_key
  UNIQUE NULLS NOT DISTINCT (tenant_id, idempotency_key);

DROP TRIGGER IF EXISTS append_only ON public.ops_cron_nonces;
CREATE TRIGGER append_only BEFORE UPDATE ON public.ops_cron_nonces
  FOR EACH ROW EXECUTE FUNCTION public.tg_append_only();

CREATE TABLE IF NOT EXISTS public.ops_snapshot_job_runs (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL,
  project_id       uuid NOT NULL,
  team_id          uuid NOT NULL,
  logical_date     date NOT NULL,
  time_zone        text NOT NULL DEFAULT 'Africa/Cairo',
  status           public.sync_run_status NOT NULL DEFAULT 'queued',
  idempotency_key  text,
  started_at       timestamptz,
  finished_at      timestamptz,
  finalized_at     timestamptz,
  rows_written     bigint NOT NULL DEFAULT 0,
  details          jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ops_snapshot_job_runs_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT ops_snapshot_job_runs_natural_key UNIQUE (tenant_id, team_id, logical_date),
  CONSTRAINT ops_snapshot_job_runs_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE
);
DROP TRIGGER IF EXISTS block_finalized ON public.ops_snapshot_job_runs;
CREATE TRIGGER block_finalized BEFORE UPDATE ON public.ops_snapshot_job_runs
  FOR EACH ROW EXECUTE FUNCTION public.tg_block_update_when_finalized();

CREATE TABLE IF NOT EXISTS public.ops_data_quality_issues (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL,
  project_id    uuid,
  rule_id       text NOT NULL,
  entity_kind   text NOT NULL,
  entity_id     uuid,
  field         text,
  severity      public.severity_level NOT NULL DEFAULT 'medium',
  status        public.issue_status NOT NULL DEFAULT 'open',
  message_en    text NOT NULL,
  message_ar    text NOT NULL,
  details       jsonb NOT NULL DEFAULT '{}'::jsonb,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz NOT NULL DEFAULT now(),
  resolved_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ops_data_quality_issues_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT ops_data_quality_issues_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE
);
ALTER TABLE public.ops_data_quality_issues
  DROP CONSTRAINT IF EXISTS ops_data_quality_issues_natural_key;
ALTER TABLE public.ops_data_quality_issues
  ADD CONSTRAINT ops_data_quality_issues_natural_key
  UNIQUE NULLS NOT DISTINCT (tenant_id, rule_id, entity_kind, entity_id, field);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'ops_sync_connections','ops_sync_runs','ops_sync_cursors','ops_sync_locks',
    'ops_snapshot_job_runs','ops_data_quality_issues'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I', t);
    EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()', t);
    EXECUTE format('DROP TRIGGER IF EXISTS immutable_identity ON public.%I', t);
    EXECUTE format('CREATE TRIGGER immutable_identity BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change(''tenant_id'')', t);
  END LOOP;

  FOREACH t IN ARRAY ARRAY[
    'ops_sync_connections','ops_sync_runs','ops_sync_cursors','ops_sync_locks',
    'ops_cron_nonces','ops_snapshot_job_runs','ops_data_quality_issues'
  ] LOOP
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
  -- nonces are operational secrets-adjacent: no client read access at all
  EXECUTE 'REVOKE ALL ON public.ops_cron_nonces FROM authenticated';
END $$;