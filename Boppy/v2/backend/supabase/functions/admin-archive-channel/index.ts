import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { enforceAdminActionRateLimit } from "../_shared/rateLimit.ts";
import { adminPatch, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminArchiveChannelBody {
  channel_id: string;
  reason: string;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminArchiveChannelBody>(req);

    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");
    assert(body.reason?.trim(), 400, "invalid_request", "reason is required.");

    await requireChannelRole(body.channel_id, user.id, "owner");
    await enforceAdminActionRateLimit({
      actorId: user.id,
      channelId: body.channel_id,
      actions: ["channel_archived"],
      windowSeconds: 60 * 60,
      maxEvents: 10,
    });

    const rows = await adminPatch(
      `channels?id=eq.${encodeURIComponent(body.channel_id)}&select=id,title,is_active,updated_at`,
      { is_active: false }
    ) as Array<Record<string, unknown>>;

    const channel = rows[0];
    assert(channel, 500, "db_error", "Failed to archive channel.");

    await appendAdminAudit(
      body.channel_id,
      user.id,
      "channel_archived",
      "channel",
      body.channel_id,
      body.reason.trim(),
      {}
    );

    return ok(rid, channel);
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
