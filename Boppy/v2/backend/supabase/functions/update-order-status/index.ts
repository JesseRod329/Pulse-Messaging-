import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { appendLedger } from "../_shared/ledger.ts";
import { enforceAdminActionRateLimit } from "../_shared/rateLimit.ts";
import { adminGet, adminPatch, adminPost, SupabaseRequestError } from "../_shared/supabase.ts";
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

interface OrderLineItemRow {
  id: string;
  item_id: string | null;
  variant_id: string | null;
  quantity: number;
}

interface ItemStockRow {
  id: string;
  channel_id: string;
  stock_on_hand: number;
}

interface VariantStockRow {
  id: string;
  item_id: string;
  stock_on_hand: number;
}

interface InventoryMutationSummary {
  event: "order_inventory_reserved" | "order_inventory_restocked";
  reason: string;
  entities_adjusted: number;
  units_adjusted: number;
}

function inFilter(values: readonly string[]): string {
  return values.map((value) => encodeURIComponent(value)).join(",");
}

function mapToDemand(items: OrderLineItemRow[]): {
  itemDemand: Map<string, number>;
  variantDemand: Map<string, number>;
} {
  const itemDemand = new Map<string, number>();
  const variantDemand = new Map<string, number>();

  for (const item of items) {
    if (item.variant_id) {
      variantDemand.set(item.variant_id, (variantDemand.get(item.variant_id) ?? 0) + item.quantity);
      continue;
    }
    if (item.item_id) {
      itemDemand.set(item.item_id, (itemDemand.get(item.item_id) ?? 0) + item.quantity);
    }
  }

  return { itemDemand, variantDemand };
}

async function hasInventoryMutation(
  channelID: string,
  reason: string,
): Promise<boolean> {
  const rows = await adminGet(
    `inventory_stock_ledger?select=id&channel_id=eq.${encodeURIComponent(channelID)}&reason=eq.${encodeURIComponent(reason)}&limit=1`
  ) as Array<{ id: string }>;
  return rows.length > 0;
}

async function loadOrderLineItems(orderID: string): Promise<OrderLineItemRow[]> {
  return await adminGet(
    `order_line_items?select=id,item_id,variant_id,quantity&order_id=eq.${encodeURIComponent(orderID)}`
  ) as OrderLineItemRow[];
}

async function reserveOrderInventory(order: OrderRow, actorID: string): Promise<InventoryMutationSummary | null> {
  const reason = `order_reserved:${order.id}`;
  if (await hasInventoryMutation(order.channel_id, reason)) {
    return null;
  }

  const lineItems = await loadOrderLineItems(order.id);
  const { itemDemand, variantDemand } = mapToDemand(lineItems);
  if (itemDemand.size === 0 && variantDemand.size === 0) {
    return null;
  }

  const variantIDs = [...variantDemand.keys()];
  const variantRows = variantIDs.length > 0
    ? await adminGet(
      `inventory_item_variants?select=id,item_id,stock_on_hand&id=in.(${inFilter(variantIDs)})`
    ) as VariantStockRow[]
    : [];
  const variantMap = new Map(variantRows.map((row) => [row.id, row]));
  assert(
    variantMap.size === variantIDs.length,
    409,
    "inventory_reference_missing",
    "Order references missing inventory variants."
  );

  const allItemIDs = new Set<string>([...itemDemand.keys(), ...variantRows.map((row) => row.item_id)]);
  const itemRows = allItemIDs.size > 0
    ? await adminGet(
      `inventory_items?select=id,channel_id,stock_on_hand&id=in.(${inFilter([...allItemIDs])})&channel_id=eq.${encodeURIComponent(order.channel_id)}`
    ) as ItemStockRow[]
    : [];
  const itemMap = new Map(itemRows.map((row) => [row.id, row]));
  assert(
    itemMap.size === allItemIDs.size,
    409,
    "inventory_reference_missing",
    "Order references inventory items outside this channel."
  );

  const variantNextBalance = new Map<string, number>();
  for (const [variantID, qty] of variantDemand) {
    const variant = variantMap.get(variantID);
    assert(variant, 409, "inventory_reference_missing", `Variant ${variantID} not found.`);
    const next = variant.stock_on_hand - qty;
    assert(next >= 0, 409, "insufficient_stock", `Insufficient stock for variant ${variantID}.`);
    variantNextBalance.set(variantID, next);
  }

  const itemNextBalance = new Map<string, number>();
  for (const [itemID, qty] of itemDemand) {
    const item = itemMap.get(itemID);
    assert(item, 409, "inventory_reference_missing", `Item ${itemID} not found.`);
    const next = item.stock_on_hand - qty;
    assert(next >= 0, 409, "insufficient_stock", `Insufficient stock for item ${itemID}.`);
    itemNextBalance.set(itemID, next);
  }

  for (const [variantID, next] of variantNextBalance) {
    await adminPatch(
      `inventory_item_variants?id=eq.${encodeURIComponent(variantID)}&select=id,stock_on_hand`,
      { stock_on_hand: next }
    );
  }

  for (const [itemID, next] of itemNextBalance) {
    await adminPatch(
      `inventory_items?id=eq.${encodeURIComponent(itemID)}&select=id,stock_on_hand`,
      { stock_on_hand: next }
    );
  }

  for (const [variantID, qty] of variantDemand) {
    await adminPost("inventory_stock_ledger?select=id", {
      channel_id: order.channel_id,
      item_id: variantMap.get(variantID)!.item_id,
      variant_id: variantID,
      actor_id: actorID,
      delta: -qty,
      balance_after: variantNextBalance.get(variantID)!,
      reason,
      metadata_json: {
        event_kind: "order_inventory_reserved",
        order_id: order.id,
      },
    });
  }

  for (const [itemID, qty] of itemDemand) {
    await adminPost("inventory_stock_ledger?select=id", {
      channel_id: order.channel_id,
      item_id: itemID,
      variant_id: null,
      actor_id: actorID,
      delta: -qty,
      balance_after: itemNextBalance.get(itemID)!,
      reason,
      metadata_json: {
        event_kind: "order_inventory_reserved",
        order_id: order.id,
      },
    });
  }

  const entitiesAdjusted = variantDemand.size + itemDemand.size;
  const unitsAdjusted = [...variantDemand.values(), ...itemDemand.values()].reduce((sum, qty) => sum + qty, 0);

  await appendAdminAudit(
    order.channel_id,
    actorID,
    "order_inventory_reserved",
    "order_request",
    order.id,
    null,
    {
      entities_adjusted: entitiesAdjusted,
      units_adjusted: unitsAdjusted,
    }
  );

  return {
    event: "order_inventory_reserved",
    reason,
    entities_adjusted: entitiesAdjusted,
    units_adjusted: unitsAdjusted,
  };
}

