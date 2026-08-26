# Security and Access Architecture

Nothing in this phase requests, stores or references a real credential. No secret placeholders contain real values.

## Development prototype (Phase 4)

- Credential: a **read-only Azure DevOps Personal Access Token**, created by the customer.
- Minimum scopes: `Work Items (Read)`, `Project and Team (Read)`, `Code (Read)`, `Build (Read)`, `Release (Read)`, `Test Management (Read)`, `Identity (Read)`, `Graph (Read)`. No write, no manage, no full access.
- Storage: backend secret only, referenced by name (`SyncConnection.secretRef`). Never in the database, never in `VITE_*`, never in the client bundle, never in logs or error messages.
- Access: only server-side sync code reads it; browser code has no path to it.
- Lifetime: maximum 90 days, calendar reminder for rotation, revocable instantly from Azure DevOps user settings; revocation is detected as a 401 and disables the connection with an audit event.
- Scope of use: GET requests plus WIQL POST for querying only; write verbs are rejected by an allowlist in the HTTP client.

## Production

- Identity: **Microsoft Entra ID OAuth 2.0** against Azure DevOps (`499b84ac-1321-427f-aa17-267ca6975798/.default`), authorization code with PKCE for per-user access, or a service principal / managed identity for tenant-wide background sync.
- Deployment models: *per-user delegated* (each viewer sees only what they can see in Azure DevOps) or *service principal* (one read-only integration identity, MATN enforces visibility). The model is a per-tenant setting on `SyncConnection.authMode`.
- Tokens: short-lived access tokens held in memory for the request; refresh tokens encrypted at rest in the secret store, bound to tenant and connection, rotated on use, revoked on disconnect.
- Tenant isolation: every token is bound to one `(tenantId, organizationId)`; the sync worker refuses to write rows whose tenant differs from the run's tenant.
- Authorization: role-based, evaluated server-side; the client never asserts its own role.
- Auditing: connection created/verified/disabled, token refresh failures, role changes, recommendation decisions, and any future write-back are recorded in `aud_audit_events`.
- Rotation: secrets rotate on a schedule and on personnel change; rotation is a config update with no code change because only `secretRef` is stored.

## Application roles and permissions

| Role | Scope | Read dashboards | Drill into work items | Manage connections | Configure thresholds/process mapping | Decide recommendations | Manage users/roles | View audit |
|---|---|---|---|---|---|---|---|---|
| Platform Admin | all tenants | yes | yes | yes | yes | no | yes | yes |
| Tenant Admin | one tenant | yes | yes | yes | yes | yes | yes | yes |
| Executive Viewer | tenant | yes (aggregate) | limited | no | no | no | no | no |
| Delivery Manager | projects | yes | yes | no | yes (thresholds) | yes | no | no |
| Team Lead | own teams | yes (own teams) | yes | no | no | yes (own teams) | no | no |
| Contributor | own teams | yes (own teams) | yes | no | no | no | no | no |
| QA & Release Owner | projects | yes | yes | no | yes (release gates) | yes (quality) | no | no |
| Read-only Viewer | assigned scope | yes | read-only | no | no | no | no | no |

Notes: Executive Viewer sees aggregates and named risks but not individual member utilization detail; per-person metrics are visible to Delivery Manager, Team Lead (own team) and the member themself. No role exposes secrets or the service role key.

RLS is **not implemented in this phase**. Phase 3 will translate the table above into policies keyed on `tenant_id` plus a `has_role()` security-definer function and a scope table for project/team-limited roles.

## Data protection

- No Azure DevOps write operations in this release; the HTTP client allowlists GET (plus WIQL POST).
- Descriptions and titles may contain customer content: they are stored, never sent to third parties except the configured AI gateway, and only with tenant consent.
- AI never modifies Azure DevOps. Any future write requires user confirmation, a permission check, an audit event, an idempotency key and post-write verification (`WriteBackIntent`).
- PII minimisation: only display name, unique name, email and avatar URL are stored for identities; no HR or performance data.
