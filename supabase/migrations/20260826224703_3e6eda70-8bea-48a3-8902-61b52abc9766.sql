-- =====================================================================
-- Phase 3 migration 08 — analytics and KPI tables
-- Scope fingerprint: deterministic, version-prefixed serialization
--   'v1|tenant|project|team|team_iteration|member|iteration'
-- with the approved sentinel 00000000-0000-0000-0000-000000000000 for
-- absent dimensions (guarded by *_id_not_sentinel CHECKs on real ids).
-- Rollback: DROP TABLE an_* CASCADE;
-- =====================================================================

-- --------------------------------------------------------------- global
CREATE TABLE IF NOT EXISTS public.an_kpi_definitions (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kpi_id               text NOT NULL,
  calculation_version  integer NOT NULL DEFAULT 1,
  name_en              text NOT NULL,
  name_ar              text NOT NULL,
  description_en       text,
  description_ar       text,
  category             text NOT NULL,
  unit                 text NOT NULL,
  direction            public.kpi_direction NOT NULL DEFAULT 'higherIsBetter',
  formula              text NOT NULL,
  inputs               jsonb NOT NULL DEFAULT '[]'::jsonb,
  default_configuration jsonb NOT NULL DEFAULT '{}'::jsonb,
  supported_scopes     public.kpi_scope_level[] NOT NULL DEFAULT '{tenant,project,team}',
  is_active            boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT an_kpi_definitions_version_key UNIQUE (kpi_id, calculation_version)
);
CREATE UNIQUE INDEX IF NOT EXISTS an_kpi_definitions_active_kpi
  ON public.an_kpi_definitions (kpi_id) WHERE is_active;

-- Immutable per calculation version: a new version means a new row.
DROP TRIGGER IF EXISTS append_only ON public.an_kpi_definitions;
CREATE TRIGGER append_only BEFORE UPDATE OR DELETE ON public.an_kpi_definitions
  FOR EACH ROW EXECUTE FUNCTION public.tg_append_only();

-- ------------------------------------------------------- tenant overrides
CREATE TABLE IF NOT EXISTS public.an_kpi_configuration_overrides (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  kpi_definition_id  uuid NOT NULL REFERENCES public.an_kpi_definitions (id),
  kpi_id             text NOT NULL,
  project_id         uuid,
  team_id            uuid,
  configuration      jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_enabled         boolean NOT NULL DEFAULT true,
  configuration_version integer NOT NULL DEFAULT 1,
  effective_from     timestamptz NOT NULL DEFAULT now(),
  effective_to       timestamptz,
  created_by_user_id uuid,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT an_kpi_overrides_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT an_kpi_overrides_team_requires_project
    CHECK (team_id IS NULL OR project_id IS NOT NULL),
  CONSTRAINT an_kpi_overrides_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT an_kpi_overrides_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT an_kpi_overrides_window CHECK (effective_to IS NULL OR effective_to > effective_from)
);
CREATE UNIQUE INDEX IF NOT EXISTS kpi_override_tenant_level
  ON public.an_kpi_configuration_overrides (tenant_id, kpi_definition_id, effective_from)
  WHERE project_id IS NULL AND team_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS kpi_override_project_level
  ON public.an_kpi_configuration_overrides (tenant_id, kpi_definition_id, project_id, effective_from)
  WHERE project_id IS NOT NULL AND team_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS kpi_override_team_level
  ON public.an_kpi_configuration_overrides (tenant_id, kpi_definition_id, project_id, team_id, effective_from)
  WHERE team_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS an_kpi_overrides_lookup
  ON public.an_kpi_configuration_overrides (tenant_id, kpi_id, effective_from DESC);

