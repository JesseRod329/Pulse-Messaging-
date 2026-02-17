import { assertEquals } from "jsr:@std/assert@1";
import { canTransition } from "./transitions.ts";
import type { OrderStatus } from "../_shared/types.ts";

Deno.test("allows self transitions for idempotent updates", () => {
  const statuses: OrderStatus[] = [
    "requested",
    "quoted",
    "accepted",
    "assigned",
    "out_for_delivery",
    "delivered",
    "cancelled",
    "address_review",
  ];

  for (const status of statuses) {
    assertEquals(canTransition(status, status), true);
  }
});

Deno.test("accepts legal transitions in owner workflow", () => {
  assertEquals(canTransition("requested", "quoted"), true);
  assertEquals(canTransition("quoted", "accepted"), true);
  assertEquals(canTransition("accepted", "assigned"), true);
  assertEquals(canTransition("assigned", "out_for_delivery"), true);
  assertEquals(canTransition("out_for_delivery", "delivered"), true);
});

Deno.test("rejects illegal status jumps and terminal exits", () => {
  assertEquals(canTransition("requested", "assigned"), false);
  assertEquals(canTransition("quoted", "delivered"), false);
  assertEquals(canTransition("cancelled", "requested"), false);
  assertEquals(canTransition("delivered", "cancelled"), false);
});

Deno.test("supports address review recovery path", () => {
  assertEquals(canTransition("requested", "address_review"), true);
  assertEquals(canTransition("address_review", "requested"), true);
  assertEquals(canTransition("address_review", "quoted"), true);
  assertEquals(canTransition("address_review", "accepted"), true);
  assertEquals(canTransition("address_review", "assigned"), true);
  assertEquals(canTransition("address_review", "cancelled"), true);
  assertEquals(canTransition("address_review", "out_for_delivery"), false);
});
