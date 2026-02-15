import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { adminGet, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminOrderLineItemsListBody {
  order_id: string;
}

interface OrderRow {
  id: string;
  channel_id: string;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminOrderLineItemsListBody>(req);
    assert(body.order_id, 400, "invalid_request", "order_id is required.");

    const orderRows = await adminGet(
      `order_requests?select=id,channel_id&id=eq.${encodeURIComponent(body.order_id)}&limit=1`,
    ) as OrderRow[];
    const order = orderRows[0];
    assert(order, 404, "order_not_found", "Order not found.");

    await requireChannelRole(order.channel_id, user.id, "owner");

    const lineItems = await adminGet(
      `order_line_items?select=id,order_id,item_id,variant_id,title,sku,quantity,unit_price_cents,line_total_cents,created_at&order_id=eq.${encodeURIComponent(order.id)}&order=created_at.desc`,
    ) as Array<Record<string, unknown>>;

    return ok(rid, {
      order_id: order.id,
      count: lineItems.length,
      line_items: lineItems,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
