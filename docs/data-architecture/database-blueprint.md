# Database Blueprint (Proposal Only)

No migrations, tables or SQL are created in this phase. This is the reviewed target for Phase 3.

## Schema strategy

Conceptual separation:

| Schema | Contents |
|---|---|
| `core` | tenants, organizations, projects, teams, members, memberships, iterations, process mappings |
| `azure` | raw cached payloads and identity mapping tables |
| `analytics` | snapshots, KPI values, flow metrics |
| `intelligence` | risk signals, recommendations, decisions, copilot answers |
| `operations` | sync connections, runs, cursors, data-quality issues |
| `audit` | audit events |

**Recommended for Supabase:** because PostgREST exposure, generated types and grants are simplest on a single schema, ship everything in `public` with **table-name prefixes** (`core_`, `az_`, `an_`, `intel_`, `ops_`, `aud_`) and keep the schema names above as a documentation-level grouping. Multiple exposed schemas add per-schema grants, extra `db-schema` configuration and noisier generated types for no security gain — RLS provides the isolation either way. Table names below use the prefixed form.

## Tables

Conventions: PK `id uuid default gen_random_uuid()`; every customer table has `tenant_id uuid not null`; timestamps `timestamptz`; **every tenant-owned parent table also declares `UNIQUE (tenant_id, id)`** so composite foreign keys have a matching candidate key; every FK between tenant-owned tables is composite with `tenant_id`; every table gets `GRANT` statements alongside RLS in Phase 3. Azure-sourced tables additionally carry the source-lifecycle columns `source_status`, `is_deleted`, `deleted_at_source`, `last_seen_at`, `access_revoked_at`.

### core

| Table | Purpose | PK | FKs | Unique | Indexes | Tenant boundary | Mutability | Retention | Volume (per tenant) | Source of truth |
|---|---|---|---|---|---|---|---|---|---|---|
| `core_tenants` | customer boundary | id | — | `slug` | — | self | mutable | indefinite | 1s | MATN |
| `core_users` | app users ↔ tenant | id | tenant | `(tenant_id, auth_user_id)` | auth_user_id | tenant | mutable | indefinite | 10²–10³ | MATN/auth |
| `core_user_roles` | role assignment (separate table, never on profiles) | id | tenant, user | `(tenant_id, user_id, role)` | user_id | tenant | mutable | indefinite | 10²–10³ | MATN |
| `core_organizations` | Azure orgs | id | tenant | `(tenant_id, azure_organization_name)` | tenant | tenant | mutable | indefinite | 1–10 | Azure |
| `core_projects` | Azure projects | id | tenant, org | `(tenant_id, organization_id, azure_project_id)` | org | tenant+org | mutable | indefinite | 10–10² | Azure |
| `core_process_mappings` | normalization config | id | tenant, project | `(tenant_id, project_id, team_id)` | project | tenant+project | mutable | indefinite | 10–10² | MATN |
| `core_teams` | Azure teams | id | tenant, project | `(tenant_id, project_id, azure_team_id)` | project | tenant+project | mutable | indefinite | 10²  | Azure |
| `core_members` | identities | id | tenant, org | `(tenant_id, organization_id, azure_descriptor)` | org | tenant+org | mutable | indefinite | 10²–10³ | Azure |
| `core_team_memberships` | membership history | id | tenant, team, member | `(tenant_id, team_id, member_id, joined_at)` | team, member | tenant+team | append + close | indefinite | 10³ | Azure |
| `core_iterations` | Azure iteration **nodes**, project-owned, never duplicated per team | id | tenant, org, project | `(tenant_id, id)`, `(tenant_id, project_id, azure_iteration_id)` | `(tenant_id, project_id, start_date)` | tenant+project | mutable | indefinite | 10²–10³ | Azure |
| `core_team_iterations` | a team's subscription + team-specific settings | id | tenant, team, iteration | `(tenant_id, id)`, `(tenant_id, team_id, iteration_id)`, partial `(tenant_id, team_id) WHERE is_current` | `(tenant_id, iteration_id)`, `selected_for_sync` | tenant+team | mutable | indefinite | 10³ | Azure + MATN |
| `core_member_capacity` | capacity config | id | tenant, team_iteration, member | `(tenant_id, id)`, `(tenant_id, team_iteration_id, member_id)` | team_iteration | tenant+team | mutable | 3 years | 10⁴ | Azure |
| `core_user_project_scopes` | explicit project grants | id | tenant, user, project, granted_by user | `(tenant_id, id)`, partial `(tenant_id, user_id, project_id) WHERE revoked_at IS NULL` | user | tenant | mutable | indefinite | 10³ | MATN |
| `core_user_team_scopes` | explicit team grants | id | tenant, user, team, granted_by user | `(tenant_id, id)`, partial `(tenant_id, user_id, team_id) WHERE revoked_at IS NULL` | user | tenant | mutable | indefinite | 10³ | MATN |

