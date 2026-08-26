import { useState } from "react";
import { ChevronDown, ExternalLink } from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n";
import type { Risk } from "@/data/types";
import { SectionCard, StatusPill, severityToStatus } from "./primitives";

const severityLabel = {
  critical: "status.critical",
  high: "status.atRisk",
  medium: "status.neutral",
} as const;

function RiskRow({ risk, index }: { risk: Risk; index: number }) {
  const { t, locale } = useI18n();
  const [open, setOpen] = useState(index === 0);
  const status = severityToStatus[risk.severity];

  return (
    <li className="border-b border-border last:border-b-0">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="grid w-full grid-cols-[auto_minmax(0,1fr)_auto] items-start gap-3 px-4 py-3 text-start transition-colors hover:bg-surface focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring sm:px-5"
      >
        <span className="mt-0.5 shrink-0">
          <StatusPill status={status}>{t(severityLabel[risk.severity])}</StatusPill>
        </span>
        <span className="min-w-0">
          <span className="block text-sm font-medium text-foreground">{risk.title[locale]}</span>
          <span className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground">
            <span>
              {t("risks.owner")}: {risk.owner}
            </span>
            <span>
              {t("risks.age")}: {t("risks.days", { a: risk.ageDays })}
            </span>
            <span>
              {t("risks.items")}: {risk.items.length}
            </span>
          </span>
        </span>
        <ChevronDown
          className={cn("mt-1 size-4 shrink-0 text-muted-foreground transition-transform", open && "rotate-180")}
          aria-hidden
        />
      </button>

      {open ? (
        <div className="space-y-3 bg-surface px-4 pb-4 pt-1 sm:px-5">
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
                  <span className="tabular-nums text-muted-foreground">#{item.id}</span>{" "}
                  {item.title[locale]}
                </li>
              ))}
            </ul>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => toast.info(t("risks.adoSoon"))}
          >
            <ExternalLink className="size-3.5" aria-hidden />
            {t("risks.openAdo")}
          </Button>
        </div>
      ) : null}
    </li>
  );
}

export function RisksCard({ risks }: { risks: Risk[] }) {
  const { t } = useI18n();
  return (
    <SectionCard title={t("risks.title")} subtitle={t("risks.subtitle")} bodyClassName="p-0">
      <ul>
        {risks.slice(0, 5).map((risk, i) => (
          <RiskRow key={risk.id} risk={risk} index={i} />
        ))}
      </ul>
    </SectionCard>
  );
}
