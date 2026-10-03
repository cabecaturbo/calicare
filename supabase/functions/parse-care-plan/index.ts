// parse-care-plan (prompt 4.2): reads a care plan's text and returns its
// items for the parent to review.
//
// - The phone sends text it extracted itself (Vision for photos, PDFKit for
//   PDFs). The file never leaves the phone.
// - Claude extracts items with the tool in prompt.ts; grounding.ts then drops
//   anything not in the plan's text and flags blanks. Nothing is filled in.
// - Nothing is stored: not the text, not the items. Only a per-day count of
//   uses per account, for the rate limit. The text is never logged.

import { createClient } from "@supabase/supabase-js";
import { check, type RawItem } from "./grounding.ts";
import { isFaithful, PLAIN_SYSTEM, PLAIN_TOOL } from "./plain.ts";
import { SYSTEM, TOOL } from "./prompt.ts";

export const MAX_TEXT = 60_000;
export const DAILY_LIMIT = 10;
export const MODEL = "claude-sonnet-5";
/** Lines per plain-words request. */
export const MAX_LINES = 60;

/** One line to put in plain words: the app's id and the provider's words. */
export interface Line {
  id: string;
  text: string;
}

export interface Deps {
  /** The signed-in caller's id, or null. */
  userID(authorization: string, apikey: string): Promise<string | null>;
  /** Counts this use for today and returns today's total. */
  noteUse(authorization: string, apikey: string): Promise<number>;
  /** Asks the model; returns its raw items. */
  extract(text: string): Promise<RawItem[]>;
  /** Asks the model for plain words; returns {id, plain} pairs. */
  simplify(lines: Line[]): Promise<{ id: string; plain: string }[]>;
}

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== "POST") return reply(405, { error: "Use POST." });

  const authorization = req.headers.get("Authorization");
  const apikey = req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!authorization?.startsWith("Bearer ")) return reply(401, { error: "Sign in first." });
  if (!(await deps.userID(authorization, apikey))) return reply(401, { error: "Sign in first." });

  let text: unknown;
  let mode: unknown;
  let lines: unknown;
  try {
    ({ text, mode, lines } = await req.json());
  } catch {
    return reply(400, { error: "Send the plan's text as JSON: {\"text\": \"...\"}." });
  }
  if (mode === "plain") return plainWords(lines, authorization, apikey, deps);
  if (typeof text !== "string" || text.trim().length === 0) return reply(400, { error: "The plan's text is empty." });
  if (text.length > MAX_TEXT) return reply(413, { error: "That plan is too long to read in one go." });

  if ((await deps.noteUse(authorization, apikey)) > DAILY_LIMIT) {
    return reply(429, { error: "That's a lot of plans for one day. Please try again tomorrow." });
  }

  let raw: RawItem[];
  try {
    raw = await deps.extract(text);
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown";
    console.error("extract failed", reason);
    return reply(502, { error: "Couldn't read the plan just now. Please try again.", reason });
  }
  return reply(200, { ...check(raw, text) });
}

/**
 * Plain words for lines the parent already has (a plan read before plain
 * words existed). Nothing is stored; each result is checked against its line.
 */
async function plainWords(lines: unknown, authorization: string, apikey: string, deps: Deps): Promise<Response> {
  if (!Array.isArray(lines) || lines.length === 0 || lines.length > MAX_LINES) {
    return reply(400, { error: `Send 1 to ${MAX_LINES} lines as {"mode": "plain", "lines": [{"id", "text"}]}.` });
  }
  const valid = lines.filter((l): l is Line => typeof l?.id === "string" && typeof l?.text === "string" && l.text.length <= 4000);
  if ((await deps.noteUse(authorization, apikey)) > DAILY_LIMIT) {
    return reply(429, { error: "That's a lot for one day. Please try again tomorrow." });
  }
  let raw: { id: string; plain: string }[];
  try {
    raw = await deps.simplify(valid);
  } catch (error) {
    const reason = error instanceof Error ? error.message : "unknown";
    console.error("simplify failed", reason);
    return reply(502, { error: "Couldn't do that just now. Please try again.", reason });
  }
  const byID = new Map(valid.map((l) => [l.id, l.text]));
  const items = raw
    .filter((r) => typeof r?.id === "string" && typeof r?.plain === "string" && byID.has(r.id))
    .filter((r) => isFaithful(r.plain.trim(), byID.get(r.id)!))
    .map((r) => ({ id: r.id, plain: r.plain.trim() }));
  return reply(200, { items, rejected: raw.length - items.length });
}

// MARK: - Live dependencies

const url = Deno.env.get("SUPABASE_URL") ?? "";

function asCaller(authorization: string, apikey: string) {
  return createClient(url, apikey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export const live: Deps = {
  async userID(authorization, apikey) {
    const { data: { user } } = await asCaller(authorization, apikey).auth.getUser();
    return user?.id ?? null;
  },
  async noteUse(authorization, apikey) {
    const { data, error } = await asCaller(authorization, apikey).rpc("note_parse_use");
    if (error) throw new Error(error.message);
    return data as number;
  },
  async extract(text) {
    const input = await callModel(SYSTEM, TOOL, `The care plan's text:\n\n${text}`);
    return Array.isArray(input?.items) ? input.items : [];
  },
  async simplify(lines) {
    const listing = lines.map((l) => `id ${l.id}: ${l.text}`).join("\n\n");
    const input = await callModel(PLAIN_SYSTEM, PLAIN_TOOL, `Lines from the care plan:\n\n${listing}`);
    return Array.isArray(input?.items) ? input.items : [];
  },
};

// deno-lint-ignore no-explicit-any
async function callModel(system: string, tool: { name: string }, content: string): Promise<any> {
    const key = Deno.env.get("ANTHROPIC_API_KEY");
    if (!key) throw new Error("ANTHROPIC_API_KEY isn't set");
    const headers: Record<string, string> = {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    };
    // Keys that aren't scoped to a workspace must say which one to use.
    const workspace = Deno.env.get("ANTHROPIC_WORKSPACE_ID");
    if (workspace) headers["anthropic-workspace-id"] = workspace;
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers,
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 8000,
        system,
        tools: [tool],
        tool_choice: { type: "tool", name: tool.name },
        messages: [{ role: "user", content }],
      }),
    });
    if (!response.ok) {
      // Anthropic's error type and message only: never the key or the plan.
      const detail = await response.json().catch(() => ({}));
      throw new Error(`model returned ${response.status}: ${detail?.error?.type ?? ""} ${detail?.error?.message ?? ""}`.trim());
    }
    const body = await response.json();
    return body.content?.find((part: { type: string }) => part.type === "tool_use")?.input;
}

if (import.meta.main) Deno.serve((req) => handle(req, live));
