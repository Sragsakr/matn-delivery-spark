import {
  Area,
  CartesianGrid,
  ComposedChart,
  Line,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip as RTooltip,
  XAxis,
  YAxis,
} from "recharts";
import { useI18n } from "@/lib/i18n";
import type { SprintTrajectory } from "@/data/types";
import { SectionCard } from "./primitives";

export function TrajectoryCard({
  trajectory,
  currentDay,
}: {
  trajectory: SprintTrajectory;
  currentDay: number;
}) {
  const { t, locale } = useI18n();
  const data = trajectory.points.map((p) => ({
    ...p,
    band:
      p.forecastLow !== null && p.forecastHigh !== null
        ? [p.forecastLow, p.forecastHigh]
        : undefined,
  }));

  return (
    <SectionCard
      title={t("trajectory.title")}
      subtitle={t("trajectory.subtitle")}
      action={
        <div className="text-end">
          <div className="text-[11px] text-muted-foreground">{t("trajectory.forecastLabel")}</div>
          <div className="text-sm font-semibold tabular-nums text-foreground">
            {trajectory.forecastCompletion}%{" "}
            <span className="text-xs font-normal text-muted-foreground">
              ({trajectory.forecastRange[0]}–{trajectory.forecastRange[1]}%)
            </span>
          </div>
        </div>
      }
    >
      <div className="h-64 w-full" dir="ltr">
        <ResponsiveContainer width="100%" height="100%">
          <ComposedChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -18 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
            <XAxis
              dataKey="day"
              tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
              tickLine={false}
              axisLine={{ stroke: "var(--border)" }}
            />
            <YAxis
              domain={[0, 100]}
              tick={{ fontSize: 11, fill: "var(--muted-foreground)" }}
              tickLine={false}
              axisLine={false}
              tickFormatter={(v) => `${v}%`}
            />
            <RTooltip
              contentStyle={{
                background: "var(--card)",
                border: "1px solid var(--border)",
                borderRadius: 8,
                fontSize: 12,
                color: "var(--foreground)",
              }}
              labelFormatter={(v) => `${t("trajectory.day")} ${v}`}
            />
            <Area
              dataKey="band"
              stroke="none"
              fill="var(--azure)"
              fillOpacity={0.14}
              name={t("trajectory.range")}
              isAnimationActive={false}
            />
            <Line
              type="monotone"
              dataKey="expected"
              stroke="var(--muted-foreground)"
              strokeDasharray="5 4"
              strokeWidth={2}
              dot={false}
              name={t("trajectory.expected")}
            />
            <Line
              type="monotone"
              dataKey="actual"
              stroke="var(--navy)"
              strokeWidth={2.5}
              dot={false}
              connectNulls={false}
              name={t("trajectory.actual")}
            />
            <Line
              type="monotone"
              dataKey="forecast"
              stroke="var(--azure)"
              strokeWidth={2.5}
              strokeDasharray="2 3"
              dot={false}
              connectNulls
              name={t("trajectory.forecast")}
            />
            <ReferenceLine x={currentDay} stroke="var(--warning)" strokeWidth={1.5} />
          </ComposedChart>
        </ResponsiveContainer>
      </div>

      <div className="mt-4 flex flex-wrap items-center gap-x-5 gap-y-2 text-xs text-muted-foreground">
        <span className="flex items-center gap-1.5">
          <span className="h-0.5 w-4 rounded bg-navy" aria-hidden />
          {t("trajectory.actual")}
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-0.5 w-4 rounded bg-muted-foreground" aria-hidden />
          {t("trajectory.expected")}
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-0.5 w-4 rounded bg-azure" aria-hidden />
          {t("trajectory.forecast")}
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-2.5 w-4 rounded bg-azure/20" aria-hidden />
          {t("trajectory.range")}
        </span>
        <span className="ms-auto tabular-nums" dir="ltr">
          {new Intl.DateTimeFormat(locale === "ar" ? "ar-EG" : "en-GB", {
            day: "numeric",
            month: "short",
          }).format(new Date(trajectory.startDate))}
          {" — "}
          {new Intl.DateTimeFormat(locale === "ar" ? "ar-EG" : "en-GB", {
            day: "numeric",
            month: "short",
          }).format(new Date(trajectory.endDate))}
        </span>
      </div>
    </SectionCard>
  );
}
