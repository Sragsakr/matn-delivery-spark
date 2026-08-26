-- =====================================================================
-- Phase 3 migration 07 — engineering tables
-- Rollback: DROP TABLE az_test_result_summaries, az_test_runs,
--   az_deployments, az_environments, az_builds, az_pipelines,
--   az_pull_request_reviews, az_pull_requests, az_repositories CASCADE;
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.az_repositories (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            uuid NOT NULL,
  organization_id      uuid NOT NULL,
  project_id           uuid NOT NULL,
  azure_repository_id  text NOT NULL,
  name                 text NOT NULL,
  default_branch       text,
  is_disabled          boolean NOT NULL DEFAULT false,
  web_url              text,
  source_status        public.source_status NOT NULL DEFAULT 'active',
  is_deleted           boolean NOT NULL DEFAULT false,
  deleted_at_source    timestamptz,
  last_seen_at         timestamptz,
  access_revoked_at    timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_repositories_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_repositories_tenant_project_id_key UNIQUE (tenant_id, project_id, id),
  CONSTRAINT az_repositories_natural_key UNIQUE (tenant_id, project_id, azure_repository_id),
  CONSTRAINT az_repositories_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_repositories_deleted_consistent CHECK (is_deleted = false OR source_status = 'deleted')
);

CREATE TABLE IF NOT EXISTS public.az_pull_requests (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id                uuid NOT NULL,
  organization_id          uuid NOT NULL,
  project_id               uuid NOT NULL,
  repository_id            uuid NOT NULL,
  team_id                  uuid,
  azure_pull_request_id    bigint NOT NULL,
  title                    text NOT NULL,
  status                   public.pull_request_status NOT NULL DEFAULT 'active',
  is_draft                 boolean NOT NULL DEFAULT false,
  created_by_member_id     uuid,
  source_branch            text,
  target_branch            text,
  created_at_source        timestamptz NOT NULL,
  first_review_at          timestamptz,
  approved_at              timestamptz,
  closed_at                timestamptz,
  merged_at                timestamptz,
  last_activity_at         timestamptz,
  reviewer_count           integer NOT NULL DEFAULT 0,
  comment_count            integer NOT NULL DEFAULT 0,
  added_lines              integer,
  deleted_lines            integer,
  time_to_first_review_seconds bigint,
  time_to_merge_seconds        bigint,
  source_status            public.source_status NOT NULL DEFAULT 'active',
  is_deleted               boolean NOT NULL DEFAULT false,
  deleted_at_source        timestamptz,
  last_seen_at             timestamptz,
  access_revoked_at        timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_pull_requests_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_pull_requests_natural_key UNIQUE (tenant_id, organization_id, azure_pull_request_id),
  CONSTRAINT az_pull_requests_repo_fk FOREIGN KEY (tenant_id, project_id, repository_id)
    REFERENCES public.az_repositories (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT az_pull_requests_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id),
  CONSTRAINT az_pull_requests_author_fk FOREIGN KEY (tenant_id, created_by_member_id)
    REFERENCES public.core_members (tenant_id, id),
  CONSTRAINT az_pull_requests_deleted_consistent CHECK (is_deleted = false OR source_status = 'deleted')
);
CREATE INDEX IF NOT EXISTS az_pull_requests_status_idx
  ON public.az_pull_requests (tenant_id, status, last_activity_at DESC);

