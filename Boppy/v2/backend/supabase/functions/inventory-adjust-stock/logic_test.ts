import { assertEquals } from "jsr:@std/assert@1";
import { computeBalanceAfter } from "./logic.ts";

Deno.test("computes positive stock adjustments", () => {
  assertEquals(computeBalanceAfter(8, 4), 12);
});

Deno.test("computes negative stock adjustments", () => {
  assertEquals(computeBalanceAfter(8, -3), 5);
});

