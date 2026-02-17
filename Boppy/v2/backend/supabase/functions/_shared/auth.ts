import { ApiHttpError, assert } from "./http.ts";
import type { AuthUser, Role } from "./types.ts";
import { adminGet, SupabaseRequestError, authUserFromToken } from "./supabase.ts";

function bearerToken(req: Request): string {
  const header = req.headers.get("authorization") ?? "";
  const [scheme, token] = header.split(" ");
  if (scheme?.toLowerCase() != "bearer" || !token) {
    throw new ApiHttpError(401, "missing_auth", "Bearer token is required.");
  }
  return token;
}

export async function requireUser(req: Request): Promise<AuthUser> {
  const token = bearerToken(req);

  try {
    const payload = await authUserFromToken(token) as { id?: string; phone?: string };
    assert(payload.id, 401, "invalid_auth", "Invalid or expired auth token.");

    return {
      id: payload.id,
      phone: payload.phone,
    };
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      throw new ApiHttpError(401, "invalid_auth", error.message);
    }
    throw error;
  }
}

export async function requireChannelRole(channelId: string, userId: string, role: Role): Promise<void> {
  const cid = encodeURIComponent(channelId);
  const uid = encodeURIComponent(userId);
  const rows = await adminGet(
    `channel_memberships?select=channel_id&channel_id=eq.${cid}&user_id=eq.${uid}&role=eq.${role}&limit=1`
  ) as Array<unknown>;

  assert(rows.length > 0, 403, "forbidden", `User does not have ${role} role for channel.`);
}

export async function requireAnyChannelRole(channelId: string, userId: string, roles: ReadonlyArray<Role>): Promise<void> {
  assert(roles.length > 0, 500, "server_error", "requireAnyChannelRole requires at least one role.");
  const cid = encodeURIComponent(channelId);
  const uid = encodeURIComponent(userId);
  const roleFilter = roles.map((role) => encodeURIComponent(role)).join(",");
  const rows = await adminGet(
    `channel_memberships?select=channel_id&channel_id=eq.${cid}&user_id=eq.${uid}&role=in.(${roleFilter})&limit=1`
  ) as Array<unknown>;

  assert(rows.length > 0, 403, "forbidden", `User does not have one of required roles: ${roles.join(", ")}.`);
}
