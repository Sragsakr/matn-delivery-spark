-- =====================================================================
-- Phase 3 migration 04 — roles and authorization scopes
-- Rollback: DROP TABLE core_user_team_scopes, core_user_project_scopes,
--           core_user_roles CASCADE;
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.core_user_roles (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL,
  user_id             uuid NOT NULL,
  role                public.app_role NOT NULL,
  granted_by_user_id  uuid,
  granted_at          timestamptz NOT NULL DEFAULT now(),
  revoked_at          timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_user_roles_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_user_roles_natural_key UNIQUE (tenant_id, user_id, role),
  CONSTRAINT core_user_roles_user_fk FOREIGN KEY (tenant_id, user_id)
    REFERENCES public.core_users (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_user_roles_granted_by_fk FOREIGN KEY (tenant_id, granted_by_user_id)
    REFERENCES public.core_users (tenant_id, id)
);
CREATE INDEX IF NOT EXISTS core_user_roles_user_idx
  ON public.core_user_roles (user_id) WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS public.core_user_project_scopes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL,
  user_id             uuid NOT NULL,
  project_id          uuid NOT NULL,
  granted_by_user_id  uuid,
  granted_at          timestamptz NOT NULL DEFAULT now(),
  expires_at          timestamptz,
  revoked_at          timestamptz,
  closed_reason       text CHECK (closed_reason IN ('expired','revoked_by_admin','superseded')),
  idempotency_key     text,
  reason              text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_user_project_scopes_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_user_project_scopes_user_fk FOREIGN KEY (tenant_id, user_id)
    REFERENCES public.core_users (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_user_project_scopes_granted_by_fk FOREIGN KEY (tenant_id, granted_by_user_id)
    REFERENCES public.core_users (tenant_id, id),
  CONSTRAINT core_user_project_scopes_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE
);
-- Documented partial-unique decision: at most one OPEN grant per target.
-- Expired-open rows are closed transactionally by grant_project_scope().
CREATE UNIQUE INDEX IF NOT EXISTS core_user_project_scopes_active
  ON public.core_user_project_scopes (tenant_id, user_id, project_id)
  WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS core_user_project_scopes_lookup
  ON public.core_user_project_scopes (tenant_id, user_id, project_id, expires_at)
  WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS public.core_user_team_scopes (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL,
  user_id             uuid NOT NULL,
  team_id             uuid NOT NULL,
  granted_by_user_id  uuid,
  granted_at          timestamptz NOT NULL DEFAULT now(),
  expires_at          timestamptz,
  revoked_at          timestamptz,
  closed_reason       text CHECK (closed_reason IN ('expired','revoked_by_admin','superseded')),
  idempotency_key     text,
  reason              text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT core_user_team_scopes_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT core_user_team_scopes_user_fk FOREIGN KEY (tenant_id, user_id)
    REFERENCES public.core_users (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT core_user_team_scopes_granted_by_fk FOREIGN KEY (tenant_id, granted_by_user_id)
    REFERENCES public.core_users (tenant_id, id),
  CONSTRAINT core_user_team_scopes_team_fk FOREIGN KEY (tenant_id, team_id)
    REFERENCES public.core_teams (tenant_id, id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS core_user_team_scopes_active
  ON public.core_user_team_scopes (tenant_id, user_id, team_id)
  WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS core_user_team_scopes_lookup
  ON public.core_user_team_scopes (tenant_id, user_id, team_id, expires_at)
  WHERE revoked_at IS NULL;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['core_user_roles','core_user_project_scopes','core_user_team_scopes'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I', t);
    EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()', t);
    EXECUTE format('DROP TRIGGER IF EXISTS immutable_identity ON public.%I', t);
    EXECUTE format('CREATE TRIGGER immutable_identity BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change(''tenant_id'',''user_id'')', t);
    -- Read-only for authenticated: role/scope writes go through restricted
    -- security-definer functions executed by service_role only.
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;