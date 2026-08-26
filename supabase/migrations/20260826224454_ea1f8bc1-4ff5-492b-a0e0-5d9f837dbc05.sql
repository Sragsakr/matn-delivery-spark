-- =====================================================================
-- Phase 3 migration 06 — Azure immutable history tables
-- Immutability mechanism: append-only BEFORE UPDATE/DELETE trigger
-- (applies to every role, service_role included) + no UPDATE/DELETE policy.
-- Rollback: DROP TABLE az_raw_payloads, az_work_item_scope_changes,
--           az_work_item_transitions, az_work_item_revisions CASCADE;
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.az_work_item_revisions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL,
  project_id         uuid NOT NULL,
  work_item_id       uuid NOT NULL,
  azure_work_item_id bigint NOT NULL,
  rev                integer NOT NULL,
  revised_at         timestamptz NOT NULL,
  revised_by_member_id uuid,
  state              text,
  state_category     public.state_category NOT NULL DEFAULT 'unknown',
  iteration_path     text,
  area_path          text,
  estimate           numeric(12,2),
  remaining_work     numeric(12,2),
  completed_work     numeric(12,2),
  is_blocked         boolean,
  assigned_to_member_id uuid,
  fields             jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_work_item_revisions_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_work_item_revisions_natural_key UNIQUE (tenant_id, work_item_id, rev),
  CONSTRAINT az_work_item_revisions_item_fk FOREIGN KEY (tenant_id, work_item_id)
    REFERENCES public.az_work_items (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_work_item_revisions_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS az_work_item_revisions_time_idx
  ON public.az_work_item_revisions (tenant_id, work_item_id, revised_at);

CREATE TABLE IF NOT EXISTS public.az_work_item_transitions (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL,
  project_id       uuid NOT NULL,
  work_item_id     uuid NOT NULL,
  occurred_at      timestamptz NOT NULL,
  from_state       text,
  to_state         text NOT NULL,
  from_state_category public.state_category NOT NULL DEFAULT 'unknown',
  to_state_category   public.state_category NOT NULL DEFAULT 'unknown',
  duration_seconds bigint,
  changed_by_member_id uuid,
  source_rev       integer,
  created_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_work_item_transitions_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_work_item_transitions_natural_key
    UNIQUE (tenant_id, work_item_id, occurred_at, to_state),
  CONSTRAINT az_work_item_transitions_item_fk FOREIGN KEY (tenant_id, work_item_id)
    REFERENCES public.az_work_items (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_work_item_transitions_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS az_work_item_transitions_item_idx
  ON public.az_work_item_transitions (tenant_id, work_item_id);

CREATE TABLE IF NOT EXISTS public.az_work_item_scope_changes (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL,
  project_id        uuid NOT NULL,
  work_item_id      uuid NOT NULL,
  iteration_id      uuid NOT NULL,
  team_iteration_id uuid,
  occurred_at       timestamptz NOT NULL,
  change_type       text NOT NULL CHECK (change_type IN ('added','removed','reestimated')),
  estimate_delta    numeric(12,2),
  source_rev        integer,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_work_item_scope_changes_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_work_item_scope_changes_natural_key
    UNIQUE (tenant_id, work_item_id, iteration_id, occurred_at, change_type),
  CONSTRAINT az_work_item_scope_changes_item_fk FOREIGN KEY (tenant_id, work_item_id)
    REFERENCES public.az_work_items (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT az_work_item_scope_changes_iteration_fk FOREIGN KEY (tenant_id, project_id, iteration_id)
    REFERENCES public.core_iterations (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT az_work_item_scope_changes_ti_fk FOREIGN KEY (tenant_id, project_id, team_iteration_id)
    REFERENCES public.core_team_iterations (tenant_id, project_id, id)
);
CREATE INDEX IF NOT EXISTS az_work_item_scope_changes_iteration_idx
  ON public.az_work_item_scope_changes (tenant_id, iteration_id, occurred_at);

CREATE TABLE IF NOT EXISTS public.az_raw_payloads (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  entity_kind  text NOT NULL,
  azure_id     text NOT NULL,
  rev          integer NOT NULL DEFAULT 0,
  payload      jsonb NOT NULL,
  fetched_at   timestamptz NOT NULL DEFAULT now(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT az_raw_payloads_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT az_raw_payloads_natural_key UNIQUE (tenant_id, entity_kind, azure_id, rev)
);
CREATE INDEX IF NOT EXISTS az_raw_payloads_fetched_idx ON public.az_raw_payloads (fetched_at);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'az_work_item_revisions','az_work_item_transitions',
    'az_work_item_scope_changes','az_raw_payloads'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS append_only ON public.%I', t);
    EXECUTE format('CREATE TRIGGER append_only BEFORE UPDATE OR DELETE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_append_only()', t);
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', t);
    -- service_role may INSERT and SELECT; UPDATE/DELETE are withheld and
    -- additionally blocked by the append_only trigger.
    EXECUTE format('GRANT SELECT, INSERT ON public.%I TO service_role', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;