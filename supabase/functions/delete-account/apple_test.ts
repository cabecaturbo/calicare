import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { type AppleKey, clientSecret, keyFromEnv, revoke } from "./apple.ts";

/** A throwaway P-256 key, made fresh for each run. */
async function testKey(): Promise<{ key: AppleKey; publicKey: CryptoKey }> {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...pkcs8))}\n-----END PRIVATE KEY-----`;
  return {
    key: { teamID: "F2J8ZU2NQJ", keyID: "KEY1234567", clientID: "com.cursorkittens.calicare", privateKey: pem },
    publicKey: pair.publicKey,
  };
}

function decode(part: string): Uint8Array<ArrayBuffer> {
  const base64 = part.replaceAll("-", "+").replaceAll("_", "/");
  return Uint8Array.from(atob(base64 + "=".repeat((4 - base64.length % 4) % 4)), (c) => c.charCodeAt(0));
}

Deno.test("client secret is a signed ES256 JWT with Apple's claims", async () => {
  const { key, publicKey } = await testKey();
  const jwt = await clientSecret(key, new Date(1_000_000_000_000));
  const [header, claims, signature] = jwt.split(".");
  assertEquals(JSON.parse(new TextDecoder().decode(decode(header))), { alg: "ES256", kid: "KEY1234567" });
  assertEquals(JSON.parse(new TextDecoder().decode(decode(claims))), {
    iss: "F2J8ZU2NQJ",
    iat: 1_000_000_000,
    exp: 1_000_000_300,
    aud: "https://appleid.apple.com",
    sub: "com.cursorkittens.calicare",
  });
  const valid = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" }, publicKey, decode(signature), new TextEncoder().encode(`${header}.${claims}`),
  );
  assertEquals(valid, true);
});

Deno.test("swaps the code, then revokes the refresh token", async () => {
  const { key } = await testKey();
  const calls: [string, URLSearchParams][] = [];
  const fake = ((url: string, init: RequestInit) => {
    calls.push([url, init.body as URLSearchParams]);
    const body = url.endsWith("/token") ? { refresh_token: "r-1", access_token: "a-1" } : {};
    return Promise.resolve(new Response(JSON.stringify(body), { status: 200 }));
  }) as typeof fetch;

  await revoke(key, "code-1", fake);

  assertEquals(calls.map(([url]) => url), ["https://appleid.apple.com/auth/token", "https://appleid.apple.com/auth/revoke"]);
  assertEquals(calls[0][1].get("code"), "code-1");
  assertEquals(calls[0][1].get("grant_type"), "authorization_code");
  assertEquals(calls[1][1].get("token"), "r-1");
  assertEquals(calls[1][1].get("token_type_hint"), "refresh_token");
  assertEquals(calls[1][1].get("client_id"), "com.cursorkittens.calicare");
});

Deno.test("a failed swap throws and doesn't call revoke", async () => {
  const { key } = await testKey();
  let calls = 0;
  const fake = (() => {
    calls += 1;
    return Promise.resolve(new Response("{}", { status: 400 }));
  }) as typeof fetch;
  await assertRejects(() => revoke(key, "expired", fake));
  assertEquals(calls, 1);
});

Deno.test("no key until all four secrets are set", () => {
  const env = new Map([["APPLE_TEAM_ID", "T"], ["APPLE_KEY_ID", "K"], ["APPLE_CLIENT_ID", "C"]]);
  assertEquals(keyFromEnv((name) => env.get(name)), undefined);
  env.set("APPLE_PRIVATE_KEY", "-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----");
  assertEquals(keyFromEnv((name) => env.get(name))?.privateKey.includes("\nabc\n"), true);
});
