import { assertEquals } from "jsr:@std/assert@1";
import { canHardDeleteStatus } from "./logic.ts";

Deno.test("allows hard delete only for terminal statuses", () => {
  assertEquals(canHardDeleteStatus("cancelled"), true);
  assertEquals(canHardDeleteStatus("delivered"), true);
  assertEquals(canHardDeleteStatus("requested"), false);
  assertEquals(canHardDeleteStatus("assigned"), false);
});

