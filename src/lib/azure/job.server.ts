/**
 * Resumable, checkpointed foundation sync job.
 *
 * The interactive request only *starts* the job: it authorizes, takes the lock,
 * writes the run row and returns immediately. Progress is made by short
 * `advance` calls (driven by the client's status polling), each bounded by
 * ADVANCE_BUDGET_MS and each persisting its cursor, so an interrupted runtime
 * resumes from the stored domain/page cursor instead of restarting.
 *
 * Tombstones are applied only after a domain reaches the end of a complete,
 * failure-free scan.
 */
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import { AzureDevOpsClient } from "./client.server";
import { AzureDevOpsError, toAzureFailure } from "./errors";
import { emptyCounts, SYNC_DOMAINS, type DomainCounts, type SyncDomain, type SyncRunReport } from "./contracts";
import { discoverAzureProjectsBounded } from "./discovery.server";
import {
  ADVANCE_BUDGET_MS,
  LOCK_TTL_MS,
  canTombstone,
  decideStart,
  deriveRunStatus,
  initialCursor,
  nextCursor,
  type JobCursor,
  type JobState,
} from "./job-rules";
import { ensureConnection, ensureOrganization } from "./sync.server";
import { dateOnly, iterationPhase, memberKey, templateFromName } from "./sync-rules";
import type { Database } from "@/integrations/supabase/types";

type Json = Database["public"]["Tables"]["ops_sync_runs"]["Row"]["details"];

type Mutable<T> = { -readonly [K in keyof T]: T[K] };

const blankDomains = (): Record<SyncDomain, DomainCounts> =>
  Object.fromEntries(SYNC_DOMAINS.map((d) => [d, emptyCounts()])) as Record<SyncDomain, DomainCounts>;

const sumCounts = (domains: Record<SyncDomain, DomainCounts>): DomainCounts => {
  const totals: Mutable<DomainCounts> = { ...emptyCounts() };
  for (const domain of SYNC_DOMAINS) {
    const c = domains[domain];
    totals.discovered += c.discovered;
    totals.inserted += c.inserted;
    totals.updated += c.updated;
    totals.unchanged += c.unchanged;
    totals.missing += c.missing;
    totals.failed += c.failed;
  }
  totals.complete = SYNC_DOMAINS.every((d) => domains[d].complete);
  return totals;
};

interface WorkingState {
  runId: string;
  status: SyncRunReport["status"];
  startedAt: string;
  completedAt: string | null;
  organization: string;
  domains: Record<SyncDomain, DomainCounts>;
  warnings: string[];
  cursor: JobCursor | null;
  scannedDomains: SyncDomain[];
  error: SyncRunReport["error"];
}

const toState = (w: WorkingState): JobState => ({
  runId: w.runId,
  status: w.status,
  startedAt: w.startedAt,
  completedAt: w.completedAt,
  organization: w.organization,
  totals: sumCounts(w.domains),
  domains: { ...w.domains },
  warnings: [...w.warnings],
  partialDomains: SYNC_DOMAINS.filter((d) => !w.domains[d].complete),
  nextSafeAction:
    w.error?.code === "invalid_credentials" || w.error?.code === "not_configured"
      ? "fix_credentials"
      : w.error?.code === "forbidden" || w.error?.code === "insufficient_permissions"
        ? "contact_admin"
        : w.error
          ? "wait_and_retry"
          : w.status === "succeeded"
            ? "none"
            : w.status === "queued" || w.status === "running"
              ? "none"
              : "retry_sync",
  error: w.error,
  cursor: w.cursor,
  scannedDomains: [...w.scannedDomains],
});

const fromState = (state: JobState): WorkingState => ({
  runId: state.runId,
  status: state.status,
  startedAt: state.startedAt,
  completedAt: state.completedAt,
  organization: state.organization,
  domains: { ...blankDomains(), ...state.domains },
  warnings: [...state.warnings],
  cursor: state.cursor,
  scannedDomains: [...(state.scannedDomains ?? [])],
  error: state.error,
});

const bump = (state: WorkingState, domain: SyncDomain, patch: Partial<Mutable<DomainCounts>>): void => {
  state.domains[domain] = { ...state.domains[domain], ...patch };
};

