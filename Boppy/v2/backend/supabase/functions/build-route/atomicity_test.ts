import { assertEquals } from "jsr:@std/assert@1";

interface IntegrationConfig {
  supabaseURL: string;
  serviceRoleKey: string;
  channelID: string;
  driverID: string;
  actorID: string;
  orderIDs: string[];
}

async function integrationConfig(): Promise<IntegrationConfig | null> {
  const envPermission = await Deno.permissions.query({ name: "env" });
  if (envPermission.state !== "granted") {
    return null;
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const channelID = Deno.env.get("BEAMBOX_ROUTE_ATOMIC_TEST_CHANNEL_ID");
  const driverID = Deno.env.get("BEAMBOX_ROUTE_ATOMIC_TEST_DRIVER_ID");
  const actorID = Deno.env.get("BEAMBOX_ROUTE_ATOMIC_TEST_ACTOR_ID");
  const rawOrderIDs = Deno.env.get("BEAMBOX_ROUTE_ATOMIC_TEST_ORDER_IDS");

  if (!supabaseURL || !serviceRoleKey || !channelID || !driverID || !actorID || !rawOrderIDs) {
    return null;
  }

  const orderIDs = rawOrderIDs.split(",").map((id) => id.trim()).filter(Boolean);
  if (orderIDs.length < 2) {
    return null;
  }

  return { supabaseURL, serviceRoleKey, channelID, driverID, actorID, orderIDs };
}

async function routeCount(config: IntegrationConfig): Promise<number> {
  const query = new URL(`${config.supabaseURL}/rest/v1/delivery_routes`);
  query.searchParams.set("select", "id");
  query.searchParams.set("channel_id", `eq.${config.channelID}`);
  query.searchParams.set("driver_id", `eq.${config.driverID}`);

  const response = await fetch(query.toString(), {
    method: "GET",
    headers: {
      "apikey": config.serviceRoleKey,
      "authorization": `Bearer ${config.serviceRoleKey}`,
    },
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`delivery_routes count query failed (${response.status}): ${text}`);
  }

  const payload = await response.json() as Array<{ id: string }>;
  return payload.length;
}

Deno.test("route build RPC rejects malformed payload without creating partial routes", async () => {
  const config = await integrationConfig();
  if (!config) {
    return;
  }

  const before = await routeCount(config);

  const response = await fetch(`${config.supabaseURL}/rest/v1/rpc/build_delivery_route`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "apikey": config.serviceRoleKey,
      "authorization": `Bearer ${config.serviceRoleKey}`,
    },
    body: JSON.stringify({
      p_channel_id: config.channelID,
      p_driver_id: config.driverID,
      p_actor_id: config.actorID,
      p_order_ids: config.orderIDs,
      // Mismatched lengths should fail validation before any inserts.
      p_etas: [5],
      p_approximate: true,
    }),
  });

  assertEquals(response.ok, false);

  const after = await routeCount(config);
  assertEquals(after, before);
});
