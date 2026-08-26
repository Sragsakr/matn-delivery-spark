import type { IsoDate, IsoTimestamp, Localized, RecordMeta, TenantScoped, TimeZone, Uuid } from "./common";

/** Lifecycle of a sprint relative to "now". */
export type IterationPhase = "future" | "current" | "completed" | "undated";

/** A non-working day inside an iteration (weekend, public holiday, team day off). */
export interface NonWorkingDay {
  readonly date: IsoDate;
  readonly kind: "weekend" | "holiday" | "team_off";
  readonly label: Localized | null;
}

/** Azure iteration node bound to a team. Current-state record. */
export interface Iteration extends TenantScoped, RecordMeta {
  readonly id: Uuid;
  readonly organizationId: Uuid;
  readonly projectId: Uuid;
  /** Iterations are project nodes; the same node may be shared by many teams. */
  readonly teamId: Uuid | null;
  readonly azureIterationId: string;
  readonly azureIterationPath: string;
  readonly name: Localized;
  /** Null when the sprint has no dates configured in Azure. */
  readonly startDate: IsoDate | null;
  readonly finishDate: IsoDate | null;
  /** Time zone used to resolve day boundaries; falls back to the team default. */
  readonly timeZone: TimeZone;
  readonly phase: IterationPhase;
}

/** Derived sprint calendar; all progress math uses working days. */
export interface SprintCalendar {
  readonly iterationId: Uuid;
  readonly teamId: Uuid;
  readonly timeZone: TimeZone;
  /** Weekday numbers considered working days (0 = Sunday). */
  readonly workingWeekdays: readonly number[];
  readonly nonWorkingDays: readonly NonWorkingDay[];
  readonly totalWorkingDays: number | null;
  readonly elapsedWorkingDays: number | null;
  /** 1-based current day, null for undated or non-current sprints. */
  readonly currentWorkingDay: number | null;
  /** elapsedWorkingDays / totalWorkingDays * 100, null when dates are missing. */
  readonly elapsedPercentage: number | null;
  readonly computedAt: IsoTimestamp;
}
