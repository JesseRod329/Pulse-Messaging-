import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { appendLedger } from "../_shared/ledger.ts";
import { enforceAdminActionRateLimit } from "../_shared/rateLimit.ts";
import { adminDelete, adminGet, adminPatch, SupabaseRequestError } from "../_shared/supabase.ts";
import { canHardDeleteStatus } from "./logic.ts";

interface AdminDeleteOrderBody {
  order_id: string;
  reason: string;
  hard_delete?: boolean;
}

interface OrderRow {
  id: string;
  channel_id: string;
  status: string;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminDeleteOrderBody>(req);

    assert(body.order_id, 400, "invalid_request", "order_id is required.");
    assert(body.reason?.trim(), 400, "invalid_request", "reason is required.");

    const orderRows = await adminGet(
      `order_requests?select=id,channel_id,status&id=eq.${encodeURIComponent(body.order_id)}&limit=1`
    ) as OrderRow[];
    const order = orderRows[0];
    assert(order, 404, "order_not_found", "Order not found.");

    await requireChannelRole(order.channel_id, user.id, "owner");
    await enforceAdminActionRateLimit({
      actorId: user.id,
      channelId: order.channel_id,
      actions: ["order_soft_deleted", "order_hard_deleted"],
      windowSeconds: 60 * 60,
      maxEvents: 30,
    });
    const hardDelete = body.hard_delete ?? false;

    if (hardDelete) {
      const hardDeleteEnabled = Deno.env.get("ALLOW_HARD_DELETE")?.toLowerCase() == "true";
      assert(
        hardDeleteEnabled,
        403,
        "hard_delete_disabled",
        "Hard delete is disabled by policy.",
      );
      assert(
        canHardDeleteStatus(order.status),
        409,
        "hard_delete_not_allowed_for_status",
        `Hard delete is only allowed for terminal orders (cancelled/delivered). Current status: ${order.status}.`,
      );
      await adminDelete(`order_requests?id=eq.${encodeURIComponent(order.id)}&select=id`);
      await appendAdminAudit(
        order.channel_id,
        user.id,
        "order_hard_deleted",
        "order_request",
        order.id,
        body.reason.trim(),
        { previous_status: order.status }
      );
      return ok(rid, {
        order_id: order.id,
        mode: "hard_delete",
      });
    }

    const rows = await adminPatch(
      `order_requests?id=eq.${encodeURIComponent(order.id)}&select=id,status,updated_at,archived_at`,
      {
        status: "cancelled",
        archived_at: new Date().toISOString(),
      }
    ) as Array<Record<string, unknown>>;
    const updated = rows[0];
    assert(updated, 500, "db_error", "Order archive failed.");

    await appendLedger(order.id, user.id, "order_admin_archived", {
      previous_status: order.status,
      reason: body.reason.trim(),
    });

    await appendAdminAudit(
      order.channel_id,
      user.id,
      "order_soft_deleted",
      "order_request",
      order.id,
      body.reason.trim(),
      { previous_status: order.status }
    );

    return ok(rid, {
      order_id: order.id,
      mode: "soft_delete",
      order: updated,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