const add = (state: WorkingState, domain: SyncDomain, key: keyof DomainCounts, value = 1): void => {
  const current = state.domains[domain];
  bump(state, domain, { [key]: (current[key] as number) + value } as Partial<Mutable<DomainCounts>>);
};

async function checkpoint(tenantId: string, state: WorkingState): Promise<void> {
  const snapshot = toState(state);
  await supabaseAdmin
    .from("ops_sync_runs")
    .update({
      status: state.status,
      items_read: snapshot.totals.discovered,
      items_written: snapshot.totals.inserted + snapshot.totals.updated,
      error_count: snapshot.totals.failed,
      details: snapshot as unknown as Json,
      updated_at: new Date().toISOString(),
      ...(state.completedAt ? { finished_at: state.completedAt, finalized_at: state.completedAt } : {}),
    })
    .eq("tenant_id", tenantId)
    .eq("id", state.runId);
}

async function tombstone(
  table: "core_projects" | "core_teams",
  tenantId: string,
  scope: Readonly<Record<string, string>>,
  cutoffIso: string,
): Promise<number> {
  let query = supabaseAdmin
    .from(table)
    .update({ source_status: "deleted", is_deleted: true, deleted_at_source: cutoffIso })
    .eq("tenant_id", tenantId)
    .eq("is_deleted", false)
    .lt("last_seen_at", cutoffIso);
  for (const [column, value] of Object.entries(scope)) query = query.eq(column, value);
  const { data } = await query.select("id");
  return data?.length ?? 0;
}

export interface StartJobInput {
  readonly tenantId: string;
  readonly actorUserId: string | null;
  readonly organizationName: string;
}

export interface StartJobResult {
  readonly state: JobState;
  readonly reused: boolean;
}

/** Authorizes-free (caller already authorized) job start: fast, never syncs inline. */
export async function startFoundationJob(input: StartJobInput): Promise<StartJobResult> {
  const nowDate = new Date();
  const nowIso = nowDate.toISOString();
  const organizationId = await ensureOrganization(input.tenantId, input.organizationName, nowIso);
  const connectionId = await ensureConnection(input.tenantId, organizationId);

  // Release expired locks before looking at what is active.
  await supabaseAdmin
    .from("ops_sync_locks")
    .update({ released_at: nowIso })
    .eq("tenant_id", input.tenantId)
    .eq("organization_id", organizationId)
    .is("released_at", null)
    .lt("expires_at", nowIso);

  const { data: activeLock } = await supabaseAdmin
    .from("ops_sync_locks")
    .select("run_id, expires_at")
    .eq("tenant_id", input.tenantId)
    .eq("organization_id", organizationId)
    .is("released_at", null)
    .limit(1)
    .maybeSingle();

  if (activeLock?.run_id) {
    const { data: activeRun } = await supabaseAdmin
      .from("ops_sync_runs")
      .select("id, status, updated_at, details")
      .eq("tenant_id", input.tenantId)
      .eq("id", activeLock.run_id)
      .maybeSingle();

    const decision = decideStart(
      activeRun
        ? {
            runId: activeRun.id,
            status: activeRun.status as SyncRunReport["status"],
            heartbeatAt: activeRun.updated_at,
            expiresAt: activeLock.expires_at,
          }
        : null,
      nowDate.getTime(),
    );

    if (decision.kind === "reuse" && activeRun) {
      return { state: (activeRun.details as unknown as JobState), reused: true };
    }
    // Stale or finished: reclaim the lock so a fresh run can start.
    await supabaseAdmin
      .from("ops_sync_locks")
      .update({ released_at: nowIso })
      .eq("tenant_id", input.tenantId)
      .eq("run_id", activeLock.run_id)
      .is("released_at", null);
  }

  const runId = crypto.randomUUID();
  const state: WorkingState = {
    runId,
    status: "queued",
    startedAt: nowIso,
    completedAt: null,
    organization: input.organizationName,
    domains: blankDomains(),
    warnings: [],
    cursor: initialCursor(),
    scannedDomains: [],
    error: null,
  };

  const { error: lockError } = await supabaseAdmin.from("ops_sync_locks").insert({
    tenant_id: input.tenantId,
    organization_id: organizationId,
    run_id: runId,
    acquired_at: nowIso,
    expires_at: new Date(nowDate.getTime() + LOCK_TTL_MS).toISOString(),
    holder: "foundation_sync",
  });
  if (lockError) throw new AzureDevOpsError("conflict");

  await supabaseAdmin.from("ops_sync_runs").insert({
    id: runId,
    tenant_id: input.tenantId,
    connection_id: connectionId,
    organization_id: organizationId,
    trigger_kind: "manual",
    status: "queued",
    entity_kinds: [...SYNC_DOMAINS],
    started_at: nowIso,
    correlation_id: runId,
    idempotency_key: `foundation:${organizationId}:${nowIso}`,
    details: toState(state) as unknown as Json,
  });

  return { state: toState(state), reused: false };
}

