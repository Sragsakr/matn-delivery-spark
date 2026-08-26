import { useState, type ReactNode } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import {
  Activity,
  ChevronsLeft,
  ChevronsRight,
  CircleUserRound,
  Cpu,
  Gauge,
  LayoutGrid,
  LogOut,
  Menu,
  Moon,
  RefreshCw,
  Settings,
  Sparkles,
  Sun,
  Users,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useI18n, type TKey } from "@/lib/i18n";
import { useTheme } from "@/lib/theme";
import { useWorkspace } from "@/data/workspace";
import { statusDot } from "./primitives";
import type { DataFreshness, WorkspaceFilters } from "@/data/types";

const navItems = [
  { to: "/", key: "nav.overview", icon: LayoutGrid },
  { to: "/delivery", key: "nav.delivery", icon: Gauge },
  { to: "/team", key: "nav.team", icon: Users },
  { to: "/engineering", key: "nav.engineering", icon: Cpu },
  { to: "/intelligence", key: "nav.intelligence", icon: Sparkles },
] as const;

function BrandMark({ compact }: { compact?: boolean }) {
  const { t } = useI18n();
  return (
    <div className="flex min-w-0 items-center gap-2.5">
      <span className="grid size-9 shrink-0 place-items-center rounded-md bg-navy text-navy-foreground">
        <Activity className="size-4.5" aria-hidden />
      </span>
      {!compact && (
        <span className="min-w-0">
          <span className="block truncate text-sm font-semibold leading-tight text-sidebar-foreground">
            {t("brand.name")}
          </span>
          <span className="block truncate text-[11px] leading-tight text-muted-foreground">
            {t("brand.tagline")}
          </span>
        </span>
      )}
    </div>
  );
}

function NavList({ compact, onNavigate }: { compact?: boolean; onNavigate?: () => void }) {
  const { t } = useI18n();
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  return (
    <nav className="flex flex-col gap-1 px-2" aria-label={t("shell.menu")}>
      {navItems.map((item) => {
        const active = pathname === item.to;
        const Icon = item.icon;
        return (
          <Link
            key={item.to}
            to={item.to}
            onClick={onNavigate}
            title={compact ? t(item.key as TKey) : undefined}
            className={cn(
              "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
              compact && "justify-center px-2",
              active
                ? "bg-navy text-navy-foreground"
                : "text-sidebar-foreground/80 hover:bg-sidebar-accent hover:text-sidebar-foreground",
            )}
          >
            <Icon className="size-4 shrink-0" aria-hidden />
            {!compact && <span className="truncate">{t(item.key as TKey)}</span>}
          </Link>
        );
      })}
    </nav>
  );
}

