import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { adminGet, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminOrdersListBody {
  channel_id: string;
  status?: string;
  limit?: number;
  include_archived?: boolean;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminOrdersListBody>(req);
    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");

    await requireChannelRole(body.channel_id, user.id, "owner");

    const limit = Math.max(1, Math.min(body.limit ?? 100, 300));
    const cid = encodeURIComponent(body.channel_id);
    const statusFilter = body.status?.trim()
      ? `&status=eq.${encodeURIComponent(body.status.trim())}`
      : "";
    const archivedFilter = body.include_archived ? "" : "&archived_at=is.null";

    const orders = await adminGet(
      `order_requests?select=id,channel_id,post_id,customer_id,customer_phone,status,assigned_driver_id,quote_note,created_at,updated_at,archived_at&channel_id=eq.${cid}${statusFilter}${archivedFilter}&order=created_at.desc&limit=${limit}`,
    ) as Array<Record<string, unknown>>;

    return ok(rid, {
      channel_id: body.channel_id,
      count: orders.length,
      orders,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
