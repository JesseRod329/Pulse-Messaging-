import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { adminGet, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminRoutesListBody {
  channel_id: string;
  status?: string;
  limit?: number;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminRoutesListBody>(req);
    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");

    await requireChannelRole(body.channel_id, user.id, "owner");

    const limit = Math.max(1, Math.min(body.limit ?? 120, 300));
    const cid = encodeURIComponent(body.channel_id);
    const statusFilter = body.status?.trim()
      ? `&status=eq.${encodeURIComponent(body.status.trim())}`
      : "";

    const routes = await adminGet(
      `delivery_routes?select=id,channel_id,driver_id,status,approximate,created_at,started_at,completed_at,delivery_route_stops(id,order_id,stop_index,eta_minutes,completed_at)&channel_id=eq.${cid}${statusFilter}&order=created_at.desc&limit=${limit}`,
    ) as Array<Record<string, unknown>>;

    return ok(rid, {
      channel_id: body.channel_id,
      count: routes.length,
      routes,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
