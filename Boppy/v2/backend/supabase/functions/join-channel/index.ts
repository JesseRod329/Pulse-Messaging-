import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireUser } from "../_shared/auth.ts";
import { adminGet, adminPatch, adminPost, SupabaseRequestError } from "../_shared/supabase.ts";

interface JoinChannelBody {
  token: string;
}

interface InviteRow {
  id: string;
  channel_id: string;
  expires_at: string;
  max_uses: number | null;
  uses_count: number;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<JoinChannelBody>(req);
    assert(body.token, 400, "invalid_request", "token is required.");

    const token = encodeURIComponent(body.token);
    const inviteRows = await adminGet(
      `channel_invites?select=id,channel_id,expires_at,max_uses,uses_count&token=eq.${token}&limit=1`
    ) as InviteRow[];

    const invite = inviteRows[0];
    assert(invite, 404, "invite_not_found", "Invite not found.");

    const expiresAt = new Date(invite.expires_at);
    assert(expiresAt.getTime() > Date.now(), 410, "invite_expired", "Invite has expired.");
    if (invite.max_uses != null) {
      assert(invite.uses_count < invite.max_uses, 410, "invite_exhausted", "Invite usage limit reached.");
    }

    const cid = encodeURIComponent(invite.channel_id);
    const uid = encodeURIComponent(user.id);
    const membershipRows = await adminGet(
      `channel_memberships?select=channel_id&channel_id=eq.${cid}&user_id=eq.${uid}&limit=1`
    ) as Array<unknown>;

    if (membershipRows.length == 0) {
      await adminPost("channel_memberships", {
        channel_id: invite.channel_id,
        user_id: user.id,
        role: "follower",
      });

      const inviteId = encodeURIComponent(invite.id);
      await adminPatch(`channel_invites?id=eq.${inviteId}&select=id`, {
        uses_count: invite.uses_count + 1,
      });
    }

    return ok(rid, {
      channel_id: invite.channel_id,
      already_joined: membershipRows.length > 0,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
