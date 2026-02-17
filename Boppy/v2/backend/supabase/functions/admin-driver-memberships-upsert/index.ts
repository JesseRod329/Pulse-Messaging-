import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { adminGet, adminPatch, adminPost, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminDriverMembershipsUpsertBody {
  channel_id: string;
  driver_user_id: string;
  operation: "add" | "remove";
  reason: string;
}

const ACTIVE_DRIVER_ORDER_STATUSES = ["assigned", "out_for_delivery"];

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminDriverMembershipsUpsertBody>(req);

    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");
    assert(body.driver_user_id, 400, "invalid_request", "driver_user_id is required.");
    assert(body.operation == "add" || body.operation == "remove", 400, "invalid_request", "operation must be add or remove.");
    assert(body.reason?.trim(), 400, "invalid_request", "reason is required.");

    await requireChannelRole(body.channel_id, user.id, "owner");

    const membershipRows = await adminGet(
      `channel_memberships?select=channel_id,user_id,role&channel_id=eq.${encodeURIComponent(body.channel_id)}&user_id=eq.${encodeURIComponent(body.driver_user_id)}&limit=1`
    ) as Array<{ channel_id: string; user_id: string; role: string }>;
    const existing = membershipRows[0];

    if (body.operation == "add") {
      if (!existing) {
        await adminPost("channel_memberships?select=channel_id,user_id,role", {
          channel_id: body.channel_id,
          user_id: body.driver_user_id,
          role: "driver",
        });
      } else if (existing.role != "driver") {
        assert(
          existing.role != "owner",
          409,
          "owner_cannot_be_driver",
          "Owner membership cannot be converted to driver via this endpoint."
        );
        await adminPatch(
          `channel_memberships?channel_id=eq.${encodeURIComponent(body.channel_id)}&user_id=eq.${encodeURIComponent(body.driver_user_id)}&select=channel_id,user_id,role`,
          { role: "driver" }
        );
      }

      await appendAdminAudit(
        body.channel_id,
        user.id,
        "driver_membership_added",
        "channel_membership",
        `${body.channel_id}:${body.driver_user_id}`,
        body.reason.trim(),
        {}
      );

      return ok(rid, {
        channel_id: body.channel_id,
        driver_user_id: body.driver_user_id,
        operation: "add",
        role_after: "driver",
        already_driver: Boolean(existing && existing.role == "driver"),
      });
    }

    if (existing && existing.role == "driver") {
      const statusFilter = ACTIVE_DRIVER_ORDER_STATUSES.map((status) => encodeURIComponent(status)).join(",");
      const activeOrders = await adminGet(
        `order_requests?select=id&channel_id=eq.${encodeURIComponent(body.channel_id)}&assigned_driver_id=eq.${encodeURIComponent(body.driver_user_id)}&status=in.(${statusFilter})&limit=1`
      ) as Array<{ id: string }>;
      assert(
        activeOrders.length == 0,
        409,
        "driver_has_active_orders",
        "Cannot remove driver role while driver has active assigned orders."
      );

      await adminPatch(
        `channel_memberships?channel_id=eq.${encodeURIComponent(body.channel_id)}&user_id=eq.${encodeURIComponent(body.driver_user_id)}&role=eq.driver&select=channel_id,user_id,role`,
        { role: "follower" }
      );
    }

    await appendAdminAudit(
      body.channel_id,
      user.id,
      "driver_membership_removed",
      "channel_membership",
      `${body.channel_id}:${body.driver_user_id}`,
      body.reason.trim(),
      {}
    );

    return ok(rid, {
      channel_id: body.channel_id,
      driver_user_id: body.driver_user_id,
      operation: "remove",
      role_after: existing && existing.role == "driver" ? "follower" : existing?.role ?? null,
      removed_driver_role: Boolean(existing && existing.role == "driver"),
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
