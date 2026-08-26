-- =====================================================================
-- Phase 3 migration 02 — shared helpers + core tenant/user tables
-- Rollback: DROP TABLE core_tenant_retention_settings, core_users,
--           core_tenants CASCADE; DROP FUNCTION tg_* CASCADE;
-- =====================================================================

-- ---------------------------------------------------------------------
-- Shared record-metadata helpers
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tg_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Immutability mechanism #1: BEFORE UPDATE trigger rejecting changes to
-- structural ownership columns. Column names are passed as trigger args.
CREATE OR REPLACE FUNCTION public.tg_prevent_column_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  col text;
  old_val text;
  new_val text;
BEGIN
  FOREACH col IN ARRAY TG_ARGV LOOP
    EXECUTE format('SELECT ($1).%I::text', col) INTO old_val USING OLD;
    EXECUTE format('SELECT ($1).%I::text', col) INTO new_val USING NEW;
    IF old_val IS DISTINCT FROM new_val THEN
      RAISE EXCEPTION 'column %.% is immutable', TG_TABLE_NAME, col
        USING ERRCODE = '23514';
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;

-- Immutability mechanism #2: append-only tables reject every UPDATE/DELETE,
-- including from service_role (history must never be silently rewritten).
CREATE OR REPLACE FUNCTION public.tg_append_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION '% is append-only; % is not permitted', TG_TABLE_NAME, TG_OP
    USING ERRCODE = '23514';
END;
$$;

-- Immutability mechanism #3: rows may be updated until finalized, never after.
CREATE OR REPLACE FUNCTION public.tg_block_update_when_finalized()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF OLD.finalized_at IS NOT NULL THEN
    RAISE EXCEPTION 'row in % is finalized and immutable', TG_TABLE_NAME
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------
-- core_tenants
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_tenants (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug          extensions.citext NOT NULL UNIQUE,
  name_en       text NOT NULL,
  name_ar       text NOT NULL,
  default_time_zone text NOT NULL DEFAULT 'Africa/Cairo',
  is_active     boolean NOT NULL DEFAULT true,
  legal_hold    boolean NOT NULL DEFAULT false,
  is_demo       boolean NOT NULL DEFAULT false,
  settings      jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_tenants_id_not_sentinel
    CHECK (id <> '00000000-0000-0000-0000-000000000000'::uuid)
);

DROP TRIGGER IF EXISTS set_updated_at ON public.core_tenants;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.core_tenants
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

GRANT SELECT ON public.core_tenants TO authenticated;
GRANT ALL ON public.core_tenants TO service_role;
ALTER TABLE public.core_tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.core_tenants FORCE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- core_users  (maps auth.users -> tenant; roles live in core_user_roles)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  auth_user_id  uuid NOT NULL,
  email         extensions.citext NOT NULL,
  display_name  text NOT NULL,
  locale        text NOT NULL DEFAULT 'ar' CHECK (locale IN ('ar','en')),
  is_active     boolean NOT NULL DEFAULT true,
  last_seen_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_users_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_users_tenant_auth_user_key UNIQUE (tenant_id, auth_user_id),
  CONSTRAINT core_users_tenant_email_key UNIQUE (tenant_id, email)
);

-- One app user per sign-in account in this phase (single-tenant membership).
CREATE UNIQUE INDEX IF NOT EXISTS core_users_auth_user_unique
  ON public.core_users (auth_user_id);
CREATE INDEX IF NOT EXISTS core_users_tenant_idx ON public.core_users (tenant_id);

DROP TRIGGER IF EXISTS set_updated_at ON public.core_users;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.core_users
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

-- tenant_id and auth_user_id are structural identity: never re-parentable.
DROP TRIGGER IF EXISTS immutable_identity ON public.core_users;
CREATE TRIGGER immutable_identity BEFORE UPDATE ON public.core_users
  FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change('tenant_id','auth_user_id');

GRANT SELECT ON public.core_users TO authenticated;
GRANT ALL ON public.core_users TO service_role;
ALTER TABLE public.core_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.core_users FORCE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- core_tenant_retention_settings
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.core_tenant_retention_settings (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  rule_key          text NOT NULL,
  retention_days    integer NOT NULL CHECK (retention_days > 0),
  minimum_days      integer NOT NULL CHECK (minimum_days > 0),
  legal_hold        boolean NOT NULL DEFAULT false,
  notes             text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_tenant_retention_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_tenant_retention_rule_key UNIQUE (tenant_id, rule_key),
  CONSTRAINT core_tenant_retention_above_minimum CHECK (retention_days >= minimum_days),
  CONSTRAINT core_tenant_retention_rule_known CHECK (rule_key IN (
    'work_item_revisions','daily_project_snapshots','daily_team_snapshots',
    'daily_iteration_snapshots','daily_member_snapshots','raw_payloads',
    'sync_runs','audit_events','copilot_answers'))
);

DROP TRIGGER IF EXISTS set_updated_at ON public.core_tenant_retention_settings;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.core_tenant_retention_settings
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

DROP TRIGGER IF EXISTS immutable_identity ON public.core_tenant_retention_settings;
CREATE TRIGGER immutable_identity BEFORE UPDATE ON public.core_tenant_retention_settings
  FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change('tenant_id');

GRANT SELECT ON public.core_tenant_retention_settings TO authenticated;
GRANT ALL ON public.core_tenant_retention_settings TO service_role;
ALTER TABLE public.core_tenant_retention_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.core_tenant_retention_settings FORCE ROW LEVEL SECURITY;