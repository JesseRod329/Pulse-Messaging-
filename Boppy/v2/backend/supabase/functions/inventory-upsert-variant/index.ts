import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { adminGet, adminPatch, adminPost, SupabaseRequestError } from "../_shared/supabase.ts";

interface InventoryUpsertVariantBody {
  channel_id: string;
  item_id: string;
  variant_id?: string;
  name: string;
  sku: string;
  price_cents: number;
  stock_on_hand?: number;
  is_active?: boolean;
}

interface ItemRow {
  id: string;
  channel_id: string;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<InventoryUpsertVariantBody>(req);

    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");
    assert(body.item_id, 400, "invalid_request", "item_id is required.");
    assert(body.name?.trim(), 400, "invalid_request", "name is required.");
    assert(body.sku?.trim(), 400, "invalid_request", "sku is required.");
    assert(Number.isInteger(body.price_cents) && body.price_cents >= 0, 400, "invalid_request", "price_cents must be >= 0.");

    await requireChannelRole(body.channel_id, user.id, "owner");

    const itemRows = await adminGet(
      `inventory_items?select=id,channel_id&id=eq.${encodeURIComponent(body.item_id)}&channel_id=eq.${encodeURIComponent(body.channel_id)}&limit=1`
    ) as ItemRow[];
    const item = itemRows[0];
    assert(item, 404, "item_not_found", "Inventory item not found in this channel.");

    const payload = {
      item_id: item.id,
      name: body.name.trim(),
      sku: body.sku.trim(),
      price_cents: body.price_cents,
      stock_on_hand: body.stock_on_hand ?? 0,
      is_active: body.is_active ?? true,
    };

    let rows: Array<Record<string, unknown>>;
    if (body.variant_id) {
      rows = await adminPatch(
        `inventory_item_variants?id=eq.${encodeURIComponent(body.variant_id)}&item_id=eq.${encodeURIComponent(item.id)}&select=id,item_id,name,sku,price_cents,stock_on_hand,is_active,created_at,updated_at`,
        payload
      ) as Array<Record<string, unknown>>;
    } else {
      rows = await adminPost(
        "inventory_item_variants?select=id,item_id,name,sku,price_cents,stock_on_hand,is_active,created_at,updated_at",
        payload
      ) as Array<Record<string, unknown>>;
    }

    const variant = rows[0];
    assert(variant, 500, "db_error", "Variant upsert failed.");

    await appendAdminAudit(
      body.channel_id,
      user.id,
      body.variant_id ? "inventory_variant_updated" : "inventory_variant_created",
      "inventory_variant",
      String(variant.id),
      null,
      { item_id: item.id, sku: body.sku.trim() }
    );

    return ok(rid, variant);
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
