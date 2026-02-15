import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { appendLedger } from "../_shared/ledger.ts";
import { adminDelete, adminGet, adminPost, SupabaseRequestError } from "../_shared/supabase.ts";

interface LineItemInput {
  item_id?: string;
  variant_id?: string;
  title: string;
  sku: string;
  quantity: number;
  unit_price_cents: number;
}

interface OrderUpsertLineItemsBody {
  order_id: string;
  line_items: LineItemInput[];
}

interface OrderRow {
  id: string;
  channel_id: string;
}

interface InventoryItemRow {
  id: string;
  channel_id: string;
}

interface InventoryVariantRow {
  id: string;
  item_id: string;
}

function inFilter(values: readonly string[]): string {
  return values.map((value) => encodeURIComponent(value)).join(",");
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<OrderUpsertLineItemsBody>(req);

    assert(body.order_id, 400, "invalid_request", "order_id is required.");
    assert(Array.isArray(body.line_items), 400, "invalid_request", "line_items must be an array.");
    assert(body.line_items.length > 0, 400, "invalid_request", "line_items cannot be empty.");
    assert(body.line_items.length <= 100, 400, "invalid_request", "line_items cannot exceed 100 rows.");

    const orderRows = await adminGet(
      `order_requests?select=id,channel_id&id=eq.${encodeURIComponent(body.order_id)}&limit=1`
    ) as OrderRow[];
    const order = orderRows[0];
    assert(order, 404, "order_not_found", "Order not found.");

    await requireChannelRole(order.channel_id, user.id, "owner");

    const itemIDs = [...new Set(body.line_items.map((line) => line.item_id).filter((value): value is string => Boolean(value)))];
    const variantIDs = [...new Set(body.line_items.map((line) => line.variant_id).filter((value): value is string => Boolean(value)))];

    const itemRows = itemIDs.length > 0
      ? await adminGet(
        `inventory_items?select=id,channel_id&id=in.(${inFilter(itemIDs)})&channel_id=eq.${encodeURIComponent(order.channel_id)}`
      ) as InventoryItemRow[]
      : [];

    const itemMap = new Map(itemRows.map((row) => [row.id, row]));
    assert(
      itemMap.size === itemIDs.length,
      400,
      "invalid_inventory_reference",
      "One or more item_id values do not belong to this channel."
    );

    const variantRows = variantIDs.length > 0
      ? await adminGet(
        `inventory_item_variants?select=id,item_id&id=in.(${inFilter(variantIDs)})`
      ) as InventoryVariantRow[]
      : [];
    const variantMap = new Map(variantRows.map((row) => [row.id, row]));
    assert(
      variantMap.size === variantIDs.length,
      400,
      "invalid_inventory_reference",
      "One or more variant_id values were not found."
    );

    const lineItems = body.line_items.map((line, index) => {
      assert(line.title?.trim(), 400, "invalid_request", `line_items[${index}].title is required.`);
      assert(line.sku?.trim(), 400, "invalid_request", `line_items[${index}].sku is required.`);
      assert(Number.isInteger(line.quantity) && line.quantity > 0, 400, "invalid_request", `line_items[${index}].quantity must be > 0.`);
      assert(
        Number.isInteger(line.unit_price_cents) && line.unit_price_cents >= 0,
        400,
        "invalid_request",
        `line_items[${index}].unit_price_cents must be >= 0.`
      );

      if (line.item_id) {
        assert(
          itemMap.has(line.item_id),
          400,
          "invalid_inventory_reference",
          `line_items[${index}].item_id does not belong to the order channel.`
        );
      }

      if (line.variant_id) {
        const variant = variantMap.get(line.variant_id);
        assert(
          variant,
          400,
          "invalid_inventory_reference",
          `line_items[${index}].variant_id was not found.`
        );
        if (line.item_id) {
          assert(
            variant.item_id === line.item_id,
            400,
            "invalid_inventory_reference",
            `line_items[${index}].variant_id does not belong to line_items[${index}].item_id.`
          );
        } else {
          assert(
            itemMap.has(variant.item_id),
            400,
            "invalid_inventory_reference",
            `line_items[${index}].variant_id item does not belong to the order channel.`
          );
        }
      }

      return {
        order_id: order.id,
        item_id: line.item_id ?? null,
        variant_id: line.variant_id ?? null,
        title: line.title.trim(),
        sku: line.sku.trim(),
        quantity: line.quantity,
        unit_price_cents: line.unit_price_cents,
      };
    });

    const deletedRows = await adminDelete(
      `order_line_items?order_id=eq.${encodeURIComponent(order.id)}&select=id`
    ) as Array<{ id: string }>;

    const rows = await adminPost(
      "order_line_items?select=id,order_id,item_id,variant_id,title,sku,quantity,unit_price_cents,line_total_cents,created_at",
      lineItems
    ) as Array<Record<string, unknown>>;

    const lineTotalCents = lineItems.reduce((sum, line) => sum + (line.quantity * line.unit_price_cents), 0);

    await appendLedger(order.id, user.id, "order_line_items_upserted", {
      replaced_count: deletedRows.length,
      line_item_count: lineItems.length,
      line_total_cents: lineTotalCents,
    });

    await appendAdminAudit(
      order.channel_id,
      user.id,
      "order_line_items_upserted",
      "order_request",
      order.id,
      null,
      {
        replaced_count: deletedRows.length,
        line_item_count: lineItems.length,
        line_total_cents: lineTotalCents,
      }
    );

    return ok(rid, {
      order_id: order.id,
      line_items: rows,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
