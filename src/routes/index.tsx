import { createFileRoute } from "@tanstack/react-router";
import { Sparkles } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { AppShell } from "@/components/matn/AppShell";
import { KpiGrid } from "@/components/matn/KpiGrid";
import { TrajectoryCard } from "@/components/matn/Trajectory";
import { RisksCard } from "@/components/matn/Risks";
import { FunnelCard } from "@/components/matn/Funnel";
import { TeamLoadCard } from "@/components/matn/TeamLoad";
import { EngineeringHealthCard } from "@/components/matn/EngineeringHealth";
import { RecommendedActionsCard } from "@/components/matn/RecommendedActions";
import { ErrorBlock, LoadingBlock, Notice, SectionCard } from "@/components/matn/primitives";
import { useI18n } from "@/lib/i18n";
import { useWorkspace } from "@/data/workspace";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "MATN Delivery Intelligence — Executive Overview" },
      {
        name: "description",
        content:
          "Executive delivery command center: sprint confidence, trajectory forecast, risks, team load, and recommended actions in Arabic and English.",
      },
      { property: "og:title", content: "MATN Delivery Intelligence — Executive Overview" },
      {
        property: "og:description",
        content:
          "Sprint confidence, trajectory forecast, risks, team load, and recommended actions in one executive view.",
      },
    ],
  }),
  component: OverviewPage,
});

function OverviewPage() {
  const { t, locale } = useI18n();
  const { snapshot, iteration, loading, error, refresh } = useWorkspace();

  return (
    <AppShell>
      <div className="mx-auto flex w-full max-w-[1400px] flex-col gap-6">
        <header className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-4">
          <div className="min-w-0">
            <h1 className="text-xl font-semibold tracking-tight text-foreground sm:text-2xl">
              {t("overview.title")}
            </h1>
            <p className="mt-1 text-sm text-muted-foreground">{t("overview.subtitle")}</p>
            {iteration ? (
              <p className="mt-2 text-xs text-muted-foreground">
                <span className="font-medium text-foreground">{iteration.name[locale]}</span>
                {" · "}
                {t("overview.sprintDay", { a: iteration.currentDay, b: iteration.totalDays })}
              </p>
            ) : null}
          </div>
          <Button
            variant="outline"
            size="sm"
            className="shrink-0"
            onClick={() => toast.info(t("overview.copilotSoon"))}
          >
            <Sparkles className="size-3.5" aria-hidden />
            <span className="hidden sm:inline">{t("overview.askCopilot")}</span>
          </Button>
        </header>

        {error ? (
          <SectionCard title={t("state.error.title")}>
            <ErrorBlock onRetry={refresh} />
          </SectionCard>
        ) : (
          <>
            {!loading && snapshot && snapshot.freshness === "stale" ? (
              <Notice tone="warning" title={t("state.stale.title")} body={t("state.stale.body")} />
            ) : null}

            <KpiGrid kpis={snapshot?.kpis ?? []} loading={loading} />

            <div className="grid gap-6 xl:grid-cols-[1.35fr_1fr]">
              {loading || !snapshot ? (
                <SectionCard title={t("trajectory.title")}>
                  <LoadingBlock rows={5} />
                </SectionCard>
              ) : (
                <TrajectoryCard
                  trajectory={snapshot.trajectory}
                  currentDay={iteration?.currentDay ?? 0}
                />
              )}

              {loading || !snapshot ? (
                <SectionCard title={t("risks.title")}>
                  <LoadingBlock rows={5} />
                </SectionCard>
              ) : (
                <RisksCard risks={snapshot.risks} />
              )}
            </div>

            {loading || !snapshot ? (
              <SectionCard title={t("funnel.title")}>
                <LoadingBlock rows={2} />
              </SectionCard>
            ) : (
              <FunnelCard stages={snapshot.funnel} />
            )}

            <div className="grid gap-6 xl:grid-cols-[1.35fr_1fr]">
              {loading || !snapshot ? (
                <SectionCard title={t("team.title")}>
                  <LoadingBlock rows={5} />
                </SectionCard>
              ) : (
                <TeamLoadCard members={snapshot.teamLoad} />
              )}

              {loading || !snapshot ? (
                <SectionCard title={t("eng.title")}>
                  <LoadingBlock rows={4} />
                </SectionCard>
              ) : (
                <EngineeringHealthCard data={snapshot.engineering} />
              )}
            </div>

            {loading || !snapshot ? (
              <SectionCard title={t("actions.title")}>
                <LoadingBlock rows={3} />
              </SectionCard>
            ) : (
              <RecommendedActionsCard actions={snapshot.actions} />
            )}
          </>
        )}
      </div>
    </AppShell>
  );
}
