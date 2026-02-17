import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendLedger } from "../_shared/ledger.ts";
import { adminGet, adminPatch, SupabaseRequestError } from "../_shared/supabase.ts";

interface ReorderRouteStopsBody {
  route_id: string;
  ordered_stop_ids: string[];
}

interface RouteRow {
  id: string;
  channel_id: string;
  status: string;
}

interface StopRow {
  id: string;
  order_id: string;
  stop_index: number;
}

function isUnique(values: string[]): boolean {
  return new Set(values).size == values.length;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<ReorderRouteStopsBody>(req);

    assert(body.route_id, 400, "invalid_request", "route_id is required.");
    assert(Array.isArray(body.ordered_stop_ids), 400, "invalid_request", "ordered_stop_ids must be an array.");
    assert(body.ordered_stop_ids.length > 0, 400, "invalid_request", "ordered_stop_ids cannot be empty.");
    assert(isUnique(body.ordered_stop_ids), 400, "invalid_request", "ordered_stop_ids must contain unique stop IDs.");

    const routeRows = await adminGet(
      `delivery_routes?select=id,channel_id,status&id=eq.${encodeURIComponent(body.route_id)}&limit=1`
    ) as RouteRow[];

    const route = routeRows[0];
    assert(route, 404, "route_not_found", "Route not found.");

    await requireChannelRole(route.channel_id, user.id, "owner");
    assert(route.status == "planned", 409, "invalid_route_status", "Only planned routes can be reordered.");

    const stops = await adminGet(
      `delivery_route_stops?select=id,order_id,stop_index&route_id=eq.${encodeURIComponent(route.id)}`
    ) as StopRow[];

    assert(stops.length > 0, 404, "stops_not_found", "No stops found for route.");
    assert(
      stops.length == body.ordered_stop_ids.length,
      400,
      "stop_mismatch",
      "ordered_stop_ids must include every stop in this route."
    );

    const existingById = new Map(stops.map((stop) => [stop.id, stop]));
    for (const stopID of body.ordered_stop_ids) {
      assert(existingById.has(stopID), 400, "stop_mismatch", `Stop ${stopID} does not belong to route.`);
    }

    const existingOrderedIDs = stops
      .slice()
      .sort((a, b) => a.stop_index - b.stop_index)
      .map((stop) => stop.id);

    for (const [index, stopID] of existingOrderedIDs.entries()) {
      await adminPatch(
        `delivery_route_stops?id=eq.${encodeURIComponent(stopID)}&route_id=eq.${encodeURIComponent(route.id)}&select=id`,
        { stop_index: 1000 + index }
      );
    }

    for (const [index, stopID] of body.ordered_stop_ids.entries()) {
      const etaMinutes = Math.max(5, (index + 1) * 8);
      await adminPatch(
        `delivery_route_stops?id=eq.${encodeURIComponent(stopID)}&route_id=eq.${encodeURIComponent(route.id)}&select=id`,
        {
          stop_index: index,
          eta_minutes: etaMinutes,
        }
      );

      const stop = existingById.get(stopID);
      if (stop) {
        await appendLedger(stop.order_id, user.id, "route_reordered", {
          route_id: route.id,
          stop_id: stopID,
          stop_index: index,
          eta_minutes: etaMinutes,
        });
      }
    }

    return ok(rid, {
      route_id: route.id,
      stop_count: body.ordered_stop_ids.length,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
