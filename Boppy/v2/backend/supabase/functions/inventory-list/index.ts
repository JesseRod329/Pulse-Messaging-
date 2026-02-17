import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireAnyChannelRole, requireUser } from "../_shared/auth.ts";
import { adminGet, SupabaseRequestError } from "../_shared/supabase.ts";

interface InventoryListBody {
  channel_id: string;
  include_inactive?: boolean;
  include_ledger?: boolean;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<InventoryListBody>(req);
    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");

    await requireAnyChannelRole(body.channel_id, user.id, ["owner", "driver"]);

    const cid = encodeURIComponent(body.channel_id);
    const includeInactive = body.include_inactive ?? false;
    const itemsQuery = includeInactive
      ? `inventory_items?select=id,channel_id,name,sku,description,default_price_cents,currency_code,track_stock,stock_on_hand,low_stock_threshold,is_active,thumbnail_url,category,show_in_catalog,created_at,updated_at&channel_id=eq.${cid}&order=created_at.desc`
      : `inventory_items?select=id,channel_id,name,sku,description,default_price_cents,currency_code,track_stock,stock_on_hand,low_stock_threshold,is_active,thumbnail_url,category,show_in_catalog,created_at,updated_at&channel_id=eq.${cid}&is_active=eq.true&order=created_at.desc`;

    const items = await adminGet(itemsQuery) as Array<Record<string, unknown>>;
    const itemIds = items.map((item) => String(item.id));
    const activeOrderStatuses = "requested,quoted,accepted,assigned,out_for_delivery,address_review";
    const activeOrders = await adminGet(
      `order_requests?select=id&channel_id=eq.${cid}&status=in.(${activeOrderStatuses})&archived_at=is.null&limit=1000`,
    ) as Array<Record<string, unknown>>;
    const activeOrderIds = activeOrders.map((order) => String(order.id));
    const lineItems = activeOrderIds.length > 0
      ? await adminGet(
        `order_line_items?select=item_id,order_id&order_id=in.(${activeOrderIds.map(encodeURIComponent).join(",")})`,
      ) as Array<Record<string, unknown>>
      : [];
    const activeOrderCountByItem = new Map<string, number>();
    for (const lineItem of lineItems) {
      const itemId = String(lineItem.item_id ?? "");
      if (!itemId) continue;
      activeOrderCountByItem.set(itemId, (activeOrderCountByItem.get(itemId) ?? 0) + 1);
    }

    const variants = itemIds.length > 0
      ? await adminGet(
        `inventory_item_variants?select=id,item_id,name,sku,price_cents,stock_on_hand,is_active,created_at,updated_at&item_id=in.(${itemIds.map(encodeURIComponent).join(",")})&order=created_at.asc`
      ) as Array<Record<string, unknown>>
      : [];

    const groupedVariants: Record<string, Array<Record<string, unknown>>> = {};
    for (const variant of variants) {
      const itemId = String(variant.item_id);
      if (!groupedVariants[itemId]) groupedVariants[itemId] = [];
      groupedVariants[itemId].push(variant);
    }

    const dataItems = items.map((item) => ({
      ...item,
      active_order_count: typeof item.active_order_count === "number"
        ? item.active_order_count
        : (activeOrderCountByItem.get(String(item.id)) ?? 0),
      variants: groupedVariants[String(item.id)] ?? [],
    }));

    const includeLedger = body.include_ledger ?? false;
    const ledger = includeLedger
      ? await adminGet(
        `inventory_stock_ledger?select=id,item_id,variant_id,delta,balance_after,reason,metadata_json,created_at&channel_id=eq.${cid}&order=created_at.desc&limit=100`
      ) as Array<Record<string, unknown>>
      : [];

    return ok(rid, {
      channel_id: body.channel_id,
      items: dataItems,
      ledger,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
