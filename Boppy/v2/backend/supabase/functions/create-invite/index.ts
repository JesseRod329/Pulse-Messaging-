import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { enforceAdminActionRateLimit } from "../_shared/rateLimit.ts";
import { adminPost, SupabaseRequestError } from "../_shared/supabase.ts";

interface CreateInviteBody {
  channel_id: string;
  expires_in_hours?: number;
  max_uses?: number | null;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<CreateInviteBody>(req);

    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");
    await requireChannelRole(body.channel_id, user.id, "owner");
    await enforceAdminActionRateLimit({
      actorId: user.id,
      channelId: body.channel_id,
      actions: ["invite_created"],
      windowSeconds: 60 * 60,
      maxEvents: 25,
    });

    const expiresHours = Math.max(1, Math.min(body.expires_in_hours ?? 72, 24 * 30));
    const expiresAt = new Date(Date.now() + expiresHours * 60 * 60 * 1000).toISOString();
    const token = crypto.randomUUID().replaceAll("-", "").slice(0, 20);

    const rows = await adminPost("channel_invites?select=id,channel_id,token,expires_at,max_uses,uses_count", {
      channel_id: body.channel_id,
      token,
      expires_at: expiresAt,
      max_uses: body.max_uses ?? null,
      created_by: user.id,
    }) as Array<Record<string, unknown>>;

    const data = rows[0];
    assert(data, 500, "db_error", "Failed to create invite.");

    const inviteID = typeof data.id === "string" ? data.id : "unknown";
    await appendAdminAudit(
      body.channel_id,
      user.id,
      "invite_created",
      "channel_invite",
      inviteID,
      null,
      {
        expires_at: data.expires_at ?? expiresAt,
        max_uses: data.max_uses ?? (body.max_uses ?? null),
      }
    );

    return ok(rid, {
      ...data,
      invite_url: `beambox://invite/${token}`,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
