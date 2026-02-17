import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { adminGet, adminPatch, adminPost, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminMemberRoleUpsertBody {
  channel_id: string;
  user_id: string;
  role: "driver" | "follower";
  reason: string;
}

interface ChannelRow {
  id: string;
  owner_id: string;
}

interface MembershipRow {
  channel_id: string;
  user_id: string;
  role: string;
  joined_at: string;
}

const ACTIVE_DRIVER_ORDER_STATUSES = ["assigned", "out_for_delivery"];

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminMemberRoleUpsertBody>(req);

    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");
    assert(body.user_id, 400, "invalid_request", "user_id is required.");
    assert(body.role === "driver" || body.role === "follower", 400, "invalid_request", "role must be driver or follower.");
    assert(body.reason?.trim(), 400, "invalid_request", "reason is required.");

    await requireChannelRole(body.channel_id, user.id, "owner");

    const channelRows = await adminGet(
      `channels?select=id,owner_id&id=eq.${encodeURIComponent(body.channel_id)}&limit=1`,
    ) as ChannelRow[];
    const channel = channelRows[0];
    assert(channel, 404, "channel_not_found", "Channel not found.");
    assert(channel.owner_id !== body.user_id, 409, "invalid_target", "Cannot change channel owner role.");

    const membershipRows = await adminGet(
      `channel_memberships?select=channel_id,user_id,role,joined_at&channel_id=eq.${encodeURIComponent(body.channel_id)}&user_id=eq.${encodeURIComponent(body.user_id)}&limit=1`,
    ) as MembershipRow[];
    const existing = membershipRows[0];

    const demotingDriverToFollower = existing?.role == "driver" && body.role == "follower";
    if (demotingDriverToFollower) {
      const statusFilter = ACTIVE_DRIVER_ORDER_STATUSES.map((status) => encodeURIComponent(status)).join(",");
      const activeOrders = await adminGet(
        `order_requests?select=id&channel_id=eq.${encodeURIComponent(body.channel_id)}&assigned_driver_id=eq.${encodeURIComponent(body.user_id)}&status=in.(${statusFilter})&limit=1`,
      ) as Array<{ id: string }>;
      assert(
        activeOrders.length == 0,
        409,
        "driver_has_active_orders",
        "Cannot change driver to follower while driver has active assigned orders.",
      );
    }

    let result: MembershipRow | undefined;
    if (existing) {
      const rows = await adminPatch(
        `channel_memberships?channel_id=eq.${encodeURIComponent(body.channel_id)}&user_id=eq.${encodeURIComponent(body.user_id)}&select=channel_id,user_id,role,joined_at`,
        { role: body.role },
      ) as MembershipRow[];
      result = rows[0];
    } else {
      const rows = await adminPost(
        "channel_memberships?select=channel_id,user_id,role,joined_at",
        {
          channel_id: body.channel_id,
          user_id: body.user_id,
          role: body.role,
        },
      ) as MembershipRow[];
      result = rows[0];
    }

    assert(result, 500, "db_error", "Failed to upsert member role.");

    await appendAdminAudit(
      body.channel_id,
      user.id,
      "channel_member_role_upserted",
      "channel_membership",
      `${body.channel_id}:${body.user_id}`,
      body.reason.trim(),
      {
        previous_role: existing?.role ?? null,
        next_role: body.role,
      },
    );

    return ok(rid, {
      membership: result,
      previous_role: existing?.role ?? null,
      created: !existing,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