-- ------------------------------------------------------------ kpi values
CREATE TABLE IF NOT EXISTS public.an_kpi_values (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  kpi_id              text NOT NULL,
  kpi_definition_id   uuid NOT NULL REFERENCES public.an_kpi_definitions (id),
  project_id          uuid,
  team_id             uuid,
  team_iteration_id   uuid,
  member_id           uuid,
  scope_level         public.kpi_scope_level NOT NULL DEFAULT 'tenant',
  scope_hash          text GENERATED ALWAYS AS (
    encode(extensions.digest(
      'v1|' || tenant_id::text
        || '|' || COALESCE(project_id::text, '00000000-0000-0000-0000-000000000000')
        || '|' || COALESCE(team_id::text, '00000000-0000-0000-0000-000000000000')
        || '|' || COALESCE(team_iteration_id::text, '00000000-0000-0000-0000-000000000000')
        || '|' || COALESCE(member_id::text, '00000000-0000-0000-0000-000000000000')
        || '|' || kpi_id, 'sha256'), 'hex')
  ) STORED,
  value               numeric(18,4),
  numerator           numeric(18,4),
  denominator         numeric(18,4),
  health              public.health_status NOT NULL DEFAULT 'unknown',
  sample_size         integer,
  calculation_version integer NOT NULL DEFAULT 1,
  configuration_version integer NOT NULL DEFAULT 1,
  resolved_configuration jsonb NOT NULL DEFAULT '{}'::jsonb,
  valid_from          timestamptz NOT NULL,
  valid_to            timestamptz,
  calculated_at       timestamptz NOT NULL DEFAULT now(),
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT an_kpi_values_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT an_kpi_values_natural_key UNIQUE (tenant_id, kpi_id, scope_hash, valid_from),
  CONSTRAINT an_kpi_values_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT an_kpi_values_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT an_kpi_values_ti_fk FOREIGN KEY (tenant_id, project_id, team_iteration_id)
    REFERENCES public.core_team_iterations (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT an_kpi_values_member_fk FOREIGN KEY (tenant_id, member_id)
    REFERENCES public.core_members (tenant_id, id),
  CONSTRAINT an_kpi_values_scope_requires_project
    CHECK ((team_id IS NULL AND team_iteration_id IS NULL) OR project_id IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS an_kpi_values_ti_idx
  ON public.an_kpi_values (tenant_id, team_iteration_id, kpi_id, valid_from DESC);

DROP TRIGGER IF EXISTS append_only ON public.an_kpi_values;
CREATE TRIGGER append_only BEFORE UPDATE OR DELETE ON public.an_kpi_values
  FOR EACH ROW EXECUTE FUNCTION public.tg_append_only();

-- ------------------------------------------------------------- snapshots
CREATE TABLE IF NOT EXISTS public.an_daily_project_snapshots (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  project_id         uuid NOT NULL,
  snapshot_date      date NOT NULL,
  time_zone          text NOT NULL DEFAULT 'Africa/Cairo',
  metrics            jsonb NOT NULL DEFAULT '{}'::jsonb,
  finalized_at       timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT an_daily_project_snapshots_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT an_daily_project_snapshots_natural_key UNIQUE (tenant_id, project_id, snapshot_date),
  CONSTRAINT an_daily_project_snapshots_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.an_daily_iteration_snapshots (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             uuid NOT NULL,
  project_id            uuid NOT NULL,
  team_iteration_id     uuid NOT NULL,
  iteration_id          uuid NOT NULL,
  team_id               uuid NOT NULL,
  snapshot_date         date NOT NULL,
  time_zone             text NOT NULL DEFAULT 'Africa/Cairo',
  working_day_index     integer,
  total_working_days    integer,
  committed_estimate    numeric(14,2),
  completed_estimate    numeric(14,2),
  remaining_estimate    numeric(14,2),
  added_estimate        numeric(14,2),
  removed_estimate      numeric(14,2),
  blocked_count         integer,
  item_counts           jsonb NOT NULL DEFAULT '{}'::jsonb,
  metrics               jsonb NOT NULL DEFAULT '{}'::jsonb,
  finalized_at          timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT an_daily_iteration_snapshots_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT an_daily_iteration_snapshots_natural_key
    UNIQUE (tenant_id, team_iteration_id, snapshot_date),
  CONSTRAINT an_daily_iteration_snapshots_ti_fk FOREIGN KEY (tenant_id, project_id, team_iteration_id)
    REFERENCES public.core_team_iterations (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT an_daily_iteration_snapshots_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT an_daily_iteration_snapshots_iteration_fk FOREIGN KEY (tenant_id, project_id, iteration_id)
    REFERENCES public.core_iterations (tenant_id, project_id, id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS an_daily_iteration_snapshots_date_idx
  ON public.an_daily_iteration_snapshots (tenant_id, snapshot_date);

CREATE TABLE IF NOT EXISTS public.an_daily_team_snapshots (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  project_id         uuid NOT NULL,
  team_id            uuid NOT NULL,
  team_iteration_id  uuid,
  snapshot_date      date NOT NULL,
  time_zone          text NOT NULL DEFAULT 'Africa/Cairo',
  metrics            jsonb NOT NULL DEFAULT '{}'::jsonb,
  finalized_at       timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT an_daily_team_snapshots_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT an_daily_team_snapshots_natural_key UNIQUE (tenant_id, team_id, snapshot_date),
  CONSTRAINT an_daily_team_snapshots_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT an_daily_team_snapshots_ti_fk FOREIGN KEY (tenant_id, project_id, team_iteration_id)
    REFERENCES public.core_team_iterations (tenant_id, project_id, id)
);

CREATE TABLE IF NOT EXISTS public.an_daily_member_snapshots (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  project_id         uuid NOT NULL,
  team_id            uuid NOT NULL,
  member_id          uuid NOT NULL,
  team_iteration_id  uuid,
  snapshot_date      date NOT NULL,
  time_zone          text NOT NULL DEFAULT 'Africa/Cairo',
  capacity_hours     numeric(10,2),
  assigned_estimate  numeric(14,2),
  completed_estimate numeric(14,2),
  utilization        numeric(6,3),
  metrics            jsonb NOT NULL DEFAULT '{}'::jsonb,
  finalized_at       timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT an_daily_member_snapshots_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT an_daily_member_snapshots_natural_key
    UNIQUE (tenant_id, member_id, team_id, snapshot_date),
  CONSTRAINT an_daily_member_snapshots_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT an_daily_member_snapshots_member_fk FOREIGN KEY (tenant_id, member_id)
    REFERENCES public.core_members (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT an_daily_member_snapshots_ti_fk FOREIGN KEY (tenant_id, project_id, team_iteration_id)
    REFERENCES public.core_team_iterations (tenant_id, project_id, id)
);
CREATE INDEX IF NOT EXISTS an_daily_member_snapshots_date_idx
  ON public.an_daily_member_snapshots (tenant_id, snapshot_date);

-- snapshots: mutable until finalized, immutable afterwards
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'an_daily_project_snapshots','an_daily_iteration_snapshots',
    'an_daily_team_snapshots','an_daily_member_snapshots'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I', t);
    EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()', t);
    EXECUTE format('DROP TRIGGER IF EXISTS block_finalized ON public.%I', t);
    EXECUTE format('CREATE TRIGGER block_finalized BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_block_update_when_finalized()', t);
    EXECUTE format('DROP TRIGGER IF EXISTS immutable_identity ON public.%I', t);
    EXECUTE format('CREATE TRIGGER immutable_identity BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change(
        ''tenant_id'',''project_id'',''snapshot_date'')', t);
  END LOOP;
END $$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'an_kpi_definitions','an_kpi_configuration_overrides','an_kpi_values',
    'an_daily_project_snapshots','an_daily_iteration_snapshots',
    'an_daily_team_snapshots','an_daily_member_snapshots'
  ] LOOP
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
  -- global catalog and append-only values are never rewritten
  EXECUTE 'REVOKE UPDATE, DELETE ON public.an_kpi_definitions FROM service_role';
  EXECUTE 'REVOKE UPDATE, DELETE ON public.an_kpi_values FROM service_role';
  EXECUTE 'DROP TRIGGER IF EXISTS set_updated_at ON public.an_kpi_configuration_overrides';
  EXECUTE 'CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.an_kpi_configuration_overrides
    FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()';
END $$;