### azure + delivery data

| Table | Purpose | PK | FKs | Unique | Indexes | Mutability | Retention | Volume | Source |
|---|---|---|---|---|---|---|---|---|---|
| `az_work_items` | normalized current state | id | tenant, project, iteration, team, assignee | `(tenant_id, organization_id, azure_work_item_id)` | `(tenant_id, iteration_id, state_category)`, `(tenant_id, project_id, changed_at_source)`, `parent_work_item_id`, GIN on `tags`, GIN on `custom_fields` | mutable | indefinite | 10⁵–10⁶ | Azure |
| `az_work_item_relations` | typed links | id | tenant, work item | `(tenant_id, source_work_item_id, azure_relation_name, target_azure_work_item_id)` | target | mutable | indefinite | 10⁵ | Azure |
| `az_work_item_revisions` | immutable revisions | id | tenant, work item | `(tenant_id, work_item_id, rev)` | `(tenant_id, work_item_id, revised_at)` | **immutable** | ≥ 3 years | 10⁶–10⁷ | Azure |
| `az_work_item_transitions` | derived state changes | id | tenant, work item | `(tenant_id, work_item_id, occurred_at, to_state)` | `(tenant_id, work_item_id)` | **immutable** | ≥ 3 years | 10⁶ | derived |
| `az_work_item_scope_changes` | scope in/out events | id | tenant, work item, iteration | `(tenant_id, work_item_id, iteration_id, occurred_at, change_type)` | iteration | **immutable** | ≥ 3 years | 10⁵ | derived |
| `az_repositories` | git repos | id | tenant, project | `(tenant_id, project_id, azure_repository_id)` | project | mutable | indefinite | 10² | Azure |
| `az_pull_requests` | PRs | id | tenant, repo | `(tenant_id, organization_id, azure_pull_request_id)` | `(tenant_id, status, last_activity_at)` | mutable until completed | 2 years | 10⁴–10⁵ | Azure |
| `az_pull_request_reviews` | reviewer votes | id | tenant, PR, member | `(tenant_id, pull_request_id, reviewer_member_id)` | PR | mutable | 2 years | 10⁵ | Azure |
| `az_pipelines` | definitions | id | tenant, project | `(tenant_id, project_id, azure_pipeline_id)` | project | mutable | indefinite | 10² | Azure |
| `az_builds` | runs | id | tenant, pipeline | `(tenant_id, project_id, azure_build_id)` | `(tenant_id, pipeline_id, finished_at)` | immutable once completed | 1 year | 10⁵ | Azure |
| `az_environments` | deploy targets | id | tenant, project | `(tenant_id, project_id, name)` | project | mutable | indefinite | 10¹ | Azure |
| `az_deployments` | deploy attempts | id | tenant, env, build | `(tenant_id, project_id, azure_deployment_id, attempt)` | `(tenant_id, environment_id, finished_at)` | immutable once finished | 2 years | 10⁴ | Azure |
| `az_test_runs` | runs | id | tenant, build/deployment | `(tenant_id, project_id, azure_test_run_id)` | `(tenant_id, completed_at)` | mutable until completed | 1 year | 10⁴ | Azure |
| `az_test_result_summaries` | aggregates | id | tenant, test run | `(tenant_id, test_run_id)` | run | calculated | 1 year | 10⁴ | derived |
| `az_raw_payloads` | optional raw cache for replay | id | tenant | `(tenant_id, entity_kind, azure_id, rev)` | fetched_at | append-only | 30 days | 10⁶ | Azure |