async function restockCancelledOrder(order: OrderRow, actorID: string): Promise<InventoryMutationSummary | null> {
  const reserveReason = `order_reserved:${order.id}`;
  const restockReason = `order_cancel_restock:${order.id}`;

  if (!(await hasInventoryMutation(order.channel_id, reserveReason))) {
    return null;
  }
  if (await hasInventoryMutation(order.channel_id, restockReason)) {
    return null;
  }

  const lineItems = await loadOrderLineItems(order.id);
  const { itemDemand, variantDemand } = mapToDemand(lineItems);
  if (itemDemand.size === 0 && variantDemand.size === 0) {
    return null;
  }

  const variantIDs = [...variantDemand.keys()];
  const variantRows = variantIDs.length > 0
    ? await adminGet(
      `inventory_item_variants?select=id,item_id,stock_on_hand&id=in.(${inFilter(variantIDs)})`
    ) as VariantStockRow[]
    : [];
  const variantMap = new Map(variantRows.map((row) => [row.id, row]));
  assert(
    variantMap.size === variantIDs.length,
    409,
    "inventory_reference_missing",
    "Order references missing inventory variants."
  );

  const allItemIDs = new Set<string>([...itemDemand.keys(), ...variantRows.map((row) => row.item_id)]);
  const itemRows = allItemIDs.size > 0
    ? await adminGet(
      `inventory_items?select=id,channel_id,stock_on_hand&id=in.(${inFilter([...allItemIDs])})&channel_id=eq.${encodeURIComponent(order.channel_id)}`
    ) as ItemStockRow[]
    : [];
  const itemMap = new Map(itemRows.map((row) => [row.id, row]));
  assert(
    itemMap.size === allItemIDs.size,
    409,
    "inventory_reference_missing",
    "Order references inventory items outside this channel."
  );

  const variantNextBalance = new Map<string, number>();
  for (const [variantID, qty] of variantDemand) {
    const variant = variantMap.get(variantID);
    assert(variant, 409, "inventory_reference_missing", `Variant ${variantID} not found.`);
    variantNextBalance.set(variantID, variant.stock_on_hand + qty);
  }

  const itemNextBalance = new Map<string, number>();
  for (const [itemID, qty] of itemDemand) {
    const item = itemMap.get(itemID);
    assert(item, 409, "inventory_reference_missing", `Item ${itemID} not found.`);
    itemNextBalance.set(itemID, item.stock_on_hand + qty);
  }

  for (const [variantID, next] of variantNextBalance) {
    await adminPatch(
      `inventory_item_variants?id=eq.${encodeURIComponent(variantID)}&select=id,stock_on_hand`,
      { stock_on_hand: next }
    );
  }

  for (const [itemID, next] of itemNextBalance) {
    await adminPatch(
      `inventory_items?id=eq.${encodeURIComponent(itemID)}&select=id,stock_on_hand`,
      { stock_on_hand: next }
    );
  }

  for (const [variantID, qty] of variantDemand) {
    await adminPost("inventory_stock_ledger?select=id", {
      channel_id: order.channel_id,
      item_id: variantMap.get(variantID)!.item_id,
      variant_id: variantID,
      actor_id: actorID,
      delta: qty,
      balance_after: variantNextBalance.get(variantID)!,
      reason: restockReason,
      metadata_json: {
        event_kind: "order_inventory_restocked",
        order_id: order.id,
      },
    });
  }

  for (const [itemID, qty] of itemDemand) {
    await adminPost("inventory_stock_ledger?select=id", {
      channel_id: order.channel_id,
      item_id: itemID,
      variant_id: null,
      actor_id: actorID,
      delta: qty,
      balance_after: itemNextBalance.get(itemID)!,
      reason: restockReason,
      metadata_json: {
        event_kind: "order_inventory_restocked",
        order_id: order.id,
      },
    });
  }

  const entitiesAdjusted = variantDemand.size + itemDemand.size;
  const unitsAdjusted = [...variantDemand.values(), ...itemDemand.values()].reduce((sum, qty) => sum + qty, 0);

  await appendAdminAudit(
    order.channel_id,
    actorID,
    "order_inventory_restocked",
    "order_request",
    order.id,
    null,
    {
      entities_adjusted: entitiesAdjusted,
      units_adjusted: unitsAdjusted,
    }
  );

  return {
    event: "order_inventory_restocked",
    reason: restockReason,
    entities_adjusted: entitiesAdjusted,
    units_adjusted: unitsAdjusted,
  };
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
    if (order.status !== body.status && body.status === "accepted") {
      inventoryMutation = await reserveOrderInventory(order, user.id);
    } else if (order.status !== body.status && body.status === "cancelled") {
      inventoryMutation = await restockCancelledOrder(order, user.id);
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
