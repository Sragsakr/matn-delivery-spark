import type { AzureIdentityRef } from "./azure-common";

/** GET {org}/{project}/{team}/_apis/work/teamsettings/iterations/{id}/capacities */
export interface AzureTeamMemberCapacity {
  readonly teamMember: AzureIdentityRef;
  readonly activities: readonly { readonly capacityPerDay: number; readonly name: string | null }[];
  readonly daysOff: readonly { readonly start: string; readonly end: string }[];
  readonly url?: string;
}