interface RunRow {
  readonly organization_id: string;
  readonly connection_id: string;
  readonly details: unknown;
  readonly status: string;
}

/** Executes bounded work for an active run and checkpoints after every unit. */
export async function advanceFoundationJob(
  tenantId: string,
  runId: string,
  client: AzureDevOpsClient,
  budgetMs = ADVANCE_BUDGET_MS,
): Promise<JobState> {
  const { data: row } = await supabaseAdmin
    .from("ops_sync_runs")
    .select("organization_id, connection_id, details, status")
    .eq("tenant_id", tenantId)
    .eq("id", runId)
    .maybeSingle();
  if (!row) throw new AzureDevOpsError("unknown");
  const runRow = row as RunRow;
  const stored = runRow.details as unknown as JobState;
  const state = fromState(stored);

  if (runRow.status !== "queued" && runRow.status !== "running") return toState(state);

  state.status = "running";
  const deadline = Date.now() + budgetMs;
  const organizationId = runRow.organization_id;

  // Refresh the lock so a long job is never reclaimed mid-flight.
  await supabaseAdmin
    .from("ops_sync_locks")
    .update({ expires_at: new Date(Date.now() + LOCK_TTL_MS).toISOString() })
    .eq("tenant_id", tenantId)
    .eq("run_id", runId)
    .is("released_at", null);

  try {
    while (state.cursor && Date.now() < deadline) {
      const more = await runUnit(tenantId, organizationId, state, client);
      state.cursor = nextCursor(state.cursor, more);
      await checkpoint(tenantId, state);
    }
  } catch (error) {
    state.error = toAzureFailure(error);
    state.status = "failed";
    state.completedAt = new Date().toISOString();
    await checkpoint(tenantId, state);
    await releaseLock(tenantId, runId);
    return toState(state);
  }

  if (!state.cursor) {
    state.status = deriveRunStatus(state.domains);
    state.completedAt = new Date().toISOString();
    await checkpoint(tenantId, state);
    await releaseLock(tenantId, runId);
    await supabaseAdmin
      .from("ops_sync_connections")
      .update({
        status: state.status === "succeeded" ? "connected" : "error",
        status_message: state.status === "succeeded" ? null : "partial_sync",
        last_verified_at: state.completedAt,
      })
      .eq("tenant_id", tenantId)
      .eq("id", runRow.connection_id);
    return toState(state);
  }

  await checkpoint(tenantId, state);
  return toState(state);
}

async function releaseLock(tenantId: string, runId: string): Promise<void> {
  await supabaseAdmin
    .from("ops_sync_locks")
    .update({ released_at: new Date().toISOString() })
    .eq("tenant_id", tenantId)
    .eq("run_id", runId)
    .is("released_at", null);
}

/** Cancels an active run and frees its lock. */
export async function cancelFoundationJob(tenantId: string, runId: string): Promise<void> {
  const nowIso = new Date().toISOString();
  await supabaseAdmin
    .from("ops_sync_runs")
    .update({ status: "failed", finished_at: nowIso, finalized_at: nowIso })
    .eq("tenant_id", tenantId)
    .eq("id", runId)
    .in("status", ["queued", "running"]);
  await releaseLock(tenantId, runId);
}

async function listProjectsFromDb(tenantId: string, organizationId: string) {
  const { data } = await supabaseAdmin
    .from("core_projects")
    .select("id, azure_project_id")
    .eq("tenant_id", tenantId)
    .eq("organization_id", organizationId)
    .eq("is_deleted", false)
    .order("id");
  return data ?? [];
}

