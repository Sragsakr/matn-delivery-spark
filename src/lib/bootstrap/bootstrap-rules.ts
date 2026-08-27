/** Pure, testable input rules for the bootstrap flow (no I/O, no secrets). */
import type { BootstrapRejectionReason } from "./contracts";

export const RESERVED_SLUGS: readonly string[] = ["matn-demo"];
const SLUG_PATTERN = /^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$/;

export const normalizeSlug = (value: string): string => value.trim().toLowerCase();
export const normalizeName = (value: string): string => value.trim().replace(/\s+/g, " ");

/** Returns null when the payload is acceptable, else the rejection reason. */
export function validateBootstrapInput(input: {
  tenantName: string;
  tenantSlug: string;
}): BootstrapRejectionReason | null {
  const name = normalizeName(input.tenantName);
  if (name.length === 0 || name.length > 120) return "invalid_name";
  const slug = normalizeSlug(input.tenantSlug);
  if (!SLUG_PATTERN.test(slug)) return "invalid_slug";
  if (slug.startsWith("ci-") || RESERVED_SLUGS.includes(slug)) return "invalid_slug";
  return null;
}
