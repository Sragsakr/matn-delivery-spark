import type { IsoDate, IsoTimestamp, CalculationStamp, TenantScoped, Uuid } from "./common";

/**
 * Daily snapshots are append-only. A later sync may add a missing day but must
 * never rewrite a day that was already closed.
 */
interface SnapshotBase extends TenantScoped {
  readonly id: Uuid;
  /** Snapshot business date in the tenant/team time zone. */
  readonly snapshotDate: IsoDate;
  readonly capturedAt: IsoTimestamp;
  readonly stamp: CalculationStamp;
  /** True when some source domains were stale/missing at capture time. */
  readonly isPartial: boolean;
}

export interface DailyProjectSnapshot extends SnapshotBase {
  readonly projectId: Uuid;
  readonly openWorkItems: number;
  readonly completedWorkItems: number;
  readonly activeBugs: number;
  readonly criticalBugs: number;
  readonly activePullRequests: number;
  readonly buildSuccessRate: number | null;
  readonly deploymentCount: number;
}

export interface DailyIterationSnapshot extends SnapshotBase {
  readonly iterationId: Uuid;
  readonly teamId: Uuid;
  readonly workingDayIndex: number | null;
  readonly totalWorkingDays: number | null;
  readonly originalScopeEstimate: number | null;
  readonly currentScopeEstimate: number | null;
  readonly completedEstimate: number | null;
  readonly remainingEstimate: number | null;
  readonly scopeAddedEstimate: number;
  readonly scopeRemovedEstimate: number;
  readonly blockedItemCount: number;
  readonly blockedEstimate: number | null;
  readonly itemsByStateCategory: Readonly<Record<string, number>>;
}

export interface DailyTeamSnapshot extends SnapshotBase {
  readonly teamId: Uuid;
  readonly iterationId: Uuid | null;
  readonly availableCapacityHours: number | null;
  readonly assignedRemainingHours: number | null;
  readonly utilizationPercentage: number | null;
  readonly activeMemberCount: number;
}

export interface DailyMemberSnapshot extends SnapshotBase {
  readonly memberId: Uuid;
  readonly teamId: Uuid;
  readonly iterationId: Uuid | null;
  readonly availableCapacityHours: number | null;
  readonly assignedRemainingHours: number | null;
  readonly activeItemCount: number;
  readonly blockedItemCount: number;
  readonly utilizationPercentage: number | null;
}