### analytics

| Table | Purpose | PK | Unique | Indexes | Mutability | Retention | Volume |
|---|---|---|---|---|---|---|---|
| `an_daily_project_snapshots` | project trend | id | `(tenant_id, project_id, snapshot_date)` | date | append-only | 3 years | 10⁴ |
| `an_daily_iteration_snapshots` | burndown/scope source, one row per **team iteration** per day | id | `(tenant_id, team_iteration_id, snapshot_date)` | date, `(tenant_id, iteration_id)` | append-only | 3 years | 10⁴ |
| `an_daily_team_snapshots` | team trend | id | `(tenant_id, team_id, snapshot_date)` | date | append-only | 3 years | 10⁴ |
| `an_daily_member_snapshots` | member load trend | id | `(tenant_id, member_id, team_id, snapshot_date)` | date | append-only | 18 months | 10⁵ |
| `an_kpi_definitions` | **global** catalog: identity, formula, defaults. No `tenant_id`. | id | `kpi_id` (globally unique), `(kpi_id, calculation_version)` | — | immutable per version | indefinite | 10² |
| `an_kpi_configuration_overrides` | tenant/project/team thresholds, weights, enablement | id | `(tenant_id, id)`, functional unique `(tenant_id, kpi_definition_id, COALESCE(project_id,'…'), COALESCE(team_id,'…'), effective_from)` | `(tenant_id, kpi_id, effective_from desc)` | mutable config, versioned by `effective_from/to` | indefinite | 10³ |
| `an_kpi_values` | computed values (+ `resolved_configuration` jsonb, `configuration_version`) | id | `(tenant_id, kpi_id, scope_hash, valid_from)` | `(tenant_id, team_iteration_id, kpi_id, valid_from desc)` | append-only | 3 years | 10⁶ |

### intelligence, operations, audit

| Table | Purpose | PK | Unique | Mutability | Retention |
|---|---|---|---|---|---|
| `intel_risk_signals` | deterministic signals | id | `(tenant_id, rule_id, scope_hash, first_detected_at)` | mutable status, immutable evidence | 2 years |
| `intel_recommendations` | evidence-based advice | id | `(tenant_id, id)` | mutable status | 2 years |
| `intel_recommendation_decisions` | human decisions | id | `(tenant_id, recommendation_id, decided_at)` | **immutable** | indefinite |
| `intel_copilot_answers` | AI answers with citations | id | — | append-only | 180 days |
| `ops_sync_connections` | connection config, `secret_ref` only | id | `(tenant_id, organization_id)` | mutable | indefinite |
| `ops_sync_runs` | run log | id | — | append + finalize | 180 days |
| `ops_sync_cursors` | watermarks | id | `(tenant_id, connection_id, entity_kind, project_id)` **`NULLS NOT DISTINCT`** | mutable | indefinite |
| `ops_sync_locks` | one active run per organization | id | partial `(tenant_id, organization_id) WHERE released_at IS NULL` | mutable | 30 days |
| `ops_cron_nonces` | replay protection for signed triggers | id | `(nonce)`, `(tenant_id, idempotency_key)` | append-only | 7 days |
| `ops_snapshot_job_runs` | snapshot idempotency + finalization state | id | `(tenant_id, team_id, logical_date)` | append + finalize | 1 year |
| `ops_data_quality_issues` | validation findings | id | `(tenant_id, rule_id, entity_kind, entity_id, field)` | mutable status | 1 year |
| `aud_audit_events` | security audit trail | id | — | **immutable** | 2 years |

