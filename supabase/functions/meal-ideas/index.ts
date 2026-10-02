// meal-ideas (prompt 5.4): "What can I make" from what's in the fridge and the
// safe list. Claude suggests simple meals; filter.ts then drops any idea that
// mentions a paused or avoided food (categories expanded) or uses anything
// not listed. Nothing is stored except a per-day count per account.

import { createClient } from "@supabase/supabase-js";
import { filterIdeas } from "./filter.ts";

export const DAILY_LIMIT = 20;
export const MODEL = "claude-sonnet-5";
/** From the research notes; a fact, not advice. */
export const FRESH_NOTE = "Freshly cooked food is lower in histamine than leftovers or aged foods.";

export interface Deps {
  userID(authorization: string, apikey: string): Promise<string | null>;
  noteUse(authorization: string, apikey: string): Promise<number>;
  ideas(fridge: string[], safe: string[], avoid: string[]): Promise<unknown>;
}

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function names(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((v): v is string => typeof v === "string").map((v) => v.trim()).filter((v) => v.length > 0 && v.length <= 80).slice(0, 80)
    : [];
}

export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== "POST") return reply(405, { error: "Use POST." });
  const authorization = req.headers.get("Authorization");
  const apikey = req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!authorization?.startsWith("Bearer ") || !(await deps.userID(authorization, apikey))) {
    return reply(401, { error: "Sign in first." });
  }
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: "Send {fridge, safe, avoid}." });
  }
  const fridge = names(body.fridge), safe = names(body.safe), avoid = names(body.avoid);
  if (fridge.length === 0) return reply(400, { error: "Pick what's in the fridge first." });
  if ((await deps.noteUse(authorization, apikey)) > DAILY_LIMIT) {
    return reply(429, { error: "That's a lot of ideas for one day. Please try again tomorrow." });
  }
  let raw: unknown;
  try {
    raw = await deps.ideas(fridge, safe, avoid);
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown";
    console.error("ideas failed", reason);
    return reply(502, { error: "Couldn't get ideas just now. Please try again.", reason });
  }
  const { ideas, rejected } = filterIdeas(raw, avoid, [...fridge, ...safe]);
  return reply(200, { ideas, rejected, note: FRESH_NOTE });
}

// MARK: - Live dependencies

const url = Deno.env.get("SUPABASE_URL") ?? "";

function asCaller(authorization: string, apikey: string) {
  return createClient(url, apikey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

const TOOL = {
  name: "record_meal_ideas",
  description: "Record up to 4 simple meal ideas.",
  input_schema: {
    type: "object",
    properties: {
      ideas: {
        type: "array",
        items: {
          type: "object",
          properties: {
            title: { type: "string" },
            ingredients: { type: "array", items: { type: "string" } },
            steps: { type: "array", items: { type: "string" } },
          },
          required: ["title", "ingredients", "steps"],
        },
      },
    },
    required: ["ideas"],
  },
} as const;

const SYSTEM = `You suggest simple meals a parent can make for a young child, using only the foods listed.
- Use only foods from "In the fridge" and "Safe foods", plus water and salt. Nothing else: no oils, spices, or sauces unless listed.
- Never use, mention, or suggest any food in "Avoid", or anything made from it.
- No health claims, no advice about what to eat or avoid. Just meals.
- Up to 4 ideas, each with 3 to 6 short steps. Plain words.`;

export const live: Deps = {
  async userID(authorization, apikey) {
    const { data: { user } } = await asCaller(authorization, apikey).auth.getUser();
    return user?.id ?? null;
  },
  async noteUse(authorization, apikey) {
    const { data, error } = await asCaller(authorization, apikey).rpc("note_meal_ideas_use");
    if (error) throw new Error(error.message);
    return data as number;
  },
  async ideas(fridge, safe, avoid) {
    const key = Deno.env.get("ANTHROPIC_API_KEY");
    if (!key) throw new Error("ANTHROPIC_API_KEY isn't set");
    const headers: Record<string, string> = {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    };
    const workspace = Deno.env.get("ANTHROPIC_WORKSPACE_ID");
    if (workspace) headers["anthropic-workspace-id"] = workspace;
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers,
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 3000,
        system: SYSTEM,
        tools: [TOOL],
        tool_choice: { type: "tool", name: TOOL.name },
        messages: [{
          role: "user",
          content: `In the fridge: ${fridge.join(", ")}\nSafe foods: ${safe.join(", ") || "(none listed)"}\nAvoid: ${avoid.join(", ") || "(none)"}`,
        }],
      }),
    });
    if (!response.ok) {
      const detail = await response.json().catch(() => ({}));
      throw new Error(`model returned ${response.status}: ${detail?.error?.type ?? ""} ${detail?.error?.message ?? ""}`.trim());
    }
    const result = await response.json();
    const call = result.content?.find((part: { type: string }) => part.type === "tool_use");
    return call?.input?.ideas ?? [];
  },
};

if (import.meta.main) Deno.serve((req) => handle(req, live));
