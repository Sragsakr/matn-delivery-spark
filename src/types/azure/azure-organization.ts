import type { AzureFieldBag } from "./azure-common";

/** Accounts API entry (https://app.vssps.visualstudio.com/_apis/accounts). */
export interface AzureOrganization {
  readonly accountId: string;
  readonly accountName: string;
  readonly accountUri: string;
  readonly properties?: AzureFieldBag;
}
