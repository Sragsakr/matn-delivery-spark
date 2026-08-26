-- =====================================================================
-- Phase 3 migration 09 — intelligence tables
-- Rollback: DROP TABLE intel_* CASCADE;
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.intel_risk_signals (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  rule_id            text NOT NULL,
  rule_version       integer NOT NULL DEFAULT 1,
  project_id         uuid,
  team_id            uuid,
  team_iteration_id  uuid,
  work_item_id       uuid,
  scope_hash         text GENERATED ALWAYS AS (
    encode(extensions.digest(
      'v1|' || tenant_id::text
        || '|' || COALESCE(project_id::text, '00000000-0000-0000-0000-000000000000')
        || '|' || COALESCE(team_id::text, '00000000-0000-0000-0000-000000000000')
        || '|' || COALESCE(team_iteration_id::text, '00000000-0000-0000-0000-000000000000')
        || '|' || COALESCE(work_item_id::text, '00000000-0000-0000-0000-000000000000')
        || '|' || rule_id, 'sha256'), 'hex')
  ) STORED,
  severity           public.severity_level NOT NULL DEFAULT 'medium',
  status             public.risk_status NOT NULL DEFAULT 'open',
  origin             public.content_origin NOT NULL DEFAULT 'deterministic',
  title_en           text NOT NULL,
  title_ar           text NOT NULL,
  detail_en          text,
  detail_ar          text,
  evidence           jsonb NOT NULL DEFAULT '{}'::jsonb,
  first_detected_at  timestamptz NOT NULL DEFAULT now(),
  last_detected_at   timestamptz NOT NULL DEFAULT now(),
  resolved_at        timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT intel_risk_signals_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT intel_risk_signals_natural_key UNIQUE (tenant_id, rule_id, scope_hash, first_detected_at),
  CONSTRAINT intel_risk_signals_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT intel_risk_signals_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT intel_risk_signals_ti_fk FOREIGN KEY (tenant_id, project_id, team_iteration_id)
    REFERENCES public.core_team_iterations (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT intel_risk_signals_work_item_fk FOREIGN KEY (tenant_id, work_item_id)
    REFERENCES public.az_work_items (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT intel_risk_signals_scope_requires_project
    CHECK ((team_id IS NULL AND team_iteration_id IS NULL) OR project_id IS NOT NULL),
  -- risk signals are deterministic; AI text is not allowed here
  CONSTRAINT intel_risk_signals_deterministic CHECK (origin = 'deterministic')
);
CREATE INDEX IF NOT EXISTS intel_risk_signals_open_idx
  ON public.intel_risk_signals (tenant_id, status, severity);

CREATE TABLE IF NOT EXISTS public.intel_recommendations (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  project_id         uuid,
  team_id            uuid,
  team_iteration_id  uuid,
  risk_signal_id     uuid,
  rule_id            text,
  origin             public.content_origin NOT NULL DEFAULT 'deterministic',
  model_name         text,
  title_en           text NOT NULL,
  title_ar           text NOT NULL,
  body_en            text,
  body_ar            text,
  expected_impact    text,
  effort             text CHECK (effort IN ('low','medium','high')),
  priority           integer NOT NULL DEFAULT 3,
  status             public.recommendation_status NOT NULL DEFAULT 'proposed',
  evidence_refs      jsonb NOT NULL DEFAULT '[]'::jsonb,
  valid_until        timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT intel_recommendations_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT intel_recommendations_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT intel_recommendations_team_fk FOREIGN KEY (tenant_id, project_id, team_id)
    REFERENCES public.core_teams (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT intel_recommendations_ti_fk FOREIGN KEY (tenant_id, project_id, team_iteration_id)
    REFERENCES public.core_team_iterations (tenant_id, project_id, id) ON DELETE CASCADE,
  CONSTRAINT intel_recommendations_signal_fk FOREIGN KEY (tenant_id, risk_signal_id)
    REFERENCES public.intel_risk_signals (tenant_id, id) ON DELETE SET NULL,
  CONSTRAINT intel_recommendations_ai_labeled
    CHECK (origin <> 'ai_generated' OR model_name IS NOT NULL),
  CONSTRAINT intel_recommendations_scope_requires_project
    CHECK ((team_id IS NULL AND team_iteration_id IS NULL) OR project_id IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS intel_recommendations_status_idx
  ON public.intel_recommendations (tenant_id, status, priority);

CREATE TABLE IF NOT EXISTS public.intel_recommendation_decisions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  recommendation_id   uuid NOT NULL,
  decided_by_user_id  uuid,
  decision            public.recommendation_status NOT NULL,
  rationale           text,
  decided_at          timestamptz NOT NULL DEFAULT now(),
  created_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT intel_recommendation_decisions_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT intel_recommendation_decisions_natural_key
    UNIQUE (tenant_id, recommendation_id, decided_at),
  CONSTRAINT intel_recommendation_decisions_rec_fk FOREIGN KEY (tenant_id, recommendation_id)
    REFERENCES public.intel_recommendations (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT intel_recommendation_decisions_user_fk FOREIGN KEY (tenant_id, decided_by_user_id)
    REFERENCES public.core_users (tenant_id, id)
);

CREATE TABLE IF NOT EXISTS public.intel_copilot_answers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES public.core_tenants (id) ON DELETE CASCADE,
  asked_by_user_id uuid,
  project_id      uuid,
  team_iteration_id uuid,
  question        text NOT NULL,
  answer          text NOT NULL,
  origin          public.content_origin NOT NULL DEFAULT 'ai_generated',
  model_name      text NOT NULL,
  citations       jsonb NOT NULL DEFAULT '[]'::jsonb,
  locale          text NOT NULL DEFAULT 'ar' CHECK (locale IN ('ar','en')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT intel_copilot_answers_tenant_id_key UNIQUE (tenant_id, id),
  CONSTRAINT intel_copilot_answers_user_fk FOREIGN KEY (tenant_id, asked_by_user_id)
    REFERENCES public.core_users (tenant_id, id) ON DELETE SET NULL,
  CONSTRAINT intel_copilot_answers_project_fk FOREIGN KEY (tenant_id, project_id)
    REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE,
  CONSTRAINT intel_copilot_answers_ai_labeled CHECK (origin = 'ai_generated')
);

-- append-only: decisions and copilot answers
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['intel_recommendation_decisions','intel_copilot_answers'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS append_only ON public.%I', t);
    EXECUTE format('CREATE TRIGGER append_only BEFORE UPDATE OR DELETE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_append_only()', t);
  END LOOP;

  FOREACH t IN ARRAY ARRAY['intel_risk_signals','intel_recommendations'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_updated_at ON public.%I', t);
    EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at()', t);
    EXECUTE format('DROP TRIGGER IF EXISTS immutable_identity ON public.%I', t);
    EXECUTE format('CREATE TRIGGER immutable_identity BEFORE UPDATE ON public.%I
      FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change(
        ''tenant_id'',''project_id'',''team_id'',''team_iteration_id'')', t);
  END LOOP;
END $$;
-- evidence on a risk signal is immutable once written
DROP TRIGGER IF EXISTS immutable_evidence ON public.intel_risk_signals;
CREATE TRIGGER immutable_evidence BEFORE UPDATE ON public.intel_risk_signals
  FOR EACH ROW EXECUTE FUNCTION public.tg_prevent_column_change(
    'rule_id','rule_version','evidence','first_detected_at');

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'intel_risk_signals','intel_recommendations',
    'intel_recommendation_decisions','intel_copilot_answers'
  ] LOOP
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
  EXECUTE 'REVOKE UPDATE, DELETE ON public.intel_recommendation_decisions FROM service_role';
  EXECUTE 'REVOKE UPDATE, DELETE ON public.intel_copilot_answers FROM service_role';
END $$;