import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { adminGet, adminRpc, SupabaseRequestError } from "../_shared/supabase.ts";

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

interface RpcRoutePayload {
  route: {
    id: string;
    status: string;
    approximate: boolean;
    created_at: string;
  };
  stops: Array<{
    route_id: string;
    order_id: string;
    stop_index: number;
    eta_minutes: number | null;
  }>;
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

function coerceRoutePayload(payload: unknown): RpcRoutePayload {
  const normalized = Array.isArray(payload) ? payload[0] : payload;
  const value = normalized as Record<string, unknown>;
  const nested = (value?.build_delivery_route ?? value) as Record<string, unknown>;

  const route = nested?.route as Record<string, unknown> | undefined;
  const stops = nested?.stops as Array<Record<string, unknown>> | undefined;

  if (!route || !Array.isArray(stops)) {
    throw new ApiHttpError(500, "db_error", "Route build returned an unexpected payload.");
  }

  return {
    route: {
      id: String(route.id),
      status: String(route.status),
      approximate: Boolean(route.approximate),
      created_at: String(route.created_at),
    },
    stops: stops.map((stop) => ({
      route_id: String(stop.route_id),
      order_id: String(stop.order_id),
      stop_index: Number(stop.stop_index),
      eta_minutes: stop.eta_minutes == null ? null : Number(stop.eta_minutes),
    })),
  };
}

function mapRouteRpcError(error: SupabaseRequestError): ApiHttpError {
  const message = error.message.toLowerCase();

  if (message.includes("no_routable_orders")) {
    return new ApiHttpError(404, "no_routable_orders", "No routable assigned orders found.");
  }

  if (message.includes("invalid_request")) {
    return new ApiHttpError(400, "invalid_request", "Route build payload is invalid.");
  }

  return new ApiHttpError(500, "db_error", error.message);
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
    const mapboxResult = await mapboxOptimize(orders, start);
    const plan = mapboxResult ?? nearestNeighbor(orders, start);
    const approximate = mapboxResult == null;

    let rpcPayload: unknown;
    try {
      rpcPayload = await adminRpc("build_delivery_route", {
        p_channel_id: body.channel_id,
        p_driver_id: body.driver_id,
        p_actor_id: user.id,
        p_order_ids: plan.orderedIds,
        p_etas: plan.etas,
        p_approximate: approximate,
      });
    } catch (error) {
      if (error instanceof SupabaseRequestError) {
        throw mapRouteRpcError(error);
      }
      throw error;
    }

    const builtRoute = coerceRoutePayload(rpcPayload);

    return ok(rid, {
      route: builtRoute.route,
      stops: builtRoute.stops,
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
