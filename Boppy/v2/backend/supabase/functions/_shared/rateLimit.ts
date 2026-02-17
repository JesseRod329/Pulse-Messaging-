import { ApiHttpError, assert } from "./http.ts";
import { adminGet } from "./supabase.ts";

interface AdminActionRateLimitOptions {
  actorId: string;
  channelId?: string;
  actions: ReadonlyArray<string>;
  windowSeconds: number;
  maxEvents: number;
}

export function buildAdminActionRateLimitQuery(options: AdminActionRateLimitOptions): string {
  const since = new Date(Date.now() - options.windowSeconds * 1000).toISOString();
  const actor = encodeURIComponent(options.actorId);
  const channelFilter = options.channelId
    ? `&channel_id=eq.${encodeURIComponent(options.channelId)}`
    : "";
  const actionFilter = options.actions.length === 1
    ? `&action=eq.${encodeURIComponent(options.actions[0])}`
    : `&action=in.(${options.actions.map((action) => encodeURIComponent(action)).join(",")})`;

  return `admin_audit_events?select=id&actor_id=eq.${actor}${channelFilter}${actionFilter}&created_at=gte.${encodeURIComponent(since)}&order=created_at.desc&limit=${options.maxEvents}`;
}

export async function enforceAdminActionRateLimit(options: AdminActionRateLimitOptions): Promise<void> {
  assert(options.actorId, 500, "server_error", "actorId is required for rate limit checks.");
  assert(options.actions.length > 0, 500, "server_error", "At least one action is required for rate limit checks.");
  assert(options.windowSeconds > 0, 500, "server_error", "windowSeconds must be greater than 0.");
  assert(options.maxEvents > 0, 500, "server_error", "maxEvents must be greater than 0.");

  const rows = await adminGet(buildAdminActionRateLimitQuery(options)) as Array<{ id: string }>;

  if (rows.length >= options.maxEvents) {
    throw new ApiHttpError(
      429,
      "rate_limited",
      `Rate limit exceeded for action(s): ${options.actions.join(", ")}.`
    );
  }
}
