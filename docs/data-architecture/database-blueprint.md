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

Conventions: PK `id uuid default gen_random_uuid()`; every customer table has `tenant_id uuid not null`; timestamps `timestamptz`; every FK is composite with `tenant_id`; every table gets `GRANT` statements alongside RLS in Phase 3.

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
| `core_iterations` | sprints | id | tenant, project, team | `(tenant_id, project_id, azure_iteration_id, team_id)` | team, dates | tenant+project | mutable | indefinite | 10²–10³ | Azure |
| `core_member_capacity` | capacity config | id | tenant, team, iteration, member | `(tenant_id, team_id, iteration_id, member_id)` | iteration | tenant+team | mutable | 3 years | 10⁴ | Azure |

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
| `an_daily_iteration_snapshots` | burndown/scope source | id | `(tenant_id, iteration_id, team_id, snapshot_date)` | date | append-only | 3 years | 10⁴ |
| `an_daily_team_snapshots` | team trend | id | `(tenant_id, team_id, snapshot_date)` | date | append-only | 3 years | 10⁴ |
| `an_daily_member_snapshots` | member load trend | id | `(tenant_id, member_id, team_id, snapshot_date)` | date | append-only | 18 months | 10⁵ |
| `an_kpi_definitions` | catalog (global, tenant-overridable thresholds) | id | `(tenant_id, kpi_id)` | — | mutable config | indefinite | 10² |
| `an_kpi_values` | computed values | id | `(tenant_id, kpi_id, scope_hash, valid_from)` | `(tenant_id, iteration_id, kpi_id, valid_from desc)` | append-only | 3 years | 10⁶ |

### intelligence, operations, audit

| Table | Purpose | PK | Unique | Mutability | Retention |
|---|---|---|---|---|---|
| `intel_risk_signals` | deterministic signals | id | `(tenant_id, rule_id, scope_hash, first_detected_at)` | mutable status, immutable evidence | 2 years |
| `intel_recommendations` | evidence-based advice | id | `(tenant_id, id)` | mutable status | 2 years |
| `intel_recommendation_decisions` | human decisions | id | `(tenant_id, recommendation_id, decided_at)` | **immutable** | indefinite |
| `intel_copilot_answers` | AI answers with citations | id | — | append-only | 180 days |
| `ops_sync_connections` | connection config, `secret_ref` only | id | `(tenant_id, organization_id)` | mutable | indefinite |
| `ops_sync_runs` | run log | id | — | append + finalize | 180 days |
| `ops_sync_cursors` | watermarks | id | `(tenant_id, connection_id, entity_kind, project_id)` | mutable | indefinite |
| `ops_data_quality_issues` | validation findings | id | `(tenant_id, rule_id, entity_kind, entity_id, field)` | mutable status | 1 year |
| `aud_audit_events` | security audit trail | id | — | **immutable** | 2 years |

Partitioning candidates once volume justifies it: `az_work_item_revisions`, `an_kpi_values`, `aud_audit_events` by month; `az_raw_payloads` by week with automatic drop.

## Non-negotiables for Phase 3 migrations

1. `CREATE TABLE` → `GRANT` → `ENABLE ROW LEVEL SECURITY` → `CREATE POLICY`, in that order, in the same migration.
2. Roles live in `core_user_roles` with a `has_role(user_id, role)` security-definer function; never on a profile table.
3. Every policy scopes by `tenant_id`; `anon` gets no grants on these tables.
4. Immutable tables get `UPDATE`/`DELETE` policies that deny everyone except `service_role`.
