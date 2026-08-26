import type { CalculationStamp, IsoTimestamp, Localized, TenantScoped, Uuid } from "./common";
import type { RiskEvidence } from "./risk";

export type RecommendationSource = "rule" | "ai" | "user";
export type RecommendationStatus = "proposed" | "accepted" | "hidden" | "completed" | "expired";
export type RecommendationConfidence = "high" | "medium" | "low";

export interface Recommendation extends TenantScoped {
  readonly id: Uuid;
  readonly organizationId: Uuid;
  readonly projectId: Uuid;
  readonly teamId: Uuid | null;
  /** Canonical team-sprint reference for sprint-scoped recommendations. */
  readonly teamIterationId: Uuid | null;
  /** Derived convenience value. */
  readonly iterationId: Uuid | null;
  readonly priority: number;
  readonly title: Localized;
  readonly reason: Localized;
  readonly expectedImpact: Localized;
  readonly confidence: RecommendationConfidence;
  readonly source: RecommendationSource;
  readonly relatedRiskSignalIds: readonly Uuid[];
  readonly evidence: readonly RiskEvidence[];
  readonly relatedWorkItemIds: readonly Uuid[];
  readonly targetMemberId: Uuid | null;
  readonly targetRole: string | null;
  readonly status: RecommendationStatus;
  readonly createdAt: IsoTimestamp;
  readonly acceptedAt: IsoTimestamp | null;
  readonly hiddenAt: IsoTimestamp | null;
  readonly completedAt: IsoTimestamp | null;
  readonly stamp: CalculationStamp;
}

/** Append-only audit of every human decision on a recommendation. */
export interface RecommendationDecision extends TenantScoped {
  readonly id: Uuid;
  readonly recommendationId: Uuid;
  readonly decision: "accept" | "hide" | "complete" | "reopen";
  readonly decidedByUserId: Uuid;
  readonly decidedAt: IsoTimestamp;
  readonly comment: string | null;
}

/**
 * Contract for a future Azure write-back. Not implemented in this phase:
 * every write requires confirmation, permission, audit, idempotency and verification.
 */
export interface WriteBackIntent {
  readonly id: Uuid;
  readonly recommendationId: Uuid;
  readonly action: "comment" | "assign" | "retag" | "moveIteration" | "changeState";
  readonly targetAzureWorkItemId: number;
  readonly idempotencyKey: string;
  readonly requiresUserConfirmation: true;
  readonly requiredPermission: string;
  readonly confirmedByUserId: Uuid | null;
  readonly executedAt: IsoTimestamp | null;
  readonly verificationStatus: "pending" | "verified" | "mismatch" | "failed";
}