Partitioning candidates once volume justifies it: `az_work_item_revisions`, `an_kpi_values`, `aud_audit_events` by month; `az_raw_payloads` by week with automatic drop.

## Non-negotiables for Phase 3 migrations

1. `CREATE TABLE` → `GRANT` → `ENABLE ROW LEVEL SECURITY` → `CREATE POLICY`, in that order, in the same migration.
2. Roles live in `core_user_roles` with a `has_role(user_id, role)` security-definer function; never on a profile table.
3. Every policy scopes by `tenant_id`; `anon` gets no grants on these tables.
4. Immutable tables get `UPDATE`/`DELETE` policies that deny everyone except `service_role`.


## Composite tenant integrity rules (Phase 2.1)

Every tenant-owned parent table declares a redundant candidate key so children can reference it together with the tenant:

```sql
ALTER TABLE public.core_projects ADD CONSTRAINT core_projects_tenant_id_key UNIQUE (tenant_id, id);
```

Children then reference the composite key, in matching column order and types:

```sql
-- core_teams
FOREIGN KEY (tenant_id, project_id) REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE
-- core_iterations
FOREIGN KEY (tenant_id, organization_id) REFERENCES public.core_organizations (tenant_id, id)
FOREIGN KEY (tenant_id, project_id)      REFERENCES public.core_projects      (tenant_id, id)
-- core_team_iterations
FOREIGN KEY (tenant_id, team_id)      REFERENCES public.core_teams      (tenant_id, id) ON DELETE CASCADE
FOREIGN KEY (tenant_id, iteration_id) REFERENCES public.core_iterations (tenant_id, id) ON DELETE CASCADE
-- core_member_capacity
FOREIGN KEY (tenant_id, team_iteration_id) REFERENCES public.core_team_iterations (tenant_id, id) ON DELETE CASCADE
FOREIGN KEY (tenant_id, member_id)         REFERENCES public.core_members         (tenant_id, id)
-- core_user_project_scopes / core_user_team_scopes
FOREIGN KEY (tenant_id, user_id)            REFERENCES public.core_users (tenant_id, id) ON DELETE CASCADE
FOREIGN KEY (tenant_id, granted_by_user_id) REFERENCES public.core_users (tenant_id, id)
FOREIGN KEY (tenant_id, project_id)         REFERENCES public.core_projects (tenant_id, id) ON DELETE CASCADE
FOREIGN KEY (tenant_id, team_id)            REFERENCES public.core_teams    (tenant_id, id) ON DELETE CASCADE
-- az_work_items
FOREIGN KEY (tenant_id, project_id)   REFERENCES public.core_projects   (tenant_id, id)
FOREIGN KEY (tenant_id, iteration_id) REFERENCES public.core_iterations (tenant_id, id)
FOREIGN KEY (tenant_id, team_id)      REFERENCES public.core_teams      (tenant_id, id)
-- an_kpi_values / an_daily_* / intel_* / ops_* follow the same pattern
-- an_kpi_configuration_overrides
FOREIGN KEY (kpi_definition_id) REFERENCES public.an_kpi_definitions (id)   -- global table, no tenant column
```

### Migration rule (binding for Phase 3)

1. No tenant-owned child may reference a parent by `id` alone.
2. Every tenant-owned relationship includes `tenant_id` in the foreign key.
3. `tenant_id` is `NOT NULL` on child and parent, so a cross-tenant row is structurally impossible — the database rejects it before RLS is consulted.
4. Foreign-key columns use matching order (`tenant_id` first) and matching types (`uuid`).
5. A child's `tenant_id` is never updatable (`ON UPDATE RESTRICT` plus a trigger-free `CHECK` on immutability via policy).
6. The only non-tenant-scoped tables are `core_tenants` and `an_kpi_definitions`; both are explicitly listed and reviewed.

