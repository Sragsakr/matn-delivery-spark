-- Phase 5A security corrections (forward-only)

-- 1. Remove unused dblink dependency
DROP EXTENSION IF EXISTS dblink;

-- 2. Explicit user -> member relationship (replaces email matching)
ALTER TABLE public.core_users ADD COLUMN IF NOT EXISTS member_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'core_users_member_tenant_fkey' AND conrelid = 'public.core_users'::regclass
  ) THEN
    ALTER TABLE public.core_users
      ADD CONSTRAINT core_users_member_tenant_fkey
      FOREIGN KEY (tenant_id, member_id)
      REFERENCES public.core_members (tenant_id, id)
      ON DELETE SET NULL (member_id);
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS core_users_tenant_member_key
  ON public.core_users (tenant_id, member_id) WHERE member_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.is_own_member_record(target_tenant_id uuid, target_member_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.core_users u
    WHERE u.auth_user_id = (SELECT auth.uid())
      AND u.is_active
      AND u.tenant_id = target_tenant_id
      AND u.member_id IS NOT NULL
      AND u.member_id = target_member_id
  );
$function$;

-- 3. One active foundation sync lock per tenant + organization
CREATE UNIQUE INDEX IF NOT EXISTS ops_sync_locks_active_key
  ON public.ops_sync_locks (tenant_id, organization_id) WHERE released_at IS NULL;