CREATE OR REPLACE FUNCTION public.bootstrap_first_tenant_admin(
  p_auth_user_id uuid,
  p_email text,
  p_display_name text,
  p_tenant_name text,
  p_tenant_slug text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
  v_slug text := lower(btrim(coalesce(p_tenant_slug, '')));
  v_name text := btrim(coalesce(p_tenant_name, ''));
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_tenant_id uuid;
  v_user_id uuid;
  v_reason text;
BEGIN
  IF p_auth_user_id IS NULL OR v_email = '' THEN
    v_reason := 'invalid_identity';
  ELSIF v_name = '' OR length(v_name) > 120 THEN
    v_reason := 'invalid_name';
  ELSIF v_slug !~ '^[a-z0-9](?:[a-z0-9-]{1,38}[a-z0-9])$'
        OR v_slug LIKE 'ci-%' OR v_slug = 'matn-demo' THEN
    v_reason := 'invalid_slug';
  END IF;

  IF v_reason IS NOT NULL THEN
    INSERT INTO public.aud_audit_events (tenant_id, actor_type, actor_user_id, action, entity_type, outcome, metadata)
    VALUES (NULL, 'user', NULL, 'tenant.bootstrap', 'core_tenants', 'denied',
            jsonb_build_object('reason', v_reason));
    RETURN jsonb_build_object('status', 'rejected', 'reason', v_reason);
  END IF;

  -- Serialize every bootstrap attempt for the lifetime of this transaction.
  PERFORM pg_advisory_xact_lock(hashtext('matn:bootstrap_first_tenant_admin'));

  -- Re-check every precondition inside the lock.
  IF EXISTS (SELECT 1 FROM public.core_tenants WHERE is_demo = false) THEN
    v_reason := 'tenant_exists';
  ELSIF EXISTS (SELECT 1 FROM public.core_users WHERE auth_user_id = p_auth_user_id) THEN
    v_reason := 'already_member';
  ELSIF EXISTS (SELECT 1 FROM public.core_user_roles r
                JOIN public.core_tenants t ON t.id = r.tenant_id
                WHERE r.role = 'tenant_admin' AND r.revoked_at IS NULL AND t.is_demo = false) THEN
    v_reason := 'already_provisioned';
  END IF;

  IF v_reason IS NOT NULL THEN
    INSERT INTO public.aud_audit_events (tenant_id, actor_type, actor_user_id, action, entity_type, outcome, metadata)
    VALUES (NULL, 'user', NULL, 'tenant.bootstrap', 'core_tenants', 'denied',
            jsonb_build_object('reason', v_reason));
    RETURN jsonb_build_object('status', 'rejected', 'reason', v_reason);
  END IF;

  INSERT INTO public.core_tenants (name_en, name_ar, slug, is_demo, is_active)
  VALUES (v_name, v_name, v_slug, false, true)
  RETURNING id INTO v_tenant_id;

  INSERT INTO public.core_users (tenant_id, auth_user_id, email, display_name, is_active)
  VALUES (v_tenant_id, p_auth_user_id, v_email,
          coalesce(nullif(btrim(coalesce(p_display_name, '')), ''), split_part(v_email, '@', 1)), true)
  RETURNING id INTO v_user_id;

  INSERT INTO public.core_user_roles (tenant_id, user_id, role, granted_by_user_id)
  VALUES (v_tenant_id, v_user_id, 'tenant_admin', v_user_id);

  INSERT INTO public.aud_audit_events (tenant_id, actor_type, actor_user_id, action, entity_type, entity_id, outcome, metadata)
  VALUES (v_tenant_id, 'user', v_user_id, 'tenant.bootstrap', 'core_tenants', v_tenant_id, 'success',
          jsonb_build_object('slug', v_slug));

  RETURN jsonb_build_object('status', 'created', 'tenantId', v_tenant_id, 'tenantSlug', v_slug);
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('status', 'rejected', 'reason', 'tenant_exists');
END;
$$;

REVOKE ALL ON FUNCTION public.bootstrap_first_tenant_admin(uuid, text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_first_tenant_admin(uuid, text, text, text, text) TO service_role;

CREATE OR REPLACE FUNCTION public.real_tenant_exists()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$ SELECT EXISTS (SELECT 1 FROM public.core_tenants WHERE is_demo = false) $$;

REVOKE ALL ON FUNCTION public.real_tenant_exists() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.real_tenant_exists() TO authenticated, service_role;