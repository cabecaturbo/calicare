// delete-account (prompt 2.6): deletes the signed-in person's account.
//
// 1. Checks who's calling from their access token.
// 2. As that person, runs delete_my_account_data(): if they're a household's
//    last owner, the whole household goes (children, logs, members, invites);
//    otherwise only their membership.
// 3. Tells Apple to forget the app, when the app sent a fresh Sign in with
//    Apple code (see apple.ts). A failure here is logged, never blocking.
// 4. Deletes their auth user with the service role.
//
// Data on the phone is the app's business, not this function's.

import { createClient } from "@supabase/supabase-js";
import { keyFromEnv, revoke } from "./apple.ts";

const url = Deno.env.get("SUPABASE_URL")!;

/** The service key, from the legacy or the new-style environment. */
function serviceKey(): string | undefined {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    return keys.default ?? Object.values(keys)[0] as string | undefined;
  } catch {
    return undefined;
  }
}

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return reply(405, { error: "Use POST." });

  const authorization = req.headers.get("Authorization");
  const apikey = req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY");
  if (!authorization?.startsWith("Bearer ") || !apikey) {
    return reply(401, { error: "Sign in first." });
  }

  // Act as the caller, so RLS and auth.uid() apply.
  const asCaller = createClient(url, apikey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await asCaller.auth.getUser();
  if (userError || !user) return reply(401, { error: "Sign in first." });

  const { error: dataError } = await asCaller.rpc("delete_my_account_data");
  if (dataError) {
    console.error("delete_my_account_data failed", dataError.message);
    return reply(500, { error: "Couldn't delete the account's data." });
  }

  await revokeApple(req);

  const key = serviceKey();
  if (!key) return reply(500, { error: "Server isn't set up to delete accounts." });
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("deleteUser failed", deleteError.message);
    return reply(500, { error: "Couldn't delete the account." });
  }

  return reply(200, { deleted: true });
});

/** Revokes the Sign in with Apple token, if the app sent a code. */
async function revokeApple(req: Request): Promise<void> {
  const body = await req.json().catch(() => ({})) as { apple_authorization_code?: unknown };
  const code = body.apple_authorization_code;
  if (typeof code !== "string" || code.length === 0) return;
  const appleKey = keyFromEnv();
  if (!appleKey) {
    console.error("Apple revoke skipped: the APPLE_* secrets aren't set");
    return;
  }
  try {
    await revoke(appleKey, code);
  } catch (error) {
    console.error("Apple revoke failed", (error as Error).message);
  }
}
