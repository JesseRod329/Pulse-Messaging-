import type { OrderStatus } from "../_shared/types.ts";

export function nextOrderStatusFromGeocode(
  geocoded: { lat: number; lng: number } | null,
): OrderStatus {
  return geocoded ? "requested" : "address_review";
}

