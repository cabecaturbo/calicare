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
import { SYSTEM, TOOL } from "./prompt.ts";

export const MAX_TEXT = 60_000;
export const DAILY_LIMIT = 10;
export const MODEL = "claude-sonnet-5";

export interface Deps {
  /** The signed-in caller's id, or null. */
  userID(authorization: string, apikey: string): Promise<string | null>;
  /** Counts this use for today and returns today's total. */
  noteUse(authorization: string, apikey: string): Promise<number>;
  /** Asks the model; returns its raw items. */
  extract(text: string): Promise<RawItem[]>;
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
  try {
    ({ text } = await req.json());
  } catch {
    return reply(400, { error: "Send the plan's text as JSON: {\"text\": \"...\"}." });
  }
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
        temperature: 0,
        system: SYSTEM,
        tools: [TOOL],
        tool_choice: { type: "tool", name: TOOL.name },
        messages: [{ role: "user", content: `The care plan's text:\n\n${text}` }],
      }),
    });
    if (!response.ok) {
      // Anthropic's error type and message only: never the key or the plan.
      const detail = await response.json().catch(() => ({}));
      throw new Error(`model returned ${response.status}: ${detail?.error?.type ?? ""} ${detail?.error?.message ?? ""}`.trim());
    }
    const body = await response.json();
    const call = body.content?.find((part: { type: string }) => part.type === "tool_use");
    return Array.isArray(call?.input?.items) ? call.input.items : [];
  },
};

if (import.meta.main) Deno.serve((req) => handle(req, live));
