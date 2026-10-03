import { assertEquals } from "jsr:@std/assert@1";
import { DAILY_LIMIT, type Deps, FRESH_NOTE, handle } from "./index.ts";

function deps(overrides: Partial<Deps> = {}): Deps {
  return {
    userID: () => Promise.resolve("user-1"),
    noteUse: () => Promise.resolve(1),
    ideas: () => Promise.resolve([
      { title: "Apple oats", ingredients: ["oats", "apple"], steps: ["Cook oats.", "Add apple."] },
      { title: "Cheesy oats", ingredients: ["oats", "cheese"], steps: ["Add cheese."] },
    ]),
    ...overrides,
  };
}

function post(body: unknown, auth = "Bearer token"): Request {
  return new Request("http://localhost/meal-ideas", {
    method: "POST",
    headers: { Authorization: auth, apikey: "anon", "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

Deno.test("returns only safe ideas, with the fresh-food note", async () => {
  const response = await handle(post({ fridge: ["oats", "apple"], safe: [], avoid: ["Dairy"] }), deps());
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.ideas.map((i: { title: string }) => i.title), ["Apple oats"]);
  assertEquals(body.rejected, 1);
  assertEquals(body.note, FRESH_NOTE);
});

Deno.test("needs sign-in, a fridge, and stays under the daily limit", async () => {
  assertEquals((await handle(post({ fridge: ["oats"] }), deps({ userID: () => Promise.resolve(null) }))).status, 401);
  assertEquals((await handle(post({ fridge: [] }), deps())).status, 400);
  assertEquals((await handle(post({ fridge: ["oats"] }), deps({ noteUse: () => Promise.resolve(DAILY_LIMIT + 1) }))).status, 429);
});
