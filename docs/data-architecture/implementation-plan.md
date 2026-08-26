# Implementation Plan

Phase 2 stops at specification. Nothing below is executed until a human approves it.

## Architecture Decision Records

### ADR-001: Lovable React frontend (TanStack Start)
- **Context**: An executive command center needs bilingual RTL/LTR rendering, SSR-friendly SEO, and fast iteration with a small team.
- **Decision**: Keep the approved Phase 1 TanStack Start + React + Tailwind frontend as the single client.
- **Consequences**: One deployment target, server functions available for backend logic, no separate BFF; Phase 1 visual work is preserved unchanged.
- **Alternatives**: Power BI embedded (weak Arabic RTL and custom UX), Next.js rewrite (no benefit, loses approved work), native mobile (out of scope).

### ADR-002: Supabase PostgreSQL as the analytics store
- **Context**: We need relational integrity, time-series snapshots, row-level tenant isolation and generated types.
- **Decision**: Store all normalized, historical and calculated data in Supabase PostgreSQL with RLS.
- **Consequences**: Strong constraints and SQL-based KPI computation; volume management (partitioning) needed for revisions and KPI values.
- **Alternatives**: Direct Azure Analytics OData queries (no history control, throttling, no cross-source joins), a document store (weak relational integrity), a data warehouse (overkill for the first release).

### ADR-003: Server-side integration layer for Azure DevOps
- **Context**: PATs and OAuth tokens must never reach the browser; syncs are long-running and scheduled.
- **Decision**: Run all Azure DevOps access server-side. On this TanStack Start stack that means `createServerFn` for app-internal calls and server routes under `src/routes/api/public/*` for scheduled/cron triggers — no Supabase Edge Functions.
- **Consequences**: Secrets stay in backend configuration; scheduling uses pg_cron calling an authenticated public route; workers must respect Worker runtime limits (bounded batch sizes, resumable runs).
- **Alternatives**: Client-side calls (unacceptable, leaks credentials), Supabase Edge Functions (not used on this stack), a separate container service (extra operations for no current benefit).

### ADR-004: REST API before runtime MCP
- **Context**: Azure DevOps offers a stable REST surface; MCP-based agent access is attractive but immature for scheduled bulk sync.
- **Decision**: Use REST (api-version 7.1) for all synchronization in this release; revisit MCP later for interactive copilot queries only.
- **Consequences**: Predictable pagination, throttling and error handling; MCP can be added later on top of the same normalized store.
- **Alternatives**: MCP-first (unproven throughput, weaker cursor semantics), Analytics OData only (limited entities, no PR/build depth).

### ADR-005: Immutable revisions and daily snapshots
- **Context**: Trends, burndown and scope-change history cannot be reconstructed from current state alone.
- **Decision**: Persist Azure revisions as immutable rows, derive transitions and scope-change events, and write append-only daily snapshots.
- **Consequences**: Trustworthy history, larger storage, retention/partitioning required; a later sync can fill gaps but never rewrite a closed day.
- **Alternatives**: Recompute from Azure on demand (slow, throttled, lossy after edits), current-state-only (no trends).

### ADR-006: Process-template normalization through configuration
- **Context**: Agile, Scrum, CMMI, Basic and custom inherited processes name types, states and estimate fields differently.
- **Decision**: Normalize through a per-project `ProcessMapping` record; preserve unmapped fields in a JSON-safe `customFields` bag.
- **Consequences**: New customers onboard by configuration, not code; mapping quality becomes a data-quality concern with explicit `unknown_*` issues.
- **Alternatives**: Hardcoding one template (breaks the second tenant), per-customer code branches (unmaintainable).

### ADR-007: Transparent, versioned KPI calculations
- **Context**: Executives must trust and challenge every number; formulas will evolve.
- **Decision**: Every KPI has a documented formula, configurable thresholds and a `calculationVersion` stored with each value; Sprint Confidence and Release Readiness expose their components and gates.
- **Consequences**: Historical values remain explainable across formula changes; slightly larger payloads and more catalog maintenance.
- **Alternatives**: Opaque AI score (rejected — unauditable), hardcoded thresholds (rejected — not tenant-specific).

### ADR-008: Read-only integration for the first release
- **Context**: Write-back to Azure DevOps carries real operational risk and demands full audit and permission handling.
- **Decision**: The first release is strictly read-only; write intents are modeled (`WriteBackIntent`) but not implemented.
- **Consequences**: Zero risk of corrupting customer work items; recommendations remain advisory; write-back becomes a separate, gated project.
- **Alternatives**: Immediate write-back (rejected), agent-driven changes (rejected — no confirmation, audit or verification path yet).

## Phase 3 — Database foundation

- **Inputs**: approved `database-blueprint.md`, `domain-model.md`, `security-and-access.md`.
- **Tasks**: enable the backend connection; author migrations per table group (core → azure → analytics → intelligence → operations → audit); add GRANTs, enable RLS and write tenant-scoped policies plus `core_user_roles` + `has_role()`; add non-production seed data for one demo tenant; regenerate types.
- **Outputs**: reviewed migrations, generated `Database` types, seeded demo tenant, RLS policy matrix.
- **Acceptance**: every public table has GRANT + RLS + at least one policy; no table stores roles on a profile; cross-tenant read attempt returns zero rows in tests; types compile.
- **Rollback**: migrations are additive and reversible per group; drop the newest group and restore generated types.
- **Security checks**: linter clean; no `anon` grants on tenant tables; immutable tables deny UPDATE/DELETE except `service_role`.
- **Tests**: policy tests per role, uniqueness/constraint tests, seed integrity test.

