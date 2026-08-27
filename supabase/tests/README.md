# SQL test suite (Phase 3)

Plain SQL, no pgTAP dependency. Every suite is self-contained: it builds its own
clearly-fake fixtures (`is_demo = true`), asserts, and then either deletes the
fixtures or aborts the surrounding transaction so nothing persists.

| File | Covers |
| --- | --- |
| `01_tenant_isolation.sql` | cross-tenant inserts, cross-tenant scope grants, tenant re-parenting |
| `02_project_integrity.sql` | cross-project team iteration / KPI override / process mapping / work item / snapshot, sentinel uuid rejection |
| `03_roles_and_rls.sql` | project-limited delivery manager, team-limited team lead, aggregate-only executive viewer, tenant-limited admin, self role/scope elevation, expired scope |
| `04_scope_grants.sql` | grant idempotency, expired close-and-replace, revoked replace, invalid expiry, cross-tenant grant, audit trail |
| `05_immutability.sql` | revision update/delete, finalized snapshot update, audit update/delete, project re-parenting |
| `06_schema_invariants.sql` | `tenant_id NOT NULL`, RLS enabled, no `anon` grants, pinned `search_path`, privileged functions restricted, composite FKs present, KPI catalog seeded |

## Running

```bash
npm run db:test          # psql, ON_ERROR_STOP=1
```

A suite passes when it completes without an `ERROR`. Suites that must leave no
trace end with a deliberate `RAISE EXCEPTION 'SUITE ... PASSED'`, which rolls the
transaction back — an aborting "PASSED" message is the success signal there.

Suites `03`, `04` and `05` must run with a role that can `SET ROLE authenticated`
and execute the privileged grant functions (i.e. the service role). The sandbox
psql role is intentionally weaker; those suites were executed through the
managed SQL runner.

## Known intentional exemptions

- `ops_cron_nonces` and `aud_audit_events` allow `tenant_id IS NULL` for
  platform-level rows, so they are excluded from invariant 6.1.
- The read-only authorization helpers (`has_role`, `has_tenant_access`,
  `has_project_access`, `has_team_access`, `has_full_tenant_access`,
  `current_core_user_id`, `current_tenant_id`, `can_view_member_detail`) are
  `SECURITY DEFINER` and executable by `authenticated` on purpose: RLS policies
  call them as the requesting user. They accept no privileged input and return
  only booleans/ids for the caller's own identity.
