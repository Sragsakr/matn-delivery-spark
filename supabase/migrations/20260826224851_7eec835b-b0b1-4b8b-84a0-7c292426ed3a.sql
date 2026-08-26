-- =====================================================================
-- Phase 3 migration 11 — audit events (append-only)
-- Rollback: DROP TABLE aud_audit_events CASCADE;
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.aud_audit_events (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  actor_type       public.actor_type NOT NULL DEFAULT 'system',
  actor_user_id    uuid,
  action           text NOT NULL,
  entity_type      text NOT NULL,
  entity_id        uuid,
  correlation_id   uuid NOT NULL DEFAULT gen_random_uuid(),
  idempotency_key  text,
  outcome          public.audit_outcome NOT NULL DEFAULT 'success',
  metadata         jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT aud_audit_events_actor_fk FOREIGN KEY (tenant_id, actor_user_id)
    REFERENCES public.core_users (tenant_id, id),
  -- defence in depth: never store credentials in audit metadata
  CONSTRAINT aud_audit_events_metadata_no_secrets CHECK (
    NOT (metadata ?| ARRAY['token','access_token','refresh_token','password',
                           'secret','pat','authorization','api_key']))
);
CREATE INDEX IF NOT EXISTS aud_audit_events_tenant_time_idx
  ON public.aud_audit_events (tenant_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS aud_audit_events_entity_idx
  ON public.aud_audit_events (tenant_id, entity_type, entity_id);
CREATE INDEX IF NOT EXISTS aud_audit_events_correlation_idx
  ON public.aud_audit_events (correlation_id);

DROP TRIGGER IF EXISTS append_only ON public.aud_audit_events;
CREATE TRIGGER append_only BEFORE UPDATE OR DELETE ON public.aud_audit_events
  FOR EACH ROW EXECUTE FUNCTION public.tg_append_only();

GRANT SELECT ON public.aud_audit_events TO authenticated;
GRANT SELECT, INSERT ON public.aud_audit_events TO service_role;
ALTER TABLE public.aud_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aud_audit_events FORCE ROW LEVEL SECURITY;