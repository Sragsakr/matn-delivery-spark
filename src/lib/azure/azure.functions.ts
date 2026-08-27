/**
 * Azure DevOps server operations (thin RPC wrappers only).
 * Every handler: validated bearer token -> tenant + role check -> audit -> sanitized DTO.
 */
import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import type {
  ConnectionValidationResult,
  ProjectDiscoveryResult,
  SyncStatusResult,
} from "./contracts";
import type { JobState } from "./job-rules";

const tenantInput = z.object({ tenantId: z.string().uuid().nullish() }).default({ tenantId: null });

export const getAzureSyncStatus = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => tenantInput.parse(data ?? {}))
  .handler(async ({ context, data }): Promise<SyncStatusResult> => {
    const { readSyncStatus } = await import("./operations.server");
    return readSyncStatus(context.userId, data.tenantId ?? null);
  });

export const validateAzureConnection = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => tenantInput.parse(data ?? {}))
  .handler(async ({ context, data }): Promise<ConnectionValidationResult> => {
    const { validateConnection } = await import("./operations.server");
    return validateConnection(context.userId, data.tenantId ?? null);
  });

export const discoverAzureProjects = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => tenantInput.parse(data ?? {}))
  .handler(async ({ context, data }): Promise<ProjectDiscoveryResult> => {
    const { discoverProjects } = await import("./operations.server");
    return discoverProjects(context.userId, data.tenantId ?? null);
  });

export const startAzureFoundationSync = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => tenantInput.parse(data ?? {}))
  .handler(async ({ context, data }): Promise<JobState> => {
    const { startFoundationSync } = await import("./operations.server");
    return startFoundationSync(context.userId, data.tenantId ?? null);
  });

const runInput = z.object({ tenantId: z.string().uuid().nullish(), runId: z.string().uuid() });

export const advanceAzureFoundationSync = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => runInput.parse(data))
  .handler(async ({ context, data }): Promise<JobState> => {
    const { advanceFoundationSync } = await import("./operations.server");
    return advanceFoundationSync(context.userId, data.tenantId ?? null, data.runId);
  });

export const cancelAzureFoundationSync = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => runInput.parse(data))
  .handler(async ({ context, data }): Promise<{ cancelled: true }> => {
    const { cancelFoundationSync } = await import("./operations.server");
    await cancelFoundationSync(context.userId, data.tenantId ?? null, data.runId);
    return { cancelled: true };
  });
