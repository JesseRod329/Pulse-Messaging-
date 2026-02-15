import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireUser } from "../_shared/auth.ts";
import { appendLedger } from "../_shared/ledger.ts";
import { adminGet, adminPatch, SupabaseRequestError } from "../_shared/supabase.ts";

interface CompleteStopBody {
  route_id: string;
  stop_id?: string;
  order_id?: string;
}

interface RouteRow {
  id: string;
  channel_id: string;
  driver_id: string;
  status: string;
  started_at: string | null;
}

interface StopRow {
  id: string;
  order_id: string;
  completed_at: string | null;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<CompleteStopBody>(req);

    assert(body.route_id, 400, "invalid_request", "route_id is required.");
    assert(body.stop_id || body.order_id, 400, "invalid_request", "stop_id or order_id is required.");

    const routeRows = await adminGet(
      `delivery_routes?select=id,channel_id,driver_id,status,started_at&id=eq.${encodeURIComponent(body.route_id)}&limit=1`
    ) as RouteRow[];

    const route = routeRows[0];
    assert(route, 404, "route_not_found", "Route not found.");

    const ownerRows = await adminGet(
      `channels?select=id&id=eq.${encodeURIComponent(route.channel_id)}&owner_id=eq.${encodeURIComponent(user.id)}&limit=1`
    ) as Array<unknown>;

    const isOwner = ownerRows.length > 0;
    const isDriver = route.driver_id == user.id;
    assert(isOwner || isDriver, 403, "forbidden", "Only route owner or assigned driver can complete stops.");

    const stopFilters = [
      `route_id=eq.${encodeURIComponent(route.id)}`,
      body.stop_id ? `id=eq.${encodeURIComponent(body.stop_id)}` : null,
      body.order_id ? `order_id=eq.${encodeURIComponent(body.order_id)}` : null,
      "limit=1",
    ].filter(Boolean).join("&");

    const stopRows = await adminGet(
      `delivery_route_stops?select=id,order_id,completed_at&${stopFilters}`
    ) as StopRow[];

    const stop = stopRows[0];
    assert(stop, 404, "stop_not_found", "Route stop not found.");

    if (stop.completed_at == null) {
      await adminPatch(`delivery_route_stops?id=eq.${encodeURIComponent(stop.id)}`, {
        completed_at: new Date().toISOString(),
      });
    }

    await adminPatch(`order_requests?id=eq.${encodeURIComponent(stop.order_id)}`, {
      status: "delivered",
    });

    await appendLedger(stop.order_id, user.id, "order_delivered", {
      route_id: route.id,
      stop_id: stop.id,
    });

    const remainingRows = await adminGet(
      `delivery_route_stops?select=id&route_id=eq.${encodeURIComponent(route.id)}&completed_at=is.null`
    ) as Array<unknown>;

    if (remainingRows.length == 0) {
      await adminPatch(`delivery_routes?id=eq.${encodeURIComponent(route.id)}`, {
        status: "completed",
        completed_at: new Date().toISOString(),
        started_at: route.started_at ?? new Date().toISOString(),
      });
    } else if (route.status == "planned") {
      await adminPatch(`delivery_routes?id=eq.${encodeURIComponent(route.id)}`, {
        status: "in_progress",
        started_at: route.started_at ?? new Date().toISOString(),
      });
    }

    return ok(rid, {
      route_id: route.id,
      order_id: stop.order_id,
      remaining_stops: remainingRows.length,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
