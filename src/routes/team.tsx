import { createFileRoute } from "@tanstack/react-router";
import { AppShell } from "@/components/matn/AppShell";
import { PlaceholderPage } from "@/components/matn/PlaceholderPage";

export const Route = createFileRoute("/team")({
  head: () => ({
    meta: [
      { title: "Team Capacity — MATN Delivery Intelligence" },
      {
        name: "description",
        content: "Understand team capacity, workload balance, and collaboration patterns per sprint.",
      },
      { property: "og:title", content: "Team Capacity — MATN Delivery Intelligence" },
      {
        property: "og:description",
        content: "Understand team capacity, workload balance, and collaboration patterns per sprint.",
      },
    ],
  }),
  component: TeamPage,
});

function TeamPage() {
  return (
    <AppShell>
      <PlaceholderPage
        titleKey="teamPage.title"
        subtitleKey="teamPage.subtitle"
        bulletKeys={["teamPage.p1", "teamPage.p2", "teamPage.p3"]}
      />
    </AppShell>
  );
}
