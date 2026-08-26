import { Construction } from "lucide-react";
import { useI18n, type TKey } from "@/lib/i18n";
import { useWorkspace } from "@/data/workspace";
import { SectionCard } from "./primitives";
import { Skeleton } from "@/components/ui/skeleton";

export function PlaceholderPage({
  titleKey,
  subtitleKey,
  bulletKeys,
}: {
  titleKey: TKey;
  subtitleKey: TKey;
  bulletKeys: TKey[];
}) {
  const { t, locale } = useI18n();
  const { iteration, loading } = useWorkspace();

  return (
    <div className="mx-auto flex w-full max-w-[1400px] flex-col gap-6">
      <header className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-4">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="text-xl font-semibold tracking-tight text-foreground sm:text-2xl">
              {t(titleKey)}
            </h1>
            <span className="rounded-full border border-border bg-surface px-2 py-0.5 text-[11px] font-medium text-muted-foreground">
              {t("placeholder.badge")}
            </span>
          </div>
          <p className="mt-1 text-sm text-muted-foreground">{t(subtitleKey)}</p>
        </div>
        <div className="shrink-0 text-end text-xs text-muted-foreground">
          {iteration ? iteration.name[locale] : null}
        </div>
      </header>

      <SectionCard title={t("placeholder.planned")} subtitle={t("placeholder.body")}>
        {loading ? (
          <div className="space-y-3">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-2/3" />
          </div>
        ) : (
          <ul className="grid gap-3 sm:grid-cols-3">
            {bulletKeys.map((k) => (
              <li
                key={k}
                className="flex items-start gap-3 rounded-md border border-dashed border-border bg-surface p-4"
              >
                <Construction className="mt-0.5 size-4 shrink-0 text-azure" aria-hidden />
                <span className="text-sm text-foreground">{t(k)}</span>
              </li>
            ))}
          </ul>
        )}
      </SectionCard>
    </div>
  );
}
