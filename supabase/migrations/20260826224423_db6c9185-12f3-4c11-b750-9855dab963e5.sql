-- =====================================================================
-- Phase 3 migration 05 — Azure normalized current-state tables
-- Rollback: DROP TABLE az_work_item_relations, az_work_items CASCADE;
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.az_work_items (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id              uuid NOT NULL,
  organization_id        uuid NOT NULL,
  project_id             uuid NOT NULL,
  team_id                uuid,
  iteration_id           uuid,
  team_iteration_id      uuid,

  azure_work_item_id     bigint NOT NULL,
  azure_rev              integer NOT NULL DEFAULT 1,

  title                  text NOT NULL,
  description            text,
  azure_work_item_type   text NOT NULL,
  alias                  public.work_item_alias NOT NULL DEFAULT 'custom',
  state                  text NOT NULL,
  state_category         public.state_category NOT NULL DEFAULT 'unknown',
  reason                 text,

  area_path              text NOT NULL DEFAULT '',
  iteration_path         text NOT NULL DEFAULT '',
  tags                   text[] NOT NULL DEFAULT '{}',

  assigned_to_member_id  uuid,
  created_by_member_id   uuid,
  changed_by_member_id   uuid,
  created_at_source      timestamptz NOT NULL DEFAULT now(),
  changed_at_source      timestamptz NOT NULL DEFAULT now(),

  activated_date         timestamptz,
  resolved_date          timestamptz,
  closed_date            timestamptz,
  state_change_date      timestamptz,

  priority               integer,
  severity               public.severity_level,
  azure_severity_raw     text,

  estimate               numeric(12,2),
  estimate_unit          text CHECK (estimate_unit IN ('storyPoints','hours','effort')),
  estimate_source_field  text,
  remaining_work         numeric(12,2),
  completed_work         numeric(12,2),
  original_estimate      numeric(12,2),

  is_blocked             boolean NOT NULL DEFAULT false,
  blocked_source_field   text,
  blocked_since          timestamptz,

  parent_work_item_id    uuid,
  parent_azure_work_item_id bigint,
  hierarchy_depth        integer,
  is_leaf                boolean NOT NULL DEFAULT true,

  counts_toward_scope    boolean NOT NULL DEFAULT true,
  azure_url              text,
  custom_fields          jsonb NOT NULL DEFAULT '{}'::jsonb,

  source_status          public.source_status NOT NULL DEFAULT 'active',
  is_deleted             boolean NOT NULL DEFAULT false,
  deleted_at_source      timestamptz,
  last_seen_at           timestamptz,
  access_revoked_at      timestamptz,
  last_synced_at         timestamptz,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT az_work_items_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_work_items_natural_key UNIQUE (tenant_id, organization_id, azure_work_item_id),
  CONSTRAINT az_work_items_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_work_items_iteration_fk FOREIGN KEY (tenant_id, project_id, iteration_id)
    REFERENCES public.core_iterations (tenant_id, project_id, id),
  CONSTRAINT az_work_items_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id),
  CONSTRAINT az_work_items_team_iteration_fk FOREIGN KEY (tenant_id, project_id, team_iteration_id)
    REFERENCES public.core_team_iterations (tenant_id, project_id, id),
  CONSTRAINT az_work_items_assignee_fk FOREIGN KEY (tenant_id, assigned_to_member_id)
    REFERENCES public.core_members (tenant_id, id),
  CONSTRAINT az_work_items_parent_fk FOREIGN KEY (tenant_id, parent_work_item_id)
    REFERENCES public.az_work_items (tenant_id, id),
  CONSTRAINT az_work_items_deleted_consistent
    CHECK (is_deleted = false OR source_status = 'deleted')
);

CREATE INDEX IF NOT EXISTS az_work_items_iteration_state_idx
  ON public.az_work_items (tenant_id, iteration_id, state_category);
CREATE INDEX IF NOT EXISTS az_work_items_team_iteration_idx
  ON public.az_work_items (tenant_id, team_iteration_id);
CREATE INDEX IF NOT EXISTS az_work_items_project_changed_idx
  ON public.az_work_items (tenant_id, project_id, changed_at_source DESC);
CREATE INDEX IF NOT EXISTS az_work_items_parent_idx
  ON public.az_work_items (tenant_id, parent_work_item_id);
CREATE INDEX IF NOT EXISTS az_work_items_tags_gin
  ON public.az_work_items USING gin (tags);
CREATE INDEX IF NOT EXISTS az_work_items_custom_fields_gin
  ON public.az_work_items USING gin (custom_fields jsonb_path_ops);

CREATE TABLE IF NOT EXISTS public.az_work_item_relations (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id                 uuid NOT NULL,
  source_work_item_id       uuid NOT NULL,
  target_work_item_id       uuid,
  target_azure_work_item_id bigint NOT NULL,
  relation_type             text NOT NULL CHECK (relation_type IN (
    'parent','child','related','predecessor','successor','duplicate',
    'duplicateOf','testedBy','tests','affects','other')),
  azure_relation_name       text NOT NULL,
  is_cross_project          boolean NOT NULL DEFAULT false,
  source_status             public.source_status NOT NULL DEFAULT 'active',
  is_deleted                boolean NOT NULL DEFAULT false,
  deleted_at_source         timestamptz,
  last_seen_at              timestamptz,
  access_revoked_at         timestamptz,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_work_item_relations_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_work_item_relations_natural_key
    UNIQUE (tenant_id, source_work_item_id, azure_relation_name, target_azure_work_item_id),
  CONSTRAINT az_work_item_relations_source_fk FOREIGN KEY (tenant_id, source_work_item_id)
    REFERENCES public.az_work_items (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_work_item_relations_target_fk FOREIGN KEY (tenant_id, target_work_item_id)
    REFERENCES public.az_work_items (tenant_id, id),
  CONSTRAINT az_work_item_relations_deleted_consistent
    CHECK (is_deleted = false OR source_status = 'deleted')
);
CREATE INDEX IF NOT EXISTS az_work_item_relations_target_idx
  ON public.az_work_item_relations (tenant_id, target_work_item_id);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['az_work_items','az_work_item_relations'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I', t);
    EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()', t);
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

DROP TRIGGER IF EXISTS immutable_identity ON public.az_work_items;
CREATE TRIGGER immutable_identity BEFORE UPDATE ON public.az_work_items
  FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change(
    'tenant_id','organization_id','project_id','azure_work_item_id');

DROP TRIGGER IF EXISTS immutable_identity ON public.az_work_item_relations;
CREATE TRIGGER immutable_identity BEFORE UPDATE ON public.az_work_item_relations
  FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change(
    'tenant_id','source_work_item_id','azure_relation_name','target_azure_work_item_id');