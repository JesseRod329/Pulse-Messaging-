type RoleKey = "owner" | "driver" | "follower" | "anon";

interface Scenario {
  name: string;
  endpoint: string;
  role: RoleKey;
  expectedStatus: number;
  body: Record<string, unknown>;
}

interface ScenarioResult {
  scenario: Scenario;
  actualStatus: number;
  ok: boolean;
  requestId: string | null;
  errorCode: string | null;
  message: string | null;
}

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

function resolveFunctionsBaseUrl(): string {
  const explicit = Deno.env.get("SUPABASE_FUNCTIONS_BASE_URL");
  if (explicit) return explicit.replace(/\/$/, "");
  const supabaseUrl = env("SUPABASE_URL").replace(/\/$/, "");
  return `${supabaseUrl}/functions/v1`;
}

const channelId = env("RLS_CHANNEL_ID");
const baseUrl = resolveFunctionsBaseUrl();
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

const roleTokens: Record<Exclude<RoleKey, "anon">, string> = {
  owner: env("RLS_OWNER_TOKEN"),
  driver: env("RLS_DRIVER_TOKEN"),
  follower: env("RLS_FOLLOWER_TOKEN"),
};

const scenarios: Scenario[] = [
  {
    name: "inventory-list owner read",
    endpoint: "inventory-list",
    role: "owner",
    expectedStatus: 200,
    body: { channel_id: channelId, include_inactive: false, include_ledger: false },
  },
  {
    name: "inventory-list driver read",
    endpoint: "inventory-list",
    role: "driver",
    expectedStatus: 200,
    body: { channel_id: channelId, include_inactive: false, include_ledger: false },
  },
  {
    name: "inventory-list follower forbidden",
    endpoint: "inventory-list",
    role: "follower",
    expectedStatus: 403,
    body: { channel_id: channelId, include_inactive: false, include_ledger: false },
  },
  {
    name: "inventory-list anon unauthorized",
    endpoint: "inventory-list",
    role: "anon",
    expectedStatus: 401,
    body: { channel_id: channelId, include_inactive: false, include_ledger: false },
  },
  {
    name: "admin-orders-list owner read",
    endpoint: "admin-orders-list",
    role: "owner",
    expectedStatus: 200,
    body: { channel_id: channelId, limit: 1 },
  },
  {
    name: "admin-orders-list driver forbidden",
    endpoint: "admin-orders-list",
    role: "driver",
    expectedStatus: 403,
    body: { channel_id: channelId, limit: 1 },
  },
  {
    name: "admin-orders-list follower forbidden",
    endpoint: "admin-orders-list",
    role: "follower",
    expectedStatus: 403,
    body: { channel_id: channelId, limit: 1 },
  },
  {
    name: "admin-channel-members-list owner read",
    endpoint: "admin-channel-members-list",
    role: "owner",
    expectedStatus: 200,
    body: { channel_id: channelId, limit: 1 },
  },
  {
    name: "admin-channel-members-list driver forbidden",
    endpoint: "admin-channel-members-list",
    role: "driver",
    expectedStatus: 403,
    body: { channel_id: channelId, limit: 1 },
  },
  {
    name: "admin-audit-events-list owner read",
    endpoint: "admin-audit-events-list",
    role: "owner",
    expectedStatus: 200,
    body: { channel_id: channelId, limit: 1 },
  },
  {
    name: "admin-audit-events-list follower forbidden",
    endpoint: "admin-audit-events-list",
    role: "follower",
    expectedStatus: 403,
    body: { channel_id: channelId, limit: 1 },
  },
];

function tokenForRole(role: RoleKey): string | undefined {
  if (role == "anon") return undefined;
  return roleTokens[role];
}

async function runScenario(scenario: Scenario): Promise<ScenarioResult> {
  const token = tokenForRole(scenario.role);
  const response = await fetch(`${baseUrl}/${scenario.endpoint}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(anonKey ? { apikey: anonKey } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(scenario.body),
  });

  let payload: Record<string, unknown> | null = null;
  try {
    payload = await response.json() as Record<string, unknown>;
  } catch {
    payload = null;
  }

  const requestId = typeof payload?.request_id == "string" ? payload.request_id : null;
  const error = payload?.error as Record<string, unknown> | undefined;
  const errorCode = typeof error?.code == "string" ? error.code : null;
  const message = typeof error?.message == "string" ? error.message : null;

  return {
    scenario,
    actualStatus: response.status,
    ok: response.status === scenario.expectedStatus,
    requestId,
    errorCode,
    message,
  };
}

function printSummary(results: ScenarioResult[]): void {
  const passed = results.filter((result) => result.ok).length;
  const failed = results.length - passed;

  console.log("");
  console.log("RLS matrix results");
  console.log("==================");

  for (const result of results) {
    const status = result.ok ? "PASS" : "FAIL";
    const role = result.scenario.role.padEnd(8, " ");
    const expected = String(result.scenario.expectedStatus).padEnd(3, " ");
    const actual = String(result.actualStatus).padEnd(3, " ");
    const name = result.scenario.name;
    const suffix = result.errorCode ? ` (${result.errorCode})` : "";
    console.log(`[${status}] ${role} expected ${expected} got ${actual} - ${name}${suffix}`);
    if (!result.ok && result.message) {
      console.log(`       message: ${result.message}`);
    }
    if (!result.ok && result.requestId) {
      console.log(`       request_id: ${result.requestId}`);
    }
  }

  console.log("");
  console.log(`Total: ${results.length}  Passed: ${passed}  Failed: ${failed}`);
}

const results = await Promise.all(scenarios.map(runScenario));
printSummary(results);

const hasFailures = results.some((result) => !result.ok);
if (hasFailures) {
  Deno.exit(1);
}
