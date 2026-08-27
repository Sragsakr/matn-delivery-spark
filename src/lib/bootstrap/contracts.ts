/** Client-safe DTOs for the first-administrator bootstrap flow. */

export type BootstrapRejectionReason =
  | "unauthenticated"
  | "email_unverified"
  | "invalid_identity"
  | "invalid_name"
  | "invalid_slug"
  | "tenant_exists"
  | "already_member"
  | "already_provisioned"
  | "unknown";

export interface BootstrapState {
  /** True once a real (non-demo) workspace exists anywhere in the system. */
  readonly hasRealTenant: boolean;
  /** True when the caller is already linked to a workspace. */
  readonly hasMembership: boolean;
  readonly emailVerified: boolean;
}

export type BootstrapResult =
  | { readonly status: "created"; readonly tenantSlug: string }
  | { readonly status: "rejected"; readonly reason: BootstrapRejectionReason };
