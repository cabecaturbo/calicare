import { assertEquals } from "jsr:@std/assert@1";
import { DAILY_LIMIT, type Deps, handle, MAX_TEXT } from "./index.ts";

const plan = await Deno.readTextFile(new URL("./fixtures/example-plan.txt", import.meta.url));

function deps(overrides: Partial<Deps> = {}): Deps {
  return {
    userID: () => Promise.resolve("user-1"),
    noteUse: () => Promise.resolve(1),
    extract: () =>
      Promise.resolve([
        { kind: "bath", text: "Oat bath", frequency: "3x/week", duration: "10 minutes", source_page: 1, source_line: "Oat bath 3x/week, 10 minutes" },
        { kind: "supplement", text: "Fish oil", dose: "1 tsp", source_page: 2, source_line: "Fish oil 1 tsp" },
      ]),
    simplify: (lines) => Promise.resolve(lines.map((l) => ({ id: l.id, plain: l.text }))),
    ...overrides,
  };
}

function post(body: unknown, auth = "Bearer token"): Request {
  return new Request("http://localhost/parse-care-plan", {
    method: "POST",
    headers: { Authorization: auth, apikey: "anon", "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

Deno.test("returns only grounded items", async () => {
  const response = await handle(post({ text: plan }), deps());
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.items.map((i: { text: string }) => i.text), ["Oat bath"]);
  assertEquals(body.dropped, 1);
});

Deno.test("needs a signed-in caller", async () => {
  assertEquals((await handle(post({ text: plan }), deps({ userID: () => Promise.resolve(null) }))).status, 401);
  assertEquals((await handle(post({ text: plan }, ""), deps())).status, 401);
});

Deno.test("refuses empty and oversized text", async () => {
  assertEquals((await handle(post({ text: "  " }), deps())).status, 400);
  assertEquals((await handle(post({ text: "x".repeat(MAX_TEXT + 1) }), deps())).status, 413);
});

Deno.test("rate limited per account per day", async () => {
  const response = await handle(post({ text: plan }), deps({ noteUse: () => Promise.resolve(DAILY_LIMIT + 1) }));
  assertEquals(response.status, 429);
});

Deno.test("a model failure says try again, without echoing the plan", async () => {
  const response = await handle(post({ text: plan }), deps({ extract: () => Promise.reject(new Error("boom")) }));
  assertEquals(response.status, 502);
  assertEquals((await response.text()).includes("Oat"), false);
});

Deno.test("plain words: kept only when they change no number or brand", async () => {
  const lines = [
    { id: "a", text: "Step 3: Jojoba oil + Neem oil. Start with 50:50 ratio and work up, as tolerated. Kate Blanc Brand on Amazon." },
    { id: "b", text: "Coptis by Hawaii Pharm 8 drops, 3x daily. Start with a single drop, 2x per day and work up slowly." },
  ];
  const simplify = () =>
    Promise.resolve([
      { id: "a", plain: "Start with a 50:50 mix of Jojoba oil and Neem oil. Use more as the skin allows. Kate Blanc brand, on Amazon. This is step 3." },
      { id: "b", plain: "Give 10 drops of Coptis from Hawaii Pharm, 3x a day." },
    ]);
  const response = await handle(post({ mode: "plain", lines }), deps({ simplify }));
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.items.map((i: { id: string }) => i.id), ["a"]);
  assertEquals(body.rejected, 1);
});

Deno.test("plain words: needs lines and a signed-in caller", async () => {
  assertEquals((await handle(post({ mode: "plain", lines: [] }), deps())).status, 400);
  assertEquals((await handle(post({ mode: "plain", lines: [{ id: "a", text: "x" }] }), deps({ userID: () => Promise.resolve(null) }))).status, 401);
});
