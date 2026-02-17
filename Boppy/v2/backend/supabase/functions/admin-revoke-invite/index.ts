import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { adminDelete, adminGet, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminRevokeInviteBody {
  invite_id: string;
  reason: string;
}

interface InviteRow {
  id: string;
  channel_id: string;
  token: string;
  max_uses: number | null;
  uses_count: number;
  expires_at: string;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminRevokeInviteBody>(req);

    assert(body.invite_id, 400, "invalid_request", "invite_id is required.");
    assert(body.reason?.trim(), 400, "invalid_request", "reason is required.");

    const inviteRows = await adminGet(
      `channel_invites?select=id,channel_id,token,max_uses,uses_count,expires_at&id=eq.${encodeURIComponent(body.invite_id)}&limit=1`,
    ) as InviteRow[];
    const invite = inviteRows[0];
    assert(invite, 404, "invite_not_found", "Invite not found.");

    await requireChannelRole(invite.channel_id, user.id, "owner");

    await adminDelete(
      `channel_invites?id=eq.${encodeURIComponent(invite.id)}&select=id`,
    );

    await appendAdminAudit(
      invite.channel_id,
      user.id,
      "invite_revoked",
      "channel_invite",
      invite.id,
      body.reason.trim(),
      {
        token: invite.token,
        uses_count: invite.uses_count,
        max_uses: invite.max_uses,
        expires_at: invite.expires_at,
      },
    );

    return ok(rid, {
      invite_id: invite.id,
      revoked: true,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
