import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { appendLedger } from "../_shared/ledger.ts";
import { adminGet, adminPatch, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminUnassignDriverBody {
  order_id: string;
  reason: string;
}

interface OrderRow {
  id: string;
  channel_id: string;
  assigned_driver_id: string | null;
  status: string;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminUnassignDriverBody>(req);

    assert(body.order_id, 400, "invalid_request", "order_id is required.");
    assert(body.reason?.trim(), 400, "invalid_request", "reason is required.");

    const orderRows = await adminGet(
      `order_requests?select=id,channel_id,assigned_driver_id,status&id=eq.${encodeURIComponent(body.order_id)}&limit=1`
    ) as OrderRow[];
    const order = orderRows[0];
    assert(order, 404, "order_not_found", "Order not found.");

    await requireChannelRole(order.channel_id, user.id, "owner");
    assert(order.assigned_driver_id, 409, "no_driver_assigned", "Order has no assigned driver.");

    const rows = await adminPatch(
      `order_requests?id=eq.${encodeURIComponent(order.id)}&select=id,assigned_driver_id,status,updated_at`,
      {
        assigned_driver_id: null,
        status: "accepted",
      }
    ) as Array<Record<string, unknown>>;
    const updated = rows[0];
    assert(updated, 500, "db_error", "Driver unassignment failed.");

    await appendLedger(order.id, user.id, "driver_unassigned", {
      previous_driver_id: order.assigned_driver_id,
      reason: body.reason.trim(),
    });

    await appendAdminAudit(
      order.channel_id,
      user.id,
      "order_driver_unassigned",
      "order_request",
      order.id,
      body.reason.trim(),
      { previous_driver_id: order.assigned_driver_id }
    );

    return ok(rid, updated);
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
