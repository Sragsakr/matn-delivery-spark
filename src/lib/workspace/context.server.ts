/**
 * Server-only workspace selection.
 *
 * Every list is derived from the caller's tenant and explicit scope grants.
 * A client-supplied id is never trusted: it is re-validated against the same
 * tenant-scoped query that produced the options.
 */
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import { AzureDevOpsError } from "@/lib/azure/errors";
import type { TenantContext } from "@/lib/azure/authz.server";
import { cairoToday, containsDate } from "@/lib/calendar/cairo";

export interface SelectorOption {
  readonly id: string;
  readonly nameEn: string;
  readonly nameAr: string;
}

export interface TeamIterationOption extends SelectorOption {
  readonly teamId: string;
  readonly projectId: string;
  readonly iterationId: string;
  readonly startDate: string | null;
  readonly finishDate: string | null;
  readonly isCurrent: boolean;
}

export interface WorkspaceSelectors {
  readonly organizations: readonly SelectorOption[];
  readonly projects: readonly (SelectorOption & { organizationId: string })[];
  readonly teams: readonly (SelectorOption & { projectId: string })[];
  readonly teamIterations: readonly TeamIterationOption[];
  /** Best current selection, resolved server-side from the Cairo calendar. */
  readonly defaults: {
    readonly organizationId: string | null;
    readonly projectId: string | null;
    readonly teamId: string | null;
    readonly teamIterationId: string | null;
  };
}

const FULL_ACCESS_ROLES = ["platform_admin", "tenant_admin", "executive_viewer", "delivery_manager"] as const;

const hasFullAccess = (context: TenantContext): boolean =>
  context.roles.some((role) => (FULL_ACCESS_ROLES as readonly string[]).includes(role));

/** Project/team ids the caller may see, or `null` meaning "all in tenant". */
export async function resolveScope(
  context: TenantContext,
): Promise<{ projectIds: string[] | null; teamIds: string[] | null }> {
  if (hasFullAccess(context)) return { projectIds: null, teamIds: null };

  const nowIso = new Date().toISOString();
  const [projects, teams] = await Promise.all([
    supabaseAdmin
      .from("core_user_project_scopes")
      .select("project_id, expires_at")
      .eq("tenant_id", context.tenantId)
      .eq("user_id", context.coreUserId)
      .is("revoked_at", null),
    supabaseAdmin
      .from("core_user_team_scopes")
      .select("team_id, expires_at")
      .eq("tenant_id", context.tenantId)
      .eq("user_id", context.coreUserId)
      .is("revoked_at", null),
  ]);

  const live = <T extends { expires_at: string | null }>(rows: T[] | null): T[] =>
    (rows ?? []).filter((row) => !row.expires_at || row.expires_at > nowIso);

  return {
    projectIds: live(projects.data).map((r) => r.project_id),
    teamIds: live(teams.data).map((r) => r.team_id),
  };
}

export async function loadWorkspaceSelectors(context: TenantContext): Promise<WorkspaceSelectors> {
  const scope = await resolveScope(context);

  const orgQuery = await supabaseAdmin
    .from("core_organizations")
    .select("id, name_en, name_ar")
    .eq("tenant_id", context.tenantId)
    .eq("is_deleted", false)
    .order("name_en");
  if (orgQuery.error) throw new AzureDevOpsError("unknown");

  let projectQuery = supabaseAdmin
    .from("core_projects")
    .select("id, organization_id, name_en, name_ar")
    .eq("tenant_id", context.tenantId)
    .eq("is_deleted", false)
    .order("name_en");
  if (scope.projectIds) projectQuery = projectQuery.in("id", scope.projectIds.length ? scope.projectIds : [""]);
  const projectRows = await projectQuery;
  if (projectRows.error) throw new AzureDevOpsError("unknown");

  const projectIds = (projectRows.data ?? []).map((p) => p.id);

  let teamQuery = supabaseAdmin
    .from("core_teams")
    .select("id, project_id, name_en, name_ar")
    .eq("tenant_id", context.tenantId)
    .eq("is_deleted", false)
    .order("name_en");
  if (projectIds.length > 0) teamQuery = teamQuery.in("project_id", projectIds);
  else teamQuery = teamQuery.eq("project_id", "00000000-0000-0000-0000-000000000000");
  if (scope.teamIds) teamQuery = teamQuery.in("id", scope.teamIds.length ? scope.teamIds : [""]);
  const teamRows = await teamQuery;
  if (teamRows.error) throw new AzureDevOpsError("unknown");

  const teamIds = (teamRows.data ?? []).map((t) => t.id);

  const iterationRows = teamIds.length
    ? await supabaseAdmin
        .from("core_team_iterations")
        .select(
          "id, team_id, project_id, iteration_id, is_current, core_iterations(name_en, name_ar, start_date, finish_date)",
        )
        .eq("tenant_id", context.tenantId)
        .eq("is_deleted", false)
        .in("team_id", teamIds)
    : { data: [], error: null };
  if (iterationRows.error) throw new AzureDevOpsError("unknown");

  type IterationJoin = {
    id: string;
    team_id: string;
    project_id: string;
    iteration_id: string;
    is_current: boolean;
    core_iterations: { name_en: string; name_ar: string; start_date: string | null; finish_date: string | null } | null;
  };

  const today = cairoToday();
  const teamIterations: TeamIterationOption[] = ((iterationRows.data ?? []) as unknown as IterationJoin[])
    .map((row) => ({
      id: row.id,
      teamId: row.team_id,
      projectId: row.project_id,
      iterationId: row.iteration_id,
      nameEn: row.core_iterations?.name_en ?? "Iteration",
      nameAr: row.core_iterations?.name_ar ?? "تكرار",
      startDate: row.core_iterations?.start_date ?? null,
      finishDate: row.core_iterations?.finish_date ?? null,
      isCurrent: containsDate(row.core_iterations?.start_date ?? null, row.core_iterations?.finish_date ?? null, today),
    }))
    .sort((a, b) => (a.startDate ?? "").localeCompare(b.startDate ?? ""));

  const current = teamIterations.find((it) => it.isCurrent) ?? teamIterations[teamIterations.length - 1] ?? null;
  const defaultTeam = current
    ? (teamRows.data ?? []).find((t) => t.id === current.teamId)
    : (teamRows.data ?? [])[0];
  const defaultProject = defaultTeam
    ? (projectRows.data ?? []).find((p) => p.id === defaultTeam.project_id)
    : (projectRows.data ?? [])[0];

  return {
    organizations: (orgQuery.data ?? []).map((o) => ({ id: o.id, nameEn: o.name_en, nameAr: o.name_ar })),
    projects: (projectRows.data ?? []).map((p) => ({
      id: p.id,
      organizationId: p.organization_id,
      nameEn: p.name_en,
      nameAr: p.name_ar,
    })),
    teams: (teamRows.data ?? []).map((t) => ({
      id: t.id,
      projectId: t.project_id,
      nameEn: t.name_en,
      nameAr: t.name_ar,
    })),
    teamIterations,
    defaults: {
      organizationId: defaultProject?.organization_id ?? (orgQuery.data ?? [])[0]?.id ?? null,
      projectId: defaultProject?.id ?? null,
      teamId: defaultTeam?.id ?? null,
      teamIterationId: current?.id ?? null,
    },
  };
}