async function listTeamsFromDb(tenantId: string, organizationId: string) {
  const { data } = await supabaseAdmin
    .from("core_teams")
    .select("id, azure_team_id, project_id, core_projects!inner(azure_project_id)")
    .eq("tenant_id", tenantId)
    .eq("organization_id", organizationId)
    .eq("is_deleted", false)
    .order("id");
  return (data ?? []) as unknown as {
    id: string;
    azure_team_id: string;
    project_id: string;
    core_projects: { azure_project_id: string };
  }[];
}

/** Runs a single work unit. Returns true when the current domain has more units. */
async function runUnit(
  tenantId: string,
  organizationId: string,
  state: WorkingState,
  client: AzureDevOpsClient,
): Promise<boolean> {
  const cursor = state.cursor!;
  const nowIso = new Date().toISOString();

  if (cursor.domain === "organization") {
    bump(state, "organization", { discovered: 1, updated: 1, complete: true, freshnessAt: nowIso });
    state.scannedDomains.push("organization");
    return false;
  }

  if (cursor.domain === "projects") {
    const discovery = await discoverAzureProjectsBounded({
      organization: state.organization,
      pat: process.env["AZURE_DEVOPS_PAT"] ?? null,
    });
    bump(state, "projects", { discovered: discovery.projectCount });
    if (discovery.status === "failed") {
      add(state, "projects", "failed");
      state.warnings.push(`projects_incomplete:${discovery.warning ?? "unknown"}`);
      bump(state, "projects", { complete: false, freshnessAt: nowIso });
      return false;
    }
    for (const project of discovery.projects) {
      const { data, error } = await supabaseAdmin
        .from("core_projects")
        .upsert(
          {
            tenant_id: tenantId,
            organization_id: organizationId,
            azure_project_id: project.azureProjectId,
            azure_project_name: project.name,
            name_en: project.name,
            name_ar: project.name,
            description: project.description,
            process_template_kind: templateFromName(project.name),
            visibility: project.visibility,
            state: project.state,
            source_status: "active",
            is_deleted: false,
            last_seen_at: nowIso,
            last_synced_at: nowIso,
          },
          { onConflict: "tenant_id,organization_id,azure_project_id" },
        )
        .select("id, created_at")
        .single();
      if (error || !data) {
        add(state, "projects", "failed");
        continue;
      }
      if (data.created_at >= state.startedAt) add(state, "projects", "inserted");
      else add(state, "projects", "updated");
    }
    const scanReachedEnd = discovery.status === "complete";
    bump(state, "projects", {
      complete: scanReachedEnd && state.domains.projects.failed === 0,
      freshnessAt: nowIso,
    });
    if (canTombstone(state.domains.projects, scanReachedEnd)) {
      const missing = await tombstone("core_projects", tenantId, { organization_id: organizationId }, nowIso);
      bump(state, "projects", { missing });
      state.scannedDomains.push("projects");
    } else if (!scanReachedEnd) {
      state.warnings.push("projects_partial_no_tombstone");
    }
    return false;
  }

  if (cursor.domain === "teams") {
    const dependency = blockingDependency("teams", state.domains);
    if (dependency) {
      state.domains.teams = blockedCounts(state.domains.teams, dependency);
      state.warnings.push(`teams_skipped_dependency:${dependency}`);
      return false;
    }
    const projects = await listProjectsFromDb(tenantId, organizationId);
    const project = projects[cursor.index];
    if (!project) {
      const ok = state.domains.teams.failed === 0 && !state.domains.teams.blocked;
      bump(state, "teams", {
        complete: ok,
        freshnessAt: ok ? (state.domains.teams.freshnessAt ?? nowIso) : null,
      });
      if (ok) state.scannedDomains.push("teams");
      return false;
    }

    // Bounded, project-id addressed read; partial pages are preserved.
    const read = await readProjectTeams({
      organization: state.organization,
      pat: process.env["AZURE_DEVOPS_PAT"] ?? null,
      azureProjectId: project.azure_project_id,
    });
    add(state, "teams", "discovered", read.teamCount);
    let failedHere = read.status === "failed" ? 1 : 0;
    if (read.status !== "complete") {
      add(state, "teams", "failed");
      state.warnings.push(`teams_${read.status}:${project.azure_project_id}:${read.warning ?? "unknown"}`);
    }

    for (const team of read.teams) {
      const fieldValues = await client.getTeamFieldValues(project.azure_project_id, team.azureTeamId);
      const settings = await client.getTeamSettings(project.azure_project_id, team.azureTeamId);
      const { data, error } = await supabaseAdmin
        .from("core_teams")
        .upsert(
          {
            tenant_id: tenantId,
            organization_id: organizationId,
            project_id: project.id,
            azure_team_id: team.azureTeamId,
            azure_team_name: team.name,
            name_en: team.name,
            name_ar: team.name,
            description: team.description,
            area_paths: fieldValues ? fieldValues.values.map((v) => v.value) : [],
            default_iteration_path: settings?.defaultIteration?.path ?? null,
            source_status: "active",
            is_deleted: false,
            last_seen_at: nowIso,
            last_synced_at: nowIso,
          },
          { onConflict: "tenant_id,project_id,azure_team_id" },
        )
        .select("id, created_at")
        .single();
      if (error || !data) {
        failedHere += 1;
        add(state, "teams", "failed");
        continue;
      }
      if (data.created_at >= state.startedAt) add(state, "teams", "inserted");
      else add(state, "teams", "updated");
    }

    // Per-project tombstones only after that project's scan fully succeeded.
    if (failedHere === 0 && read.status === "complete") {
      const missing = await tombstone("core_teams", tenantId, { project_id: project.id }, nowIso);
      add(state, "teams", "missing", missing);
    }
    bump(state, "teams", { freshnessAt: nowIso });
    return cursor.index + 1 < projects.length;
  }

  if (cursor.domain === "iterations") {
    const teams = await listTeamsFromDb(tenantId, organizationId);
    const team = teams[cursor.index];
    if (!team) {
      const ok = state.domains.iterations.failed === 0;
      bump(state, "iterations", { complete: ok, freshnessAt: state.domains.iterations.freshnessAt ?? nowIso });
      bump(state, "teamIterations", {
        complete: state.domains.teamIterations.failed === 0,
        freshnessAt: state.domains.teamIterations.freshnessAt ?? nowIso,
      });
      if (ok) state.scannedDomains.push("iterations");
      return false;
    }
    try {
      const iterations = await client.listTeamIterations(team.core_projects.azure_project_id, team.azure_team_id);
      add(state, "iterations", "discovered", iterations.length);
      for (const iteration of iterations) {
        const phase = iterationPhase(iteration, new Date());
        const { data, error } = await supabaseAdmin
          .from("core_iterations")
          .upsert(
            {
              tenant_id: tenantId,
              organization_id: organizationId,
              project_id: team.project_id,
              azure_iteration_id: iteration.id,
              azure_iteration_path: iteration.path,
              name_en: iteration.name,
              name_ar: iteration.name,
              start_date: dateOnly(iteration.attributes?.startDate),
              finish_date: dateOnly(iteration.attributes?.finishDate),
              phase,
              source_status: "active",
              is_deleted: false,
              last_seen_at: nowIso,
              last_synced_at: nowIso,
            },
            { onConflict: "tenant_id,project_id,azure_iteration_id" },
          )
          .select("id, created_at")
          .single();
        if (error || !data) {
          add(state, "iterations", "failed");
          continue;
        }
        if (data.created_at >= state.startedAt) add(state, "iterations", "inserted");
        else add(state, "iterations", "updated");

        add(state, "teamIterations", "discovered");
        const { data: link, error: linkError } = await supabaseAdmin
          .from("core_team_iterations")
          .upsert(
            {
              tenant_id: tenantId,
              organization_id: organizationId,
              project_id: team.project_id,
              team_id: team.id,
              iteration_id: data.id,
              phase,
              source_status: "active",
              is_deleted: false,
              last_seen_at: nowIso,
              last_synced_at: nowIso,
            },
            { onConflict: "tenant_id,team_id,iteration_id" },
          )
          .select("id, created_at")
          .single();
        if (linkError || !link) {
          add(state, "teamIterations", "failed");
          continue;
        }
        if (link.created_at >= state.startedAt) add(state, "teamIterations", "inserted");
        else add(state, "teamIterations", "updated");
      }
      bump(state, "iterations", { freshnessAt: nowIso });
      bump(state, "teamIterations", { freshnessAt: nowIso });
    } catch {
      add(state, "iterations", "failed");
      state.warnings.push(`iterations_incomplete:${team.azure_team_id}`);
    }
    return cursor.index + 1 < teams.length;
  }

  if (cursor.domain === "members") {
    const teams = await listTeamsFromDb(tenantId, organizationId);
    const team = teams[cursor.index];
    if (!team) {
      const ok = state.domains.members.failed === 0;
      bump(state, "members", { complete: ok, freshnessAt: state.domains.members.freshnessAt ?? nowIso });
      bump(state, "teamMemberships", {
        complete: state.domains.teamMemberships.failed === 0,
        freshnessAt: state.domains.teamMemberships.freshnessAt ?? nowIso,
      });
      if (ok) state.scannedDomains.push("members");
      return false;
    }
    try {
      const members = await client.listTeamMembers(team.core_projects.azure_project_id, team.azure_team_id);
      add(state, "members", "discovered", members.length);
      const memberIds: string[] = [];
      for (const entry of members) {
        const identity = entry.identity;
        const descriptor = memberKey(identity);
        if (!descriptor) {
          add(state, "members", "failed");
          continue;
        }
        const { data, error } = await supabaseAdmin
          .from("core_members")
          .upsert(
            {
              tenant_id: tenantId,
              organization_id: organizationId,
              azure_descriptor: descriptor,
              azure_unique_name: identity.uniqueName ?? null,
              display_name: identity.displayName ?? descriptor,
              email: identity.uniqueName?.includes("@") ? identity.uniqueName : null,
              image_url: identity.imageUrl ?? null,
              is_active: true,
              source_status: "active",
              is_deleted: false,
              last_seen_at: nowIso,
              last_synced_at: nowIso,
            },
            { onConflict: "tenant_id,organization_id,azure_descriptor" },
          )
          .select("id, created_at")
          .single();
        if (error || !data) {
          add(state, "members", "failed");
          continue;
        }
        memberIds.push(data.id);
        if (data.created_at >= state.startedAt) add(state, "members", "inserted");
        else add(state, "members", "updated");
      }

      const { data: existing } = await supabaseAdmin
        .from("core_team_memberships")
        .select("id, member_id")
        .eq("tenant_id", tenantId)
        .eq("team_id", team.id);
      const existingByMember = new Map((existing ?? []).map((r) => [r.member_id, r.id]));
      add(state, "teamMemberships", "discovered", memberIds.length);
      for (const memberId of memberIds) {
        const existingId = existingByMember.get(memberId);
        if (existingId) {
          await supabaseAdmin
            .from("core_team_memberships")
            .update({
              is_active: true,
              left_at: null,
              source_status: "active",
              is_deleted: false,
              last_seen_at: nowIso,
            })
            .eq("tenant_id", tenantId)
            .eq("id", existingId);
          add(state, "teamMemberships", "updated");
        } else {
          const { error } = await supabaseAdmin.from("core_team_memberships").insert({
            tenant_id: tenantId,
            project_id: team.project_id,
            team_id: team.id,
            member_id: memberId,
            role: "member",
            is_active: true,
            source_status: "active",
            is_deleted: false,
            last_seen_at: nowIso,
          });
          if (error) add(state, "teamMemberships", "failed");
          else add(state, "teamMemberships", "inserted");
        }
      }
      const activeSet = new Set(memberIds);
      for (const [memberId, membershipId] of existingByMember) {
        if (activeSet.has(memberId)) continue;
        await supabaseAdmin
          .from("core_team_memberships")
          .update({ is_active: false, left_at: nowIso, source_status: "deleted", is_deleted: true })
          .eq("tenant_id", tenantId)
          .eq("id", membershipId)
          .eq("is_deleted", false);
        add(state, "teamMemberships", "missing");
      }
      bump(state, "members", { freshnessAt: nowIso });
      bump(state, "teamMemberships", { freshnessAt: nowIso });
    } catch {
      add(state, "members", "failed");
      state.warnings.push(`members_incomplete:${team.azure_team_id}`);
    }
    return cursor.index + 1 < teams.length;
  }

  return false;
}
