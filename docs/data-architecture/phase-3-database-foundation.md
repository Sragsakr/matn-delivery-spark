# Phase 3 — Database foundation (applied)

The Lovable Cloud database provisioned for this project holds the full Phase 2.2
schema. No external database, no credentials, no Azure DevOps integration, no
sync jobs, no cron routes. The application remains in explicit mock mode.

## Migration order and rollback strategy

Migrations are timestamped and applied in filename order; each is a single
transaction and is re-runnable where meaningful (`IF NOT EXISTS`,
`ON CONFLICT DO NOTHING`).

| # | Contents |
| --- | --- |
| 01 | Extensions (`pgcrypto`, `citext`) and shared enums |
| 02 | Immutability triggers, `core_tenants`, `core_users`, retention settings |
| 03 | Organizations, projects, teams, iterations, team iterations, members, capacity, process mappings |
| 04 | Roles and authorization scopes |
| 05 | Azure normalized current state |
| 06 | Azure immutable history (revisions, transitions, scope changes, raw payloads) |
| 07 | Engineering tables (repositories, PRs, pipelines, builds, environments, deployments, tests) |
| 08 | Analytics: KPI catalog, overrides, values, daily snapshots |
| 09 | Intelligence: risk signals, recommendations, decisions, copilot answers |
| 10 | Operations: connections, runs, cursors, locks, nonces, snapshot jobs, data quality |
| 11 | `aud_audit_events` (append-only) |
| 12 | Helper functions and privileged scope-grant functions |
| 13 | Grants and RLS policies |
| 14 | Global KPI catalog seed and development demo seed |

### Extensions and justification

- `pgcrypto` — `gen_random_uuid()` for primary keys, and digests for risk-signal
  fingerprints and KPI scope hashes.
- `citext` — case-insensitive identity fields (user email, Azure descriptors),
  so `A@x` and `a@x` cannot coexist.

Nothing else is enabled.

### Rollback

Forward-only, documented per layer; dropping a layer discards data.

1. **Seed (14)** — `SELECT public.remove_demo_tenant();` plus
   `DELETE FROM public.an_kpi_definitions WHERE calculation_version = 1;`
2. **Policies and grants (13)** — re-apply a corrected migration; never leave a
   tenant table with RLS disabled between steps.
3. **Functions (12)** — `CREATE OR REPLACE` in a new migration; drop only when
   no policy references the function.
4. **Tables (03–11)** — drop in reverse dependency order, tables listed
   explicitly (no blanket `CASCADE` in production).
5. **Enums and extensions (01–02)** — last, and only when unused.

Immutable data (revisions, finalized snapshots, audit events) is never rewritten
by a rollback; correct it with a new append-only record.

## Immutability mechanism per table

| Table | Mechanism |
| --- | --- |
| `az_work_item_revisions`, `az_work_item_transitions`, `az_work_item_scope_changes`, `az_raw_payloads` | `tg_append_only` BEFORE UPDATE/DELETE trigger; no UPDATE/DELETE policy for `authenticated` |
| `an_daily_*_snapshots` | `tg_block_update_when_finalized` — rows are freely rewritten until `finalized_at` is set, immutable afterwards |
| `aud_audit_events`, `intel_recommendation_decisions` | append-only trigger, INSERT-only grants |
| every tenant-owned table | `tg_prevent_column_change` guards `tenant_id`; project-owned children also guard `project_id` |
| Azure natural identity (`azure_*_id`) | guarded by the same column-change trigger after first insert |

A CHECK constraint cannot compare OLD and NEW, so none is used for these rules.

## Authorization

Roles live only in `core_user_roles`. Scope grants live in
`core_user_project_scopes` / `core_user_team_scopes` and are active only when

```
revoked_at IS NULL AND (expires_at IS NULL OR expires_at > now())
```

Helper functions — `current_core_user_id()`, `current_tenant_id()`,
`has_role()`, `has_tenant_access()`, `has_full_tenant_access()`,
`has_project_access()`, `has_team_access()`, `can_view_member_detail()` — are
`SECURITY DEFINER STABLE` with a pinned empty `search_path` and fully qualified
references. They are executable by `authenticated` because RLS policies call
them as the requesting user; they take no privileged input and return only
booleans or the caller's own identity.

`grant_project_scope()` / `grant_team_scope()` and the seed helpers are
`REVOKE`d from `PUBLIC`, `anon` and `authenticated`, and `GRANT`ed only to
`service_role`. A future tenant-admin UI must call a server function that
verifies the caller, then invokes these; the browser never reaches them.

## Seeding and tenant bootstrap

`seed_demo_tenant()` refuses to run when any non-demo tenant exists, so
production stays empty. It creates one obviously fake tenant (`matn-demo`) with
one organization, one project, one team, one sprint, one team sprint, two demo
people, retention defaults and three placeholder users on `example.invalid`
addresses with documented fake auth uuids. No real employee data, no Azure ids.

**First real tenant admin:** provisioned out-of-band by the platform operator —
create the tenant row and the `core_users` row for the invited person's real
`auth.users` id, then insert the single `tenant_admin` role row through the
service role. Sign-up alone never yields a role, and no policy lets a user
insert their own role or scope.

## Retention and legal holds

`core_tenant_retention_settings` holds per-tenant rule keys with a configurable
`retention_days` and an enforced `minimum_days` floor. `core_tenants.legal_hold`
and per-record hold flags exist so future purge logic can skip held tenants and
records. Phase 3 deletes nothing.

## Test results

All six suites in `supabase/tests/` pass: tenant isolation, same-project
integrity (23503 / 23514 as specified), roles and RLS, scope-grant lifecycle,
immutability, and schema invariants (34 KPI definitions seeded).

## Remaining Phase 4 decisions

- Where the Azure sync worker runs and how the connection secret is referenced
  (`ops_sync_connections.secret_ref` is a pointer only).
- Snapshot job scheduling and the signed cron boundary (tables exist, no route).
- Mapper implementations behind `src/data/mappers/` and the switch from mock to
  live dashboard reads.
- Concurrency verification for grant functions under real parallel sessions.
