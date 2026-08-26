import type { IsoTimestamp, RecordMeta, TenantScoped, Uuid } from "./common";

export type TestRunState = "notStarted" | "inProgress" | "completed" | "aborted" | "unknown";

export interface TestRun extends TenantScoped, RecordMeta {
  readonly id: Uuid;
  readonly organizationId: Uuid;
  readonly projectId: Uuid;
  readonly azureTestRunId: number;
  readonly name: string;
  readonly buildId: Uuid | null;
  readonly deploymentId: Uuid | null;
  readonly state: TestRunState;
  readonly isAutomated: boolean;
  readonly startedAt: IsoTimestamp | null;
  readonly completedAt: IsoTimestamp | null;
  /** True when the run only covers a subset (e.g. smoke, not regression). */
  readonly isRegressionSuite: boolean;
  readonly webUrl: string;
}

/** Aggregated outcome of a run. Executed = total - notExecuted. */
export interface TestResultSummary extends TenantScoped, RecordMeta {
  readonly id: Uuid;
  readonly testRunId: Uuid;
  readonly totalTests: number;
  readonly passedTests: number;
  readonly failedTests: number;
  readonly blockedTests: number;
  readonly notExecutedTests: number;
  readonly executedTests: number;
  /** passedTests / executedTests * 100; null when nothing executed. */
  readonly passRate: number | null;
  readonly durationSeconds: number | null;
  readonly failedWorkItemIds: readonly Uuid[];
}
