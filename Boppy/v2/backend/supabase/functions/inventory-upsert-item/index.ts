import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { adminPatch, adminPost, SupabaseRequestError } from "../_shared/supabase.ts";

interface InventoryUpsertItemBody {
  channel_id: string;
  item_id?: string;
  name: string;
  sku: string;
  description?: string;
  default_price_cents: number;
  currency_code?: string;
  track_stock?: boolean;
  stock_on_hand?: number;
  low_stock_threshold?: number;
  is_active?: boolean;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<InventoryUpsertItemBody>(req);

    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");
    assert(body.name?.trim(), 400, "invalid_request", "name is required.");
    assert(body.sku?.trim(), 400, "invalid_request", "sku is required.");
    assert(Number.isInteger(body.default_price_cents) && body.default_price_cents >= 0, 400, "invalid_request", "default_price_cents must be >= 0.");

    await requireChannelRole(body.channel_id, user.id, "owner");

    const payload = {
      channel_id: body.channel_id,
      owner_id: user.id,
      name: body.name.trim(),
      sku: body.sku.trim(),
      description: body.description ?? "",
      default_price_cents: body.default_price_cents,
      currency_code: body.currency_code ?? "USD",
      track_stock: body.track_stock ?? true,
      stock_on_hand: body.stock_on_hand ?? 0,
      low_stock_threshold: body.low_stock_threshold ?? 0,
      is_active: body.is_active ?? true,
    };

    let rows: Array<Record<string, unknown>>;
    if (body.item_id) {
      rows = await adminPatch(
        `inventory_items?id=eq.${encodeURIComponent(body.item_id)}&channel_id=eq.${encodeURIComponent(body.channel_id)}&select=id,channel_id,name,sku,description,default_price_cents,currency_code,track_stock,stock_on_hand,low_stock_threshold,is_active,created_at,updated_at`,
        payload
      ) as Array<Record<string, unknown>>;
    } else {
      rows = await adminPost(
        "inventory_items?select=id,channel_id,name,sku,description,default_price_cents,currency_code,track_stock,stock_on_hand,low_stock_threshold,is_active,created_at,updated_at",
        payload
      ) as Array<Record<string, unknown>>;
    }

    const item = rows[0];
    assert(item, 500, "db_error", "Inventory upsert failed.");

    await appendAdminAudit(
      body.channel_id,
      user.id,
      body.item_id ? "inventory_item_updated" : "inventory_item_created",
      "inventory_item",
      String(item.id),
      null,
      { sku: body.sku.trim() }
    );

    return ok(rid, item);
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
