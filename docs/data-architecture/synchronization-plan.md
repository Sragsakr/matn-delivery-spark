# Synchronization Plan

Design only. No Edge Functions, workers or API calls are implemented in this phase.

## Initial synchronization order

Dependencies force this order; each stage completes before the next begins.

1. Organization metadata
2. Projects (+ process template properties)
3. Teams (+ team settings, area paths, working days)
4. Iterations (+ team days off)
5. Members (team memberships, identity resolution)
6. Capacity (per team, per iteration)
7. Current work items (WIQL by project, batched fetch)
8. Work-item revisions/updates (derive transitions, scope changes, blocked history)
9. Repositories
10. Pull requests (+ reviewers, threads for first meaningful review)
11. Pipelines and builds (+ timelines for stages)
12. Deployments (environments, approvals, retries)
13. Test runs and result summaries
14. Snapshots and calculated KPIs, risk signals, recommendations

Backfill window defaults: work items and revisions 12 months, PRs/builds/deployments/tests 6 months, snapshots reconstructed from revisions where possible and otherwise started from the first sync date (gaps recorded as `snapshot_gap`).

## Incremental synchronization

- Watermark: `System.ChangedDate` for work items, `minTime`/`minModifiedTime`/`minLastUpdatedDate` for PRs, builds, deployments and tests; continuation tokens where the endpoint provides them.
- Cursors persist in `SyncCursor` per `(connection, entityKind, project)` with an `overlapMinutes` window (default 10) to absorb clock skew; overlap is safe because writes are idempotent.
- Pagination: `$top = 200` for work item batches, `continuationToken` loops elsewhere; hard page cap per run with resumable cursor.
- Concurrency: bounded worker pool (default 4 concurrent requests per organization, 1 run per organization at a time).
- Throttling: honour `Retry-After` and `X-RateLimit-*`; exponential backoff with jitter (1s → 60s, max 6 attempts) for 429/502/503/504 and network errors. 401/403/404 are non-transient and fail the entity scope, not the run.
- Idempotency: upsert on natural keys — `(tenant_id, organization_id, azure_work_item_id)`, `(tenant_id, work_item_id, rev)`, `(tenant_id, organization_id, azure_pull_request_id)`, etc. History tables use `ON CONFLICT DO NOTHING`.
- Revisions are never overwritten; a re-sync can only add missing revisions.
- Partial failures are recorded per entity kind; the run ends `partially_completed` and the failing scope keeps its old cursor so the next run retries exactly that gap.
- Resumption: `SyncRun.resumeCursor` stores the in-flight position, so a canceled or crashed run resumes without re-reading completed pages.

## Sync run lifecycle

`queued → running → { completed | partially_completed | failed | canceled }`

Recorded per run: scope, project ids, started/completed timestamps, cursor before and after, `recordsRead`, `recordsInserted`, `recordsUpdated`, `recordsSkipped`, error list (code, entity, transient flag), rate-limit info (delayed, throttled, max `Retry-After`, remaining budget), and linked data-quality issue ids.

Proposed schedules: work items and PRs every 15 minutes; builds, deployments and tests every 30 minutes; capacity hourly; org/project/team/iteration metadata daily; snapshots once per day at 23:55 in the iteration time zone plus an intra-day recompute of KPIs after each work-item sync.

## Data freshness

Freshness is computed **per domain** (`FreshnessReport`), never as a single global flag.

| Domain | Current | Delayed | Stale | Unavailable |
|---|---|---|---|---|
| Work items | ≤ 30 min | 31–120 min | > 120 min | never synced or last run failed |
| Capacity | ≤ 2 h | 2–8 h | > 8 h | not configured in Azure |
| Repositories | ≤ 24 h | 24–48 h | > 48 h | no repositories |
| Pull requests | ≤ 30 min | 31–120 min | > 120 min | no repositories |
| Builds | ≤ 60 min | 1–4 h | > 4 h | no pipelines |
| Deployments | ≤ 2 h | 2–8 h | > 8 h | no environments |
| Tests | ≤ 2 h | 2–12 h | > 12 h | no test runs |

`partial` applies when a domain synced only some projects or ended `partially_completed`. The overall status is the worst domain status, and the UI must name which domains are behind — it may never state that everything is current when only work items are.
