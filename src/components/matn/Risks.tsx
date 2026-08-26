import { useState } from "react";
import { ChevronDown, ExternalLink } from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useI18n } from "@/lib/i18n";
import type { Risk } from "@/data/types";
import { EmptyBlock, Iso, SectionCard, StatusPill, severityToStatus } from "./primitives";

const severityLabel = {
  critical: "status.critical",
  high: "status.atRisk",
  medium: "status.neutral",
  watch: "status.watch",
} as const;

function RiskRow({ risk, open, onToggle }: { risk: Risk; open: boolean; onToggle: () => void }) {
  const { t, locale, days } = useI18n();
  const status = severityToStatus[risk.severity];
  const panelId = `risk-panel-${risk.id}`;

  return (
    <li className="border-b border-border last:border-b-0">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={open}
        aria-controls={panelId}
        className="grid w-full grid-cols-[auto_minmax(0,1fr)_auto] items-start gap-3 px-4 py-2.5 text-start transition-colors hover:bg-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring sm:px-5"
      >
        <span className="mt-0.5 shrink-0">
          <StatusPill status={status}>{t(severityLabel[risk.severity])}</StatusPill>
        </span>
        <span className="min-w-0">
          <span className="block text-sm font-medium text-foreground">{risk.title[locale]}</span>
          <span className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground">
            <span>
              {t("risks.owner")}: <Iso>{risk.owner}</Iso>
            </span>
            <span>
              {t("risks.age")}: <Iso>{days(risk.ageDays)}</Iso>
            </span>
            <span>
              {t("risks.items")}: <Iso className="tabular-nums">{risk.items.length}</Iso>
            </span>
          </span>
        </span>
        <ChevronDown
          className={cn(
            "mt-1 size-4 shrink-0 text-muted-foreground transition-transform motion-reduce:transition-none",
            open && "rotate-180",
          )}
          aria-hidden
        />
      </button>

      {open ? (
        <div id={panelId} className="space-y-3 bg-surface px-4 pb-4 pt-1 sm:px-5">
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
              {t("risks.why")}
            </h4>
            <p className="mt-1 text-sm text-foreground">{risk.explanation[locale]}</p>
          </div>
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
              {t("risks.action")}
            </h4>
            <p className="mt-1 text-sm text-foreground">{risk.recommendation[locale]}</p>
          </div>
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
              {t("risks.items")}
            </h4>
            <ul className="mt-1 flex flex-wrap gap-2">
              {risk.items.map((item) => (
                <li
                  key={item.id}
                  className="rounded-md border border-border bg-card px-2.5 py-1 text-xs text-foreground"
                >
                  <Iso className="tabular-nums text-muted-foreground">#{item.id}</Iso>{" "}
                  {item.title[locale]}
                </li>
              ))}
            </ul>
          </div>
          <Tooltip>
            <TooltipTrigger asChild>
              <span className="inline-block">
                <Button variant="outline" size="sm" disabled aria-disabled="true">
                  <ExternalLink className="size-3.5" aria-hidden />
                  {t("risks.openAdo")}
                </Button>
              </span>
            </TooltipTrigger>
            <TooltipContent className="max-w-64 text-xs">{t("risks.adoDisabled")}</TooltipContent>
          </Tooltip>
        </div>
      ) : null}
    </li>
  );
}

export function RisksCard({ risks }: { risks: Risk[] }) {
  const { t } = useI18n();
  const [openId, setOpenId] = useState<string | null>(null);

  return (
    <SectionCard
      title={t("risks.title")}
      subtitle={t("risks.subtitle")}
      bodyClassName="p-0"
      action={
        <Button
          variant="ghost"
          size="sm"
          className="text-xs"
          onClick={() => toast.info(t("risks.adoDisabled"))}
        >
          {t("risks.viewAll")}
        </Button>
      }
    >
      {risks.length === 0 ? (
        <div className="p-4">
          <EmptyBlock />
        </div>
      ) : (
        <ul>
          {risks.slice(0, 5).map((risk) => (
            <RiskRow
              key={risk.id}
              risk={risk}
              open={openId === risk.id}
              onToggle={() => setOpenId((cur) => (cur === risk.id ? null : risk.id))}
            />
          ))}
        </ul>
      )}
    </SectionCard>
  );
}
