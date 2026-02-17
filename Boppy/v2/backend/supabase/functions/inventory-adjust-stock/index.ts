import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendAdminAudit } from "../_shared/adminAudit.ts";
import { enforceAdminActionRateLimit } from "../_shared/rateLimit.ts";
import { adminGet, adminPatch, adminPost, SupabaseRequestError } from "../_shared/supabase.ts";
import { computeBalanceAfter } from "./logic.ts";

interface InventoryAdjustStockBody {
  channel_id: string;
  item_id: string;
  variant_id?: string;
  delta: number;
  reason: string;
}

interface ItemRow {
  id: string;
  stock_on_hand: number;
}

interface VariantRow {
  id: string;
  stock_on_hand: number;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<InventoryAdjustStockBody>(req);

    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");
    assert(body.item_id, 400, "invalid_request", "item_id is required.");
    assert(Number.isInteger(body.delta), 400, "invalid_request", "delta must be an integer.");
    assert(body.reason?.trim(), 400, "invalid_request", "reason is required.");

    await requireChannelRole(body.channel_id, user.id, "owner");
    await enforceAdminActionRateLimit({
      actorId: user.id,
      channelId: body.channel_id,
      actions: ["inventory_stock_adjusted"],
      windowSeconds: 5 * 60,
      maxEvents: 60,
    });

    const itemRows = await adminGet(
      `inventory_items?select=id,stock_on_hand&id=eq.${encodeURIComponent(body.item_id)}&channel_id=eq.${encodeURIComponent(body.channel_id)}&limit=1`
    ) as ItemRow[];
    const item = itemRows[0];
    assert(item, 404, "item_not_found", "Inventory item not found.");

    let balanceAfter: number;

    if (body.variant_id) {
      const variantRows = await adminGet(
        `inventory_item_variants?select=id,stock_on_hand&id=eq.${encodeURIComponent(body.variant_id)}&item_id=eq.${encodeURIComponent(body.item_id)}&limit=1`
      ) as VariantRow[];
      const variant = variantRows[0];
      assert(variant, 404, "variant_not_found", "Variant not found.");

      balanceAfter = computeBalanceAfter(variant.stock_on_hand, body.delta);
      assert(balanceAfter >= 0, 409, "insufficient_stock", "Stock cannot be negative.");

      await adminPatch(
        `inventory_item_variants?id=eq.${encodeURIComponent(variant.id)}&select=id,stock_on_hand`,
        { stock_on_hand: balanceAfter }
      );
    } else {
      balanceAfter = computeBalanceAfter(item.stock_on_hand, body.delta);
      assert(balanceAfter >= 0, 409, "insufficient_stock", "Stock cannot be negative.");

      await adminPatch(
        `inventory_items?id=eq.${encodeURIComponent(item.id)}&select=id,stock_on_hand`,
        { stock_on_hand: balanceAfter }
      );
    }

    const ledgerRows = await adminPost("inventory_stock_ledger?select=id,item_id,variant_id,delta,balance_after,reason,created_at", {
      channel_id: body.channel_id,
      item_id: body.item_id,
      variant_id: body.variant_id ?? null,
      actor_id: user.id,
      delta: body.delta,
      balance_after: balanceAfter,
      reason: body.reason.trim(),
      metadata_json: {},
    }) as Array<Record<string, unknown>>;
    const ledger = ledgerRows[0];
    assert(ledger, 500, "db_error", "Inventory stock event insert failed.");

    await appendAdminAudit(
      body.channel_id,
      user.id,
      "inventory_stock_adjusted",
      body.variant_id ? "inventory_variant" : "inventory_item",
      body.variant_id ?? body.item_id,
      body.reason.trim(),
      {
        item_id: body.item_id,
        variant_id: body.variant_id ?? null,
        delta: body.delta,
        balance_after: balanceAfter,
      }
    );

    return ok(rid, ledger);
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