### Acceptance tests (constraint-level, not RLS-level)

Run as `service_role` with RLS bypassed, so the failure proves the constraint:

| Test | Statement | Expected |
|---|---|---|
| Cross-tenant team | insert `core_teams` with tenant A and a project of tenant B | `23503 foreign_key_violation` |
| Cross-tenant team iteration | insert `core_team_iterations` with team of tenant A and iteration of tenant B | `23503` |
| Cross-tenant capacity | insert `core_member_capacity` with member of tenant B | `23503` |
| Cross-tenant work item | insert `az_work_items` with iteration of tenant B | `23503` |
| Cross-tenant scope grant | insert `core_user_project_scopes` with user A / project B | `23503` |
| Tenant re-parenting | `UPDATE core_teams SET tenant_id = <other>` | `23503` |
| Missing candidate key | `SELECT` every composite FK from `pg_constraint` and assert a matching `UNIQUE (tenant_id, id)` exists on the referenced table | zero unmatched |

The last row is a schema-wide invariant test, not a per-table test; it runs in CI on every migration.

## Nullable unique constraints — explicit decisions

| Table | Constraint | Nullable part | Decision | Rationale |
|---|---|---|---|---|
| `core_process_mappings` | `(tenant_id, project_id, team_id)` | `team_id` (null = project default) | **Partial unique indexes** — `(tenant_id, project_id) WHERE team_id IS NULL` plus `(tenant_id, project_id, team_id) WHERE team_id IS NOT NULL` | Keeps exactly one project default and one override per team; intent is readable in the index name |
| `an_kpi_configuration_overrides` | scope + effective window | `project_id`, `team_id` | **Functional unique index using COALESCE** over both columns plus `effective_from` | Two nullable dimensions; COALESCE to a fixed sentinel uuid keeps one index instead of four partials |
| `an_kpi_values` | `(tenant_id, kpi_id, scope_hash, valid_from)` | scope columns | **Functional key**: `scope_hash` is a generated column hashing COALESCE'd scope ids | Avoids nullable comparison entirely |
| `intel_recommendations`, `intel_risk_signals` | `(tenant_id, rule_id, scope_hash, first_detected_at)` | `team_id`, `iteration_id` | **Functional `scope_hash`** as above | Same reasoning; signals must dedupe across nullable scopes |
| `ops_sync_cursors` | `(tenant_id, connection_id, entity_kind, project_id)` | `project_id` (null = org-wide cursor) | **`NULLS NOT DISTINCT`** (PostgreSQL 15+) | One org-wide cursor per entity kind must collide with itself; simplest correct semantics |
| `ops_data_quality_issues` | `(tenant_id, rule_id, entity_kind, entity_id, field)` | `entity_id`, `field` | **`NULLS NOT DISTINCT`** | Run-level issues with no entity must dedupe rather than accumulate duplicates |
| `core_team_iterations` | one current sprint per team | `is_current` | **Partial unique index** `WHERE is_current` | Boolean flag, not nullable column, but same family of decision |

Rule for Phase 3: a `UNIQUE` constraint that contains a nullable column and has no recorded decision above fails review.

## Retention defaults (tenant-configurable)

| Data | Default | Minimum enforced |
|---|---|---|
| Work-item revisions | 3 years | 3 years |
| Daily project / team / iteration snapshots | 3 years | 3 years |
| Daily member snapshots | 18 months | 12 months |
| Raw payload cache (`az_raw_payloads`) | 30 days | 7 days |
| Sync run details (`ops_sync_runs`) | 180 days | 30 days |
| Audit events | 2 years | 2 years |
| Copilot answers | 180 days | 30 days |

Retention is stored per tenant (`core_tenant_retention_settings`, one row per `RetentionRule.key`) and applied by a scheduled purge job. **No purge may remove a record under legal hold**: rows carrying `legal_hold = true`, or belonging to a tenant with an active hold, are skipped and the skip is audited.
