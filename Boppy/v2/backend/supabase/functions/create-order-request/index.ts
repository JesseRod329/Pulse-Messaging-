import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { appendLedger } from "../_shared/ledger.ts";
import { adminGet, adminPost, SupabaseRequestError } from "../_shared/supabase.ts";
import type { OrderStatus } from "../_shared/types.ts";

interface DeliveryAddress {
  line1: string;
  line2?: string;
  city: string;
  state: string;
  postal_code: string;
  country?: string;
}

interface CreateOrderRequestBody {
  channel_id: string;
  post_id: string;
  quote_note: string;
  delivery_address: DeliveryAddress;
}

async function geocode(address: DeliveryAddress): Promise<{ lat: number; lng: number } | null> {
  const token = Deno.env.get("MAPBOX_ACCESS_TOKEN");
  if (!token) {
    return null;
  }

  const query = [
    address.line1,
    address.line2,
    address.city,
    address.state,
    address.postal_code,
    address.country ?? "US",
  ]
    .filter(Boolean)
    .join(", ");

  const url = new URL(`https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(query)}.json`);
  url.searchParams.set("limit", "1");
  url.searchParams.set("access_token", token);

  const response = await fetch(url.toString(), { method: "GET" });
  if (!response.ok) {
    return null;
  }

  const payload = await response.json();
  const center = payload?.features?.[0]?.center;
  if (!Array.isArray(center) || center.length < 2) {
    return null;
  }

  return { lng: Number(center[0]), lat: Number(center[1]) };
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<CreateOrderRequestBody>(req);

    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");
    assert(body.post_id, 400, "invalid_request", "post_id is required.");
    assert(body.quote_note, 400, "invalid_request", "quote_note is required.");
    assert(body.delivery_address?.line1, 400, "invalid_request", "delivery_address.line1 is required.");
    assert(body.delivery_address?.city, 400, "invalid_request", "delivery_address.city is required.");
    assert(body.delivery_address?.state, 400, "invalid_request", "delivery_address.state is required.");
    assert(body.delivery_address?.postal_code, 400, "invalid_request", "delivery_address.postal_code is required.");

    await requireChannelRole(body.channel_id, user.id, "follower");

    const postRows = await adminGet(
      `posts?select=id&channel_id=eq.${encodeURIComponent(body.channel_id)}&id=eq.${encodeURIComponent(body.post_id)}&limit=1`
    ) as Array<unknown>;
    assert(postRows.length > 0, 404, "post_not_found", "Post not found in channel.");

    const profileRows = await adminGet(
      `profiles?select=phone_e164&id=eq.${encodeURIComponent(user.id)}&limit=1`
    ) as Array<{ phone_e164: string }>;
    const profile = profileRows[0];
    assert(profile, 404, "profile_not_found", "Profile not found for current user.");

    const geocoded = await geocode(body.delivery_address);
    const status: OrderStatus = geocoded ? "requested" : "address_review";

    const insertedRows = await adminPost(
      "order_requests?select=id,channel_id,status,lat,lng,created_at",
      {
        channel_id: body.channel_id,
        post_id: body.post_id,
        customer_id: user.id,
        customer_phone: profile.phone_e164,
        delivery_address_json: body.delivery_address,
        lat: geocoded?.lat ?? null,
        lng: geocoded?.lng ?? null,
        quote_note: body.quote_note,
        status,
      }
    ) as Array<{ id: string; channel_id: string; status: string; lat: number | null; lng: number | null; created_at: string }>;

    const inserted = insertedRows[0];
    assert(inserted, 500, "db_error", "Order creation failed.");

    if (!geocoded) {
      await appendLedger(inserted.id, user.id, "address_geocode_failed", {
        reason: "mapbox_no_match",
      });
    }

    return ok(rid, inserted, 201);
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
