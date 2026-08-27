/** Thin RPC wrappers for the first-administrator bootstrap flow. */
import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import type { BootstrapResult, BootstrapState } from "./contracts";

const bootstrapInput = z.object({
  tenantName: z.string().min(1).max(120),
  tenantSlug: z.string().min(3).max(40),
});

export const getBootstrapState = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<BootstrapState> => {
    const { readBootstrapState } = await import("./bootstrap.server");
    return readBootstrapState(context.userId);
  });

export const bootstrapFirstTenantAdmin = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => bootstrapInput.parse(data))
  .handler(async ({ context, data }): Promise<BootstrapResult> => {
    const { bootstrapFirstTenantAdminServer } = await import("./bootstrap.server");
    return bootstrapFirstTenantAdminServer(context.userId, data);
  });
