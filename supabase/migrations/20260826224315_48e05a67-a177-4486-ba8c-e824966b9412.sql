-- =====================================================================
-- Phase 3 migration 03 — organizations, projects, teams, iterations,
-- team iterations, members, memberships, capacity, process mappings
-- Rollback: DROP TABLE (reverse order) CASCADE
-- =====================================================================

-- ---------------------------------------------------------------------
-- core_organizations
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_organizations (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               uuid NOT NULL REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  azure_organization_name extensions.citext NOT NULL,
  azure_organization_id   text,
  base_url                text NOT NULL,
  name_en                 text NOT NULL,
  name_ar                 text NOT NULL,
  source_status           public.source_status NOT NULL DEFAULT 'active',
  is_deleted              boolean NOT NULL DEFAULT false,
  deleted_at_source       timestamptz,
  last_seen_at            timestamptz,
  access_revoked_at       timestamptz,
  last_synced_at          timestamptz,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_organizations_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_organizations_tenant_name_key UNIQUE (tenant_id, azure_organization_name),
  CONSTRAINT core_organizations_deleted_consistent
    CHECK (is_deleted = false OR source_status = 'deleted')
);

-- ---------------------------------------------------------------------
-- core_projects
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_projects (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             uuid NOT NULL,
  organization_id       uuid NOT NULL,
  azure_project_id      text NOT NULL,
  azure_project_name    text NOT NULL,
  name_en               text NOT NULL,
  name_ar               text NOT NULL,
  description           text,
  process_template_kind public.process_template_kind NOT NULL DEFAULT 'agile',
  process_template_name text,
  visibility            text CHECK (visibility IN ('private','public')),
  state                 text NOT NULL DEFAULT 'wellFormed'
                        CHECK (state IN ('wellFormed','createPending','deleting','unknown')),
  custom_fields         jsonb NOT NULL DEFAULT '{}'::jsonb,
  source_status         public.source_status NOT NULL DEFAULT 'active',
  is_deleted            boolean NOT NULL DEFAULT false,
  deleted_at_source     timestamptz,
  last_seen_at          timestamptz,
  access_revoked_at     timestamptz,
  last_synced_at        timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_projects_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_projects_tenant_org_azure_key UNIQUE (tenant_id, organization_id, azure_project_id),
  CONSTRAINT core_projects_org_fk FOREIGN KEY (tenant_id, organization_id)
    REFERENCES public.core_organizations (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_projects_id_not_sentinel
    CHECK (id <> '00000000-0000-0000-0000-000000000000'::uuid),
  CONSTRAINT core_projects_deleted_consistent
    CHECK (is_deleted = false OR source_status = 'deleted')
);
CREATE INDEX IF NOT EXISTS core_projects_org_idx ON public.core_projects (tenant_id, organization_id);

-- ---------------------------------------------------------------------
-- core_teams
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_teams (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id                uuid NOT NULL,
  organization_id          uuid NOT NULL,
  project_id               uuid NOT NULL,
  azure_team_id            text NOT NULL,
  azure_team_name          text NOT NULL,
  name_en                  text NOT NULL,
  name_ar                  text NOT NULL,
  description              text,
  area_paths               text[] NOT NULL DEFAULT '{}',
  default_iteration_path   text,
  process_mapping_id       uuid,
  source_status            public.source_status NOT NULL DEFAULT 'active',
  is_deleted               boolean NOT NULL DEFAULT false,
  deleted_at_source        timestamptz,
  last_seen_at             timestamptz,
  access_revoked_at        timestamptz,
  last_synced_at           timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_teams_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_teams_tenant_project_id_key UNIQUE (tenant_id, project_id, id),
  CONSTRAINT core_teams_tenant_project_azure_key UNIQUE (tenant_id, project_id, azure_team_id),
  CONSTRAINT core_teams_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_teams_org_fk FOREIGN KEY (tenant_id, organization_id)
    REFERENCES public.core_organizations (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_teams_id_not_sentinel
    CHECK (id <> '00000000-0000-0000-0000-000000000000'::uuid),
  CONSTRAINT core_teams_deleted_consistent
    CHECK (is_deleted = false OR source_status = 'deleted')
);
CREATE INDEX IF NOT EXISTS core_teams_project_idx ON public.core_teams (tenant_id, project_id);

-- ---------------------------------------------------------------------
-- core_iterations  (project-owned Azure nodes; no team ownership)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_iterations (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            uuid NOT NULL,
  organization_id      uuid NOT NULL,
  project_id           uuid NOT NULL,
  azure_iteration_id   text NOT NULL,
  azure_iteration_path text NOT NULL,
  name_en              text NOT NULL,
  name_ar              text NOT NULL,
  start_date           date,
  finish_date          date,
  phase                public.iteration_phase NOT NULL DEFAULT 'undated',
  source_status        public.source_status NOT NULL DEFAULT 'active',
  is_deleted           boolean NOT NULL DEFAULT false,
  deleted_at_source    timestamptz,
  last_seen_at         timestamptz,
  access_revoked_at    timestamptz,
  last_synced_at       timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_iterations_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_iterations_tenant_project_id_key UNIQUE (tenant_id, project_id, id),
  CONSTRAINT core_iterations_tenant_project_azure_key UNIQUE (tenant_id, project_id, azure_iteration_id),
  CONSTRAINT core_iterations_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_iterations_org_fk FOREIGN KEY (tenant_id, organization_id)
    REFERENCES public.core_organizations (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_iterations_id_not_sentinel
    CHECK (id <> '00000000-0000-0000-0000-000000000000'::uuid),
  CONSTRAINT core_iterations_dates_ordered
    CHECK (start_date IS NULL OR finish_date IS NULL OR finish_date >= start_date),
  CONSTRAINT core_iterations_deleted_consistent
    CHECK (is_deleted = false OR source_status = 'deleted')
);
CREATE INDEX IF NOT EXISTS core_iterations_project_start_idx
  ON public.core_iterations (tenant_id, project_id, start_date);

-- ---------------------------------------------------------------------
-- core_team_iterations  (canonical team-sprint reference)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_team_iterations (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  organization_id    uuid NOT NULL,
  project_id         uuid NOT NULL,
  team_id            uuid NOT NULL,
  iteration_id       uuid NOT NULL,
  is_current         boolean NOT NULL DEFAULT false,
  selected_for_sync  boolean NOT NULL DEFAULT true,
  time_zone          text NOT NULL DEFAULT 'Africa/Cairo',
  working_weekdays   smallint[] NOT NULL DEFAULT '{0,1,2,3,4}',
  non_working_days   jsonb NOT NULL DEFAULT '[]'::jsonb,
  phase              public.iteration_phase NOT NULL DEFAULT 'undated',
  source_status      public.source_status NOT NULL DEFAULT 'active',
  is_deleted         boolean NOT NULL DEFAULT false,
  deleted_at_source  timestamptz,
  last_seen_at       timestamptz,
  access_revoked_at  timestamptz,
  last_synced_at     timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_team_iterations_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_team_iterations_tenant_project_id_key UNIQUE (tenant_id, project_id, id),
  CONSTRAINT core_team_iterations_team_iteration_key UNIQUE (tenant_id, team_id, iteration_id),
  CONSTRAINT core_team_iterations_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT core_team_iterations_iteration_fk FOREIGN KEY (tenant_id, project_id, iteration_id)
    REFERENCES public.core_iterations (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT core_team_iterations_id_not_sentinel
    CHECK (id <> '00000000-0000-0000-0000-000000000000'::uuid),
  CONSTRAINT core_team_iterations_deleted_consistent
    CHECK (is_deleted = false OR source_status = 'deleted')
);
-- Documented nullable/partial decision: at most one current sprint per team.
CREATE UNIQUE INDEX IF NOT EXISTS core_team_iterations_one_current
  ON public.core_team_iterations (tenant_id, team_id) WHERE is_current;
CREATE INDEX IF NOT EXISTS core_team_iterations_iteration_idx
  ON public.core_team_iterations (tenant_id, iteration_id);
CREATE INDEX IF NOT EXISTS core_team_iterations_sync_idx
  ON public.core_team_iterations (tenant_id, selected_for_sync);

-- ---------------------------------------------------------------------
-- core_members
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_members (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL,
  organization_id   uuid NOT NULL,
  azure_descriptor  extensions.citext NOT NULL,
  azure_unique_name extensions.citext,
  display_name      text NOT NULL,
  email             extensions.citext,
  image_url         text,
  is_active         boolean NOT NULL DEFAULT true,
  source_status     public.source_status NOT NULL DEFAULT 'active',
  is_deleted        boolean NOT NULL DEFAULT false,
  deleted_at_source timestamptz,
  last_seen_at      timestamptz,
  access_revoked_at timestamptz,
  last_synced_at    timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_members_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_members_tenant_org_descriptor_key UNIQUE (tenant_id, organization_id, azure_descriptor),
  CONSTRAINT core_members_org_fk FOREIGN KEY (tenant_id, organization_id)
    REFERENCES public.core_organizations (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_members_deleted_consistent
    CHECK (is_deleted = false OR source_status = 'deleted')
);

-- ---------------------------------------------------------------------
-- core_team_memberships (history-bearing: append + close)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_team_memberships (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL,
  project_id  uuid NOT NULL,
  team_id     uuid NOT NULL,
  member_id   uuid NOT NULL,
  role        text NOT NULL DEFAULT 'member' CHECK (role IN ('lead','member','admin','unknown')),
  joined_at   timestamptz,
  left_at     timestamptz,
  is_active   boolean NOT NULL DEFAULT true,
  source_status public.source_status NOT NULL DEFAULT 'active',
  is_deleted    boolean NOT NULL DEFAULT false,
  deleted_at_source timestamptz,
  last_seen_at      timestamptz,
  access_revoked_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_team_memberships_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_team_memberships_natural_key UNIQUE (tenant_id, team_id, member_id, joined_at),
  CONSTRAINT core_team_memberships_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT core_team_memberships_member_fk FOREIGN KEY (tenant_id, member_id)
    REFERENCES public.core_members (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_team_memberships_interval CHECK (left_at IS NULL OR joined_at IS NULL OR left_at >= joined_at),
  CONSTRAINT core_team_memberships_deleted_consistent
    CHECK (is_deleted = false OR source_status = 'deleted')
);
CREATE INDEX IF NOT EXISTS core_team_memberships_team_idx ON public.core_team_memberships (tenant_id, team_id);
CREATE INDEX IF NOT EXISTS core_team_memberships_member_idx ON public.core_team_memberships (tenant_id, member_id);

-- ---------------------------------------------------------------------
-- core_member_capacity (keyed on the canonical team-sprint reference)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_member_capacity (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  project_id         uuid NOT NULL,
  team_iteration_id  uuid NOT NULL,
  member_id          uuid NOT NULL,
  capacity_per_day   numeric(8,2) NOT NULL DEFAULT 0 CHECK (capacity_per_day >= 0),
  activity           text,
  days_off           jsonb NOT NULL DEFAULT '[]'::jsonb,
  net_capacity_hours numeric(10,2),
  source_status      public.source_status NOT NULL DEFAULT 'active',
  is_deleted         boolean NOT NULL DEFAULT false,
  deleted_at_source  timestamptz,
  last_seen_at       timestamptz,
  access_revoked_at  timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_member_capacity_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_member_capacity_natural_key UNIQUE (tenant_id, team_iteration_id, member_id),
  CONSTRAINT core_member_capacity_ti_fk FOREIGN KEY (tenant_id, project_id, team_iteration_id)
    REFERENCES public.core_team_iterations (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT core_member_capacity_member_fk FOREIGN KEY (tenant_id, member_id)
    REFERENCES public.core_members (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_member_capacity_deleted_consistent
    CHECK (is_deleted = false OR source_status = 'deleted')
);

-- ---------------------------------------------------------------------
-- core_process_mappings (project default + optional team override)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_process_mappings (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id              uuid NOT NULL,
  project_id             uuid NOT NULL,
  team_id                uuid,
  kind                   public.process_template_kind NOT NULL DEFAULT 'agile',
  work_item_type_aliases jsonb NOT NULL DEFAULT '{}'::jsonb,
  state_category_map     jsonb NOT NULL DEFAULT '{}'::jsonb,
  done_states            text[] NOT NULL DEFAULT '{}',
  active_states          text[] NOT NULL DEFAULT '{}',
  blocked_fields         text[] NOT NULL DEFAULT '{}',
  estimate_fields        text[] NOT NULL DEFAULT '{}',
  severity_field         text,
  bug_handling_mode      public.bug_handling_mode NOT NULL DEFAULT 'as_requirement',
  rollup_mode            public.rollup_mode NOT NULL DEFAULT 'leaf_only',
  hierarchy_rules        jsonb NOT NULL DEFAULT '{}'::jsonb,
  notes                  jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_process_mappings_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_process_mappings_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_process_mappings_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT core_process_mappings_team_requires_project
    CHECK (team_id IS NULL OR project_id IS NOT NULL)
);
-- Documented nullable-unique decision: one project default, one override per team.
CREATE UNIQUE INDEX IF NOT EXISTS core_process_mappings_project_default
  ON public.core_process_mappings (tenant_id, project_id) WHERE team_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS core_process_mappings_team_override
  ON public.core_process_mappings (tenant_id, project_id, team_id) WHERE team_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- triggers: updated_at + structural immutability
-- ---------------------------------------------------------------------
DO $$
DECLARE
  t text;
  immutable_cols text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'core_organizations','core_projects','core_teams','core_iterations',
    'core_team_iterations','core_members','core_team_memberships',
    'core_member_capacity','core_process_mappings'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I
         FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()', t);

    immutable_cols := CASE
      WHEN t IN ('core_organizations','core_members') THEN '''tenant_id'''
      WHEN t = 'core_team_iterations' THEN '''tenant_id'',''project_id'',''team_id'',''iteration_id'''
      WHEN t = 'core_member_capacity' THEN '''tenant_id'',''project_id'',''team_iteration_id'',''member_id'''
      ELSE '''tenant_id'',''project_id'''
    END;

    EXECUTE format('DROP TRIGGER IF EXISTS immutable_identity ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER immutable_identity BEFORE UPDATE ON public.%I
         FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change(%s)', t, immutable_cols);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- grants + RLS (policies land in migration 13)
-- ---------------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'core_organizations','core_projects','core_teams','core_iterations',
    'core_team_iterations','core_members','core_team_memberships',
    'core_member_capacity','core_process_mappings'
  ] LOOP
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;