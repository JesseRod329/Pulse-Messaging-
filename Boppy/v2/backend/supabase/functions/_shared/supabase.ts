export class SupabaseRequestError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

function readSupabaseConfig(): { url: string; serviceRoleKey: string; anonKey: string } {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!url || !serviceRoleKey || !anonKey) {
    throw new Error("Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or SUPABASE_ANON_KEY.");
  }

  return { url, serviceRoleKey, anonKey };
}

function adminHeaders(preferRepresentation = false): Headers {
  const config = readSupabaseConfig();
  const headers = new Headers();
  headers.set("content-type", "application/json");
  headers.set("apikey", config.serviceRoleKey);
  headers.set("authorization", `Bearer ${config.serviceRoleKey}`);

  if (preferRepresentation) {
    headers.set("prefer", "return=representation");
  }

  return headers;
}

async function parsePayload(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) {
    return null;
  }

  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function handleResponse(response: Response): Promise<unknown> {
  const payload = await parsePayload(response);

  if (!response.ok) {
    const message = typeof payload === "object" && payload && "message" in payload
      ? String((payload as { message: string }).message)
      : `Supabase request failed with status ${response.status}`;
    throw new SupabaseRequestError(response.status, message);
  }

  return payload;
}

export async function adminGet(path: string): Promise<unknown> {
  const { url } = readSupabaseConfig();
  const response = await fetch(`${url}/rest/v1/${path}`, {
    method: "GET",
    headers: adminHeaders(false),
  });
  return handleResponse(response);
}

export async function adminPost(path: string, body: unknown): Promise<unknown> {
  const { url } = readSupabaseConfig();
  const response = await fetch(`${url}/rest/v1/${path}`, {
    method: "POST",
    headers: adminHeaders(true),
    body: JSON.stringify(body),
  });
  return handleResponse(response);
}

export async function adminPatch(path: string, body: unknown): Promise<unknown> {
  const { url } = readSupabaseConfig();
  const response = await fetch(`${url}/rest/v1/${path}`, {
    method: "PATCH",
    headers: adminHeaders(true),
    body: JSON.stringify(body),
  });
  return handleResponse(response);
}

export async function adminDelete(path: string): Promise<unknown> {
  const { url } = readSupabaseConfig();
  const response = await fetch(`${url}/rest/v1/${path}`, {
    method: "DELETE",
    headers: adminHeaders(true),
  });
  return handleResponse(response);
}

export async function adminRpc(fnName: string, body: unknown): Promise<unknown> {
  const { url } = readSupabaseConfig();
  const response = await fetch(`${url}/rest/v1/rpc/${fnName}`, {
    method: "POST",
    headers: adminHeaders(false),
    body: JSON.stringify(body),
  });
  return handleResponse(response);
}

export async function authUserFromToken(token: string): Promise<unknown> {
  const config = readSupabaseConfig();
  const response = await fetch(`${config.url}/auth/v1/user`, {
    method: "GET",
    headers: new Headers({
      "apikey": config.anonKey,
      "authorization": `Bearer ${token}`,
    }),
  });

  return handleResponse(response);
}
