import type { KpiValue, Localized, Measure, Uuid } from "@/types/domain";
import type { DashboardContractBase, Section } from "./shared";
import type { TeamLoadEntryContract } from "./overview-contract";

export interface CapacityCoverage {
  readonly membersWithCapacity: number;
  readonly membersTotal: number;
  readonly itemsWithEstimate: number;
  readonly itemsTotal: number;
}

export interface WorkloadCell {
  readonly memberId: Uuid;
  readonly stage: string;
  readonly count: number;
}

/** Payload backing the Team page. Never used for individual performance ranking. */
export interface TeamContract extends DashboardContractBase {
  readonly kpis: Section<readonly KpiValue[]>;
  readonly members: Section<readonly TeamLoadEntryContract[]>;
  readonly heatmap: Section<readonly WorkloadCell[]>;
  readonly coverage: Section<CapacityCoverage>;
  readonly unassignedWork: Section<{ readonly count: number; readonly estimate: number | null }>;
  readonly utilizationAverage: Measure;
  readonly bandsLegend: readonly { readonly band: string; readonly label: Localized }[];
}
