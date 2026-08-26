import { useState } from "react";
import { Check, Search, X } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n";
import type { RecommendedAction } from "@/data/types";
import { EmptyBlock, SectionCard } from "./primitives";

export function RecommendedActionsCard({ actions }: { actions: RecommendedAction[] }) {
  const { t, locale } = useI18n();
  const [resolved, setResolved] = useState<string[]>([]);
  const visible = actions.filter((a) => !resolved.includes(a.id));

  const resolve = (id: string, accepted: boolean) => {
    setResolved((r) => [...r, id]);
    toast.success(accepted ? t("actions.accepted") : t("actions.dismissed"));
  };

  return (
    <SectionCard title={t("actions.title")} subtitle={t("actions.subtitle")} bodyClassName="p-0">
      {visible.length === 0 ? (
        <div className="p-4">
          <EmptyBlock />
        </div>
      ) : (
        <ul className="divide-y divide-border">
          {visible.map((action) => (
            <li key={action.id} className="p-4 sm:p-5">
              <div className="grid grid-cols-[auto_minmax(0,1fr)] items-start gap-3">
                <span className="grid size-6 shrink-0 place-items-center rounded-md bg-navy text-[11px] font-semibold text-navy-foreground tabular-nums">
                  {action.priority}
                </span>
                <div className="min-w-0">
                  <h3 className="text-sm font-medium text-foreground">{action.title[locale]}</h3>
                  <dl className="mt-2 grid gap-2 sm:grid-cols-2">
                    <div className="rounded-md border border-success/30 bg-success/10 px-3 py-2">
                      <dt className="text-[11px] font-medium uppercase tracking-wide text-success">
                        {t("actions.impact")}
                      </dt>
                      <dd className="mt-0.5 text-xs text-foreground">{action.impact[locale]}</dd>
                    </div>
                    <div className="rounded-md border border-border bg-surface px-3 py-2">
                      <dt className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
                        {t("actions.reason")}
                      </dt>
                      <dd className="mt-0.5 text-xs text-foreground">{action.reason[locale]}</dd>
                    </div>
                  </dl>
                  <div className="mt-2 flex flex-wrap items-center gap-1.5">
                    <span className="text-[11px] text-muted-foreground">{t("actions.items")}:</span>
                    {action.items.map((item) => (
                      <span
                        key={item.id}
                        className="rounded border border-border bg-card px-2 py-0.5 text-[11px] text-foreground"
                      >
                        <span className="tabular-nums text-muted-foreground">#{item.id}</span>{" "}
                        {item.title[locale]}
                      </span>
                    ))}
                  </div>
                  <div className="mt-3 flex flex-wrap gap-2">
                    <Button size="sm" onClick={() => resolve(action.id, true)}>
                      <Check className="size-3.5" aria-hidden />
                      {t("actions.accept")}
                    </Button>
                    <Button size="sm" variant="outline" onClick={() => resolve(action.id, false)}>
                      <X className="size-3.5" aria-hidden />
                      {t("actions.dismiss")}
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => toast.info(action.reason[locale])}
                    >
                      <Search className="size-3.5" aria-hidden />
                      {t("actions.inspect")}
                    </Button>
                  </div>
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}
    </SectionCard>
  );
}
