import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { appendLedger } from "../_shared/ledger.ts";
import { enforceAdminActionRateLimit } from "../_shared/rateLimit.ts";
import { adminGet, adminPatch, adminRpc, SupabaseRequestError } from "../_shared/supabase.ts";
import type { OrderStatus } from "../_shared/types.ts";
import { canTransition } from "./transitions.ts";

interface UpdateOrderStatusBody {
  order_id: string;
  status: OrderStatus;
  quote_note?: string;
}

interface OrderRow {
  id: string;
  channel_id: string;
  status: OrderStatus;
  quote_note: string | null;
}

interface InventoryMutationSummary {
  event: "order_inventory_reserved" | "order_inventory_restocked";
  reason: string;
  entities_adjusted: number;
  units_adjusted: number;
}

function coerceInventoryMutation(payload: unknown): InventoryMutationSummary | null {
  if (payload == null) {
    return null;
  }

  if (Array.isArray(payload)) {
    return coerceInventoryMutation(payload[0]);
  }

  if (typeof payload !== "object") {
    return null;
  }

  const value = payload as Record<string, unknown>;
  const nested = value.reserve_order_inventory_atomic ?? value.restock_order_inventory_atomic;
  if (nested !== undefined) {
    return coerceInventoryMutation(nested);
  }

  const eventRaw = value.event;
  const reason = value.reason;
  const entitiesAdjusted = value.entities_adjusted;
  const unitsAdjusted = value.units_adjusted;

  if (
    (eventRaw == "order_inventory_reserved" || eventRaw == "order_inventory_restocked") &&
    typeof reason == "string" &&
    typeof entitiesAdjusted == "number" &&
    typeof unitsAdjusted == "number"
  ) {
    const event: InventoryMutationSummary["event"] = eventRaw == "order_inventory_reserved"
      ? "order_inventory_reserved"
      : "order_inventory_restocked";
    return {
      event,
      reason,
      entities_adjusted: entitiesAdjusted,
      units_adjusted: unitsAdjusted,
    };
  }

  return null;
}

function mapInventoryRpcError(error: SupabaseRequestError): ApiHttpError {
  const message = error.message.toLowerCase();

  if (message.includes("insufficient_stock")) {
    return new ApiHttpError(409, "insufficient_stock", "Insufficient stock for one or more order line items.");
  }

  if (message.includes("inventory_reference_missing")) {
    return new ApiHttpError(409, "inventory_reference_missing", "Order references inventory items that are unavailable.");
  }

  if (message.includes("order_not_found")) {
    return new ApiHttpError(404, "order_not_found", "Order not found.");
  }

  return new ApiHttpError(500, "db_error", error.message);
}

async function reserveOrderInventory(orderID: string, actorID: string): Promise<InventoryMutationSummary | null> {
  try {
    const payload = await adminRpc("reserve_order_inventory_atomic", {
      p_order_id: orderID,
      p_actor_id: actorID,
    });
    return coerceInventoryMutation(payload);
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      throw mapInventoryRpcError(error);
    }
    throw error;
  }
}

async function restockOrderInventory(orderID: string, actorID: string): Promise<InventoryMutationSummary | null> {
  try {
    const payload = await adminRpc("restock_order_inventory_atomic", {
      p_order_id: orderID,
      p_actor_id: actorID,
    });
    return coerceInventoryMutation(payload);
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      throw mapInventoryRpcError(error);
    }
    throw error;
  }
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<UpdateOrderStatusBody>(req);

    assert(body.order_id, 400, "invalid_request", "order_id is required.");
    assert(body.status, 400, "invalid_request", "status is required.");

    const orderRows = await adminGet(
      `order_requests?select=id,channel_id,status,quote_note&id=eq.${encodeURIComponent(body.order_id)}&limit=1`
    ) as OrderRow[];

    const order = orderRows[0];
    assert(order, 404, "order_not_found", "Order not found.");

    await requireChannelRole(order.channel_id, user.id, "owner");
    await enforceAdminActionRateLimit({
      actorId: user.id,
      channelId: order.channel_id,
      actions: ["order_status_updated"],
      windowSeconds: 5 * 60,
      maxEvents: 80,
    });

    assert(
      canTransition(order.status, body.status),
      409,
      "invalid_status_transition",
      `Cannot transition order from ${order.status} to ${body.status}.`
    );

    let inventoryMutation: InventoryMutationSummary | null = null;
    if (order.status !== body.status && body.status == "accepted") {
      inventoryMutation = await reserveOrderInventory(order.id, user.id);
    } else if (order.status !== body.status && body.status == "cancelled") {
      inventoryMutation = await restockOrderInventory(order.id, user.id);
    }

    const patch: Record<string, unknown> = { status: body.status };
    if (typeof body.quote_note == "string") {
      patch.quote_note = body.quote_note;
    }

    const updatedRows = await adminPatch(
      `order_requests?id=eq.${encodeURIComponent(body.order_id)}&select=id,status,quote_note,updated_at`,
      patch
    ) as Array<{ id: string; status: string; quote_note: string | null; updated_at: string }>;

    const updated = updatedRows[0];
    assert(updated, 500, "db_error", "Order update failed.");

    await appendLedger(order.id, user.id, `status_${body.status}`, {
      from: order.status,
      to: body.status,
      quote_note: typeof body.quote_note == "string" ? body.quote_note : order.quote_note,
      inventory_mutation: inventoryMutation,
    });

    await appendAdminAudit(
      order.channel_id,
      user.id,
      "order_status_updated",
      "order_request",
      order.id,
      null,
      {
        from_status: order.status,
        to_status: body.status,
        quote_note_updated: typeof body.quote_note == "string",
        inventory_mutation: inventoryMutation,
      }
    );

    return ok(rid, updated);
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
