import { describe, expect, it } from "vitest";
import { dateOnly, iterationPhase, memberKey, templateFromName } from "../sync-rules";
import type { AzureIteration } from "@/types/azure";

const iteration = (start: string | null, finish: string | null): AzureIteration => ({
  id: "i1",
  name: "Sprint 1",
  path: "Proj\\Sprint 1",
  attributes: { startDate: start, finishDate: finish },
  url: "https://example.invalid",
});

describe("sync rules", () => {
  it("classifies process templates and falls back to custom", () => {
    expect(templateFromName("Contoso Scrum")).toBe("scrum");
    expect(templateFromName("CMMI Program")).toBe("cmmi");
    expect(templateFromName("Basic Board")).toBe("basic");
    expect(templateFromName("Agile Delivery")).toBe("agile");
    expect(templateFromName("Bespoke")).toBe("custom");
    expect(templateFromName(null)).toBe("custom");
  });

  it("derives iteration phase, treating missing dates as undated", () => {
    const now = new Date("2026-03-10T00:00:00Z");
    expect(iterationPhase(iteration("2026-03-01", "2026-03-14"), now)).toBe("current");
    expect(iterationPhase(iteration("2026-04-01", "2026-04-14"), now)).toBe("future");
    expect(iterationPhase(iteration("2026-01-01", "2026-01-14"), now)).toBe("completed");
    expect(iterationPhase(iteration(null, null), now)).toBe("undated");
  });

  it("normalizes dates to calendar days and preserves nulls", () => {
    expect(dateOnly("2026-03-01T22:00:00Z")).toBe("2026-03-01");
    expect(dateOnly(null)).toBeNull();
  });

  it("prefers stable identity descriptors", () => {
    expect(memberKey({ descriptor: "aad.x", id: "guid", uniqueName: "a@b.c" })).toBe("aad.x");
    expect(memberKey({ id: "guid", uniqueName: "a@b.c" })).toBe("guid");
    expect(memberKey({ uniqueName: "a@b.c" })).toBe("a@b.c");
    expect(memberKey({})).toBeNull();
  });
});
