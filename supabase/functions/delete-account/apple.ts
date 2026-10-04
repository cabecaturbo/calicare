// Tells Apple to forget the app when someone deletes their account
// (App Store Review Guideline 5.1.1(v)).
//
// The app sends a fresh Sign in with Apple authorization code. We swap it
// for a refresh token, then revoke that token. Needs a Sign in with Apple key
// from the Apple Developer site, stored as Supabase secrets:
// APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY (the .p8's contents), and
// APPLE_CLIENT_ID (the bundle ID).

export interface AppleKey {
  teamID: string;
  keyID: string;
  clientID: string;
  privateKey: string; // PEM, "-----BEGIN PRIVATE KEY-----…"
}

type Fetch = typeof fetch;

/** The key from the environment, or nil when it isn't set up yet. */
export function keyFromEnv(env: (name: string) => string | undefined = (name) => Deno.env.get(name)): AppleKey | undefined {
  const teamID = env("APPLE_TEAM_ID");
  const keyID = env("APPLE_KEY_ID");
  const clientID = env("APPLE_CLIENT_ID");
  const privateKey = env("APPLE_PRIVATE_KEY")?.replaceAll("\\n", "\n");
  if (!teamID || !keyID || !clientID || !privateKey) return undefined;
  return { teamID, keyID, clientID, privateKey };
}

function base64url(bytes: Uint8Array | string): string {
  const data = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let binary = "";
  for (const byte of data) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function pemBody(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

/** The ES256 JWT Apple wants as client_secret, good for five minutes. */
export async function clientSecret(key: AppleKey, now = new Date()): Promise<string> {
  const issued = Math.floor(now.getTime() / 1000);
  const header = { alg: "ES256", kid: key.keyID };
  const claims = {
    iss: key.teamID,
    iat: issued,
    exp: issued + 300,
    aud: "https://appleid.apple.com",
    sub: key.clientID,
  };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", pemBody(key.privateKey), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );
  // WebCrypto signs as raw r‖s, which is what JWS wants.
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, cryptoKey, new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

/** Swaps the authorization code for a token, then revokes it. Throws on failure. */
export async function revoke(key: AppleKey, authorizationCode: string, fetcher: Fetch = fetch): Promise<void> {
  const secret = await clientSecret(key);
  const tokenResponse = await fetcher("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: key.clientID,
      client_secret: secret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  if (!tokenResponse.ok) throw new Error(`Apple token swap returned ${tokenResponse.status}`);
  const tokens = await tokenResponse.json() as { refresh_token?: string; access_token?: string };
  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token) throw new Error("Apple returned no token");

  const revokeResponse = await fetcher("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: key.clientID,
      client_secret: secret,
      token,
      token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
    }),
  });
  if (!revokeResponse.ok) throw new Error(`Apple revoke returned ${revokeResponse.status}`);
}
