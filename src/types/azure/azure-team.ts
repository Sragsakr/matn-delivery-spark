/** GET {org}/_apis/projects/{project}/teams */
export interface AzureTeam {
  readonly id: string;
  readonly name: string;
  readonly description?: string;
  readonly url: string;
  readonly identityUrl?: string;
  readonly projectId?: string;
  readonly projectName?: string;
}

/** GET {org}/{project}/{team}/_apis/work/teamsettings/teamfieldvalues */
export interface AzureTeamFieldValues {
  readonly field: { readonly referenceName: string };
  readonly defaultValue: string;
  readonly values: readonly { readonly value: string; readonly includeChildren: boolean }[];
}
