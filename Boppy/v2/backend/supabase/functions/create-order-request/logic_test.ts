import { assertEquals } from "jsr:@std/assert@1";
import { nextOrderStatusFromGeocode } from "./logic.ts";

Deno.test("returns requested when geocode succeeds", () => {
  assertEquals(nextOrderStatusFromGeocode({ lat: 30.2, lng: -97.7 }), "requested");
});

Deno.test("returns address_review when geocode is missing", () => {
  assertEquals(nextOrderStatusFromGeocode(null), "address_review");
});

