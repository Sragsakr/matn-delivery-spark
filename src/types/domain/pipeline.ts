import type { RecordMeta, SourceTracked, TenantScoped, Uuid } from "./common";

/** A pipeline *definition* — distinct from an individual run. */
export interface Pipeline extends TenantScoped, RecordMeta, SourceTracked {
  readonly id: Uuid;
  readonly organizationId: Uuid;
  readonly projectId: Uuid;
  readonly azurePipelineId: number;
  readonly name: string;
  readonly kind: "yaml" | "classicBuild" | "classicRelease" | "unknown";
  readonly repositoryId: Uuid | null;
  readonly defaultBranch: string | null;
  readonly folderPath: string | null;
  readonly isEnabled: boolean;
  readonly webUrl: string;
}

/** Deployable environment / stage target. */
export interface Environment extends TenantScoped, RecordMeta, SourceTracked {
  readonly id: Uuid;
  readonly projectId: Uuid;
  readonly azureEnvironmentId: number | null;
  readonly name: string;
  readonly rank: number | null;
  readonly isProduction: boolean;
}