export interface ResolvedTeamIteration {
  readonly teamIterationId: string;
  readonly tenantId: string;
  readonly organizationId: string;
  readonly projectId: string;
  readonly teamId: string;
  readonly iterationId: string;
  readonly azureProjectName: string;
  readonly azureProjectId: string;
  readonly organizationBaseUrl: string;
  readonly iterationPath: string;
  readonly iterationNameEn: string;
  readonly iterationNameAr: string;
  readonly startDate: string | null;
  readonly finishDate: string | null;
  readonly timeZone: string;
  readonly workingWeekdays: number[];
  readonly processMappingId: string | null;
  readonly processTemplateKind: "agile" | "scrum" | "cmmi" | "basic" | "custom";
}

/**
 * Re-validates a client-supplied team iteration id against tenant + scope.
 * Throws `forbidden` rather than silently falling back to another sprint.
 */
export async function requireTeamIteration(
  context: TenantContext,
  teamIterationId: string,
): Promise<ResolvedTeamIteration> {
  const { data, error } = await supabaseAdmin
    .from("core_team_iterations")
    .select(
      "id, tenant_id, organization_id, project_id, team_id, iteration_id, time_zone, working_weekdays, " +
        "core_iterations(name_en, name_ar, start_date, finish_date, azure_iteration_path), " +
        "core_projects(azure_project_id, azure_project_name, process_template_kind), " +
        "core_teams(process_mapping_id), " +
        "core_organizations(base_url)",
    )
    .eq("tenant_id", context.tenantId)
    .eq("id", teamIterationId)
    .maybeSingle();

  if (error) throw new AzureDevOpsError("unknown");
  if (!data) throw new AzureDevOpsError("forbidden");

  const row = data as unknown as {
    id: string;
    tenant_id: string;
    organization_id: string;
    project_id: string;
    team_id: string;
    iteration_id: string;
    time_zone: string;
    working_weekdays: number[] | null;
    core_iterations: {
      name_en: string;
      name_ar: string;
      start_date: string | null;
      finish_date: string | null;
      azure_iteration_path: string;
    } | null;
    core_projects: {
      azure_project_id: string;
      azure_project_name: string;
      process_template_kind: ResolvedTeamIteration["processTemplateKind"];
    } | null;
    core_teams: { process_mapping_id: string | null } | null;
    core_organizations: { base_url: string } | null;
  };

  const scope = await resolveScope(context);
  if (scope.projectIds && !scope.projectIds.includes(row.project_id)) throw new AzureDevOpsError("forbidden");
  if (scope.teamIds && !scope.teamIds.includes(row.team_id)) throw new AzureDevOpsError("forbidden");

  if (!row.core_iterations || !row.core_projects) throw new AzureDevOpsError("invalid_configuration");

  return {
    teamIterationId: row.id,
    tenantId: row.tenant_id,
    organizationId: row.organization_id,
    projectId: row.project_id,
    teamId: row.team_id,
    iterationId: row.iteration_id,
    azureProjectId: row.core_projects.azure_project_id,
    azureProjectName: row.core_projects.azure_project_name,
    organizationBaseUrl: row.core_organizations?.base_url ?? "https://dev.azure.com",
    iterationPath: row.core_iterations.azure_iteration_path,
    iterationNameEn: row.core_iterations.name_en,
    iterationNameAr: row.core_iterations.name_ar,
    startDate: row.core_iterations.start_date,
    finishDate: row.core_iterations.finish_date,
    timeZone: row.time_zone,
    workingWeekdays: row.working_weekdays ?? [0, 1, 2, 3, 4],
    processMappingId: row.core_teams?.process_mapping_id ?? null,
    processTemplateKind: row.core_projects.process_template_kind,
  };
}
