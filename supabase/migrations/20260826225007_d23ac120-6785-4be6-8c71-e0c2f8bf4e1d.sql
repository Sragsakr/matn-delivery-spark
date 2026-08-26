-- =====================================================================
-- Phase 3 migration 12 — helper functions
-- All functions: SET search_path = '' + fully qualified references.
-- Rollback: DROP FUNCTION ... (see supabase/migrations/README.md)
-- =====================================================================

-- ------------------------------------------------------- identity helpers
CREATE OR REPLACE FUNCTION public.current_core_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.id
  FROM public.core_users u
  WHERE u.auth_user_id = (SELECT auth.uid())
    AND u.is_active
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.tenant_id
  FROM public.core_users u
  WHERE u.auth_user_id = (SELECT auth.uid())
    AND u.is_active
  LIMIT 1;
$$;

-- --------------------------------------------------------------- roles
CREATE OR REPLACE FUNCTION public.has_role(target_role public.app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.core_user_roles r
    JOIN public.core_users u
      ON u.id = r.user_id AND u.tenant_id = r.tenant_id
    WHERE u.auth_user_id = (SELECT auth.uid())
      AND u.is_active
      AND r.role = target_role
      AND r.revoked_at IS NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.is_platform_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT public.has_role('platform_admin'::public.app_role);
$$;

-- Tenant access: never trusts a tenant id supplied by the client; it is
-- always compared against the caller's own resolved tenant membership.
CREATE OR REPLACE FUNCTION public.has_tenant_access(target_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT target_tenant_id IS NOT NULL
     AND EXISTS (
       SELECT 1 FROM public.core_users u
       WHERE u.auth_user_id = (SELECT auth.uid())
         AND u.is_active
         AND u.tenant_id = target_tenant_id
     );
$$;

-- Roles that see the whole tenant without explicit scope rows.
CREATE OR REPLACE FUNCTION public.has_full_tenant_access(target_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.core_user_roles r
    JOIN public.core_users u
      ON u.id = r.user_id AND u.tenant_id = r.tenant_id
    WHERE u.auth_user_id = (SELECT auth.uid())
      AND u.is_active
      AND u.tenant_id = target_tenant_id
      AND r.revoked_at IS NULL
      AND r.role IN ('platform_admin'::public.app_role,
                     'tenant_admin'::public.app_role,
                     'executive_viewer'::public.app_role)
  );
$$;

-- ------------------------------------------------------ scope predicates
CREATE OR REPLACE FUNCTION public.has_project_access(target_tenant_id uuid, target_project_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.has_full_tenant_access(target_tenant_id)
     OR EXISTS (
       SELECT 1
       FROM public.core_user_project_scopes s
       JOIN public.core_users u
         ON u.id = s.user_id AND u.tenant_id = s.tenant_id
       WHERE u.auth_user_id = (SELECT auth.uid())
         AND u.is_active
         AND s.tenant_id = target_tenant_id
         AND s.project_id = target_project_id
         AND s.revoked_at IS NULL
         AND (s.expires_at IS NULL OR s.expires_at > now())
     )
     OR EXISTS (
       -- a team grant inside the project implies project visibility
       SELECT 1
       FROM public.core_user_team_scopes s
       JOIN public.core_users u
         ON u.id = s.user_id AND u.tenant_id = s.tenant_id
       JOIN public.core_teams t
         ON t.id = s.team_id AND t.tenant_id = s.tenant_id
       WHERE u.auth_user_id = (SELECT auth.uid())
         AND u.is_active
         AND s.tenant_id = target_tenant_id
         AND t.project_id = target_project_id
         AND s.revoked_at IS NULL
         AND (s.expires_at IS NULL OR s.expires_at > now())
     );
$$;

CREATE OR REPLACE FUNCTION public.has_team_access(target_tenant_id uuid, target_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.has_full_tenant_access(target_tenant_id)
     OR EXISTS (
       SELECT 1
       FROM public.core_user_team_scopes s
       JOIN public.core_users u
         ON u.id = s.user_id AND u.tenant_id = s.tenant_id
       WHERE u.auth_user_id = (SELECT auth.uid())
         AND u.is_active
         AND s.tenant_id = target_tenant_id
         AND s.team_id = target_team_id
         AND s.revoked_at IS NULL
         AND (s.expires_at IS NULL OR s.expires_at > now())
     )
     OR EXISTS (
       -- a project grant covers every team inside that project
       SELECT 1
       FROM public.core_user_project_scopes s
       JOIN public.core_users u
         ON u.id = s.user_id AND u.tenant_id = s.tenant_id
       JOIN public.core_teams t
         ON t.project_id = s.project_id AND t.tenant_id = s.tenant_id
       WHERE u.auth_user_id = (SELECT auth.uid())
         AND u.is_active
         AND s.tenant_id = target_tenant_id
         AND t.id = target_team_id
         AND s.revoked_at IS NULL
         AND (s.expires_at IS NULL OR s.expires_at > now())
     );
$$;

-- Executive viewers are aggregate-only: no individual member utilization.
CREATE OR REPLACE FUNCTION public.can_view_member_detail(target_tenant_id uuid, target_team_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT public.has_team_access(target_tenant_id, target_team_id)
     AND EXISTS (
       SELECT 1
       FROM public.core_user_roles r
       JOIN public.core_users u
         ON u.id = r.user_id AND u.tenant_id = r.tenant_id
       WHERE u.auth_user_id = (SELECT auth.uid())
         AND u.is_active
         AND u.tenant_id = target_tenant_id
         AND r.revoked_at IS NULL
         AND r.role IN ('platform_admin'::public.app_role,
                        'tenant_admin'::public.app_role,
                        'delivery_manager'::public.app_role,
                        'team_lead'::public.app_role,
                        'qa_release_owner'::public.app_role)
     );
$$;

-- ---------------------------------------------------------- audit writer
CREATE OR REPLACE FUNCTION public.write_audit_event(
  _tenant_id uuid,
  _actor_user_id uuid,
  _action text,
  _entity_type text,
  _entity_id uuid,
  _outcome public.audit_outcome DEFAULT 'success',
  _idempotency_key text DEFAULT NULL,
  _metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE _id uuid;
BEGIN
  INSERT INTO public.aud_audit_events
    (tenant_id, actor_type, actor_user_id, action, entity_type, entity_id,
     idempotency_key, outcome, metadata)
  VALUES
    (_tenant_id,
     CASE WHEN _actor_user_id IS NULL THEN 'system'::public.actor_type
          ELSE 'user'::public.actor_type END,
     _actor_user_id, _action, _entity_type, _entity_id,
     _idempotency_key, _outcome, COALESCE(_metadata, '{}'::jsonb))
  RETURNING id INTO _id;
  RETURN _id;
END;
$$;

-- ------------------------------------------------------- grant functions
CREATE OR REPLACE FUNCTION public.grant_project_scope(
  _tenant_id uuid,
  _user_id uuid,
  _project_id uuid,
  _granted_by uuid,
  _expires_at timestamptz DEFAULT NULL,
  _idempotency_key text DEFAULT NULL,
  _reason text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _existing uuid;
  _new uuid;
BEGIN
  IF _expires_at IS NOT NULL AND _expires_at <= now() THEN
    RAISE EXCEPTION 'expires_at must be null or in the future' USING ERRCODE = '22023';
  END IF;

  -- target user must belong to the tenant
  IF NOT EXISTS (SELECT 1 FROM public.core_users u
                 WHERE u.id = _user_id AND u.tenant_id = _tenant_id) THEN
    RAISE EXCEPTION 'target user does not belong to tenant' USING ERRCODE = '42501';
  END IF;

  -- target project must belong to the tenant
  IF NOT EXISTS (SELECT 1 FROM public.core_projects p
                 WHERE p.id = _project_id AND p.tenant_id = _tenant_id) THEN
    RAISE EXCEPTION 'target project does not belong to tenant' USING ERRCODE = '42501';
  END IF;

  -- granter must be a tenant admin (or platform admin) of the same tenant:
  -- no one can grant authority they do not hold
  IF _granted_by IS NULL OR NOT EXISTS (
       SELECT 1 FROM public.core_user_roles r
       JOIN public.core_users g ON g.id = r.user_id AND g.tenant_id = r.tenant_id
       WHERE g.id = _granted_by
         AND g.tenant_id = _tenant_id
         AND r.revoked_at IS NULL
         AND r.role IN ('platform_admin'::public.app_role,
                        'tenant_admin'::public.app_role)) THEN
    PERFORM public.write_audit_event(_tenant_id, _granted_by, 'scope.grant.denied',
      'core_user_project_scopes', NULL, 'denied'::public.audit_outcome, _idempotency_key,
      jsonb_build_object('project_id', _project_id, 'user_id', _user_id));
    RAISE EXCEPTION 'granter lacks authority to grant project scope' USING ERRCODE = '42501';
  END IF;

  -- 1. serialize concurrent grants per tenant/user/target
  PERFORM pg_advisory_xact_lock(
    hashtextextended(_tenant_id::text || ':' || _user_id::text || ':' || _project_id::text, 0));

  -- 2. close expired-but-open rows in the same transaction
  UPDATE public.core_user_project_scopes
     SET revoked_at = now(), closed_reason = 'expired', updated_at = now()
   WHERE tenant_id = _tenant_id AND user_id = _user_id AND project_id = _project_id
     AND revoked_at IS NULL AND expires_at IS NOT NULL AND expires_at <= now();

  -- 3. idempotent: return the existing active grant
  SELECT s.id INTO _existing
    FROM public.core_user_project_scopes s
   WHERE s.tenant_id = _tenant_id AND s.user_id = _user_id AND s.project_id = _project_id
     AND s.revoked_at IS NULL AND (s.expires_at IS NULL OR s.expires_at > now())
   FOR UPDATE;

  IF _existing IS NOT NULL THEN
    PERFORM public.write_audit_event(_tenant_id, _granted_by, 'scope.grant.noop',
      'core_user_project_scopes', _existing, 'noop'::public.audit_outcome, _idempotency_key,
      jsonb_build_object('project_id', _project_id, 'user_id', _user_id));
    RETURN _existing;
  END IF;

  -- 4. insert
  INSERT INTO public.core_user_project_scopes
    (tenant_id, user_id, project_id, granted_by_user_id, granted_at, expires_at,
     idempotency_key, reason)
  VALUES (_tenant_id, _user_id, _project_id, _granted_by, now(), _expires_at,
          _idempotency_key, _reason)
  RETURNING id INTO _new;

  PERFORM public.write_audit_event(_tenant_id, _granted_by, 'scope.grant.created',
    'core_user_project_scopes', _new, 'success'::public.audit_outcome, _idempotency_key,
    jsonb_build_object('project_id', _project_id, 'user_id', _user_id,
                       'expires_at', _expires_at));
  RETURN _new;
END;
$$;

CREATE OR REPLACE FUNCTION public.grant_team_scope(
  _tenant_id uuid,
  _user_id uuid,
  _team_id uuid,
  _granted_by uuid,
  _expires_at timestamptz DEFAULT NULL,
  _idempotency_key text DEFAULT NULL,
  _reason text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  _existing uuid;
  _new uuid;
BEGIN
  IF _expires_at IS NOT NULL AND _expires_at <= now() THEN
    RAISE EXCEPTION 'expires_at must be null or in the future' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.core_users u
                 WHERE u.id = _user_id AND u.tenant_id = _tenant_id) THEN
    RAISE EXCEPTION 'target user does not belong to tenant' USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.core_teams t
                 WHERE t.id = _team_id AND t.tenant_id = _tenant_id) THEN
    RAISE EXCEPTION 'target team does not belong to tenant' USING ERRCODE = '42501';
  END IF;

  IF _granted_by IS NULL OR NOT EXISTS (
       SELECT 1 FROM public.core_user_roles r
       JOIN public.core_users g ON g.id = r.user_id AND g.tenant_id = r.tenant_id
       WHERE g.id = _granted_by
         AND g.tenant_id = _tenant_id
         AND r.revoked_at IS NULL
         AND r.role IN ('platform_admin'::public.app_role,
                        'tenant_admin'::public.app_role,
                        'delivery_manager'::public.app_role)) THEN
    PERFORM public.write_audit_event(_tenant_id, _granted_by, 'scope.grant.denied',
      'core_user_team_scopes', NULL, 'denied'::public.audit_outcome, _idempotency_key,
      jsonb_build_object('team_id', _team_id, 'user_id', _user_id));
    RAISE EXCEPTION 'granter lacks authority to grant team scope' USING ERRCODE = '42501';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(_tenant_id::text || ':' || _user_id::text || ':' || _team_id::text, 0));

  UPDATE public.core_user_team_scopes
     SET revoked_at = now(), closed_reason = 'expired', updated_at = now()
   WHERE tenant_id = _tenant_id AND user_id = _user_id AND team_id = _team_id
     AND revoked_at IS NULL AND expires_at IS NOT NULL AND expires_at <= now();

  SELECT s.id INTO _existing
    FROM public.core_user_team_scopes s
   WHERE s.tenant_id = _tenant_id AND s.user_id = _user_id AND s.team_id = _team_id
     AND s.revoked_at IS NULL AND (s.expires_at IS NULL OR s.expires_at > now())
   FOR UPDATE;

  IF _existing IS NOT NULL THEN
    PERFORM public.write_audit_event(_tenant_id, _granted_by, 'scope.grant.noop',
      'core_user_team_scopes', _existing, 'noop'::public.audit_outcome, _idempotency_key,
      jsonb_build_object('team_id', _team_id, 'user_id', _user_id));
    RETURN _existing;
  END IF;

  INSERT INTO public.core_user_team_scopes
    (tenant_id, user_id, team_id, granted_by_user_id, granted_at, expires_at,
     idempotency_key, reason)
  VALUES (_tenant_id, _user_id, _team_id, _granted_by, now(), _expires_at,
          _idempotency_key, _reason)
  RETURNING id INTO _new;

  PERFORM public.write_audit_event(_tenant_id, _granted_by, 'scope.grant.created',
    'core_user_team_scopes', _new, 'success'::public.audit_outcome, _idempotency_key,
    jsonb_build_object('team_id', _team_id, 'user_id', _user_id, 'expires_at', _expires_at));
  RETURN _new;
END;
$$;

-- --------------------------------------------------------- execute grants
-- Read-side predicates are needed by RLS evaluated as the caller.
DO $$
DECLARE sig text;
BEGIN
  FOREACH sig IN ARRAY ARRAY[
    'public.current_core_user_id()',
    'public.current_tenant_id()',
    'public.has_role(public.app_role)',
    'public.is_platform_admin()',
    'public.has_tenant_access(uuid)',
    'public.has_full_tenant_access(uuid)',
    'public.has_project_access(uuid, uuid)',
    'public.has_team_access(uuid, uuid)',
    'public.can_view_member_detail(uuid, uuid)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', sig);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', sig);
  END LOOP;
END $$;

-- Privileged writers: service_role only. A Tenant Admin manages scopes
-- through a server-side action that authenticates the caller first and then
-- invokes these functions; the browser can never call them directly.
DO $$
DECLARE sig text;
BEGIN
  FOREACH sig IN ARRAY ARRAY[
    'public.write_audit_event(uuid, uuid, text, text, uuid, public.audit_outcome, text, jsonb)',
    'public.grant_project_scope(uuid, uuid, uuid, uuid, timestamptz, text, text)',
    'public.grant_team_scope(uuid, uuid, uuid, uuid, timestamptz, text, text)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', sig);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon', sig);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM authenticated', sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', sig);
  END LOOP;
END $$;