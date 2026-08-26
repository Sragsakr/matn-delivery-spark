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

type Ctx = {
  filters: WorkspaceFilters;
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
  const [loading, setLoading] = useState(true);
  const [error] = useState(false);
  const [tick, setTick] = useState(0);

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

  const snapshot = useMemo(
    () => (loading || error ? null : getDeliverySnapshot(filters)),
    [filters, loading, error],
  );

  const value = useMemo<Ctx>(
    () => ({
      filters,
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
    [filters, setFilter, snapshot, loading, error],
  );

  return <WorkspaceContext.Provider value={value}>{children}</WorkspaceContext.Provider>;
}

export function useWorkspace() {
  const ctx = useContext(WorkspaceContext);
  if (!ctx) throw new Error("useWorkspace must be used inside WorkspaceProvider");
  return ctx;
}
