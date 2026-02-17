import { assertEquals } from "jsr:@std/assert@1";
import { isLegalAssignmentStatus } from "./logic.ts";

Deno.test("allows legal assignment statuses", () => {
  assertEquals(isLegalAssignmentStatus("accepted"), true);
  assertEquals(isLegalAssignmentStatus("assigned"), true);
  assertEquals(isLegalAssignmentStatus("address_review"), true);
});

Deno.test("rejects illegal assignment statuses", () => {
  assertEquals(isLegalAssignmentStatus("requested"), false);
  assertEquals(isLegalAssignmentStatus("quoted"), false);
  assertEquals(isLegalAssignmentStatus("delivered"), false);
  assertEquals(isLegalAssignmentStatus("cancelled"), false);
});

