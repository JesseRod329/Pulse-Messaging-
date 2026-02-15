import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendLedger } from "../_shared/ledger.ts";
import { adminGet, adminPatch, adminPost, SupabaseRequestError } from "../_shared/supabase.ts";

interface BuildRouteBody {
  channel_id: string;
  driver_id: string;
  start_lat: number;
  start_lng: number;
}

interface RouteOrder {
  id: string;
  lat: number;
  lng: number;
}

interface Point {
  lat: number;
  lng: number;
}

function distanceKm(a: Point, b: Point): number {
  const toRad = (deg: number): number => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);

  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;

  return 2 * 6371 * Math.asin(Math.min(1, Math.sqrt(h)));
}

function nearestNeighbor(orders: RouteOrder[], start: Point): { orderedIds: string[]; etas: number[] } {
  const remaining = [...orders];
  const ordered: string[] = [];
  const etas: number[] = [];

  let current: Point = start;
  let elapsedMinutes = 0;

  while (remaining.length > 0) {
    let bestIndex = 0;
    let bestDistance = Number.POSITIVE_INFINITY;

    for (let i = 0; i < remaining.length; i += 1) {
      const candidate = remaining[i];
      const dist = distanceKm(current, { lat: candidate.lat, lng: candidate.lng });
      if (dist < bestDistance) {
        bestDistance = dist;
        bestIndex = i;
      }
    }

    const chosen = remaining.splice(bestIndex, 1)[0];
    elapsedMinutes += Math.max(4, Math.round((bestDistance / 35) * 60));
    ordered.push(chosen.id);
    etas.push(elapsedMinutes);
    current = { lat: chosen.lat, lng: chosen.lng };
  }

  return { orderedIds: ordered, etas };
}

async function mapboxOptimize(orders: RouteOrder[], start: Point): Promise<{ orderedIds: string[]; etas: number[] } | null> {
  const token = Deno.env.get("MAPBOX_ACCESS_TOKEN");
  if (!token) {
    return null;
  }

  const coordinates = [
    `${start.lng},${start.lat}`,
    ...orders.map((o) => `${o.lng},${o.lat}`),
  ].join(";");

  const url = new URL(`https://api.mapbox.com/optimized-trips/v1/mapbox/driving/${coordinates}`);
  url.searchParams.set("roundtrip", "false");
  url.searchParams.set("source", "first");
  url.searchParams.set("destination", "last");
  url.searchParams.set("geometries", "geojson");
  url.searchParams.set("overview", "simplified");
  url.searchParams.set("access_token", token);

  const response = await fetch(url.toString(), { method: "GET" });
  if (!response.ok) {
    return null;
  }

  const payload = await response.json();
  const waypoints = payload?.waypoints as Array<{ waypoint_index: number } | undefined>;
  if (!Array.isArray(waypoints) || waypoints.length < 2) {
    return null;
  }

  const reordered = waypoints
    .slice(1)
    .map((wp) => wp?.waypoint_index ?? -1)
    .filter((index) => index >= 1)
    .map((idx) => orders[idx - 1])
    .filter(Boolean);

  if (reordered.length !== orders.length) {
    return null;
  }

  return nearestNeighbor(reordered, start);
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<BuildRouteBody>(req);

    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");
    assert(body.driver_id, 400, "invalid_request", "driver_id is required.");
    assert(Number.isFinite(body.start_lat), 400, "invalid_request", "start_lat is required.");
    assert(Number.isFinite(body.start_lng), 400, "invalid_request", "start_lng is required.");

    await requireChannelRole(body.channel_id, user.id, "owner");
    await requireChannelRole(body.channel_id, body.driver_id, "driver");

    const cid = encodeURIComponent(body.channel_id);
    const did = encodeURIComponent(body.driver_id);
    const orders = await adminGet(
      `order_requests?select=id,lat,lng&channel_id=eq.${cid}&assigned_driver_id=eq.${did}&status=in.(assigned,accepted,quoted)&lat=not.is.null&lng=not.is.null`
    ) as RouteOrder[];

    assert(orders.length > 0, 404, "no_routable_orders", "No routable assigned orders found.");

    const start = { lat: body.start_lat, lng: body.start_lng };
    let approximate = false;

    const mapboxResult = await mapboxOptimize(orders, start);
    const plan = mapboxResult ?? nearestNeighbor(orders, start);
    if (!mapboxResult) {
      approximate = true;
    }

    const routeRows = await adminPost("delivery_routes?select=id,status,approximate,created_at", {
      channel_id: body.channel_id,
      driver_id: body.driver_id,
      status: "planned",
      approximate,
    }) as Array<{ id: string; status: string; approximate: boolean; created_at: string }>;

    const route = routeRows[0];
    assert(route, 500, "db_error", "Route creation failed.");

    const stopRows = plan.orderedIds.map((orderId, index) => ({
      route_id: route.id,
      order_id: orderId,
      stop_index: index,
      eta_minutes: plan.etas[index] ?? null,
    }));

    await adminPost("delivery_route_stops", stopRows);

    const orderIDs = plan.orderedIds.map((id) => encodeURIComponent(id)).join(",");
    await adminPatch(`order_requests?id=in.(${orderIDs})`, {
      status: "out_for_delivery",
    });

    for (const orderID of plan.orderedIds) {
      await appendLedger(orderID, user.id, "route_built", {
        route_id: route.id,
        approximate,
      });
    }

    return ok(rid, {
      route,
      stops: stopRows,
      approximate,
      fallback_reason: approximate ? "mapbox_unavailable_or_unusable" : null,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
