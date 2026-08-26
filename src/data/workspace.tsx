import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  defaultFilters,
  getDeliverySnapshot,
  getIteration,
  iterations,
  organizations,
  projects,
  teams,
} from "./mock";
import type { DeliverySnapshot, Iteration, WorkspaceFilters } from "./types";

export type PreviewState = "normal" | "loading" | "empty" | "error" | "stale" | "partial";

export const isDevPreview = import.meta.env.DEV;

type Ctx = {
  filters: WorkspaceFilters;
  previewState: PreviewState;
  setPreviewState: (s: PreviewState) => void;
  setFilter: (key: keyof WorkspaceFilters, value: string) => void;
  snapshot: DeliverySnapshot | null;
  iteration: Iteration | undefined;
  loading: boolean;
  error: boolean;
  refresh: () => void;
  options: {
    organizations: typeof organizations;
    projects: typeof projects;
    teams: typeof teams;
    iterations: typeof iterations;
  };
};

const WorkspaceContext = createContext<Ctx | null>(null);

export function WorkspaceProvider({ children }: { children: ReactNode }) {
  const [filters, setFilters] = useState<WorkspaceFilters>(defaultFilters);
  const [baseLoading, setLoading] = useState(true);
  const [tick, setTick] = useState(0);
  const [previewState, setPreviewState] = useState<PreviewState>("normal");

  const loading = previewState === "loading" || baseLoading;
  const error = previewState === "error";

  // Mock async read. Replaced by a server function in the integration phase.
  useEffect(() => {
    setLoading(true);
    const timer = setTimeout(() => setLoading(false), 550);
    return () => clearTimeout(timer);
  }, [filters, tick]);

  const setFilter = useCallback((key: keyof WorkspaceFilters, value: string) => {
    setFilters((prev) => {
      const next: WorkspaceFilters = { ...prev, [key]: value };
      if (key === "organizationId") {
        const p = projects.find((x) => x.organizationId === value);
        next.projectId = p?.id ?? prev.projectId;
      }
      if (key === "organizationId" || key === "projectId") {
        const t = teams.find((x) => x.projectId === next.projectId);
        next.teamId = t?.id ?? prev.teamId;
      }
      if (key !== "iterationId") {
        const it = iterations.find((x) => x.teamId === next.teamId);
        next.iterationId = it?.id ?? prev.iterationId;
      }
      return next;
    });
  }, []);

  const snapshot = useMemo(() => {
    if (loading || error) return null;
    const base = getDeliverySnapshot(filters);
    if (previewState === "empty") {
      return {
        ...base,
        kpis: [],
        risks: [],
        funnel: [],
        teamLoad: [],
        actions: [],
      };
    }
    if (previewState === "stale") return { ...base, freshness: "stale" as const, lastSyncMinutesAgo: 96 };
    if (previewState === "partial") return { ...base, freshness: "partial" as const, actions: base.actions.slice(0, 1) };
    return base;
  }, [filters, loading, error, previewState]);

  const value = useMemo<Ctx>(
    () => ({
      filters,
      previewState,
      setPreviewState,
      setFilter,
      snapshot,
      iteration: getIteration(filters.iterationId),
      loading,
      error,
      refresh: () => setTick((t) => t + 1),
      options: {
        organizations,
        projects: projects.filter((p) => p.organizationId === filters.organizationId),
        teams: teams.filter((t) => t.projectId === filters.projectId),
        iterations: iterations.filter((i) => i.teamId === filters.teamId),
      },
    }),
    [filters, setFilter, snapshot, loading, error, previewState],
  );

  return <WorkspaceContext.Provider value={value}>{children}</WorkspaceContext.Provider>;
}

export function useWorkspace() {
  const ctx = useContext(WorkspaceContext);
  if (!ctx) throw new Error("useWorkspace must be used inside WorkspaceProvider");
  return ctx;
}
