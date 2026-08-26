import type { AzureFieldBag } from "./azure-common";

/** GET {org}/_apis/projects */
export interface AzureProject {
  readonly id: string;
  readonly name: string;
  readonly description?: string;
  readonly url: string;
  readonly state: "wellFormed" | "createPending" | "deleting" | "new" | "unchanged" | "deleted";
  readonly revision?: number;
  readonly visibility?: "private" | "public" | "organization" | "unchanged";
  readonly lastUpdateTime?: string;
  readonly capabilities?: AzureFieldBag;
}

/** GET {org}/_apis/projects/{id}/properties — carries System.ProcessTemplate. */
export interface AzureProjectProperty {
  readonly name: string;
  readonly value: string;
}
