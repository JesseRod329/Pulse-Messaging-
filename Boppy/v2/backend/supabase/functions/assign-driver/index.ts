import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendLedger } from "../_shared/ledger.ts";
import { adminGet, adminPatch, SupabaseRequestError } from "../_shared/supabase.ts";
import type { OrderStatus } from "../_shared/types.ts";
import { isLegalAssignmentStatus } from "./logic.ts";

interface AssignDriverBody {
  order_id: string;
  driver_id: string;
}

interface OrderRow {
  id: string;
  channel_id: string;
  assigned_driver_id: string | null;
  status: OrderStatus;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AssignDriverBody>(req);

    assert(body.order_id, 400, "invalid_request", "order_id is required.");
    assert(body.driver_id, 400, "invalid_request", "driver_id is required.");

    const orderRows = await adminGet(
      `order_requests?select=id,channel_id,assigned_driver_id,status&id=eq.${encodeURIComponent(body.order_id)}&limit=1`
    ) as OrderRow[];

    const order = orderRows[0];
    assert(order, 404, "order_not_found", "Order not found.");

    await requireChannelRole(order.channel_id, user.id, "owner");
    await requireChannelRole(order.channel_id, body.driver_id, "driver");
    assert(
      isLegalAssignmentStatus(order.status),
      409,
      "invalid_assignment_state",
      `Cannot assign driver while order is ${order.status}.`
    );

    const updatedRows = await adminPatch(
      `order_requests?id=eq.${encodeURIComponent(body.order_id)}&select=id,assigned_driver_id,status,updated_at`,
      {
        assigned_driver_id: body.driver_id,
        status: "assigned",
      }
    ) as Array<{ id: string; assigned_driver_id: string; status: string; updated_at: string }>;

    const updated = updatedRows[0];
    assert(updated, 500, "db_error", "Order assignment failed.");

    await appendLedger(order.id, user.id, "driver_assigned", {
      from_driver_id: order.assigned_driver_id,
      to_driver_id: body.driver_id,
    });

    return ok(rid, updated);
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
