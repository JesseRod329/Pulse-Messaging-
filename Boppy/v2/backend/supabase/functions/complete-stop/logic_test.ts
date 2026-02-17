import { assertEquals } from "jsr:@std/assert@1";
import { canCompleteStop, nextRouteStatus } from "./logic.ts";

Deno.test("permits owner or assigned driver stop completion", () => {
  assertEquals(canCompleteStop(true, false), true);
  assertEquals(canCompleteStop(false, true), true);
  assertEquals(canCompleteStop(false, false), false);
});

Deno.test("computes next route status transitions", () => {
  assertEquals(nextRouteStatus("planned", 3), "in_progress");
  assertEquals(nextRouteStatus("in_progress", 3), null);
  assertEquals(nextRouteStatus("planned", 0), "completed");
  assertEquals(nextRouteStatus("in_progress", 0), "completed");
});