function FilterSelect({
  labelKey,
  filterKey,
  items,
  compact,
}: {
  labelKey: TKey;
  filterKey: keyof WorkspaceFilters;
  items: { id: string; name: { ar: string; en: string } }[];
  compact?: boolean;
}) {
  const { t, locale } = useI18n();
  const { filters, setFilter } = useWorkspace();
  return (
    <label className="block min-w-0">
      {!compact && (
        <span className="mb-1 block text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
          {t(labelKey)}
        </span>
      )}
      <Select value={filters[filterKey]} onValueChange={(v) => setFilter(filterKey, v)}>
        <SelectTrigger className="h-9 w-full bg-card text-sm" aria-label={t(labelKey)}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {items.map((i) => (
            <SelectItem key={i.id} value={i.id}>
              {i.name[locale]}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </label>
  );
}

function ScopeFilters({ compact }: { compact?: boolean }) {
  const { options } = useWorkspace();
  return (
    <div className={cn("grid gap-3", compact ? "grid-cols-1" : "grid-cols-1")}>
      <FilterSelect labelKey="shell.organization" filterKey="organizationId" items={options.organizations} />
      <FilterSelect labelKey="shell.project" filterKey="projectId" items={options.projects} />
      <FilterSelect labelKey="shell.team" filterKey="teamId" items={options.teams} />
      <FilterSelect labelKey="shell.sprint" filterKey="iterationId" items={options.iterations} />
    </div>
  );
}

function freshnessKey(f: DataFreshness): TKey {
  return `shell.freshness.${f}` as TKey;
}

function TopBar({ onOpenMobileNav }: { onOpenMobileNav: () => void }) {
  const { t, locale, setLocale } = useI18n();
  const { theme, toggleTheme } = useTheme();
  const { snapshot, loading, refresh } = useWorkspace();
  const freshness = snapshot?.freshness ?? "fresh";
  const dotClass =
    freshness === "fresh" ? statusDot.healthy : freshness === "error" ? statusDot.critical : statusDot.atRisk;

  return (
    <header className="sticky top-0 z-30 border-b border-border bg-background/95 backdrop-blur">
      <div className="grid grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 px-4 py-2.5 sm:px-6">
        <div className="flex items-center gap-2 lg:hidden">
          <Button variant="ghost" size="icon" aria-label={t("shell.menu")} onClick={onOpenMobileNav}>
            <Menu className="size-5" aria-hidden />
          </Button>
        </div>
        <div className="hidden lg:block" />

        <div className="flex min-w-0 items-center gap-2 text-xs text-muted-foreground">
          <span className={cn("size-2 shrink-0 rounded-full", dotClass)} aria-hidden />
          <span className="truncate">
            {t(freshnessKey(freshness))}
            {snapshot ? ` · ${t("shell.lastSync")} ${t("common.minutes", { a: snapshot.lastSyncMinutesAgo })}` : ""}
          </span>
        </div>

        <div className="flex shrink-0 items-center gap-1">
          <Button
            variant="ghost"
            size="icon"
            aria-label={t("shell.refresh")}
            title={t("shell.refresh")}
            onClick={refresh}
          >
            <RefreshCw className={cn("size-4", loading && "animate-spin")} aria-hidden />
          </Button>
          <Button
            variant="ghost"
            size="sm"
            className="px-2 font-semibold"
            aria-label={t("shell.language")}
            onClick={() => setLocale(locale === "ar" ? "en" : "ar")}
          >
            {locale === "ar" ? "EN" : "ع"}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            aria-label={theme === "dark" ? t("shell.theme.light") : t("shell.theme.dark")}
            onClick={toggleTheme}
          >
            {theme === "dark" ? <Sun className="size-4" aria-hidden /> : <Moon className="size-4" aria-hidden />}
          </Button>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" aria-label={t("shell.profile")}>
                <CircleUserRound className="size-5" aria-hidden />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-52">
              <DropdownMenuLabel className="font-normal">
                <span className="block text-sm font-medium">Omar Nasser</span>
                <span className="block text-xs text-muted-foreground">Delivery Manager</span>
              </DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem>
                <CircleUserRound className="size-4" aria-hidden />
                {t("shell.profile")}
              </DropdownMenuItem>
              <DropdownMenuItem>
                <Settings className="size-4" aria-hidden />
                {t("shell.settings")}
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem>
                <LogOut className="size-4" aria-hidden />
                {t("shell.signout")}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </header>
  );
}

export function AppShell({ children }: { children: ReactNode }) {
  const { t } = useI18n();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <div className="min-h-screen bg-background text-foreground">
      <div className="flex min-h-screen">
        <aside
          className={cn(
            "sticky top-0 hidden h-screen shrink-0 flex-col border-e border-sidebar-border bg-sidebar lg:flex",
            collapsed ? "w-[76px]" : "w-[264px]",
          )}
        >
          <div className="flex h-[57px] items-center justify-between gap-2 border-b border-sidebar-border px-4">
            <BrandMark compact={collapsed} />
          </div>

          {!collapsed && (
            <div className="border-b border-sidebar-border px-4 py-3">
              <p className="mb-2 text-[11px] font-medium uppercase tracking-wide text-muted-foreground">
                {t("brand.workspace")}
              </p>
              <ScopeFilters />
            </div>
          )}

          <div className="flex-1 overflow-y-auto py-3">
            <NavList compact={collapsed} />
          </div>

          <div className="border-t border-sidebar-border p-2">
            <Button
              variant="ghost"
              size="sm"
              className={cn("w-full justify-start gap-2", collapsed && "justify-center")}
              onClick={() => setCollapsed((c) => !c)}
              aria-label={collapsed ? t("shell.expand") : t("shell.collapse")}
            >
              {collapsed ? (
                <ChevronsRight className="size-4 rtl:rotate-180" aria-hidden />
              ) : (
                <ChevronsLeft className="size-4 rtl:rotate-180" aria-hidden />
              )}
              {!collapsed && <span className="truncate text-xs">{t("shell.collapse")}</span>}
            </Button>
          </div>
        </aside>

        <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
          <SheetContent side="start" className="w-[280px] bg-sidebar p-0">
            <SheetTitle className="sr-only">{t("shell.menu")}</SheetTitle>
            <div className="flex h-[57px] items-center border-b border-sidebar-border px-4">
              <BrandMark />
            </div>
            <div className="border-b border-sidebar-border px-4 py-3">
              <ScopeFilters />
            </div>
            <div className="py-3">
              <NavList onNavigate={() => setMobileOpen(false)} />
            </div>
          </SheetContent>
        </Sheet>

        <div className="flex min-w-0 flex-1 flex-col">
          <TopBar onOpenMobileNav={() => setMobileOpen(true)} />
          <div className="border-b border-border bg-surface px-4 py-3 lg:hidden">
            <div className="grid grid-cols-2 gap-2">
              <ScopeFilters compact />
            </div>
          </div>
          <main className="min-w-0 flex-1 px-4 py-5 sm:px-6 sm:py-6">{children}</main>
        </div>
      </div>
    </div>
  );
}

export { Sheet, SheetTrigger };