CREATE TABLE IF NOT EXISTS public.az_pull_request_reviews (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL,
  pull_request_id     uuid NOT NULL,
  reviewer_member_id  uuid NOT NULL,
  vote                public.review_vote NOT NULL DEFAULT 'noVote',
  is_required         boolean NOT NULL DEFAULT false,
  voted_at            timestamptz,
  source_status       public.source_status NOT NULL DEFAULT 'active',
  is_deleted          boolean NOT NULL DEFAULT false,
  deleted_at_source   timestamptz,
  last_seen_at        timestamptz,
  access_revoked_at   timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_pr_reviews_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_pr_reviews_natural_key UNIQUE (tenant_id, pull_request_id, reviewer_member_id),
  CONSTRAINT az_pr_reviews_pr_fk FOREIGN KEY (tenant_id, pull_request_id)
    REFERENCES public.az_pull_requests (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_pr_reviews_member_fk FOREIGN KEY (tenant_id, reviewer_member_id)
    REFERENCES public.core_members (tenant_id, id),
  CONSTRAINT az_pr_reviews_deleted_consistent CHECK (is_deleted = false OR source_status = 'deleted')
);

CREATE TABLE IF NOT EXISTS public.az_pipelines (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  project_id         uuid NOT NULL,
  azure_pipeline_id  bigint NOT NULL,
  name               text NOT NULL,
  folder             text,
  pipeline_type      text NOT NULL DEFAULT 'build' CHECK (pipeline_type IN ('build','release','yaml','unknown')),
  repository_id      uuid,
  is_disabled        boolean NOT NULL DEFAULT false,
  source_status      public.source_status NOT NULL DEFAULT 'active',
  is_deleted         boolean NOT NULL DEFAULT false,
  deleted_at_source  timestamptz,
  last_seen_at       timestamptz,
  access_revoked_at  timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_pipelines_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_pipelines_tenant_project_id_key UNIQUE (tenant_id, project_id, id),
  CONSTRAINT az_pipelines_natural_key UNIQUE (tenant_id, project_id, azure_pipeline_id),
  CONSTRAINT az_pipelines_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_pipelines_repo_fk FOREIGN KEY (tenant_id, project_id, repository_id)
    REFERENCES public.az_repositories (tenant_id, project_id, id),
  CONSTRAINT az_pipelines_deleted_consistent CHECK (is_deleted = false OR source_status = 'deleted')
);

CREATE TABLE IF NOT EXISTS public.az_builds (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL,
  project_id          uuid NOT NULL,
  pipeline_id         uuid NOT NULL,
  azure_build_id      bigint NOT NULL,
  build_number        text,
  branch              text,
  status              public.run_state NOT NULL DEFAULT 'unknown',
  result              public.run_result NOT NULL DEFAULT 'unknown',
  queued_at           timestamptz,
  started_at          timestamptz,
  finished_at         timestamptz,
  duration_seconds    bigint,
  requested_by_member_id uuid,
  source_status       public.source_status NOT NULL DEFAULT 'active',
  is_deleted          boolean NOT NULL DEFAULT false,
  deleted_at_source   timestamptz,
  last_seen_at        timestamptz,
  access_revoked_at   timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_builds_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_builds_tenant_project_id_key UNIQUE (tenant_id, project_id, id),
  CONSTRAINT az_builds_natural_key UNIQUE (tenant_id, project_id, azure_build_id),
  CONSTRAINT az_builds_pipeline_fk FOREIGN KEY (tenant_id, project_id, pipeline_id)
    REFERENCES public.az_pipelines (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT az_builds_deleted_consistent CHECK (is_deleted = false OR source_status = 'deleted')
);
CREATE INDEX IF NOT EXISTS az_builds_pipeline_finished_idx
  ON public.az_builds (tenant_id, pipeline_id, finished_at DESC);

CREATE TABLE IF NOT EXISTS public.az_environments (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  project_id         uuid NOT NULL,
  name               text NOT NULL,
  rank               integer NOT NULL DEFAULT 0,
  is_production      boolean NOT NULL DEFAULT false,
  source_status      public.source_status NOT NULL DEFAULT 'active',
  is_deleted         boolean NOT NULL DEFAULT false,
  deleted_at_source  timestamptz,
  last_seen_at       timestamptz,
  access_revoked_at  timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_environments_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_environments_tenant_project_id_key UNIQUE (tenant_id, project_id, id),
  CONSTRAINT az_environments_natural_key UNIQUE (tenant_id, project_id, name),
  CONSTRAINT az_environments_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_environments_deleted_consistent CHECK (is_deleted = false OR source_status = 'deleted')
);

CREATE TABLE IF NOT EXISTS public.az_deployments (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id              uuid NOT NULL,
  project_id             uuid NOT NULL,
  environment_id         uuid NOT NULL,
  build_id               uuid,
  azure_deployment_id    bigint NOT NULL,
  attempt                integer NOT NULL DEFAULT 1,
  status                 public.run_state NOT NULL DEFAULT 'unknown',
  result                 public.run_result NOT NULL DEFAULT 'unknown',
  started_at             timestamptz,
  finished_at            timestamptz,
  duration_seconds       bigint,
  is_rollback            boolean NOT NULL DEFAULT false,
  requested_by_member_id uuid,
  source_status          public.source_status NOT NULL DEFAULT 'active',
  is_deleted             boolean NOT NULL DEFAULT false,
  deleted_at_source      timestamptz,
  last_seen_at           timestamptz,
  access_revoked_at      timestamptz,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_deployments_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_deployments_natural_key UNIQUE (tenant_id, project_id, azure_deployment_id, attempt),
  CONSTRAINT az_deployments_env_fk FOREIGN KEY (tenant_id, project_id, environment_id)
    REFERENCES public.az_environments (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT az_deployments_build_fk FOREIGN KEY (tenant_id, project_id, build_id)
    REFERENCES public.az_builds (tenant_id, project_id, id),
  CONSTRAINT az_deployments_deleted_consistent CHECK (is_deleted = false OR source_status = 'deleted')
);
CREATE INDEX IF NOT EXISTS az_deployments_env_finished_idx
  ON public.az_deployments (tenant_id, environment_id, finished_at DESC);

CREATE TABLE IF NOT EXISTS public.az_test_runs (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  project_id         uuid NOT NULL,
  build_id           uuid,
  deployment_id      uuid,
  azure_test_run_id  bigint NOT NULL,
  name               text,
  state              public.run_state NOT NULL DEFAULT 'unknown',
  is_automated       boolean NOT NULL DEFAULT true,
  started_at         timestamptz,
  completed_at       timestamptz,
  source_status      public.source_status NOT NULL DEFAULT 'active',
  is_deleted         boolean NOT NULL DEFAULT false,
  deleted_at_source  timestamptz,
  last_seen_at       timestamptz,
  access_revoked_at  timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_test_runs_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_test_runs_natural_key UNIQUE (tenant_id, project_id, azure_test_run_id),
  CONSTRAINT az_test_runs_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_test_runs_build_fk FOREIGN KEY (tenant_id, project_id, build_id)
    REFERENCES public.az_builds (tenant_id, project_id, id),
  CONSTRAINT az_test_runs_deleted_consistent CHECK (is_deleted = false OR source_status = 'deleted')
);
CREATE INDEX IF NOT EXISTS az_test_runs_completed_idx ON public.az_test_runs (tenant_id, completed_at DESC);

CREATE TABLE IF NOT EXISTS public.az_test_result_summaries (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL,
  test_run_id    uuid NOT NULL,
  total_count    integer NOT NULL DEFAULT 0,
  passed_count   integer NOT NULL DEFAULT 0,
  failed_count   integer NOT NULL DEFAULT 0,
  skipped_count  integer NOT NULL DEFAULT 0,
  flaky_count    integer NOT NULL DEFAULT 0,
  pass_rate      numeric(6,3),
  duration_seconds bigint,
  calculated_at  timestamptz NOT NULL DEFAULT now(),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_test_result_summaries_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_test_result_summaries_natural_key UNIQUE (tenant_id, test_run_id),
  CONSTRAINT az_test_result_summaries_run_fk FOREIGN KEY (tenant_id, test_run_id)
    REFERENCES public.az_test_runs (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_test_result_summaries_counts CHECK (
    passed_count >= 0 AND failed_count >= 0 AND skipped_count >= 0 AND total_count >= 0)
);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'az_repositories','az_pull_requests','az_pull_request_reviews','az_pipelines',
    'az_builds','az_environments','az_deployments','az_test_runs','az_test_result_summaries'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I', t);
    EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()', t);
    EXECUTE format('DROP TRIGGER IF EXISTS immutable_identity ON public.%I', t);
    EXECUTE format('CREATE TRIGGER immutable_identity BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change(''tenant_id'')', t);
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;