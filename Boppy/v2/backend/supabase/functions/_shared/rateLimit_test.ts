import { assert, assertStringIncludes } from "jsr:@std/assert@1";
import { buildAdminActionRateLimitQuery } from "./rateLimit.ts";

Deno.test("buildAdminActionRateLimitQuery includes actor, channel, and single action filter", () => {
  const query = buildAdminActionRateLimitQuery({
    actorId: "user-123",
    channelId: "chan-1",
    actions: ["invite_created"],
    windowSeconds: 3600,
    maxEvents: 25,
  });

  assertStringIncludes(query, "admin_audit_events?select=id");
  assertStringIncludes(query, "actor_id=eq.user-123");
  assertStringIncludes(query, "&channel_id=eq.chan-1");
  assertStringIncludes(query, "&action=eq.invite_created");
  assertStringIncludes(query, "&limit=25");
});

Deno.test("buildAdminActionRateLimitQuery uses multi-action in filter when needed", () => {
  const query = buildAdminActionRateLimitQuery({
    actorId: "owner-9",
    actions: ["order_soft_deleted", "order_hard_deleted"],
    windowSeconds: 1800,
    maxEvents: 30,
  });

  assert(!query.includes("&channel_id="));
  assertStringIncludes(query, "&action=in.(order_soft_deleted,order_hard_deleted)");
  assertStringIncludes(query, "&limit=30");
});
