import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * Service-role client. Bypasses RLS — only use after validating a share token.
 * SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.
 */
export const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

/**
 * Returns the caller's user id if they sent a valid *user* JWT, otherwise null.
 * Guests send the anon/publishable key, which resolves to null.
 */
export async function optionalUserId(req: Request): Promise<string | null> {
  const header = req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return null;
  const { data, error } = await admin.auth.getUser(match[1]);
  if (error || !data?.user) return null;
  return data.user.id;
}
