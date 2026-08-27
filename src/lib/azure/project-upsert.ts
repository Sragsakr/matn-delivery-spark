/**
 * Pure reconciliation rules for the tenant-scoped Azure project natural key
 * (tenant_id, organization_id, azure_project_id).
 *
 * Immutable identity/ownership columns (id, tenant_id, organization_id,
 * azure_project_id, created_at) are never part of an update payload.
 * `name_ar` is insert-only: it is locally editable and must not be clobbered.
 * Freshness columns (last_seen_at / last_synced_at) are not content and are
 * refreshed separately so unchanged rows are never tombstoned.
 */

export interface ProjectSourceFields {
  readonly azureProjectId: string;
  readonly name: string;
  readonly description: string | null;
  readonly state: string;
  readonly visibility: string | null;
  readonly processTemplateKind: string;
}

export interface ExistingProjectRow {
  readonly id: string;
  readonly azure_project_id: string;
  readonly azure_project_name: string | null;
  readonly name_en: string | null;
  readonly description: string | null;
  readonly process_template_kind: string | null;
  readonly visibility: string | null;
  readonly state: string | null;
  readonly source_status: string | null;
  readonly is_deleted: boolean | null;
}

export interface ProjectMutablePayload {
  readonly azure_project_name: string;
  readonly name_en: string;
  readonly description: string | null;
  readonly process_template_kind: string;
  readonly visibility: string | null;
  readonly state: string;
  readonly source_status: string;
  readonly is_deleted: boolean;
}

/** Columns that must never appear in an update payload. */
export const IMMUTABLE_PROJECT_COLUMNS = [
  "id",
  "tenant_id",
  "organization_id",
  "azure_project_id",
  "created_at",
  "name_ar",
] as const;

const normText = (value: string | null | undefined): string | null => {
  if (value === null || value === undefined) return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
};

/** Normalized mutable field set derived from the Azure response. */
export function mutableProjectPayload(source: ProjectSourceFields): ProjectMutablePayload {
  return {
    azure_project_name: normText(source.name) ?? source.azureProjectId,
    name_en: normText(source.name) ?? source.azureProjectId,
    description: normText(source.description),
    process_template_kind: source.processTemplateKind,
    visibility: normText(source.visibility),
    state: normText(source.state) ?? "unknown",
    source_status: "active",
    is_deleted: false,
  };
}

/**
 * Returns null when the existing row already matches the source
 * (unchanged), otherwise the mutable-only update payload.
 */
export function diffProject(
  existing: ExistingProjectRow,
  source: ProjectSourceFields,
): ProjectMutablePayload | null {
  const next = mutableProjectPayload(source);
  const same =
    normText(existing.azure_project_name) === next.azure_project_name &&
    normText(existing.name_en) === next.name_en &&
    normText(existing.description) === next.description &&
    (existing.process_template_kind ?? null) === next.process_template_kind &&
    normText(existing.visibility) === next.visibility &&
    normText(existing.state) === next.state &&
    (existing.source_status ?? null) === next.source_status &&
    (existing.is_deleted ?? false) === next.is_deleted;
  return same ? null : next;
}

export interface DomainCountLike {
  readonly discovered: number;
  readonly inserted: number;
  readonly updated: number;
  readonly unchanged: number;
  readonly failed: number;
}

/** read = inserted + updated + unchanged + failed */
export function countsBalance(counts: DomainCountLike): boolean {
  return counts.discovered === counts.inserted + counts.updated + counts.unchanged + counts.failed;
}
