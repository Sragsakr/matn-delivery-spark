import { createFileRoute } from "@tanstack/react-router";
import { AppShell } from "@/components/matn/AppShell";
import { PlaceholderPage } from "@/components/matn/PlaceholderPage";

export const Route = createFileRoute("/delivery")({
  head: () => ({
    meta: [
      { title: "Delivery Flow — MATN Delivery Intelligence" },
      {
        name: "description",
        content: "Track sprint scope, cycle time, and release commitments across delivery teams.",
      },
      { property: "og:title", content: "Delivery Flow — MATN Delivery Intelligence" },
      {
        property: "og:description",
        content: "Track sprint scope, cycle time, and release commitments across delivery teams.",
      },
    ],
  }),
  component: DeliveryPage,
});

function DeliveryPage() {
  return (
    <AppShell>
      <PlaceholderPage
        titleKey="delivery.title"
        subtitleKey="delivery.subtitle"
        bulletKeys={["delivery.p1", "delivery.p2", "delivery.p3"]}
      />
    </AppShell>
  );
}
