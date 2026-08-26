/**
 * Raw Azure DevOps REST payload shapes (subset we consume).
 * These mirror the wire format only — never render them directly.
 */
import type { JsonValue } from "../domain/common";

/** Azure identity reference as embedded in work items, PRs and builds. */
export interface AzureIdentityRef {
  readonly id?: string;
  readonly displayName: string;
  readonly uniqueName?: string;
  readonly descriptor?: string;
  readonly imageUrl?: string;
  readonly url?: string;
}

/** Standard paged list envelope. */
export interface AzureListResponse<T> {
  readonly count: number;
  readonly value: readonly T[];
  /** Present when the endpoint supports continuation tokens. */
  readonly continuationToken?: string;
}

/** Unmapped fields are preserved as JSON-safe values, never `any`. */
export type AzureFieldBag = Readonly<Record<string, JsonValue>>;

export interface AzureLink {
  readonly href: string;
}
export type AzureLinks = Readonly<Record<string, AzureLink>>;
