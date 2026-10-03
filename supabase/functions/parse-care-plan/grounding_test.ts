import { assertEquals } from "jsr:@std/assert@1";
import { check, normalize, pages } from "./grounding.ts";

const plan = await Deno.readTextFile(new URL("./fixtures/example-plan.txt", import.meta.url));

Deno.test("splits pages on the markers", () => {
  const byPage = pages(plan);
  assertEquals([...byPage.keys()], [1, 2]);
  assertEquals(byPage.get(2)!.startsWith("supplements"), true);
});

Deno.test("keeps real items with their page and line", () => {
  const { items, dropped } = check([
    { kind: "bath", text: "Oat bath", frequency: "3x/week", duration: "10 minutes", source_page: 1, source_line: "Oat bath 3x/week, 10 minutes" },
    { kind: "supplement", text: "Probiotic", dose: "1/4 tsp", frequency: "once daily", timing: "with breakfast", duration: "3 months", source_page: 2, source_line: "Probiotic, Brand A, 1/4 tsp, once daily, with breakfast, 3 months" },
  ], plan);
  assertEquals(dropped, 0);
  assertEquals(items.map((i) => [i.kind, i.source_page, i.frequency]), [["bath", 1, "3x/week"], ["supplement", 2, "once daily"]]);
  assertEquals(items[1].blanks, []);
});

Deno.test("drops an item whose line isn't in the plan", () => {
  const { items, dropped } = check([
    { kind: "supplement", text: "Fish oil", dose: "1 tsp", source_page: 2, source_line: "Fish oil 1 tsp daily" },
  ], plan);
  assertEquals(items, []);
  assertEquals(dropped, 1);
});

Deno.test("never fills a blank: an invented dose is removed and flagged", () => {
  const { items, ungrounded } = check([
    { kind: "supplement", text: "Vitamin D3", dose: "400 IU", frequency: "daily", source_page: 2, source_line: "Vitamin D3, Brand B, dose at next visit, daily" },
  ], plan);
  assertEquals(items[0].dose, null);
  assertEquals(items[0].frequency, "daily");
  assertEquals(items[0].blanks, ["dose"]);
  assertEquals(ungrounded, 1);
});

Deno.test("a blank in the plan stays blank", () => {
  const { items } = check([
    { kind: "fundamental", text: "Hydration", dose: "32 oz", source_page: 1, source_line: "Hydration: ____ oz water daily" },
  ], plan);
  assertEquals(items[0].dose, null);
});

Deno.test("words that aren't in the plan fall back to the quoted line", () => {
  const { items } = check([
    { kind: "bath", text: "Soothing colloidal oatmeal soak", source_page: 1, source_line: "Oat bath 3x/week, 10 minutes" },
  ], plan);
  assertEquals(items[0].text, "Oat bath 3x/week, 10 minutes");
});

Deno.test("finds the line on another page and ignores unknown kinds", () => {
  const { items, dropped } = check([
    { kind: "followUp", text: "Follow-up visit in 4–6 weeks", source_page: 1, source_line: "Follow-up visit in 4–6 weeks." },
    { kind: "diagnosis", text: "Eczema", source_page: 1, source_line: "Care plan for: [child], age 5" },
  ], plan);
  assertEquals(items.map((i) => i.source_page), [2]);
  assertEquals(dropped, 1);
});

Deno.test("curly quotes and dashes match their plain forms", () => {
  assertEquals(normalize("Baths (rotate, don’t combine) 4–6"), "baths (rotate, don't combine) 4-6");
  const { items } = check([
    { kind: "bath", text: "rotate, don't combine", source_page: 1, source_line: "Baths (rotate, don't combine)" },
  ], plan);
  assertEquals(items.length, 1);
});

Deno.test("a rule with no details has nothing to flag", () => {
  const { items } = check([
    { kind: "supplement", text: "Add one at a time, 3–5 days apart", source_page: 2, source_line: "Add one at a time, 3–5 days apart. Start with a drop." },
  ], plan);
  assertEquals(items[0].blanks, []);
});

Deno.test("a rule with only a duration isn't missing a dose", () => {
  const { items } = check([
    { kind: "supplement", text: "Rotate antimicrobial", duration: "3 weeks", source_page: 2, source_line: "Antimicrobial herb, Brand C, 2 drops, twice daily, rotate after 3 weeks" },
  ], plan);
  assertEquals(items[0].blanks, []);
});

Deno.test("keeps a label made of the plan's words", () => {
  const { items, rejectedLabels } = check([
    { kind: "topicalStep", text: "Apply calendula balm to affected areas", source_page: 1,
      source_line: "2. Apply calendula balm to affected areas", label: "Apply calendula balm", detail: "to affected areas", category: "apply" },
  ], plan);
  assertEquals(rejectedLabels, 0);
  assertEquals([items[0].label, items[0].detail, items[0].category], ["Apply calendula balm", "to affected areas", "apply"]);
});

Deno.test("drops a label that adds a dose, a brand, or breaks the rules", () => {
  const line = "2. Apply calendula balm to affected areas";
  const { items, rejectedLabels } = check([
    { kind: "topicalStep", text: "Apply calendula balm", source_page: 1, source_line: line, label: "Apply 3 pumps calendula balm", detail: null, category: "apply" },
    { kind: "topicalStep", text: "Apply calendula balm", source_page: 1, source_line: line, label: "Apply Weleda calendula balm", detail: null, category: "apply" },
    { kind: "topicalStep", text: "Apply calendula balm", source_page: 1, source_line: line, label: "Calendula balm", detail: null, category: "apply" },
    { kind: "topicalStep", text: "Apply calendula balm", source_page: 1, source_line: line, label: "Apply calendula balm gently to every affected area", detail: null, category: "apply" },
    { kind: "topicalStep", text: "Apply calendula balm", source_page: 1, source_line: line, label: "Apply calendula balm", detail: "twice daily", category: "apply" },
    { kind: "topicalStep", text: "Apply calendula balm", source_page: 1, source_line: line, label: "Apply calendula balm", detail: null, category: "treat" },
  ], plan);
  assertEquals(rejectedLabels, 5);
  assertEquals(items.map((i) => i.label), [null, null, null, null, null, "Apply calendula balm"]);
  assertEquals(items[5].category, null);
});
