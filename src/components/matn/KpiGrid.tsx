import { useState } from "react";
import { ArrowDownRight, ArrowUpRight, ChevronLeft, Info, Minus } from "lucide-react";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import { useI18n, type TKey } from "@/lib/i18n";
import type { KpiMetric } from "@/data/types";
import { StatusPill, statusDot } from "./primitives";

const statusKey: Record<KpiMetric["status"], TKey> = {
  healthy: "status.healthy",
  atRisk: "status.atRisk",
  critical: "status.critical",
  neutral: "status.neutral",
};

function formatValue(kpi: KpiMetric) {
  if (kpi.unit === "percent") return `${kpi.value}%`;
  if (kpi.unit === "delta") return `${kpi.value > 0 ? "+" : ""}${kpi.value}%`;
  return String(kpi.value);
}

function Sparkline({ values, status }: { values: number[]; status: KpiMetric["status"] }) {
  const max = Math.max(...values, 1);
  const min = Math.min(...values, 0);
  const span = max - min || 1;
  const points = values
    .map((v, i) => `${(i / (values.length - 1)) * 100},${28 - ((v - min) / span) * 24}`)
    .join(" ");
  const stroke =
    status === "critical"
      ? "var(--critical)"
      : status === "atRisk"
        ? "var(--warning)"
        : status === "healthy"
          ? "var(--success)"
          : "var(--muted-foreground)";
  return (
    <svg viewBox="0 0 100 30" preserveAspectRatio="none" className="h-8 w-full" aria-hidden>
      <polyline fill="none" stroke={stroke} strokeWidth="2" points={points} vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

function KpiCard({ kpi, onOpen }: { kpi: KpiMetric; onOpen: () => void }) {
  const { t } = useI18n();
  const diff = kpi.value - kpi.comparison.value;
  const DiffIcon = diff > 0 ? ArrowUpRight : diff < 0 ? ArrowDownRight : Minus;

  return (
    <button
      type="button"
      onClick={onOpen}
      className="group flex flex-col gap-3 rounded-lg border border-border bg-card p-4 text-start shadow-card transition-colors hover:border-azure/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
    >
      <div className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-2">
        <span className="min-w-0 truncate text-[13px] font-medium text-muted-foreground">
          {t(kpi.labelKey as TKey)}
        </span>
        <Tooltip>
          <TooltipTrigger asChild>
            <span
              className="shrink-0 rounded p-0.5 text-muted-foreground hover:text-foreground"
              role="button"
              tabIndex={0}
              aria-label={t(kpi.tooltipKey as TKey)}
              onClick={(e) => e.stopPropagation()}
            >
              <Info className="size-3.5" aria-hidden />
            </span>
          </TooltipTrigger>
          <TooltipContent className="max-w-64 text-xs">{t(kpi.tooltipKey as TKey)}</TooltipContent>
        </Tooltip>
      </div>

      <div className="flex items-end justify-between gap-2">
        <span className="text-3xl font-semibold tabular-nums tracking-tight text-foreground">
          {formatValue(kpi)}
        </span>
        <StatusPill status={kpi.status}>{t(statusKey[kpi.status])}</StatusPill>
      </div>

      <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
        <DiffIcon
          className={cn(
            "size-3.5 shrink-0",
            diff === 0 ? "text-muted-foreground" : diff > 0 ? "text-success" : "text-critical",
          )}
          aria-hidden
        />
        <span className="tabular-nums">
          {diff > 0 ? "+" : ""}
          {diff}
        </span>
        <span className="truncate">
          {kpi.comparison.kind === "previous"
            ? t("kpi.vsPrevious")
            : `${t("kpi.target")} ${kpi.comparison.value}%`}
        </span>
      </div>

      <Sparkline values={kpi.trend.map((p) => p.value)} status={kpi.status} />

      <p className="text-xs leading-relaxed text-muted-foreground">{t(kpi.explanationKey as TKey)}</p>

      <span className="mt-auto inline-flex items-center gap-1 text-xs font-medium text-azure">
        {t("kpi.openDetails")}
        <ChevronLeft className="size-3.5 ltr:rotate-180" aria-hidden />
      </span>
    </button>
  );
}

export function KpiGrid({ kpis, loading }: { kpis: KpiMetric[]; loading?: boolean }) {
  const { t, locale } = useI18n();
  const [selected, setSelected] = useState<KpiMetric | null>(null);

  if (loading) {
    return (
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton key={i} className="h-52 w-full rounded-lg" />
        ))}
      </div>
    );
  }

  return (
    <>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {kpis.map((kpi) => (
          <KpiCard key={kpi.id} kpi={kpi} onOpen={() => setSelected(kpi)} />
        ))}
      </div>

      <Sheet open={!!selected} onOpenChange={(o) => !o && setSelected(null)}>
        <SheetContent
          side={locale === "ar" ? "left" : "right"}
          className="w-full overflow-y-auto sm:max-w-md"
        >
          {selected ? (
            <>
              <SheetHeader>
                <SheetTitle className="flex items-center gap-2">
                  <span className={cn("size-2 rounded-full", statusDot[selected.status])} aria-hidden />
                  {t(selected.labelKey as TKey)}
                </SheetTitle>
                <SheetDescription>{t(selected.tooltipKey as TKey)}</SheetDescription>
              </SheetHeader>

              <div className="space-y-6 px-4 pb-8">
                <div className="flex items-end gap-3">
                  <span className="text-4xl font-semibold tabular-nums text-foreground">
                    {formatValue(selected)}
                  </span>
                  <StatusPill status={selected.status}>{t(statusKey[selected.status])}</StatusPill>
                </div>

                <div>
                  <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                    {t("kpi.whatChanged")}
                  </h3>
                  <ul className="space-y-2">
                    {selected.drivers.map((d, i) => (
                      <li key={i} className="flex gap-2 text-sm text-foreground">
                        <span className="mt-1.5 size-1.5 shrink-0 rounded-full bg-azure" aria-hidden />
                        <span>{d[locale]}</span>
                      </li>
                    ))}
                  </ul>
                </div>

                <div>
                  <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                    {t("kpi.trend")}
                  </h3>
                  <div className="grid grid-cols-5 gap-2">
                    {selected.trend.map((p) => (
                      <div key={p.label} className="rounded-md border border-border bg-surface p-2 text-center">
                        <div className="text-[11px] text-muted-foreground">{p.label}</div>
                        <div className="text-sm font-semibold tabular-nums text-foreground">{p.value}</div>
                      </div>
                    ))}
                  </div>
                </div>

                <div>
                  <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                    {t("kpi.howCalculated")}
                  </h3>
                  <p className="text-sm text-muted-foreground">{selected.formula[locale]}</p>
                </div>

                <div>
                  <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                    {t("kpi.relatedItems")}
                  </h3>
                  {selected.relatedItems.length === 0 ? (
                    <p className="text-sm text-muted-foreground">{t("state.empty.title")}</p>
                  ) : (
                    <ul className="space-y-2">
                      {selected.relatedItems.map((item) => (
                        <li
                          key={item.id}
                          className="grid grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-2 rounded-md border border-border bg-surface px-3 py-2"
                        >
                          <span className="shrink-0 text-xs tabular-nums text-muted-foreground">#{item.id}</span>
                          <span className="min-w-0 truncate text-sm text-foreground">{item.title[locale]}</span>
                          <span className="shrink-0 text-[11px] text-muted-foreground">{item.state[locale]}</span>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
              </div>
            </>
          ) : null}
        </SheetContent>
      </Sheet>
    </>
  );
}
