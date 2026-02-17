import { assert, assertEquals } from "jsr:@std/assert@1";

interface IntegrationConfig {
  supabaseURL: string;
  serviceRoleKey: string;
  orderID: string;
  actorID: string;
}

async function integrationConfig(): Promise<IntegrationConfig | null> {
  const envPermission = await Deno.permissions.query({ name: "env" });
  if (envPermission.state !== "granted") {
    return null;
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const orderID = Deno.env.get("BEAMBOX_INVENTORY_ATOMIC_TEST_ORDER_ID");
  const actorID = Deno.env.get("BEAMBOX_INVENTORY_ATOMIC_TEST_ACTOR_ID");

  if (!supabaseURL || !serviceRoleKey || !orderID || !actorID) {
    return null;
  }

  return { supabaseURL, serviceRoleKey, orderID, actorID };
}

async function callInventoryRpc(config: IntegrationConfig, functionName: string): Promise<unknown> {
  const response = await fetch(`${config.supabaseURL}/rest/v1/rpc/${functionName}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "apikey": config.serviceRoleKey,
      "authorization": `Bearer ${config.serviceRoleKey}`,
    },
    body: JSON.stringify({
      p_order_id: config.orderID,
      p_actor_id: config.actorID,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`RPC ${functionName} failed (${response.status}): ${text}`);
  }

  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

Deno.test("atomic inventory reserve/restock RPCs are idempotent under concurrency", async () => {
  const config = await integrationConfig();
  if (!config) {
    return;
  }

  const reserveSettled = await Promise.allSettled([
    callInventoryRpc(config, "reserve_order_inventory_atomic"),
    callInventoryRpc(config, "reserve_order_inventory_atomic"),
  ]);

  assertEquals(reserveSettled.filter((result) => result.status == "rejected").length, 0);

  const reserveMutations = reserveSettled
    .filter((result): result is PromiseFulfilledResult<unknown> => result.status == "fulfilled")
    .map((result) => result.value)
    .filter((value) => {
      if (value == null || typeof value !== "object") {
        return false;
      }
      const event = (value as Record<string, unknown>).event;
      return event == "order_inventory_reserved";
    });

  assert(reserveMutations.length <= 1);

  const restockSettled = await Promise.allSettled([
    callInventoryRpc(config, "restock_order_inventory_atomic"),
    callInventoryRpc(config, "restock_order_inventory_atomic"),
  ]);

  assertEquals(restockSettled.filter((result) => result.status == "rejected").length, 0);

  const restockMutations = restockSettled
    .filter((result): result is PromiseFulfilledResult<unknown> => result.status == "fulfilled")
    .map((result) => result.value)
    .filter((value) => {
      if (value == null || typeof value !== "object") {
        return false;
      }
      const event = (value as Record<string, unknown>).event;
      return event == "order_inventory_restocked";
    });

  assert(restockMutations.length <= 1);
});