## Phase 4 — Azure DevOps connection (read-only)

- **Inputs**: customer-supplied read-only PAT, organization name, target projects.
- **Tasks**: store the PAT as a backend secret; implement the read-only HTTP client with a GET/WIQL allowlist, retry, backoff and throttling; connection verification call; sync organizations, projects, teams and iterations; persist `SyncConnection` and first `SyncRun`.
- **Outputs**: verified connection, populated core tables, first sync run log.
- **Acceptance**: connection test returns projects; teams and iterations match Azure; no credential appears in logs, responses or the client bundle; a revoked PAT disables the connection with an audit event.
- **Rollback**: disable the connection, delete synced core rows for that organization, revoke the PAT.
- **Security checks**: secret never in the database or `VITE_*`; write verbs rejected by the client; audit events recorded.
- **Tests**: mocked-transport unit tests for retry/backoff, allowlist tests, mapping tests against recorded fixtures.

## Phase 5 — Work items and revisions

- **Inputs**: Phase 4 connection, process templates per project.
- **Tasks**: seed `ProcessMapping` per template; WIQL + batch fetch with ChangedDate cursor; normalize fields per the mapping catalog; ingest revisions/updates; derive transitions, scope changes and blocked history; hierarchy resolution and roll-up mode; data-quality rules for states, types, estimates and parents.
- **Outputs**: populated work items, revisions, transitions, scope-change events, first data-quality report.
- **Acceptance**: item counts match Azure queries within tolerance; no duplicate Azure ids; re-running the sync changes no history rows; unmapped states/types raise issues rather than silent defaults.
- **Rollback**: truncate work-item domain tables for the affected project and reset cursors.
- **Security checks**: tenant binding verified per write; descriptions sanitized.
- **Tests**: fixture-based mapper tests per template (Agile/Scrum/CMMI/Basic/custom), idempotency test, roll-up double-count test.

## Phase 6 — Capacity, pull requests, builds, deployments, tests

- **Inputs**: Phase 5 data, repository/pipeline inventory.
- **Tasks**: sync capacity and days off; repositories, PRs, reviewers and threads (first meaningful review detection); pipelines, builds and timelines; environments, deployments, approvals and retries; test runs and result summaries; per-domain freshness tracking.
- **Outputs**: complete engineering dataset with per-domain freshness.
- **Acceptance**: PR review times are plausible against a manual sample; partially succeeded and canceled builds are classified correctly; freshness is reported per domain, never as one global claim.
- **Rollback**: truncate engineering tables, reset those cursors only.
- **Security checks**: no source code or diffs stored; only metadata.
- **Tests**: meaningful-review unit tests (bot/system/author exclusions), build classification tests, stale-PR policy tests.

## Phase 7 — Snapshots and KPI engine

- **Inputs**: Phases 5–6 data, `kpi-catalog.md`.
- **Tasks**: daily snapshot jobs per project/iteration/team/member; KPI engine with configurable thresholds and `calculationVersion`; Sprint Confidence components and Release Readiness gates; deterministic risk rules; evidence-based recommendations; freshness and sync-health KPIs.
- **Outputs**: `an_kpi_values`, snapshots, risk signals, recommendations.
- **Acceptance**: every Overview KPI resolves to a documented formula; missing inputs return `null`/partial with a reason instead of zero; confidence weights sum to 100% after renormalization; snapshots are never rewritten.
- **Rollback**: KPI values and signals are recomputable; delete by `calculationVersion` and recompute.
- **Security checks**: AI outputs are labeled `ai_generated` and never write to Azure.
- **Tests**: golden-file tests per KPI, renormalization tests, cap-rule tests for readiness.

## Phase 8 — Connect the Overview page to live data

- **Inputs**: Phase 7 outputs, `src/contracts/dashboard/*`.
- **Tasks**: implement server functions returning `OverviewContract`; swap the mock adapter behind an explicit mode flag; wire partial/empty/stale/unavailable section states to the existing UI states; keep the dev-only state preview.
- **Outputs**: live Overview page, mock mode retained for demos.
- **Acceptance**: no visual change to the approved design; every section degrades gracefully; mock and live data are never mixed in one payload; contract `mode` is always explicit.
- **Rollback**: flip the mode flag back to mock; the UI keeps working.
- **Security checks**: all data access is tenant-scoped server-side; no secrets in loader data.
- **Tests**: contract shape tests, section-availability tests, visual regression against Phase 1 screenshots.

## Open questions requiring human approval

1. Which Azure DevOps organization(s) and projects are in scope for the first connection?
2. Process template per project, and the preferred roll-up mode (story points at story level vs task hours)?
3. Are bugs part of committed scope (`as_requirement`) or overhead (`as_task`)?
4. Deployment model: per-user delegated OAuth or a service-principal integration identity?
5. Approved threshold values per KPI, or accept the proposed defaults for the first release?
6. Retention: is 3 years of revisions and snapshots acceptable, or is a shorter window required?
7. Which release gates apply, and who signs business acceptance?
8. Working week and holiday calendar per team (default Sun–Thu, `Africa/Cairo`)?
