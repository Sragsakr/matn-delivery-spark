import { createFileRoute } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { AppShell } from "@/components/matn/AppShell";
import { useI18n, type TKey } from "@/lib/i18n";
import { Iso } from "@/components/matn/primitives";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  discoverAzureProjects,
  getAzureSyncStatus,
  runAzureFoundationSync,
  validateAzureConnection,
} from "@/lib/azure/azure.functions";
import { SYNC_DOMAINS, type SyncDomain, type SyncRunReport } from "@/lib/azure/contracts";
import type { AzureFailure } from "@/lib/azure/errors";

export const Route = createFileRoute("/_authenticated/settings/azure")({
  head: () => ({
    meta: [
      { title: "Azure DevOps Connection — MATN Delivery Intelligence" },
      {
        name: "description",
        content: "Validate the read-only Azure DevOps connection and run the foundation synchronization.",
      },
      { property: "og:title", content: "Azure DevOps Connection — MATN Delivery Intelligence" },
      {
        property: "og:description",
        content: "Validate the read-only Azure DevOps connection and run the foundation synchronization.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: AzureSettingsPage,
});

const errorKey = (failure: AzureFailure): TKey => `azure.error.${failure.code}` as TKey;

function StatusBadge({ status }: { status: string }) {
  const { t } = useI18n();
  const tone =
    status === "connected"
      ? "bg-emerald-500/12 text-emerald-700 dark:text-emerald-300"
      : status === "error"
        ? "bg-destructive/12 text-destructive"
        : "bg-muted text-muted-foreground";
  return (
    <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${tone}`}>
      {t(`azure.status.${status}` as TKey)}
    </span>
  );
}

function ReportTable({ report }: { report: SyncRunReport }) {
  const { t, locale } = useI18n();
  const fmt = (value: string | null) =>
    value ? new Date(value).toLocaleString(locale === "ar" ? "ar-SA" : "en-GB") : "—";

  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[36rem] text-sm">
        <caption className="sr-only">{t("azure.lastRun")}</caption>
        <thead>
          <tr className="text-start text-xs uppercase tracking-wide text-muted-foreground">
            <th scope="col" className="py-2 text-start">{t("azure.domain")}</th>
            <th scope="col" className="py-2 text-start">{t("azure.discovered")}</th>
            <th scope="col" className="py-2 text-start">{t("azure.inserted")}</th>
            <th scope="col" className="py-2 text-start">{t("azure.updated")}</th>
            <th scope="col" className="py-2 text-start">{t("azure.missing")}</th>
            <th scope="col" className="py-2 text-start">{t("azure.failed")}</th>
            <th scope="col" className="py-2 text-start">{t("azure.freshness")}</th>
          </tr>
        </thead>
        <tbody>
          {SYNC_DOMAINS.map((domain: SyncDomain) => {
            const counts = report.domains[domain];
            return (
              <tr key={domain} className="border-t border-border/60">
                <th scope="row" className="py-2 text-start font-medium">
                  {t(`azure.domain.${domain}` as TKey)}{" "}
                  <Badge variant={counts.complete ? "secondary" : "destructive"} className="ms-1 align-middle">
                    {counts.complete ? t("azure.complete") : t("azure.partial")}
                  </Badge>
                </th>
                <td className="py-2"><Iso>{counts.discovered}</Iso></td>
                <td className="py-2"><Iso>{counts.inserted}</Iso></td>
                <td className="py-2"><Iso>{counts.updated}</Iso></td>
                <td className="py-2"><Iso>{counts.missing}</Iso></td>
                <td className="py-2"><Iso>{counts.failed}</Iso></td>
                <td className="py-2 text-muted-foreground"><Iso>{fmt(counts.freshnessAt)}</Iso></td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function AzureSettingsPage() {
  const { t } = useI18n();
  const queryClient = useQueryClient();
  const fetchStatus = useServerFn(getAzureSyncStatus);
  const validate = useServerFn(validateAzureConnection);
  const discover = useServerFn(discoverAzureProjects);
  const sync = useServerFn(runAzureFoundationSync);

  const statusQuery = useQuery({
    queryKey: ["azure", "status"],
    queryFn: () => fetchStatus({ data: { tenantId: null } }),
  });

  const validateMutation = useMutation({
    mutationFn: () => validate({ data: { tenantId: null } }),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["azure", "status"] }),
  });
  const discoverMutation = useMutation({ mutationFn: () => discover({ data: { tenantId: null } }) });
  const syncMutation = useMutation({
    mutationFn: () => sync({ data: { tenantId: null } }),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["azure", "status"] }),
  });

  const status = statusQuery.data;
  const busy = validateMutation.isPending || discoverMutation.isPending || syncMutation.isPending;
  const report = syncMutation.data ?? status?.lastRun ?? null;
  const failure = validateMutation.data?.error ?? discoverMutation.data?.error ?? report?.error ?? null;

  return (
    <AppShell>
      <div className="mx-auto w-full max-w-5xl space-y-6">
        <header className="space-y-1">
          <h1 className="text-xl font-semibold tracking-tight sm:text-2xl">{t("azure.title")}</h1>
          <p className="max-w-2xl text-sm text-muted-foreground">{t("azure.subtitle")}</p>
        </header>

        <Card>
          <CardHeader className="flex-row items-start justify-between gap-4 space-y-0">
            <div>
              <CardTitle className="text-base">{t("azure.status")}</CardTitle>
              <CardDescription>
                {t("azure.organization")}: <Iso>{status?.organization ?? "—"}</Iso>
              </CardDescription>
            </div>
            <StatusBadge status={status?.connectionStatus ?? "unconfigured"} />
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-sm text-muted-foreground">
              {t("azure.lastVerified")}:{" "}
              <Iso>{status?.lastVerifiedAt ? new Date(status.lastVerifiedAt).toLocaleString() : t("azure.never")}</Iso>
            </p>

            {status && !status.configured ? (
              <p role="status" className="rounded-md bg-muted p-3 text-sm">{t("azure.notConfigured")}</p>
            ) : null}
            {status && status.configured && !status.canSync ? (
              <p role="status" className="rounded-md bg-muted p-3 text-sm">{t("azure.noPermission")}</p>
            ) : null}
            {status?.activeRun ? (
              <p role="status" className="rounded-md bg-muted p-3 text-sm">{t("azure.activeRun")}</p>
            ) : null}
            {failure ? (
              <p role="alert" className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">
                {t(errorKey(failure))}
              </p>
            ) : null}
            {report ? (
              <p className="text-sm text-muted-foreground">{t(`azure.next.${report.nextSafeAction}` as TKey)}</p>
            ) : null}

            <div className="flex flex-wrap gap-2">
              <Button
                onClick={() => validateMutation.mutate()}
                disabled={busy || !status?.canValidate}
              >
                {validateMutation.isPending ? t("azure.running") : t("azure.validate")}
              </Button>
              <Button
                variant="secondary"
                onClick={() => discoverMutation.mutate()}
                disabled={busy || !status?.canSync}
              >
                {discoverMutation.isPending ? t("azure.running") : t("azure.discover")}
              </Button>
              <Button
                variant="outline"
                onClick={() => syncMutation.mutate()}
                disabled={busy || !status?.canSync || Boolean(status?.activeRun)}
              >
                {syncMutation.isPending ? t("azure.running") : t("azure.sync")}
              </Button>
            </div>
          </CardContent>
        </Card>

        {discoverMutation.data ? (
          <Card>
            <CardHeader>
              <CardTitle className="text-base">{t("azure.projects")}</CardTitle>
            </CardHeader>
            <CardContent>
              {discoverMutation.data.projects.length === 0 ? (
                <p className="text-sm text-muted-foreground">{t("azure.projectsEmpty")}</p>
              ) : (
                <ul className="grid gap-2 sm:grid-cols-2">
                  {discoverMutation.data.projects.map((project) => (
                    <li key={project.azureProjectId} className="rounded-md border border-border/60 p-3 text-sm">
                      <span className="font-medium"><Iso>{project.name}</Iso></span>
                      <span className="block text-xs text-muted-foreground"><Iso>{project.state}</Iso></span>
                    </li>
                  ))}
                </ul>
              )}
            </CardContent>
          </Card>
        ) : null}

        {report ? (
          <Card>
            <CardHeader>
              <CardTitle className="text-base">{t("azure.lastRun")}</CardTitle>
              <CardDescription>
                <Iso>{report.runId}</Iso>
              </CardDescription>
            </CardHeader>
            <CardContent>
              <ReportTable report={report} />
            </CardContent>
          </Card>
        ) : null}
      </div>
    </AppShell>
  );
}
